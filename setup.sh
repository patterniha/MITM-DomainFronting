#!/bin/bash

# Ensure we are in the script's directory
cd "$(dirname "$0")" || exit 1

# Configuration
CONFIG_DIR="Xray-config"
CERT_NAME="mycert"

echo "--- MMDF Setup (Universal) ---"

# 1. Detect OS
OS="unknown"
if [[ "$OSTYPE" == "darwin"* ]]; then
  OS="macos"
elif [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "linux"* ]]; then
  OS="linux"
fi

if [ "$OS" == "unknown" ] && [ -f /etc/os-release ]; then
    OS="linux"
fi

echo "Detected OS: $OS"

# 2. Check for Xray
XRAY_PATH=$(command -v xray)
if [ -z "$XRAY_PATH" ]; then
    # Fallback to common Mac homebrew path if command fails
    if [ -f "/opt/homebrew/bin/xray" ]; then
        XRAY_PATH="/opt/homebrew/bin/xray"
    else
        echo "Error: 'xray' not found in PATH."
        echo "Please install Xray-core first."
        exit 1
    fi
fi
echo "Using Xray: $XRAY_PATH"

# 3. Generate Certificates
echo "[1/2] Generating certificates in $CONFIG_DIR..."
mkdir -p "$CONFIG_DIR"

if [ -f "$CONFIG_DIR/${CERT_NAME}.crt" ]; then
    echo "Files already exist. Skipping generation."
else
    # generate cert inside the directory to match json config
    cd "$CONFIG_DIR" || exit 1
    "$XRAY_PATH" tls cert -ca -file="$CERT_NAME"
    cd ..
fi

# 4. Add to Keychain/Trust Store
case "$OS" in
    macos)
        echo "[2/2] Adding ${CERT_NAME}.crt to macOS System Keychain... (Password required)"
        sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$CONFIG_DIR/${CERT_NAME}.crt"
        ;;
    linux)
        if command -v update-ca-certificates >/dev/null; then
            echo "[2/2] Adding ${CERT_NAME}.crt to Debian/Ubuntu trust store..."
            sudo cp "$CONFIG_DIR/${CERT_NAME}.crt" "/usr/local/share/ca-certificates/${CERT_NAME}.crt"
            sudo update-ca-certificates
        elif command -v update-ca-trust >/dev/null; then
            echo "[2/2] Adding ${CERT_NAME}.crt to RHEL/Fedora/CentOS trust store..."
            sudo cp "$CONFIG_DIR/${CERT_NAME}.crt" "/etc/pki/ca-trust/source/anchors/${CERT_NAME}.crt"
            sudo update-ca-trust
        else
            echo "[2/2] Linux detected but common trust store paths not found."
            echo "Please manually add $CONFIG_DIR/${CERT_NAME}.crt to your system's trust store."
        fi
        ;;
    *)
        echo "[2/2] OS not fully recognized. Please trust $CONFIG_DIR/${CERT_NAME}.crt manually."
        ;;
esac

echo "-----------------------"
echo "Setup finished!"
echo "Run './mmdf.sh start' to begin."

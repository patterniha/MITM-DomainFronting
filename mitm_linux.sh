#!/bin/bash

set -e

PROXY_HOST="127.0.0.1"
PROXY_PORT="10808"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERT_DIR="$SCRIPT_DIR/Xray-config"
CERT_FILE_NAME="mycert.crt"
KEY_FILE_NAME="mycert.key"
CERT_FILE="$CERT_DIR/$CERT_FILE_NAME"
KEY_FILE="$CERT_DIR/$KEY_FILE_NAME"
CONFIG_FILE="$CERT_DIR/MITM-DomainFronting.json"
SERVICE_NAME="xray-mitm"
XRAY_BIN=""

print_header() {
    echo "=========================================="
    echo "$1"
    echo "=========================================="
    echo ""
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS="$ID"
    else
        echo "Cannot detect Linux distribution"
        exit 1
    fi
}

check_xray_installed() {
    if [ -n "${XRAY_BIN}" ]; then
        return
    fi

    XRAY_PATHS=(
        "$(command -v xray 2>/dev/null || true)"
        "/opt/v2rayN/bin/xray/xray"
        "/opt/v2rayN/xray/xray"
        "/usr/local/bin/xray"
        "/usr/bin/xray"
    )

    for path in "${XRAY_PATHS[@]}"; do
        if [ -x "$path" ]; then
            XRAY_BIN="$path"
            XRAY_BIN_DIR="$(dirname "$XRAY_BIN")"
            break
        fi
    done

    if [ -z "$XRAY_BIN" ]; then
        echo "Error: xray is not installed!"
        echo "Run: sudo ./mitm_linux.sh install-xray"
        exit 1
    fi
}

sync_certificates_to_runtime_dirs() {
    local targets=("$CERT_DIR" "$XRAY_BIN_DIR" "/opt/v2rayN/bin/xray" "/opt/v2rayN/xray")
    local unique_targets=()
    local target
    local copied_any=false

    for target in "${targets[@]}"; do
        if [ -z "$target" ] || [ ! -d "$target" ] || [ ! -w "$target" ]; then
            continue
        fi

        local exists=false
        for existing in "${unique_targets[@]}"; do
            if [ "$existing" = "$target" ]; then
                exists=true
            fi
        done

        if [ "$exists" = false ]; then
            unique_targets+=("$target")
        fi
    done

    for target in "${unique_targets[@]}"; do
        local cert_target="$target/$CERT_FILE_NAME"
        local key_target="$target/$KEY_FILE_NAME"

        if [ "$cert_target" = "$CERT_FILE" ] && [ "$key_target" = "$KEY_FILE" ]; then
            copied_any=true
            echo "  - Already present: $target"
            continue
        fi

        if cp "$CERT_FILE" "$cert_target" && cp "$KEY_FILE" "$key_target"; then
            copied_any=true
            echo "  - Synced into: $target"
        else
            echo "  - Could not sync into: $target (permission issue)"
        fi
    done

    if [ "$copied_any" = false ]; then
        echo "Warning: No writable certificate target directories found."
        return 1
    fi

    return 0
}

restore_certificates_from_known_locations() {
    local sources=("$SCRIPT_DIR" "$XRAY_BIN_DIR" "/opt/v2rayN/bin/xray" "/opt/v2rayN/xray")

    for source in "${sources[@]}"; do
        if [ -z "$source" ] || [ ! -f "$source/$CERT_FILE_NAME" ] || [ ! -f "$source/$KEY_FILE_NAME" ]; then
            continue
        fi

        cp "$source/$CERT_FILE_NAME" "$CERT_FILE"
        cp "$source/$KEY_FILE_NAME" "$KEY_FILE"
        return 0
    done

    return 1
}

install_xray() {
    print_header "Xray-core Installation Script for Linux"

    detect_os
    echo "Detected OS: $OS"
    echo ""

    if [ "$EUID" -ne 0 ]; then
        echo "This command requires root privileges for system-wide installation."
        echo "Please run with sudo: sudo ./mitm_linux.sh install-xray"
        exit 1
    fi

    echo "Installing dependencies..."
    case $OS in
        fedora|rhel|centos|rocky|almalinux)
            dnf install -y wget unzip curl
            ;;
        debian|ubuntu|linuxmint)
            apt-get update
            apt-get install -y wget unzip curl
            ;;
        arch|manjaro)
            pacman -Sy --noconfirm wget unzip curl
            ;;
        *)
            echo "Unsupported distribution: $OS"
            echo "Please install wget, unzip, and curl manually"
            exit 1
            ;;
    esac

    echo ""
    echo "Downloading Xray-core..."
    LATEST_VERSION=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [ -z "$LATEST_VERSION" ]; then
        echo "Failed to get latest version, using fallback"
        LATEST_VERSION="v1.8.23"
    fi
    echo "Latest version: $LATEST_VERSION"

    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            XRAY_ARCH="linux-64"
            ;;
        aarch64|arm64)
            XRAY_ARCH="linux-arm64-v8a"
            ;;
        armv7l)
            XRAY_ARCH="linux-arm32-v7a"
            ;;
        *)
            echo "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac

    DOWNLOAD_URL="https://github.com/XTLS/Xray-core/releases/download/${LATEST_VERSION}/Xray-${XRAY_ARCH}.zip"
    echo "Downloading from: $DOWNLOAD_URL"
    wget -O /tmp/xray.zip "$DOWNLOAD_URL"

    echo "Installing Xray..."
    mkdir -p /usr/local/bin
    unzip -o /tmp/xray.zip -d /tmp/xray_temp
    cp /tmp/xray_temp/xray /usr/local/bin/
    chmod +x /usr/local/bin/xray

    mkdir -p /usr/local/share/xray
    if [ -f /tmp/xray_temp/geoip.dat ]; then
        cp /tmp/xray_temp/geoip.dat /usr/local/share/xray/
    fi
    if [ -f /tmp/xray_temp/geosite.dat ]; then
        cp /tmp/xray_temp/geosite.dat /usr/local/share/xray/
    fi

    rm -rf /tmp/xray.zip /tmp/xray_temp

    if command -v xray &> /dev/null; then
        echo ""
        echo "Xray installed successfully!"
        xray version
    else
        echo "Installation failed!"
        exit 1
    fi
}

generate_cert() {
    print_header "Certificate Generator"

    check_xray_installed

    "$XRAY_BIN" tls cert -ca -file="$CERT_DIR/mycert"

    if [ -f "$CERT_FILE" ] && [ -f "$KEY_FILE" ]; then
        echo "Certificate generated successfully!"
        echo "Files created:"
        echo "  - $CERT_FILE"
        echo "  - $KEY_FILE"
        echo "Copying to runtime paths..."
        sync_certificates_to_runtime_dirs || true
        echo ""
        echo "WARNING: Keep your mycert.key file private and secure!"
    else
        echo "Error: Failed to generate certificate"
        exit 1
    fi
}

install_cert() {
    print_header "Certificate Installation Helper"

    if [ ! -f "$CERT_FILE" ]; then
        if ! restore_certificates_from_known_locations; then
            echo "Error: $CERT_FILE not found!"
            echo "Run: ./mitm_linux.sh generate-cert"
            exit 1
        fi
    fi

    detect_os
    echo "Detected OS: $OS"
    echo ""

    if [ "$EUID" -ne 0 ]; then
        echo "This command requires root privileges."
        echo "Please run with sudo: sudo ./mitm_linux.sh install-cert"
        exit 1
    fi

    echo "Ensuring certificate files are available in runtime paths..."
    sync_certificates_to_runtime_dirs || true

    echo "Installing certificate to system trust store..."
    echo ""

    case $OS in
        fedora|rhel|centos|rocky|almalinux)
            cp "$CERT_FILE" /etc/pki/ca-trust/source/anchors/
            update-ca-trust
            ;;
        debian|ubuntu|linuxmint)
            cp "$CERT_FILE" /usr/local/share/ca-certificates/
            update-ca-certificates
            ;;
        arch|manjaro)
            cp "$CERT_FILE" /etc/ca-certificates/trust-source/anchors/
            trust extract-compat
            ;;
        *)
            echo "Unsupported distribution: $OS"
            echo "Please install certificate manually"
            exit 1
            ;;
    esac

    echo "Certificate installed successfully!"
}

run_xray() {
    print_header "Starting Xray with MITM Domain Fronting"

    check_xray_installed

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Error: Configuration file not found: $CONFIG_FILE"
        exit 1
    fi

    if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
        if ! restore_certificates_from_known_locations; then
            echo "Error: Certificate files not found!"
            echo "Run: ./mitm_linux.sh generate-cert"
            exit 1
        fi
    fi

    echo "Proxy will be available at: $PROXY_HOST:$PROXY_PORT"
    echo "Press Ctrl+C to stop"
    echo ""

    cd "$CERT_DIR"
    "$XRAY_BIN" run -c MITM-DomainFronting.json
}

quick_setup() {
    print_header "MITM Domain Fronting - Quick Setup"

    echo "This command will:"
    echo "1. Install Xray-core"
    echo "2. Generate self-signed certificate"
    echo "3. Install certificate to system trust store"
    echo ""
    read -p "Continue? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi

    if [ "$EUID" -eq 0 ]; then
        echo "Error: Do not run quick-setup as root!"
        echo "It will request sudo where needed."
        exit 1
    fi

    echo ""
    echo "Step 1/3: Installing Xray-core..."
    sudo ./mitm_linux.sh install-xray

    echo ""
    echo "Step 2/3: Generating certificate..."
    ./mitm_linux.sh generate-cert

    echo ""
    echo "Step 3/3: Installing certificate to system..."
    sudo ./mitm_linux.sh install-cert

    echo ""
    echo "Setup complete!"
    echo "Next: ./mitm_linux.sh run"
}

setup_service() {
    print_header "Systemd Service Setup for Xray MITM"

    if [ "$EUID" -ne 0 ]; then
        echo "This command requires root privileges."
        echo "Please run with sudo: sudo ./mitm_linux.sh setup-service"
        exit 1
    fi

    check_xray_installed

    WORKING_DIR="$SCRIPT_DIR"
    CONFIG_PATH="$WORKING_DIR/Xray-config/MITM-DomainFronting.json"

    if [ ! -f "$CONFIG_PATH" ]; then
        echo "Error: Configuration file not found: $CONFIG_PATH"
        exit 1
    fi

    cat > /etc/systemd/system/${SERVICE_NAME}.service << SERVICEEOF
[Unit]
Description=Xray MITM Domain Fronting Service
After=network.target

[Service]
Type=simple
User=$SUDO_USER
WorkingDirectory=$WORKING_DIR/Xray-config
ExecStart=/usr/local/bin/xray run -c $CONFIG_PATH
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
SERVICEEOF

    systemctl daemon-reload

    echo "Systemd service created successfully!"
    echo "Start:   sudo systemctl start $SERVICE_NAME"
    echo "Enable:  sudo systemctl enable $SERVICE_NAME"
    echo "Status:  sudo systemctl status $SERVICE_NAME"
}

configure_proxy() {
    print_header "Proxy Configuration Helper"

    if [ -n "$GNOME_DESKTOP_SESSION_ID" ] || [ "$XDG_CURRENT_DESKTOP" = "GNOME" ]; then
        DE="GNOME"
    elif [ "$XDG_CURRENT_DESKTOP" = "KDE" ]; then
        DE="KDE"
    elif [ "$XDG_CURRENT_DESKTOP" = "XFCE" ]; then
        DE="XFCE"
    else
        DE="Unknown"
    fi

    echo "Detected Desktop Environment: $DE"
    echo "Proxy Address: $PROXY_HOST:$PROXY_PORT"
    echo ""

    if [ "$DE" = "GNOME" ]; then
        echo "1) Enable system proxy"
        echo "2) Disable system proxy"
        echo "3) Show current proxy settings"
        echo "4) Exit"
        read -p "Enter choice [1-4]: " choice

        case $choice in
            1)
                gsettings set org.gnome.system.proxy mode 'manual'
                gsettings set org.gnome.system.proxy.http host "$PROXY_HOST"
                gsettings set org.gnome.system.proxy.http port $PROXY_PORT
                gsettings set org.gnome.system.proxy.https host "$PROXY_HOST"
                gsettings set org.gnome.system.proxy.https port $PROXY_PORT
                gsettings set org.gnome.system.proxy.socks host "$PROXY_HOST"
                gsettings set org.gnome.system.proxy.socks port $PROXY_PORT
                echo "System proxy enabled!"
                ;;
            2)
                gsettings set org.gnome.system.proxy mode 'none'
                echo "System proxy disabled!"
                ;;
            3)
                echo "Mode: $(gsettings get org.gnome.system.proxy mode)"
                echo "HTTP: $(gsettings get org.gnome.system.proxy.http host):$(gsettings get org.gnome.system.proxy.http port)"
                echo "HTTPS: $(gsettings get org.gnome.system.proxy.https host):$(gsettings get org.gnome.system.proxy.https port)"
                echo "SOCKS: $(gsettings get org.gnome.system.proxy.socks host):$(gsettings get org.gnome.system.proxy.socks port)"
                ;;
            4)
                exit 0
                ;;
            *)
                echo "Invalid choice"
                exit 1
                ;;
        esac
    else
        echo "Configure manually to: $PROXY_HOST:$PROXY_PORT"
    fi
}

troubleshoot() {
    print_header "MITM Domain Fronting - Troubleshooting"

    echo "1. Checking Xray installation..."
    if command -v xray &> /dev/null; then
        echo "   ✓ Xray is installed"
        xray version | head -n 1
    else
        echo "   ✗ Xray is NOT installed"
    fi
    echo ""

    echo "2. Checking certificate files..."
    [ -f "$CERT_FILE" ] && echo "   ✓ $CERT_FILE exists" || echo "   ✗ $CERT_FILE missing"
    [ -f "$KEY_FILE" ] && echo "   ✓ $KEY_FILE exists" || echo "   ✗ $KEY_FILE missing"
    echo ""

    echo "3. Checking config file..."
    [ -f "$CONFIG_FILE" ] && echo "   ✓ Config exists" || echo "   ✗ Config missing"
    echo ""

    echo "4. Checking if Xray is running..."
    if pgrep -x "xray" > /dev/null; then
        echo "   ✓ Xray is running (PID: $(pgrep -x xray))"
    else
        echo "   ✗ Xray is NOT running"
    fi
    echo ""

    echo "5. Checking proxy port..."
    if ss -tlnp 2>/dev/null | grep -q ":$PROXY_PORT" || netstat -tlnp 2>/dev/null | grep -q ":$PROXY_PORT"; then
        echo "   ✓ Port $PROXY_PORT is listening"
    else
        echo "   ✗ Port $PROXY_PORT is NOT listening"
    fi
}

usage() {
    cat <<USAGE
Usage: ./mitm_linux.sh <command>

Commands:
  quick-setup     Run full setup flow
  install-xray    Install Xray-core (sudo)
  generate-cert   Generate mycert.crt/mycert.key
  install-cert    Install certificate into system trust (sudo)
  run             Run Xray with MITM config
  setup-service   Create systemd service (sudo)
  configure-proxy Configure desktop proxy settings
  troubleshoot    Check common setup/runtime issues
  help            Show this help
USAGE
}

case "${1:-help}" in
    quick-setup) quick_setup ;;
    install-xray) install_xray ;;
    generate-cert) generate_cert ;;
    install-cert) install_cert ;;
    run) run_xray ;;
    setup-service) setup_service ;;
    configure-proxy) configure_proxy ;;
    troubleshoot) troubleshoot ;;
    help|-h|--help) usage ;;
    *)
        echo "Unknown command: $1"
        echo ""
        usage
        exit 1
        ;;
esac

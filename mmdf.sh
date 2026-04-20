#!/bin/bash

# Ensure we are in the script's directory
cd "$(dirname "$0")" || exit 1

# Configuration
CONFIG_DIR="Xray-config"
CONFIG_FILE="MITM-DomainFronting.json"
PID_FILE="../.mmdf.pid" # Relative to CONFIG_DIR when inside it
PROXY_PORT=10808

# OS Detection
OS="unknown"
if [[ "$OSTYPE" == "darwin"* ]]; then
  OS="macos"
elif [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "linux"* ]]; then
  OS="linux"
fi

if [ "$OS" == "unknown" ] && [ -f /etc/os-release ]; then
    OS="linux"
fi

get_active_service_macos() {
    local interface=$(route get default 2>/dev/null | grep interface | awk '{print $2}')
    if [ -z "$interface" ]; then
        echo "Error: No active internet connection found."
        exit 1
    fi
    local service=$(networksetup -listallhardwareports | grep -B1 "Device: $interface" | grep "Hardware Port" | cut -d: -f2 | sed 's/^ //')
    echo "$service"
}

start() {
    if [ -f ".mmdf.pid" ] && ps -p $(cat ".mmdf.pid") > /dev/null 2>&1; then
        echo "MMDF is already running (PID: $(cat .mmdf.pid))"
        exit 0
    fi

    echo "--- Starting MMDF ---"
    
    # Verify Xray
    XRAY_PATH=$(command -v xray)
    if [ -z "$XRAY_PATH" ]; then
        if [ -f "/opt/homebrew/bin/xray" ]; then 
            XRAY_PATH="/opt/homebrew/bin/xray"
        else 
            echo "Error: xray not found."
            exit 1
        fi
    fi

    if [ "$OS" == "macos" ]; then
        local service=$(get_active_service_macos)
        echo "macOS Service: $service"
        sudo networksetup -setsocksfirewallproxy "$service" 127.0.0.1 $PROXY_PORT
        sudo networksetup -setsocksfirewallproxystate "$service" on
    elif [ "$OS" == "linux" ]; then
        echo "Linux Detected."
        if command -v gsettings >/dev/null 2>&1; then
            echo "Setting GNOME proxy..."
            gsettings set org.gnome.system.proxy mode 'manual'
            gsettings set org.gnome.system.proxy.socks host '127.0.0.1'
            gsettings set org.gnome.system.proxy.socks port $PROXY_PORT
        elif command -v kwriteconfig5 >/dev/null 2>&1; then
            echo "Setting KDE proxy..."
            kwriteconfig5 --file kioslaverc --group "Proxy Settings" --key "ProxyType" 1
            kwriteconfig5 --file kioslaverc --group "Proxy Settings" --key "socksProxy" "socks://127.0.0.1:$PROXY_PORT"
        else
            echo "Warning: Desktop Environment not supported for auto-proxy. Please set SOCKS manually to 127.0.0.1:$PROXY_PORT"
        fi
    fi

    # Start Xray from inside the CONFIG_DIR so it finds mycert.crt relative to its CWD
    cd "$CONFIG_DIR" || exit 1
    
    # Generate runtime config with absolute paths for certificates
    # Xray typically requires absolute paths if the certificates are not in its asset distribution directory.
    sed -e "s|\"./mycert.crt\"|\"$(pwd)/mycert.crt\"|g" \
        -e "s|\"mycert.crt\"|\"$(pwd)/mycert.crt\"|g" \
        -e "s|\"./mycert.key\"|\"$(pwd)/mycert.key\"|g" \
        -e "s|\"mycert.key\"|\"$(pwd)/mycert.key\"|g" \
        "$CONFIG_FILE" > ".runtime.json"

    nohup "$XRAY_PATH" -config ".runtime.json" > ../mmdf.log 2>&1 &
    echo $! > "$PID_FILE"
    cd ..
    
    echo "MMDF is now ACTIVE. Logs: mmdf.log"
}

stop() {
    echo "--- Stopping MMDF ---"
    
    if [ -f ".mmdf.pid" ]; then
        local pid=$(cat ".mmdf.pid")
        if ps -p "$pid" > /dev/null 2>&1; then
            echo "Stopping Xray (PID: $pid)..."
            kill "$pid"
        fi
        rm -f ".mmdf.pid"
    fi

    if [ "$OS" == "macos" ]; then
        local service=$(get_active_service_macos)
        sudo networksetup -setsocksfirewallproxystate "$service" off
    elif [ "$OS" == "linux" ]; then
        if command -v gsettings >/dev/null 2>&1; then
            echo "Resetting GNOME proxy..."
            gsettings set org.gnome.system.proxy mode 'none'
        elif command -v kwriteconfig5 >/dev/null 2>&1; then
            echo "Resetting KDE proxy..."
            kwriteconfig5 --file kioslaverc --group "Proxy Settings" --key "ProxyType" 0
        fi
    fi
    
    echo "MMDF is now INACTIVE."
}

status() {
    echo "--- MMDF Status ---"
    if [ -f ".mmdf.pid" ] && ps -p $(cat ".mmdf.pid") > /dev/null 2>&1; then
        echo "Xray: RUNNING (PID: $(cat .mmdf.pid))"
    else
        echo "Xray: STOPPED"
    fi
    
    if [ "$OS" == "macos" ]; then
        local service=$(get_active_service_macos)
        networksetup -getsocksfirewallproxy "$service" | grep "Enabled:"
    elif [ "$OS" == "linux" ] && command -v gsettings >/dev/null 2>&1; then
        echo "Proxy Mode: $(gsettings get org.gnome.system.proxy mode)"
    fi
}

case "$1" in
    start) start ;;
    stop) stop ;;
    status) status ;;
    *) echo "Usage: $0 {start|stop|status}"; exit 1 ;;
esac


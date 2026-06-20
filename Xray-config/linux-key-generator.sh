#!/bin/bash

# --- Combined script: Generate certificate & download Xray-core ---
# Fixed to handle proxy and SSL certificate issues

print_status() {
    echo -e "\e[1;34m[INFO]\e[0m $1"
}

print_success() {
    echo -e "\e[1;32m[SUCCESS]\e[0m $1"
}

print_error() {
    echo -e "\e[1;31m[ERROR]\e[0m $1" >&2
}

print_warning() {
    echo -e "\e[1;33m[WARNING]\e[0m $1"
}

# Function to check if a file is a valid ZIP
is_valid_zip() {
    if [ -f "$1" ] && unzip -t "$1" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to generate self-signed certificate
generate_certificate() {
    print_status "Generating self-signed certificate..."
    
    if ! command -v openssl &> /dev/null; then
        print_error "OpenSSL not installed. Skipping certificate generation."
        return 1
    fi
    
    local script_dir=$(dirname "$0")
    local cert_path="$script_dir/mycert.crt"
    local key_path="$script_dir/mycert.key"
    
    # Check if files already exist
    if [ -f "$cert_path" ] || [ -f "$key_path" ]; then
        print_warning "Certificate files already exist."
        read -p "Overwrite? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Skipping certificate generation."
            return 0
        fi
    fi
    
    openssl req -x509 -newkey rsa:2048 -nodes \
        -keyout "$key_path" -out "$cert_path" \
        -days 365 -subj "/C=US/ST=State/L=City/O=Org/CN=localhost" 2>/dev/null
    
    if [ $? -eq 0 ] && [ -f "$cert_path" ] && [ -f "$key_path" ]; then
        chmod 600 "$key_path"
        print_success "Certificate generated: $cert_path and $key_path"
        ls -lh "$cert_path" "$key_path"
    else
        print_error "Certificate generation failed"
        return 1
    fi
}

# Function to download Xray-core with proxy handling
download_xray() {
    print_status "Downloading Xray-core..."
    
    URL="https://github.com/XTLS/Xray-core/releases/download/v26.6.1/Xray-linux-64.zip"
    ZIP="Xray-linux-64.zip"
    DIR="./Xray"
    
    # Check if ZIP already exists and is valid
    if [ -f "$ZIP" ] && is_valid_zip "$ZIP"; then
        print_status "Valid ZIP file already exists: $ZIP"
        read -p "Use existing file? (Y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            rm -f "$ZIP"
        else
            print_status "Using existing ZIP file."
            extract_xray "$ZIP" "$DIR"
            return $?
        fi
    elif [ -f "$ZIP" ]; then
        print_warning "Existing ZIP file is corrupt. Re-downloading..."
        rm -f "$ZIP"
    fi
    
    # Create directory
    mkdir -p "$DIR"
    
    # Detect if we're behind a proxy
    if [ -n "$http_proxy" ] || [ -n "$https_proxy" ] || [ -n "$HTTP_PROXY" ] || [ -n "$HTTPS_PROXY" ]; then
        print_warning "Proxy detected. Using --no-check-certificate to bypass SSL issues."
        WGET_OPTS="--no-check-certificate"
        CURL_OPTS="-k"
    else
        WGET_OPTS=""
        CURL_OPTS=""
    fi
    
    # Download with retry logic
    local max_retries=3
    local retry_count=0
    local download_success=0
    
    while [ $retry_count -lt $max_retries ] && [ $download_success -eq 0 ]; do
        if [ $retry_count -gt 0 ]; then
            print_status "Retry attempt $((retry_count+1))/$max_retries..."
            sleep 2
        fi
        
        if command -v wget &> /dev/null; then
            print_status "Using wget to download..."
            wget $WGET_OPTS -O "$ZIP" "$URL" 2>&1 | grep -v "ERROR: cannot verify"
            if [ $? -eq 0 ] && is_valid_zip "$ZIP"; then
                download_success=1
            else
                print_warning "Download attempt $((retry_count+1)) failed"
                rm -f "$ZIP"
            fi
        elif command -v curl &> /dev/null; then
            print_status "Using curl to download..."
            curl -L $CURL_OPTS -o "$ZIP" "$URL" --progress-bar
            if [ $? -eq 0 ] && is_valid_zip "$ZIP"; then
                download_success=1
            else
                print_warning "Download attempt $((retry_count+1)) failed"
                rm -f "$ZIP"
            fi
        else
            print_error "wget or curl required"
            return 1
        fi
        
        retry_count=$((retry_count+1))
    done
    
    if [ $download_success -eq 0 ]; then
        print_error "Failed to download Xray-core after $max_retries attempts."
        print_status "Possible solutions:"
        echo "  1. Check your internet connection"
        echo "  2. Disable your proxy: unset http_proxy https_proxy"
        echo "  3. Download manually and place in this directory"
        return 1
    fi
    
    # Extract the ZIP
    extract_xray "$ZIP" "$DIR"
}

# Function to extract Xray
extract_xray() {
    local zip_file="$1"
    local extract_dir="$2"
    
    print_status "Extracting $zip_file to $extract_dir..."
    
    if ! is_valid_zip "$zip_file"; then
        print_error "Invalid ZIP file: $zip_file"
        return 1
    fi
    
    # Clear the directory first
    if [ -d "$extract_dir" ] && [ "$(ls -A "$extract_dir" 2>/dev/null)" ]; then
        print_warning "Directory $extract_dir is not empty."
        read -p "Clear it before extraction? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$extract_dir"/*
        fi
    fi
    
    if unzip -o "$zip_file" -d "$extract_dir" > /dev/null 2>&1; then
        print_success "Successfully extracted to: $extract_dir"
        
        # Show what was extracted
        echo ""
        echo "Contents of $extract_dir:"
        ls -la "$extract_dir"
        
        # Set executable permissions for binary files
        print_status "Setting executable permissions..."
        find "$extract_dir" -type f -executable -exec chmod +x {} \;
        
        # Clean up ZIP file
        read -p "Delete the ZIP file? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -f "$zip_file"
            print_status "ZIP file removed."
        fi
        
        print_success "Xray-core is ready in $extract_dir"
        return 0
    else
        print_error "Extraction failed!"
        return 1
    fi
}

# Function to manually download if automatic fails
manual_download_instructions() {
    echo ""
    print_warning "Automatic download failed. You can manually download:"
    echo "  1. Visit: https://github.com/XTLS/Xray-core/releases"
    echo "  2. Download: Xray-linux-64.zip"
    echo "  3. Place it in: $(pwd)"
    echo "  4. Run this script again"
    echo ""
    print_status "Or try disabling your proxy and re-running:"
    echo "  unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY"
    echo "  ./$(basename "$0")"
}

# Main execution
main() {
    echo "=== Xray Setup Script ==="
    echo "1. Generate SSL Certificate"
    echo "2. Download Xray-core"
    echo "3. Do both"
    echo "4. Exit"
    echo ""
    read -p "Select option (1/2/3/4): " -n 1 -r
    echo
    
    case $REPLY in
        1)
            generate_certificate
            ;;
        2)
            if ! download_xray; then
                manual_download_instructions
                exit 1
            fi
            ;;
        3)
            generate_certificate
            echo ""
            if ! download_xray; then
                manual_download_instructions
                exit 1
            fi
            ;;
        4)
            print_status "Exiting..."
            exit 0
            ;;
        *)
            print_error "Invalid option"
            exit 1
            ;;
    esac
    
    print_success "Setup complete!"
}

# Run the main function
main
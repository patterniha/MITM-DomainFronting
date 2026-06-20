#!/bin/bash

# --- Script to generate self-signed SSL certificate and key ---
# Output files: Xray-config/mycert.crt and Xray-config/mycert.key

# Configuration variables
CERT_FILE="Xray-config/mycert.crt"
KEY_FILE="Xray-config/mycert.key"
DAYS_VALID=365
KEY_SIZE=2048

# Certificate details (change these as needed)
COUNTRY="US"
STATE="California"
CITY="San Francisco"
ORGANIZATION="My Organization"
ORG_UNIT="IT Department"
COMMON_NAME="localhost"  # Use your domain or IP here
EMAIL="admin@localhost"

# Function to print colored output
print_status() {
    echo -e "\e[1;34m[INFO]\e[0m $1"
}

print_error() {
    echo -e "\e[1;31m[ERROR]\e[0m $1" >&2
}

# Check if openssl is installed
if ! command -v openssl &> /dev/null; then
    print_error "OpenSSL is not installed. Please install it first."
    echo "On Ubuntu/Debian: sudo apt-get install openssl"
    echo "On CentOS/RHEL: sudo yum install openssl"
    echo "On macOS: brew install openssl"
    exit 1
fi

# Check if files already exist
if [ -f "$CERT_FILE" ] || [ -f "$KEY_FILE" ]; then
    print_error "Certificate or key file already exists."
    echo "Existing files found:"
    [ -f "$CERT_FILE" ] && echo "  - $CERT_FILE"
    [ -f "$KEY_FILE" ] && echo "  - $KEY_FILE"
    echo "Please remove or rename them before generating new ones."
    exit 1
fi

# Generate the private key and certificate
print_status "Generating private key ($KEY_FILE) and certificate ($CERT_FILE)..."
print_status "Certificate will be valid for $DAYS_VALID days."

# Create a configuration file for non-interactive generation
cat > openssl_config.cnf << EOF
[req]
default_bits = $KEY_SIZE
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = v3_req

[dn]
C = $COUNTRY
ST = $STATE
L = $CITY
O = $ORGANIZATION
OU = $ORG_UNIT
CN = $COMMON_NAME
emailAddress = $EMAIL

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $COMMON_NAME
DNS.2 = *.local
EOF

# Generate the certificate and key in one command
if openssl req -x509 -newkey rsa:$KEY_SIZE -days $DAYS_VALID \
    -out "$CERT_FILE" -keyout "$KEY_FILE" \
    -config openssl_config.cnf -nodes; then
    
    print_status "Successfully generated certificate and key!"
    print_status "Certificate file: $CERT_FILE"
    print_status "Private key file: $KEY_FILE"
    
    # Display file information
    echo ""
    echo "File details:"
    ls -lh "$CERT_FILE" "$KEY_FILE"
    
    echo ""
    echo "Certificate information:"
    openssl x509 -in "$CERT_FILE" -text -noout | grep -E "Subject:|Issuer:|Not Before|Not After"
    
    # Clean up config file
    rm -f openssl_config.cnf
    
else
    print_error "Failed to generate certificate and key."
    rm -f openssl_config.cnf
    exit 1
fi

# Optional: Set proper permissions (read-only for key)
print_status "Setting permissions: key file is read-only for owner"
chmod 600 "$KEY_FILE"

echo ""
echo "Done! You can now use $CERT_FILE and $KEY_FILE."
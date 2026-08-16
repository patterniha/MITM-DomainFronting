#!/bin/bash

# رنگ‌ها برای خروجی بهتر
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== MITM-DomainFronting Certificate Generator & Installer for Ubuntu ===${NC}"

# مسیر xray
XRAY_PATH="/opt/v2rayN/bin/xray/xray"

# مسیر مقصد برای کپی فایل‌های certificate
DEST_DIR="$HOME/.local/share/v2rayN/bin"

# بررسی وجود xray
if [ ! -f "$XRAY_PATH" ]; then
    echo -e "${RED}Error: Xray not found at $XRAY_PATH${NC}"
    exit 1
fi

# ایجاد دایرکتوری مقصد اگر وجود ندارد
mkdir -p "$DEST_DIR"

# دایرکتوری موقت برای ساخت گواهی
CERT_DIR="/tmp/xray_cert_$$"
mkdir -p "$CERT_DIR"
cd "$CERT_DIR"

echo -e "${YELLOW}Generating new certificate in temporary directory...${NC}"
$XRAY_PATH tls cert -ca -file=mycert

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to generate certificate${NC}"
    rm -rf "$CERT_DIR"
    exit 1
fi

echo -e "${GREEN}Certificate generated successfully${NC}"

# کپی فایل‌ها به مسیر مقصد
echo -e "${YELLOW}Copying certificates to: $DEST_DIR${NC}"
cp mycert.crt mycert.key "$DEST_DIR/"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Files copied successfully to $DEST_DIR${NC}"
    echo -e "  - ${YELLOW}$DEST_DIR/mycert.crt${NC}"
    echo -e "  - ${YELLOW}$DEST_DIR/mycert.key${NC}"
else
    echo -e "${RED}Failed to copy files to destination${NC}"
fi

# نصب گواهی در سیستم
echo -e "${YELLOW}Installing certificate to system trust store...${NC}"

# کپی به دایرکتوری گواهی‌های سیستم
sudo cp mycert.crt /usr/local/share/ca-certificates/mycert.crt

# بروزرسانی لیست گواهی‌های معتبر (برای Ubuntu/Debian)
if command -v update-ca-certificates &> /dev/null; then
    sudo update-ca-certificates
    echo -e "${GREEN}Certificate installed via update-ca-certificates${NC}"
else
    echo -e "${RED}update-ca-certificates not found. Trying manual method...${NC}"
    # روش جایگزین برای توزیع‌های دیگر
    sudo cp mycert.crt /etc/ssl/certs/
    sudo c_rehash
fi

# پاک کردن دایرکتوری موقت
rm -rf "$CERT_DIR"

# نمایش خلاصه نهایی
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Summary:${NC}"
echo -e "  ${GREEN}✓${NC} Certificate generated"
echo -e "  ${GREEN}✓${NC} Copied to: ${YELLOW}$DEST_DIR${NC}"
echo -e "  ${GREEN}✓${NC} Installed to system trust store"
echo -e "${GREEN}================================${NC}"
echo -e "Certificate files location:"
echo -e "  Private key: ${YELLOW}$DEST_DIR/mycert.key${NC}"
echo -e "  Certificate: ${YELLOW}$DEST_DIR/mycert.crt${NC}"
echo -e "${GREEN}================================${NC}"

# منتظر کلید Enter 
echo ""
read -p "Press Enter to exit..."
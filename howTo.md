# Xray Setup Script Usage Guide

## Overview

This script (`Xray-config/linux-key-generator.sh`) automates the setup of Xray-core by generating a self-signed SSL certificate and downloading the latest Xray binary.

## Prerequisites

- **OpenSSL**: Required for certificate generation (if not installed, the script will skip certificate creation).
- **wget or curl**: Required for downloading Xray-core.
- **Internet connection**: To fetch Xray-core from GitHub.

## Usage

### 1. Make the script executable and run it

```bash
chmod +x Xray-config/linux-key-generator.sh && ./Xray-config/linux-key-generator.sh
```

### 2. Select an option

The script will present a menu:

```
=== Xray Setup Script ===
1. Generate SSL Certificate
2. Download Xray-core
3. Do both
4. Exit
```

- **Option 1**: Generates a self-signed certificate (`mycert.crt` and `mycert.key`) valid for 365 days within the `Xray-config` folder.
- **Option 2**: Downloads Xray-core (v26.6.1) and extracts it to the `./Xray` directory. Handles proxy detection and SSL certificate issues.
- **Option 3**: Performs both certificate generation and Xray download.
- **Option 4**: Exits the script.

## Running Xray

To start Xray with the MITM Domain Fronting configuration, run:

```bash
chmod +x ./Xray/xray && ./Xray/xray run -c ./Xray-config/MITM-DomainFronting.json
```

## Adding Certificate to Chrome

To use the self-signed certificate in Chrome and avoid security warnings:

### 1. Open Chrome Certificate Manager

1. Open Chrome and navigate to `chrome://settings/security`
2. Click on **Manage certificates** under the Security section

### 2. Import the Certificate

1. Go to the **Authorities** tab
2. Click **Import**
3. Select `Xray-config/mycert.crt`
4. Check **Trust this certificate for identifying websites**
5. Click **OK**

### 3. Verify Installation

1. The certificate should appear in the Authorities list
2. Restart Chrome if needed

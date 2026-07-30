# Linux Files Overview

This document describes the Linux setup assets after consolidation into one script.

## Main Linux Script

### `mitm_linux.sh`

Unified Linux management script for MITM Domain Fronting.

Supported commands:

```bash
./mitm_linux.sh help
./mitm_linux.sh quick-setup
sudo ./mitm_linux.sh install-xray
./mitm_linux.sh generate-cert
sudo ./mitm_linux.sh install-cert
./mitm_linux.sh run
sudo ./mitm_linux.sh setup-service
./mitm_linux.sh configure-proxy
./mitm_linux.sh troubleshoot
```

## What Each Command Does

- `quick-setup`: Runs guided setup flow (install Xray, generate cert, install cert)
- `install-xray`: Installs Xray-core and dependencies (requires sudo)
- `generate-cert`: Generates `mycert.crt` and `mycert.key`
- `install-cert`: Installs certificate into system trust store (requires sudo)
- `run`: Starts Xray with `Xray-config/MITM-DomainFronting.json`
- `setup-service`: Creates systemd service `xray-mitm` (requires sudo)
- `configure-proxy`: Helps configure desktop proxy (GNOME interactive menu)
- `troubleshoot`: Checks common setup/runtime problems

## Typical Usage

### Recommended Quick Setup

```bash
./mitm_linux.sh quick-setup
./mitm_linux.sh run
```

Then:
- Install `mycert.crt` in your browser
- Configure proxy to `127.0.0.1:10808`

### Step-by-Step Setup

```bash
sudo ./mitm_linux.sh install-xray
./mitm_linux.sh generate-cert
sudo ./mitm_linux.sh install-cert
./mitm_linux.sh run
```

### Optional System Service

```bash
sudo ./mitm_linux.sh setup-service
sudo systemctl enable xray-mitm
sudo systemctl start xray-mitm
```

### Troubleshooting

```bash
./mitm_linux.sh troubleshoot
```

## Notes

- Keep `mycert.key` private and never share it.
- Use your own generated certificate; do not import certificates from others.
- Browser certificate installation is still manual.
- Uninstallation details are in `README_LINUX.md`.

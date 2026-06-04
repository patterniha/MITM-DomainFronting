#!/usr/bin/env sh
set -eu

# Easy offline certificate generator for MITM-DomainFronting.
# Usage: sh certificate_generator.sh [OUT_DIR]
# Default OUT_DIR is the current directory.

out_dir="${1:-.}"

find_xray() {
  if [ -n "${XRAY_BIN:-}" ] && [ -x "$XRAY_BIN" ]; then
    printf '%s\n' "$XRAY_BIN"
    return 0
  fi
  if command -v xray >/dev/null 2>&1; then
    command -v xray
    return 0
  fi
  for x in ./xray ./xray/xray ./xray.exe ./xray/xray.exe; do
    if [ -x "$x" ]; then
      printf '%s\n' "$x"
      return 0
    fi
  done
  return 1
}

xray_bin="$(find_xray || true)"
if [ -z "$xray_bin" ]; then
  echo "xray not found. Put this script near xray or set XRAY_BIN=/path/to/xray" >&2
  exit 1
fi

mkdir -p "$out_dir"
(
  cd "$out_dir"
  "$xray_bin" tls cert -ca -file=mycert >/dev/null
)

chmod 644 "$out_dir/mycert.crt" 2>/dev/null || true
chmod 600 "$out_dir/mycert.key" 2>/dev/null || true

echo "created $out_dir/mycert.crt and $out_dir/mycert.key"
echo "Keep mycert.key private. Install mycert.crt and verify fingerprint."

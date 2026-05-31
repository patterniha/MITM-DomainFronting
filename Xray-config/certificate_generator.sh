#!/usr/bin/env sh
set -eu

out_dir="."
if [ "${1:-}" = "--out-dir" ]; then
  out_dir="${2:-}"
fi

if [ -z "$out_dir" ]; then
  echo "Usage: certificate_generator.sh [--out-dir DIR]" >&2
  exit 2
fi

find_xray() {
  if [ -n "${XRAY_BIN:-}" ] && [ -x "$XRAY_BIN" ]; then
    printf '%s\n' "$XRAY_BIN"
    return
  fi
  if command -v xray >/dev/null 2>&1; then
    command -v xray
    return
  fi
  for x in ./xray ./xray/xray /Applications/v2rayN.app/Contents/MacOS/bin/xray/xray; do
    if [ -x "$x" ]; then
      printf '%s\n' "$x"
      return
    fi
  done
  return 1
}

xray_bin="$(find_xray || true)"
if [ -z "$xray_bin" ]; then
  echo "xray not found; set XRAY_BIN=/path/to/xray" >&2
  exit 1
fi

mkdir -p "$out_dir"
tmp_json="$(mktemp "${TMPDIR:-/tmp}/mitm-domainfronting-cert.XXXXXX.json")"
trap 'rm -f "$tmp_json"' EXIT

"$xray_bin" tls cert -ca >"$tmp_json"

if command -v jq >/dev/null 2>&1; then
  jq -r '.certificate[]' "$tmp_json" >"$out_dir/mycert.crt"
  jq -r '.key[]' "$tmp_json" >"$out_dir/mycert.key"
else
  python3 - "$tmp_json" "$out_dir" <<'PY'
import json
import pathlib
import sys

j = json.loads(pathlib.Path(sys.argv[1]).read_text())
out = pathlib.Path(sys.argv[2])
(out / "mycert.crt").write_text("\n".join(j["certificate"]) + "\n")
(out / "mycert.key").write_text("\n".join(j["key"]) + "\n")
PY
fi

chmod 644 "$out_dir/mycert.crt"
chmod 600 "$out_dir/mycert.key"
echo "created $out_dir/mycert.crt and $out_dir/mycert.key"

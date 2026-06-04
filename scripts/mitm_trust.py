#!/usr/bin/env python3
"""Simple local certificate/key lifecycle helper.

This preserves the easy Xray certificate generation flow while adding status,
fingerprint, rotate, remove-local, and emergency helpers. It never uploads files
and never prints private-key contents.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import stat
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))


def hidden_subprocess_kwargs() -> Dict[str, object]:
    if os.name != "nt":
        return {}
    startupinfo = subprocess.STARTUPINFO()
    startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startupinfo.wShowWindow = 0
    return {
        "creationflags": getattr(subprocess, "CREATE_NO_WINDOW", 0),
        "startupinfo": startupinfo,
    }


def sha256_file(path: Path) -> Optional[str]:
    if not path.exists():
        return None
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def find_xray() -> Optional[str]:
    candidates: List[str] = []
    env = os.environ.get("XRAY_BIN")
    if env:
        candidates.append(env)
    candidates.extend([
        "./xray",
        "./xray.exe",
        "./xray/xray",
        "./xray/xray.exe",
        "xray",
        "xray.exe",
    ])
    for candidate in candidates:
        path = shutil.which(candidate) if candidate in {"xray", "xray.exe"} else candidate
        if path and Path(path).exists():
            return path
    return None


def openssl_info(cert: Path) -> str:
    if not cert.exists():
        return "certificate missing"
    try:
        p = subprocess.run(
            ["openssl", "x509", "-in", str(cert), "-noout", "-subject", "-issuer", "-enddate", "-fingerprint", "-sha256"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=5,
            check=False,
            **hidden_subprocess_kwargs(),
        )
    except Exception as exc:  # noqa: BLE001
        return f"openssl unavailable: {exc}"
    if p.returncode != 0:
        return f"openssl failed: {p.stderr.strip()}"
    return p.stdout.strip()


def run_openssl(args: List[str], timeout: float = 5.0) -> subprocess.CompletedProcess[str] | None:
    try:
        return subprocess.run(
            ["openssl", *args],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=timeout,
            check=False,
            **hidden_subprocess_kwargs(),
        )
    except Exception:
        return None


def run_openssl_bytes(args: List[str], timeout: float = 5.0) -> subprocess.CompletedProcess[bytes] | None:
    try:
        return subprocess.run(
            ["openssl", *args],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=False,
            timeout=timeout,
            check=False,
            **hidden_subprocess_kwargs(),
        )
    except Exception:
        return None


def cert_end_date(cert: Path) -> Optional[datetime]:
    if not cert.exists():
        return None
    proc = run_openssl(["x509", "-in", str(cert), "-noout", "-enddate"])
    if proc is None or proc.returncode != 0:
        return None
    line = proc.stdout.strip()
    if not line.startswith("notAfter="):
        return None
    value = line.split("=", 1)[1].strip()
    for fmt in ("%b %d %H:%M:%S %Y %Z", "%b  %d %H:%M:%S %Y %Z"):
        try:
            return datetime.strptime(value, fmt).replace(tzinfo=timezone.utc)
        except ValueError:
            continue
    return None


def public_key_fingerprint_from_cert(cert: Path) -> Optional[str]:
    if not cert.exists():
        return None
    proc = run_openssl_bytes(["x509", "-in", str(cert), "-pubkey", "-noout"])
    if proc is None or proc.returncode != 0:
        return None
    return hashlib.sha256(proc.stdout).hexdigest()


def public_key_fingerprint_from_key(key: Path) -> Optional[str]:
    if not key.exists():
        return None
    proc = run_openssl_bytes(["pkey", "-in", str(key), "-pubout"])
    if proc is None or proc.returncode != 0:
        return None
    return hashlib.sha256(proc.stdout).hexdigest()


def cert_key_match(cert: Path, key: Path) -> Optional[bool]:
    cert_fp = public_key_fingerprint_from_cert(cert)
    key_fp = public_key_fingerprint_from_key(key)
    if cert_fp is None or key_fp is None:
        return None
    return cert_fp == key_fp


def key_permissions_ok(key: Path) -> Optional[bool]:
    if not key.exists():
        return False
    if os.name == "nt":
        text = windows_acl_text(key)
        if not text:
            return None
        lowered = text.lower()
        return not any(marker in lowered for marker in ("everyone", "builtin\\users", "authenticated users"))
    mode = stat.S_IMODE(key.stat().st_mode)
    return (mode & 0o077) == 0


def key_permission_text(key: Path) -> str:
    if not key.exists():
        return "missing"
    if os.name == "nt":
        text = windows_acl_text(key)
        if not text:
            return "Windows ACL unavailable; keep file private"
        lowered = text.lower()
        if any(marker in lowered for marker in ("everyone", "builtin\\users", "authenticated users")):
            return "Windows ACL appears broad; restrict file to the current user"
        return "Windows ACL did not show broad local user access"
    mode = stat.S_IMODE(key.stat().st_mode)
    advice = []
    if mode & stat.S_IROTH:
        advice.append("world-readable; run chmod 600")
    if mode & stat.S_IRGRP:
        advice.append("group-readable; chmod 600 is stricter")
    return f"{oct(mode)}" + (" (" + "; ".join(advice) + ")" if advice else "")


def windows_acl_text(path: Path) -> str:
    try:
        proc = subprocess.run(
            ["icacls", str(path)],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            timeout=5,
            check=False,
            **hidden_subprocess_kwargs(),
        )
    except Exception:
        return ""
    return proc.stdout or ""


def status_report(cert: Path, key: Path, warn_expiry_days: int) -> Dict[str, Any]:
    now = datetime.now(timezone.utc)
    not_after = cert_end_date(cert)
    days_remaining = None
    if not_after is not None:
        days_remaining = int((not_after - now).total_seconds() // 86400)
    return {
        "cert": str(cert),
        "cert_exists": cert.exists(),
        "cert_sha256": sha256_file(cert),
        "cert_not_after_utc": not_after.isoformat() if not_after else None,
        "cert_days_remaining": days_remaining,
        "cert_expired": days_remaining is not None and days_remaining < 0,
        "cert_expires_soon": days_remaining is not None and 0 <= days_remaining <= warn_expiry_days,
        "key": str(key),
        "key_exists": key.exists(),
        "key_permissions": key_permission_text(key),
        "key_permissions_ok": key_permissions_ok(key),
        "cert_key_match": cert_key_match(cert, key),
    }


def status(cert: Path, key: Path, warn_expiry_days: int, json_out: bool) -> int:
    report = status_report(cert, key, warn_expiry_days)
    if json_out:
        print(json.dumps(report, indent=2, ensure_ascii=False))
        return 0 if report["cert_exists"] and report["key_exists"] and report["cert_key_match"] is not False else 2
    print(f"cert: {cert}")
    print(f"cert_exists: {report['cert_exists']}")
    if report["cert_sha256"]:
        print(f"cert_sha256: {report['cert_sha256']}")
        print("cert_sha256_prefix_for_issues: " + str(report["cert_sha256"])[:12])
    print(f"cert_not_after_utc: {report['cert_not_after_utc']}")
    print(f"cert_days_remaining: {report['cert_days_remaining']}")
    print(f"cert_expired: {report['cert_expired']}")
    print(f"cert_expires_soon: {report['cert_expires_soon']}")
    print(f"key: {key}")
    print(f"key_exists: {report['key_exists']}")
    print(f"key_permissions: {report['key_permissions']}")
    print(f"key_permissions_ok: {report['key_permissions_ok']}")
    print(f"cert_key_match: {report['cert_key_match']}")
    print("certificate_info:")
    print(openssl_info(cert))
    return 0 if report["cert_exists"] and report["key_exists"] and report["cert_key_match"] is not False else 2


def backup_existing(out_dir: Path) -> None:
    backup = out_dir / "cert-backups" / time.strftime("%Y%m%d%H%M%S")
    active = [out_dir / "mycert.crt", out_dir / "mycert.key"]
    if any(p.exists() for p in active):
        backup.mkdir(parents=True, exist_ok=True)
        for p in active:
            if p.exists():
                shutil.copy2(p, backup / p.name)
        print(f"backed_up_existing_files: {backup}")


def generate(out_dir: Path, backup: bool = False) -> int:
    out_dir.mkdir(parents=True, exist_ok=True)
    if backup:
        backup_existing(out_dir)
    xray = find_xray()
    if not xray:
        print("ERROR: xray binary not found. Put this script near xray or set XRAY_BIN=/path/to/xray", file=sys.stderr)
        return 2
    cmd = [xray, "tls", "cert", "-ca", "-file=mycert"]
    print("running: " + " ".join(cmd))
    p = subprocess.run(
        cmd,
        cwd=str(out_dir),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        **hidden_subprocess_kwargs(),
    )
    if p.returncode != 0:
        print(p.stdout)
        print(p.stderr, file=sys.stderr)
        return p.returncode or 1
    cert = out_dir / "mycert.crt"
    key = out_dir / "mycert.key"
    if os.name != "nt" and key.exists():
        key.chmod(0o600)
    print("created:")
    print(f"  {cert}")
    print(f"  {key}")
    cert_hash = sha256_file(cert)
    if cert_hash:
        print(f"cert_sha256: {cert_hash}")
    print("Keep mycert.key private. Do not post it in issues or send it to anyone.")
    return 0


def remove_local(cert: Path, key: Path, yes: bool) -> int:
    if not yes:
        print("Refusing to remove without --yes")
        return 2
    for path in [cert, key]:
        if path.exists():
            path.unlink()
            print(f"removed: {path}")
        else:
            print(f"not_found: {path}")
    print("Also remove the trusted CA from OS/browser trust stores if you are uninstalling.")
    return 0


def emergency(out_dir: Path) -> int:
    print("Emergency rotation: treat the old CA as compromised.")
    print("1. Remove the old trusted CA from OS/browser stores.")
    print("2. Generate a new local CA now.")
    code = generate(out_dir, backup=True)
    print("3. Install the new mycert.crt and verify its fingerprint.")
    print("4. Do not reuse the old mycert.key.")
    return code


def main() -> int:
    parser = argparse.ArgumentParser(description="Local CA helper for MITM-DomainFronting")
    sub = parser.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("status")
    s.add_argument("--cert", type=Path, default=Path("Xray-config/mycert.crt"))
    s.add_argument("--key", type=Path, default=Path("Xray-config/mycert.key"))
    s.add_argument("--warn-expiry-days", type=int, default=30)
    s.add_argument("--json", action="store_true")

    cp = sub.add_parser("check-pair")
    cp.add_argument("--cert", type=Path, default=Path("Xray-config/mycert.crt"))
    cp.add_argument("--key", type=Path, default=Path("Xray-config/mycert.key"))

    g = sub.add_parser("generate")
    g.add_argument("--out-dir", type=Path, default=Path("Xray-config"))

    r = sub.add_parser("rotate")
    r.add_argument("--out-dir", type=Path, default=Path("Xray-config"))

    rm = sub.add_parser("remove-local")
    rm.add_argument("--cert", type=Path, default=Path("Xray-config/mycert.crt"))
    rm.add_argument("--key", type=Path, default=Path("Xray-config/mycert.key"))
    rm.add_argument("--yes", action="store_true")

    e = sub.add_parser("emergency")
    e.add_argument("--out-dir", type=Path, default=Path("Xray-config"))

    rk = sub.add_parser("restrict-key", help="tighten private-key ACL (current user / chmod 600)")
    rk.add_argument("--key", type=Path, default=Path("Xray-config/mycert.key"))
    rk.add_argument("--json", action="store_true")

    wk = sub.add_parser("wrap-key", help="wrap private key with Windows DPAPI sidecar (.key.dpapi)")
    wk.add_argument("--key", type=Path, default=Path("Xray-config/mycert.key"))
    wk.add_argument("--remove-plaintext", action="store_true")
    wk.add_argument("--json", action="store_true")

    uk = sub.add_parser("unwrap-key", help="restore plaintext private key from DPAPI sidecar")
    uk.add_argument("--key", type=Path, default=Path("Xray-config/mycert.key"))
    uk.add_argument("--json", action="store_true")

    ca = sub.add_parser("cdp-assist", help="open certificate settings via CDP in an already-running isolated profile")
    ca.add_argument("--port", type=int, default=9222)
    ca.add_argument("--cert", type=Path, default=Path("Xray-config/mycert.crt"))
    ca.add_argument("--browser", default="chromium")
    ca.add_argument("--wait-timeout", type=float, default=12.0)
    ca.add_argument("--json", action="store_true")

    args = parser.parse_args()
    if args.cmd == "status":
        return status(args.cert, args.key, args.warn_expiry_days, args.json)
    if args.cmd == "check-pair":
        match = cert_key_match(args.cert, args.key)
        print(f"cert_key_match: {match}")
        return 0 if match is True else 2
    if args.cmd == "generate":
        return generate(args.out_dir, backup=False)
    if args.cmd == "rotate":
        return generate(args.out_dir, backup=True)
    if args.cmd == "remove-local":
        return remove_local(args.cert, args.key, args.yes)
    if args.cmd == "emergency":
        return emergency(args.out_dir)
    if args.cmd == "restrict-key":
        from core.key_at_rest import restrict_key_permissions

        report = restrict_key_permissions(args.key)
        payload = {
            "path": report.path,
            "platform": report.platform,
            "action": report.action,
            "status": report.status,
            "detail": report.detail,
            "dpapi_available": report.dpapi_available,
        }
        if args.json:
            print(json.dumps(payload, indent=2, ensure_ascii=False))
        else:
            print(f"status: {report.status}")
            print(f"detail: {report.detail}")
        return 0 if report.status == "pass" else 2
    if args.cmd == "wrap-key":
        from core.key_at_rest import wrap_key_dpapi

        report = wrap_key_dpapi(args.key, remove_plaintext=args.remove_plaintext)
        payload = {
            "path": report.path,
            "platform": report.platform,
            "action": report.action,
            "status": report.status,
            "detail": report.detail,
            "dpapi_available": report.dpapi_available,
        }
        if args.json:
            print(json.dumps(payload, indent=2, ensure_ascii=False))
        else:
            print(f"status: {report.status}")
            print(f"detail: {report.detail}")
        return 0 if report.status == "pass" else 2
    if args.cmd == "unwrap-key":
        from core.key_at_rest import unwrap_key_dpapi

        report = unwrap_key_dpapi(args.key)
        payload = {
            "path": report.path,
            "platform": report.platform,
            "action": report.action,
            "status": report.status,
            "detail": report.detail,
            "dpapi_available": report.dpapi_available,
        }
        if args.json:
            print(json.dumps(payload, indent=2, ensure_ascii=False))
        else:
            print(f"status: {report.status}")
            print(f"detail: {report.detail}")
        return 0 if report.status == "pass" else 2
    if args.cmd == "cdp-assist":
        from core.cdp_client import assist_profile_trust_setup

        report = assist_profile_trust_setup(
            port=args.port,
            cert_path=str(args.cert.expanduser().resolve()),
            browser=args.browser,
            wait_timeout_s=args.wait_timeout,
        )
        payload = {
            "port": report.port,
            "action": report.action,
            "status": report.status,
            "detail": report.detail,
            "browser": report.browser,
            "web_socket_url": report.web_socket_url,
            "opened_url": report.opened_url,
        }
        if args.json:
            print(json.dumps(payload, indent=2, ensure_ascii=False))
        else:
            print(f"status: {report.status}")
            print(f"detail: {report.detail}")
        return 0 if report.status == "pass" else 2
    return 2


if __name__ == "__main__":
    raise SystemExit(main())

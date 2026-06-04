#!/usr/bin/env python3
"""At-rest helpers for the local CA private key (ACL tighten and optional DPAPI wrap)."""
from __future__ import annotations

import os
import stat
import subprocess
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class KeyAtRestReport:
    path: str
    platform: str
    action: str
    status: str
    detail: str
    dpapi_available: bool = False


def dpapi_available() -> bool:
    return os.name == "nt"


def dpapi_sidecar_path(key_path: Path) -> Path:
    key_path = key_path.expanduser().resolve()
    return key_path.with_name(key_path.name + ".dpapi")


def key_is_wrapped_only(key_path: Path) -> bool:
    key_path = key_path.expanduser().resolve()
    sidecar = dpapi_sidecar_path(key_path)
    return sidecar.exists() and not key_path.exists()


def _crypt_protect(data: bytes) -> bytes:
    import ctypes
    from ctypes import wintypes

    class DATA_BLOB(ctypes.Structure):
        _fields_ = [("cbData", wintypes.DWORD), ("pbData", ctypes.POINTER(ctypes.c_byte))]

    def _to_blob(raw: bytes) -> tuple[DATA_BLOB, ctypes.Array]:
        buf = ctypes.create_string_buffer(raw, len(raw))
        blob = DATA_BLOB(len(raw), ctypes.cast(buf, ctypes.POINTER(ctypes.c_byte)))
        return blob, buf

    in_blob, in_buf = _to_blob(data)
    out_blob = DATA_BLOB()
    if not ctypes.windll.crypt32.CryptProtectData(
        ctypes.byref(in_blob),
        None,
        None,
        None,
        None,
        0,
        ctypes.byref(out_blob),
    ):
        raise OSError("CryptProtectData failed")
    _ = in_buf
    try:
        return ctypes.string_at(out_blob.pbData, out_blob.cbData)
    finally:
        ctypes.windll.kernel32.LocalFree(out_blob.pbData)


def _crypt_unprotect(data: bytes) -> bytes:
    import ctypes
    from ctypes import wintypes

    class DATA_BLOB(ctypes.Structure):
        _fields_ = [("cbData", wintypes.DWORD), ("pbData", ctypes.POINTER(ctypes.c_byte))]

    def _to_blob(raw: bytes) -> tuple[DATA_BLOB, ctypes.Array]:
        buf = ctypes.create_string_buffer(raw, len(raw))
        blob = DATA_BLOB(len(raw), ctypes.cast(buf, ctypes.POINTER(ctypes.c_byte)))
        return blob, buf

    in_blob, in_buf = _to_blob(data)
    out_blob = DATA_BLOB()
    if not ctypes.windll.crypt32.CryptUnprotectData(
        ctypes.byref(in_blob),
        None,
        None,
        None,
        None,
        0,
        ctypes.byref(out_blob),
    ):
        raise OSError("CryptUnprotectData failed")
    _ = in_buf
    try:
        return ctypes.string_at(out_blob.pbData, out_blob.cbData)
    finally:
        ctypes.windll.kernel32.LocalFree(out_blob.pbData)


def wrap_key_dpapi(key_path: Path, *, remove_plaintext: bool = False) -> KeyAtRestReport:
    if not dpapi_available():
        return KeyAtRestReport(
            path=str(key_path),
            platform=os.name,
            action="wrap",
            status="warn",
            detail="DPAPI wrap is Windows-only",
            dpapi_available=False,
        )
    key_path = key_path.expanduser().resolve()
    if not key_path.exists():
        return KeyAtRestReport(
            path=str(key_path),
            platform="nt",
            action="wrap",
            status="fail",
            detail="private key file not found",
            dpapi_available=True,
        )
    sidecar = dpapi_sidecar_path(key_path)
    try:
        protected = _crypt_protect(key_path.read_bytes())
        sidecar.write_bytes(protected)
        if remove_plaintext:
            key_path.unlink()
        else:
            restrict_key_permissions(key_path)
        return KeyAtRestReport(
            path=str(key_path),
            platform="nt",
            action="wrap",
            status="pass",
            detail=f"DPAPI sidecar written to {sidecar.name}"
            + ("; plaintext removed" if remove_plaintext else "; plaintext retained"),
            dpapi_available=True,
        )
    except OSError as exc:
        return KeyAtRestReport(
            path=str(key_path),
            platform="nt",
            action="wrap",
            status="fail",
            detail=str(exc),
            dpapi_available=True,
        )


def unwrap_key_dpapi(key_path: Path) -> KeyAtRestReport:
    if not dpapi_available():
        return KeyAtRestReport(
            path=str(key_path),
            platform=os.name,
            action="unwrap",
            status="warn",
            detail="DPAPI unwrap is Windows-only",
            dpapi_available=False,
        )
    key_path = key_path.expanduser().resolve()
    sidecar = dpapi_sidecar_path(key_path)
    if not sidecar.exists():
        return KeyAtRestReport(
            path=str(key_path),
            platform="nt",
            action="unwrap",
            status="fail",
            detail="DPAPI sidecar not found",
            dpapi_available=True,
        )
    try:
        plaintext = _crypt_unprotect(sidecar.read_bytes())
        key_path.write_bytes(plaintext)
        restrict_key_permissions(key_path)
        return KeyAtRestReport(
            path=str(key_path),
            platform="nt",
            action="unwrap",
            status="pass",
            detail=f"Restored plaintext key from {sidecar.name}",
            dpapi_available=True,
        )
    except OSError as exc:
        return KeyAtRestReport(
            path=str(key_path),
            platform="nt",
            action="unwrap",
            status="fail",
            detail=str(exc),
            dpapi_available=True,
        )


def ensure_key_material_available(key_path: Path) -> KeyAtRestReport:
    key_path = key_path.expanduser().resolve()
    if key_path.exists():
        return KeyAtRestReport(
            path=str(key_path),
            platform=os.name,
            action="ensure",
            status="pass",
            detail="plaintext key present",
            dpapi_available=dpapi_available(),
        )
    if key_is_wrapped_only(key_path):
        return unwrap_key_dpapi(key_path)
    return KeyAtRestReport(
        path=str(key_path),
        platform=os.name,
        action="ensure",
        status="fail",
        detail="private key missing (no DPAPI sidecar)",
        dpapi_available=dpapi_available(),
    )


def restrict_key_permissions(key_path: Path) -> KeyAtRestReport:
    key_path = key_path.expanduser().resolve()
    if not key_path.exists():
        return KeyAtRestReport(
            path=str(key_path),
            platform=os.name,
            action="restrict",
            status="fail",
            detail="private key file not found",
            dpapi_available=dpapi_available(),
        )
    if os.name == "nt":
        username = os.environ.get("USERNAME") or os.environ.get("USER") or ""
        if not username:
            return KeyAtRestReport(
                path=str(key_path),
                platform="nt",
                action="restrict",
                status="warn",
                detail="current Windows user unknown; run icacls manually",
                dpapi_available=False,
            )
        grant = f"{username}:(F)"
        commands = [
            ["icacls", str(key_path), "/inheritance:r"],
            ["icacls", str(key_path), "/grant:r", grant],
        ]
        for cmd in commands:
            proc = subprocess.run(cmd, text=True, capture_output=True, check=False)
            if proc.returncode != 0:
                detail = (proc.stderr or proc.stdout or "icacls failed").strip()
                return KeyAtRestReport(
                    path=str(key_path),
                    platform="nt",
                    action="restrict",
                    status="fail",
                    detail=detail,
                    dpapi_available=False,
                )
        return KeyAtRestReport(
            path=str(key_path),
            platform="nt",
            action="restrict",
            status="pass",
            detail=f"ACL reset to current user only ({username})",
            dpapi_available=dpapi_available(),
        )
    mode = stat.S_IMODE(key_path.stat().st_mode)
    key_path.chmod(0o600)
    return KeyAtRestReport(
        path=str(key_path),
        platform="posix",
        action="restrict",
        status="pass",
        detail=f"mode {oct(mode)} -> 0o600",
        dpapi_available=False,
    )

#!/usr/bin/env python3
"""Download a local Xray runtime into ./xray using only the standard library."""
from __future__ import annotations

import argparse
import json
import platform
import shutil
import sys
import tempfile
import urllib.request
import zipfile
from pathlib import Path
from typing import Any

API_URL = "https://api.github.com/repos/XTLS/Xray-core/releases/latest"


def platform_asset_terms() -> tuple[str, str]:
    system = platform.system().lower()
    machine = platform.machine().lower()
    if system == "windows":
        os_term = "windows"
    elif system == "darwin":
        os_term = "macos"
    elif system == "linux":
        os_term = "linux"
    else:
        raise SystemExit(f"Unsupported OS for automatic Xray download: {platform.system()}")
    if machine in {"amd64", "x86_64", "x64"}:
        arch_term = "64"
    elif machine in {"arm64", "aarch64"}:
        arch_term = "arm64"
    else:
        raise SystemExit(f"Unsupported CPU architecture for automatic Xray download: {platform.machine()}")
    return os_term, arch_term


def fetch_json(url: str) -> dict[str, Any]:
    req = urllib.request.Request(url, headers={"User-Agent": "MITM-DomainFronting-local-installer"})
    with urllib.request.urlopen(req, timeout=30) as response:  # noqa: S310
        return json.loads(response.read().decode("utf-8"))


def choose_asset(release: dict[str, Any]) -> tuple[str, str]:
    os_term, arch_term = platform_asset_terms()
    for asset in release.get("assets", []):
        name = str(asset.get("name", ""))
        lower = name.lower()
        if not lower.endswith(".zip"):
            continue
        if os_term in lower and arch_term in lower and "xray" in lower:
            url = str(asset.get("browser_download_url", ""))
            if url:
                return name, url
    raise SystemExit(f"No matching Xray asset found for {os_term}/{arch_term}")


def download(url: str, dest: Path) -> None:
    req = urllib.request.Request(url, headers={"User-Agent": "MITM-DomainFronting-local-installer"})
    with urllib.request.urlopen(req, timeout=120) as response:  # noqa: S310
        with dest.open("wb") as f:
            shutil.copyfileobj(response, f)


def install_archive(archive: Path, out_dir: Path, force: bool) -> list[Path]:
    out_dir.mkdir(parents=True, exist_ok=True)
    installed: list[Path] = []
    wanted = {"xray.exe", "xray", "geoip.dat", "geosite.dat"}
    with zipfile.ZipFile(archive) as zf:
        for member in zf.infolist():
            name = Path(member.filename).name
            if name not in wanted or member.is_dir():
                continue
            target = out_dir / name
            if target.exists() and not force:
                installed.append(target)
                continue
            with zf.open(member) as src, target.open("wb") as dst:
                shutil.copyfileobj(src, dst)
            if name == "xray" and platform.system().lower() != "windows":
                target.chmod(0o755)
            installed.append(target)
    if not any(path.name in {"xray.exe", "xray"} for path in installed):
        raise SystemExit("Downloaded archive did not contain an Xray executable")
    return installed


def main() -> int:
    parser = argparse.ArgumentParser(description="Download local Xray runtime into ./xray")
    parser.add_argument("--out-dir", type=Path, default=Path("xray"))
    parser.add_argument("--force", action="store_true", help="overwrite existing local files")
    args = parser.parse_args()
    release = fetch_json(API_URL)
    asset_name, asset_url = choose_asset(release)
    with tempfile.TemporaryDirectory(prefix="xray-download-") as tmp:
        archive = Path(tmp) / asset_name
        print(f"download: {asset_url}")
        download(asset_url, archive)
        installed = install_archive(archive, args.out_dir, args.force)
    print("installed:")
    for path in installed:
        print(f"  {path}")
    print("Xray files are local runtime artifacts and should not be committed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

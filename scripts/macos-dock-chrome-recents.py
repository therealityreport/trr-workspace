#!/usr/bin/env python3
from __future__ import annotations

import argparse
import plistlib
import platform
import subprocess
import sys
from pathlib import Path
from typing import Any


DEFAULT_BUNDLE_ID = "com.google.Chrome"
DEFAULT_DOCK_PLIST = Path.home() / "Library" / "Preferences" / "com.apple.dock.plist"
BINARY_PLIST_HEADER = b"bplist00"


def _tile_bundle_id(item: object) -> str:
    if not isinstance(item, dict):
        return ""
    tile_data = item.get("tile-data")
    if not isinstance(tile_data, dict):
        return ""
    bundle_id = tile_data.get("bundle-identifier")
    if not isinstance(bundle_id, str):
        return ""
    return bundle_id.strip()


def remove_recent_apps_for_bundle(
    dock_data: dict[str, Any],
    *,
    bundle_id: str = DEFAULT_BUNDLE_ID,
) -> tuple[dict[str, Any], int]:
    recent_apps = dock_data.get("recent-apps")
    if not isinstance(recent_apps, list):
        return dock_data, 0

    kept_recent_apps = [
        item for item in recent_apps if _tile_bundle_id(item) != bundle_id
    ]
    removed_count = len(recent_apps) - len(kept_recent_apps)
    if removed_count == 0:
        return dock_data, 0

    updated = dict(dock_data)
    updated["recent-apps"] = kept_recent_apps
    return updated, removed_count


def _plist_format_for_path(path: Path) -> plistlib.PlistFormat:
    with path.open("rb") as handle:
        header = handle.read(len(BINARY_PLIST_HEADER))
    if header == BINARY_PLIST_HEADER:
        return plistlib.FMT_BINARY
    return plistlib.FMT_XML


def clean_dock_plist(
    dock_plist: Path,
    *,
    bundle_id: str = DEFAULT_BUNDLE_ID,
    dry_run: bool = False,
) -> int:
    if not dock_plist.exists():
        return 0

    original_format = _plist_format_for_path(dock_plist)
    with dock_plist.open("rb") as handle:
        dock_data = plistlib.load(handle)

    if not isinstance(dock_data, dict):
        raise ValueError(f"Dock plist root is not a dictionary: {dock_plist}")

    updated, removed_count = remove_recent_apps_for_bundle(
        dock_data,
        bundle_id=bundle_id,
    )
    if removed_count == 0 or dry_run:
        return removed_count

    with dock_plist.open("wb") as handle:
        plistlib.dump(updated, handle, fmt=original_format)
    return removed_count


def restart_dock_if_needed(removed_count: int, *, restart_dock: bool) -> bool:
    if removed_count <= 0 or not restart_dock:
        return False
    if platform.system() != "Darwin":
        return False
    result = subprocess.run(["killall", "Dock"], check=False)
    return result.returncode == 0


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Remove Google Chrome entries from macOS Dock recent apps.",
    )
    parser.add_argument(
        "--plist",
        type=Path,
        default=DEFAULT_DOCK_PLIST,
        help="Dock plist path. Defaults to the current user's Dock preferences.",
    )
    parser.add_argument(
        "--bundle-id",
        default=DEFAULT_BUNDLE_ID,
        help="Bundle identifier to remove from recent-apps.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Report removable entries without writing the plist.",
    )
    parser.add_argument(
        "--restart-dock",
        action="store_true",
        help="Restart Dock when entries were removed.",
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    removed_count = clean_dock_plist(
        args.plist.expanduser(),
        bundle_id=args.bundle_id,
        dry_run=args.dry_run,
    )
    dock_restarted = restart_dock_if_needed(
        removed_count,
        restart_dock=args.restart_dock and not args.dry_run,
    )
    print(f"chrome_recent_apps_removed={removed_count}")
    print(f"dock_restarted={1 if dock_restarted else 0}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

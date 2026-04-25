from __future__ import annotations

import importlib.util
import plistlib
import subprocess
from pathlib import Path
from types import ModuleType


SCRIPT_PATH = Path(__file__).resolve().parent / "macos-dock-chrome-recents.py"


def _chrome_tile(guid: int) -> dict[str, object]:
    return {
        "GUID": guid,
        "tile-data": {
            "bundle-identifier": "com.google.Chrome",
            "file-label": "Google Chrome",
            "file-data": {
                "_CFURLString": "file:///Applications/Google%20Chrome.app/",
                "_CFURLStringType": 15,
            },
        },
        "tile-type": "file-tile",
    }


def _safari_tile(guid: int) -> dict[str, object]:
    return {
        "GUID": guid,
        "tile-data": {
            "bundle-identifier": "com.apple.Safari",
            "file-label": "Safari",
            "file-data": {
                "_CFURLString": "file:///Applications/Safari.app/",
                "_CFURLStringType": 15,
            },
        },
        "tile-type": "file-tile",
    }


def _write_plist(
    path: Path,
    data: dict[str, object],
    *,
    fmt: plistlib.PlistFormat = plistlib.FMT_XML,
) -> None:
    with path.open("wb") as handle:
        plistlib.dump(data, handle, fmt=fmt)


def _read_plist(path: Path) -> dict[str, object]:
    with path.open("rb") as handle:
        return plistlib.load(handle)


def _run_tool(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["python3", str(SCRIPT_PATH), *args],
        capture_output=True,
        text=True,
        check=False,
    )


def _load_script_module() -> ModuleType:
    spec = importlib.util.spec_from_file_location(
        "macos_dock_chrome_recents",
        SCRIPT_PATH,
    )
    assert spec is not None
    assert spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_clean_removes_only_chrome_recent_apps(tmp_path: Path) -> None:
    dock_plist = tmp_path / "com.apple.dock.plist"
    _write_plist(
        dock_plist,
        {
            "persistent-apps": [_chrome_tile(1)],
            "recent-apps": [_chrome_tile(2), _safari_tile(3), _chrome_tile(4)],
        },
    )

    result = _run_tool("--plist", str(dock_plist))

    assert result.returncode == 0, result.stderr
    assert result.stdout == "chrome_recent_apps_removed=2\ndock_restarted=0\n"
    data = _read_plist(dock_plist)
    assert data["persistent-apps"] == [_chrome_tile(1)]
    assert data["recent-apps"] == [_safari_tile(3)]


def test_clean_dry_run_reports_count_without_writing(tmp_path: Path) -> None:
    dock_plist = tmp_path / "com.apple.dock.plist"
    original = {
        "persistent-apps": [],
        "recent-apps": [_chrome_tile(10), _safari_tile(11), _chrome_tile(12)],
    }
    _write_plist(dock_plist, original)

    result = _run_tool("--plist", str(dock_plist), "--dry-run")

    assert result.returncode == 0, result.stderr
    assert result.stdout == "chrome_recent_apps_removed=2\ndock_restarted=0\n"
    assert _read_plist(dock_plist) == original


def test_clean_handles_missing_recent_apps(tmp_path: Path) -> None:
    dock_plist = tmp_path / "com.apple.dock.plist"
    original = {"persistent-apps": [_chrome_tile(20)]}
    _write_plist(dock_plist, original)

    result = _run_tool("--plist", str(dock_plist))

    assert result.returncode == 0, result.stderr
    assert result.stdout == "chrome_recent_apps_removed=0\ndock_restarted=0\n"
    assert _read_plist(dock_plist) == original


def test_clean_missing_plist_is_noop(tmp_path: Path) -> None:
    dock_plist = tmp_path / "missing.plist"

    result = _run_tool("--plist", str(dock_plist))

    assert result.returncode == 0, result.stderr
    assert result.stdout == "chrome_recent_apps_removed=0\ndock_restarted=0\n"
    assert not dock_plist.exists()


def test_clean_preserves_binary_plist_format(tmp_path: Path) -> None:
    dock_plist = tmp_path / "com.apple.dock.plist"
    _write_plist(
        dock_plist,
        {
            "persistent-apps": [],
            "recent-apps": [_chrome_tile(30), _safari_tile(31)],
        },
        fmt=plistlib.FMT_BINARY,
    )
    assert dock_plist.read_bytes().startswith(b"bplist00")

    result = _run_tool("--plist", str(dock_plist))

    assert result.returncode == 0, result.stderr
    assert result.stdout == "chrome_recent_apps_removed=1\ndock_restarted=0\n"
    assert dock_plist.read_bytes().startswith(b"bplist00")
    assert _read_plist(dock_plist)["recent-apps"] == [_safari_tile(31)]


def test_restart_dock_if_needed_returns_true_when_killall_succeeds(
    monkeypatch,
) -> None:
    module = _load_script_module()
    calls: list[tuple[list[str], bool]] = []

    def fake_run(args: list[str], *, check: bool) -> subprocess.CompletedProcess[str]:
        calls.append((args, check))
        return subprocess.CompletedProcess(args=args, returncode=0)

    monkeypatch.setattr(module.platform, "system", lambda: "Darwin")
    monkeypatch.setattr(module.subprocess, "run", fake_run)

    assert module.restart_dock_if_needed(1, restart_dock=True) is True
    assert calls == [(["killall", "Dock"], False)]


def test_restart_dock_if_needed_returns_false_when_killall_fails(
    monkeypatch,
) -> None:
    module = _load_script_module()

    def fake_run(args: list[str], *, check: bool) -> subprocess.CompletedProcess[str]:
        return subprocess.CompletedProcess(args=args, returncode=1)

    monkeypatch.setattr(module.platform, "system", lambda: "Darwin")
    monkeypatch.setattr(module.subprocess, "run", fake_run)

    assert module.restart_dock_if_needed(1, restart_dock=True) is False


def test_restart_dock_if_needed_skips_non_darwin(monkeypatch) -> None:
    module = _load_script_module()
    calls: list[tuple[list[str], bool]] = []

    def fake_run(args: list[str], *, check: bool) -> subprocess.CompletedProcess[str]:
        calls.append((args, check))
        return subprocess.CompletedProcess(args=args, returncode=0)

    monkeypatch.setattr(module.platform, "system", lambda: "Linux")
    monkeypatch.setattr(module.subprocess, "run", fake_run)

    assert module.restart_dock_if_needed(1, restart_dock=True) is False
    assert calls == []

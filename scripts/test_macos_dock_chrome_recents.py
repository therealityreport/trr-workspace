from __future__ import annotations

import importlib.util
import os
import plistlib
import shutil
import stat
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


WRAPPER_PATH = Path(__file__).resolve().parent / "cleanup-chrome-dock-recents.sh"


def _run_wrapper(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["bash", str(WRAPPER_PATH), *args],
        capture_output=True,
        text=True,
        check=False,
    )


def test_wrapper_passes_custom_plist_without_restarting_dock(tmp_path: Path) -> None:
    dock_plist = tmp_path / "com.apple.dock.plist"
    _write_plist(
        dock_plist,
        {
            "persistent-apps": [],
            "recent-apps": [_chrome_tile(30), _safari_tile(31)],
        },
    )

    result = _run_wrapper("--plist", str(dock_plist), "--no-restart-dock")

    assert result.returncode == 0, result.stderr
    assert result.stdout == "chrome_recent_apps_removed=1\ndock_restarted=0\n"
    assert _read_plist(dock_plist)["recent-apps"] == [_safari_tile(31)]


def test_wrapper_dry_run_keeps_custom_plist(tmp_path: Path) -> None:
    dock_plist = tmp_path / "com.apple.dock.plist"
    original = {
        "persistent-apps": [],
        "recent-apps": [_chrome_tile(40), _safari_tile(41)],
    }
    _write_plist(dock_plist, original)

    result = _run_wrapper("--plist", str(dock_plist), "--dry-run", "--no-restart-dock")

    assert result.returncode == 0, result.stderr
    assert result.stdout == "chrome_recent_apps_removed=1\ndock_restarted=0\n"
    assert _read_plist(dock_plist) == original


STOP_CHROME_AGENT_PATH = Path(__file__).resolve().parent / "stop-chrome-agent.sh"
MCP_CLEAN_PATH = Path(__file__).resolve().parent / "mcp-clean.sh"


def test_stop_chrome_agent_contains_opt_in_dock_cleanup_hook() -> None:
    source = STOP_CHROME_AGENT_PATH.read_text()
    assert "cleanup_chrome_dock_recents_if_requested" in source
    assert '[[ "${CHROME_AGENT_CLEAN_DOCK_RECENTS:-0}" == "1" ]]' in source
    assert '"${ROOT}/scripts/cleanup-chrome-dock-recents.sh"' in source


def test_mcp_clean_contains_opt_in_dock_cleanup_hook() -> None:
    source = MCP_CLEAN_PATH.read_text()
    assert "cleanup_chrome_dock_recents_if_requested" in source
    assert '[[ "${CHROME_AGENT_CLEAN_DOCK_RECENTS:-0}" == "1" ]]' in source
    assert '"${ROOT}/scripts/cleanup-chrome-dock-recents.sh"' in source


def _make_executable(path: Path) -> None:
    path.chmod(path.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


def _write_executable(path: Path, content: str) -> None:
    path.write_text(content)
    _make_executable(path)


def _create_mini_workspace(tmp_path: Path) -> Path:
    workspace = tmp_path / "mini-workspace"
    scripts_dir = workspace / "scripts"
    lib_dir = scripts_dir / "lib"
    bin_dir = workspace / "bin"
    lib_dir.mkdir(parents=True)
    bin_dir.mkdir()

    for source in (
        STOP_CHROME_AGENT_PATH,
        MCP_CLEAN_PATH,
        WRAPPER_PATH,
        SCRIPT_PATH,
    ):
        target = scripts_dir / source.name
        shutil.copy2(source, target)
        _make_executable(target)

    _write_executable(
        lib_dir / "mcp-runtime.sh",
        """\
chrome_wrapper_pids() { return 0; }
shared_chrome_client_pids() { return 0; }
pid_is_descendant_of() { return 1; }
kill_pid_tree() { return 1; }
""",
    )
    _write_executable(
        scripts_dir / "codex-mcp-session-reaper.sh",
        """\
#!/usr/bin/env bash
echo "[stub] reaper"
""",
    )
    _write_executable(
        scripts_dir / "chrome-devtools-mcp-clean-stale.sh",
        """\
#!/usr/bin/env bash
echo "[stub] chrome-clean"
""",
    )
    _write_executable(
        bin_dir / "uname",
        """\
#!/usr/bin/env bash
echo Darwin
""",
    )
    _write_executable(
        bin_dir / "killall",
        """\
#!/usr/bin/env bash
echo "[stub] killall $*" >&2
""",
    )
    return workspace


def _mini_env(workspace: Path, **extra: str) -> dict[str, str]:
    env = os.environ.copy()
    env.pop("CHROME_AGENT_CLEAN_DOCK_RECENTS", None)
    env.pop("CHROME_AGENT_STOP_ALL", None)
    env["PATH"] = f"{workspace / 'bin'}{os.pathsep}{env['PATH']}"
    env.update(extra)
    return env


def _write_chrome_and_safari_plist(path: Path) -> None:
    _write_plist(
        path,
        {
            "persistent-apps": [],
            "recent-apps": [_chrome_tile(50), _safari_tile(51)],
        },
    )


def test_stop_chrome_agent_stop_all_no_pid_runs_opt_in_cleanup(
    tmp_path: Path,
) -> None:
    workspace = _create_mini_workspace(tmp_path)
    dock_plist = tmp_path / "com.apple.dock.plist"
    _write_chrome_and_safari_plist(dock_plist)

    result = subprocess.run(
        ["bash", str(workspace / "scripts" / "stop-chrome-agent.sh")],
        capture_output=True,
        text=True,
        check=False,
        env=_mini_env(
            workspace,
            CHROME_AGENT_STOP_ALL="1",
            CHROME_AGENT_CLEAN_DOCK_RECENTS="1",
            CHROME_DOCK_PLIST=str(dock_plist),
        ),
    )

    assert result.returncode == 0, result.stderr
    assert "chrome_recent_apps_removed=1" in result.stderr
    assert "dock_restarted=" in result.stderr
    assert _read_plist(dock_plist)["recent-apps"] == [_safari_tile(51)]


def test_mcp_clean_without_opt_in_does_not_touch_dock_or_emit_cleanup(
    tmp_path: Path,
) -> None:
    workspace = _create_mini_workspace(tmp_path)
    dock_plist = tmp_path / "com.apple.dock.plist"
    _write_chrome_and_safari_plist(dock_plist)

    result = subprocess.run(
        ["bash", str(workspace / "scripts" / "mcp-clean.sh")],
        capture_output=True,
        text=True,
        check=False,
        env=_mini_env(workspace, CHROME_DOCK_PLIST=str(dock_plist)),
    )

    assert result.returncode == 0, result.stderr
    assert "chrome_recent_apps_removed" not in result.stdout
    assert _read_plist(dock_plist)["recent-apps"] == [
        _chrome_tile(50),
        _safari_tile(51),
    ]


def test_mcp_clean_with_opt_in_runs_dock_cleanup(tmp_path: Path) -> None:
    workspace = _create_mini_workspace(tmp_path)
    dock_plist = tmp_path / "com.apple.dock.plist"
    _write_chrome_and_safari_plist(dock_plist)

    result = subprocess.run(
        ["bash", str(workspace / "scripts" / "mcp-clean.sh")],
        capture_output=True,
        text=True,
        check=False,
        env=_mini_env(
            workspace,
            CHROME_AGENT_CLEAN_DOCK_RECENTS="1",
            CHROME_DOCK_PLIST=str(dock_plist),
        ),
    )

    assert result.returncode == 0, result.stderr
    assert "chrome_recent_apps_removed=1" in result.stdout
    assert _read_plist(dock_plist)["recent-apps"] == [_safari_tile(51)]

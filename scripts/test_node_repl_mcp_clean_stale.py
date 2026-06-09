from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path


SCRIPT_PATH = Path(__file__).resolve().parent / "node-repl-mcp-clean-stale.sh"


def _run_clean(active_execs_dir: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["/bin/bash", str(SCRIPT_PATH)],
        capture_output=True,
        text=True,
        check=False,
        env={
            **os.environ,
            "NODE_REPL_ACTIVE_EXECS_DIR": str(active_execs_dir),
            "NODE_REPL_STALE_STAMP": "20260608000000",
        },
    )


def _run_project_clean(
    active_execs_dir: Path,
    project_root: Path,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["/bin/bash", str(SCRIPT_PATH)],
        capture_output=True,
        text=True,
        check=False,
        env={
            **os.environ,
            "NODE_REPL_ACTIVE_EXECS_DIR": str(active_execs_dir),
            "NODE_REPL_STALE_STAMP": "20260608000000",
            "NODE_REPL_CLEAN_PROJECT_OWNED": "1",
            "NODE_REPL_PROJECT_ROOT": str(project_root),
        },
    )


def test_clean_stale_exec_marker_when_recorded_processes_are_dead(tmp_path: Path) -> None:
    marker = tmp_path / "dead-session.json"
    marker.write_text(
        json.dumps({"nodeReplPid": 999999, "kernelPid": 999998}),
        encoding="utf-8",
    )

    result = _run_clean(tmp_path)

    assert result.returncode == 0, result.stderr
    assert not marker.exists()
    assert (tmp_path / "dead-session.json.stale-20260608000000").exists()
    assert "cleaned: 1" in result.stdout
    assert "retained_live=0" in result.stdout


def test_retains_marker_when_recorded_process_is_live(tmp_path: Path) -> None:
    marker = tmp_path / "live-session.json"
    marker.write_text(
        json.dumps({"nodeReplPid": os.getpid(), "kernelPid": 999998}),
        encoding="utf-8",
    )

    result = _run_clean(tmp_path)

    assert result.returncode == 0, result.stderr
    assert marker.exists()
    assert not (tmp_path / "live-session.json.stale-20260608000000").exists()
    assert "cleaned: 0" in result.stdout
    assert "retained_live=1" in result.stdout


def test_retires_project_owned_node_repl_marker(tmp_path: Path) -> None:
    active_execs_dir = tmp_path / "active_execs"
    active_execs_dir.mkdir()
    project_root = tmp_path / "project"
    project_root.mkdir()
    fake_node_repl = tmp_path / "node_repl"
    fake_node_repl.write_text("#!/usr/bin/env bash\nsleep 30\n", encoding="utf-8")
    fake_node_repl.chmod(0o755)

    process = subprocess.Popen([str(fake_node_repl)], cwd=project_root)
    try:
        marker = active_execs_dir / "project-session.json"
        marker.write_text(
            json.dumps({"nodeReplPid": process.pid, "kernelPid": 999998}),
            encoding="utf-8",
        )

        result = _run_project_clean(active_execs_dir, project_root)

        assert result.returncode == 0, result.stderr
        assert not marker.exists()
        assert (active_execs_dir / "project-session.json.stale-20260608000000").exists()
        assert "cleaned: 1" in result.stdout
        assert "retired_project_owned=1" in result.stdout
        process.wait(timeout=5)
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=5)


def test_missing_active_execs_dir_is_a_noop(tmp_path: Path) -> None:
    result = _run_clean(tmp_path / "missing")

    assert result.returncode == 0, result.stderr
    assert "cleaned: 0" in result.stdout
    assert "retained_live=0" in result.stdout

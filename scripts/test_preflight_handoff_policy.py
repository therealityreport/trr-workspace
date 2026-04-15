from __future__ import annotations

import subprocess
from pathlib import Path


SCRIPT_PATH = Path(__file__).resolve().parent / "lib" / "preflight-handoff.sh"


def _run_bash(script: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["/bin/bash", "-lc", script],
        capture_output=True,
        text=True,
        check=False,
    )


def test_handoff_sync_succeeds_without_warning() -> None:
    result = _run_bash(
        f"""
        source "{SCRIPT_PATH}"
        output="$(preflight_handle_handoff_sync_result 0 0 '[sync-handoffs] OK: wrote handoffs for workspace')"
        printf '%s' "$output"
        """
    )

    assert result.returncode == 0, result.stderr
    assert result.stdout == ""


def test_handoff_sync_warns_and_continues_when_not_strict() -> None:
    result = _run_bash(
        f"""
        source "{SCRIPT_PATH}"
        set +e
        output="$(preflight_handle_handoff_sync_result 0 2 '[sync-handoffs] ERROR: docs/ai/local-status/example.md: state must be one of active, archived, blocked, recent.')"
        rc="$?"
        set -e
        printf 'rc=%s\\n%s' "$rc" "$output"
        """
    )

    assert result.returncode == 0, result.stderr
    assert "rc=0" in result.stdout
    assert "[preflight] WARNING: handoff sync failed; continuing because WORKSPACE_PREFLIGHT_STRICT=0." in result.stdout
    assert "docs/ai/local-status/example.md: state must be one of active, archived, blocked, recent." in result.stdout
    assert "make handoff-check" in result.stdout
    assert "make preflight-strict" in result.stdout


def test_handoff_sync_fails_when_strict() -> None:
    result = _run_bash(
        f"""
        source "{SCRIPT_PATH}"
        set +e
        preflight_handle_handoff_sync_result 1 2 '[sync-handoffs] ERROR: docs/ai/local-status/example.md: missing ## Handoff Snapshot section.'
        rc="$?"
        set -e
        printf 'rc=%s' "$rc"
        """
    )

    assert result.returncode == 0, result.stderr
    assert result.stdout == "rc=2"

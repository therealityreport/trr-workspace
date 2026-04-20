from __future__ import annotations

import subprocess
from pathlib import Path


SCRIPT_PATH = Path(__file__).resolve().parent / "lib" / "workspace-terminal.sh"


def _run_bash(script: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["/bin/bash", "-lc", script],
        capture_output=True,
        text=True,
        check=False,
    )


def test_attention_render_is_empty_when_no_items(tmp_path: Path) -> None:
    attention_file = tmp_path / "attention.log"

    result = _run_bash(
        f"""
        source "{SCRIPT_PATH}"
        workspace_attention_reset "{attention_file}"
        workspace_attention_render "{attention_file}" "[workspace]"
        """
    )

    assert result.returncode == 0, result.stderr
    assert result.stdout == ""


def test_attention_render_groups_nonblocking_items(tmp_path: Path) -> None:
    attention_file = tmp_path / "attention.log"

    result = _run_bash(
        f"""
        source "{SCRIPT_PATH}"
        workspace_attention_reset "{attention_file}"
        workspace_attention_add "{attention_file}" \
          "Browser automation pressure is degraded." \
          "Impact: chrome-devtools is available, but local browser pressure is elevated." \
          "Remediation: run 'make mcp-clean' if stale Chrome runtime artifacts or external MCP leftovers are not expected."
        workspace_attention_render "{attention_file}" "[workspace]"
        """
    )

    assert result.returncode == 0, result.stderr
    assert result.stdout == (
        "[workspace] Attention:\n"
        "  - Browser automation pressure is degraded.\n"
        "    Impact: chrome-devtools is available, but local browser pressure is elevated.\n"
        "    Remediation: run 'make mcp-clean' if stale Chrome runtime artifacts or external MCP leftovers are not expected.\n"
    )


def test_reaper_summary_compacts_all_zero_counts() -> None:
    result = _run_bash(
        f"""
        source "{SCRIPT_PATH}"
        workspace_reaper_render_summary "[mcp-session-reaper]" 0 0 0 0 0 0 0 0 0
        """
    )

    assert result.returncode == 0, result.stderr
    assert result.stdout == "[mcp-session-reaper] No stale MCP/Chrome runtime artifacts found.\n"


def test_reaper_summary_keeps_detailed_counts_when_cleanup_happened() -> None:
    result = _run_bash(
        f"""
        source "{SCRIPT_PATH}"
        workspace_reaper_render_summary "[mcp-session-reaper]" 2 1 0 0 0 0 1 0 0
        """
    )

    assert result.returncode == 0, result.stderr
    assert result.stdout == (
        "=== REAP SUMMARY ===\n"
        "KILLED_PROCESSES=2\n"
        "REMOVED_SESSION_FILES=1\n"
        "REMOVED_PAGES_FILES=0\n"
        "REMOVED_RESERVE_FILES=0\n"
        "REMOVED_AGENT_PIDFILES=0\n"
        "REMOVED_FIGMA_SESSION_FILES=0\n"
        "STOPPED_CHROME_AGENTS=1\n"
        "STOPPED_SHARED_HEADFUL=0\n"
        "BROKEN_LIVE_SESSIONS=0\n"
    )

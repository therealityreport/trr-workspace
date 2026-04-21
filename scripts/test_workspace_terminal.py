from __future__ import annotations

import subprocess
from pathlib import Path


SCRIPT_PATH = Path(__file__).resolve().parent / "lib" / "workspace-terminal.sh"
PREFLIGHT_BROWSER_SCRIPT_PATH = (
    Path(__file__).resolve().parent / "lib" / "preflight-browser-attention.sh"
)


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


def test_attention_render_keeps_degraded_snapshot_details(tmp_path: Path) -> None:
    attention_file = tmp_path / "attention.log"

    result = _run_bash(
        f"""
        source "{SCRIPT_PATH}"
        workspace_attention_reset "{attention_file}"
        workspace_attention_add "{attention_file}" \
          "Browser automation pressure is degraded." \
          "Impact: chrome-devtools is available, but local browser pressure is elevated (chrome_rss_mb=4415.5, shared_clients=16, managed_roots=1, conflicts=0)." \
          "Remediation: chrome-devtools remains usable; run 'make mcp-clean' only if stale Chrome runtime artifacts or external MCP leftovers are not expected."
        workspace_attention_render "{attention_file}" "[workspace]"
        """
    )

    assert result.returncode == 0, result.stderr
    assert result.stdout == (
        "[workspace] Attention:\n"
        "  - Browser automation pressure is degraded.\n"
        "    Impact: chrome-devtools is available, but local browser pressure is elevated (chrome_rss_mb=4415.5, shared_clients=16, managed_roots=1, conflicts=0).\n"
        "    Remediation: chrome-devtools remains usable; run 'make mcp-clean' only if stale Chrome runtime artifacts or external MCP leftovers are not expected.\n"
    )


def test_preflight_browser_degraded_state_does_not_render_startup_attention(
    tmp_path: Path,
) -> None:
    attention_file = tmp_path / "attention.log"

    result = _run_bash(
        f"""
        source "{SCRIPT_PATH}"
        source "{PREFLIGHT_BROWSER_SCRIPT_PATH}"
        workspace_attention_reset "{attention_file}"
        preflight_record_browser_attention "{attention_file}" $'overall_state=degraded\\nattention_kind=pressure\\npressure_state=degraded\\nshared_port=9422\\nchrome_rss_mb=4415.5\\nshared_clients=16\\nmanaged_roots=1\\nconflicts=0'
        workspace_attention_render "{attention_file}" "[workspace]"
        """
    )

    assert result.returncode == 0, result.stderr
    assert result.stdout == ""


def test_preflight_browser_recoverable_state_still_renders_startup_attention(
    tmp_path: Path,
) -> None:
    attention_file = tmp_path / "attention.log"

    result = _run_bash(
        f"""
        source "{SCRIPT_PATH}"
        source "{PREFLIGHT_BROWSER_SCRIPT_PATH}"
        workspace_attention_reset "{attention_file}"
        preflight_record_browser_attention "{attention_file}" $'overall_state=recoverable\\nattention_kind=none\\nshared_runtime_state=recoverable\\nshared_port=9422'
        workspace_attention_render "{attention_file}" "[workspace]"
        """
    )

    assert result.returncode == 0, result.stderr
    assert result.stdout == (
        "[workspace] Attention:\n"
        "  - Browser automation shared Chrome needs recovery on port 9422.\n"
        "    Impact: chrome-devtools is configured, but the shared browser runtime is not ready for this startup yet.\n"
        "    Remediation: retry the browser task once; if the shared runtime does not recover, run 'make mcp-clean' and restart the workspace.\n"
    )


def test_preflight_browser_unavailable_state_still_renders_startup_attention(
    tmp_path: Path,
) -> None:
    attention_file = tmp_path / "attention.log"

    result = _run_bash(
        f"""
        source "{SCRIPT_PATH}"
        source "{PREFLIGHT_BROWSER_SCRIPT_PATH}"
        workspace_attention_reset "{attention_file}"
        preflight_record_browser_attention "{attention_file}" $'overall_state=unavailable\\nattention_kind=unavailable\\nshared_runtime_state=unavailable\\nshared_port=9422'
        workspace_attention_render "{attention_file}" "[workspace]"
        """
    )

    assert result.returncode == 0, result.stderr
    assert result.stdout == (
        "[workspace] Attention:\n"
        "  - Browser automation shared Chrome is not responding on port 9422.\n"
        "    Impact: chrome-devtools registration is present, but the shared browser runtime is unavailable.\n"
        "    Remediation: run 'make mcp-clean' and retry the workspace startup.\n"
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

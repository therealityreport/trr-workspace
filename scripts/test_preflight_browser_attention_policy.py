from __future__ import annotations

import subprocess
from pathlib import Path


WORKSPACE_TERMINAL_SCRIPT_PATH = (
    Path(__file__).resolve().parent / "lib" / "workspace-terminal.sh"
)
SCRIPT_PATH = Path(__file__).resolve().parent / "lib" / "preflight-browser-attention.sh"


def _run_bash(script: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["/bin/bash", "-lc", script],
        capture_output=True,
        text=True,
        check=False,
    )


def test_degraded_browser_pressure_is_not_promoted_to_startup_attention(
    tmp_path: Path,
) -> None:
    attention_file = tmp_path / "attention.log"

    result = _run_bash(
        f"""
        source "{WORKSPACE_TERMINAL_SCRIPT_PATH}"
        source "{SCRIPT_PATH}"
        workspace_attention_reset "{attention_file}"
        preflight_record_browser_attention "{attention_file}" $'overall_state=degraded\\nattention_kind=pressure\\npressure_state=degraded\\nshared_port=9422\\nchrome_rss_mb=5008.5\\nshared_clients=4\\nmanaged_roots=1\\nconflicts=0'
        cat "{attention_file}"
        """
    )

    assert result.returncode == 0, result.stderr
    assert result.stdout == ""


def test_recoverable_browser_runtime_is_promoted_to_startup_attention(
    tmp_path: Path,
) -> None:
    attention_file = tmp_path / "attention.log"

    result = _run_bash(
        f"""
        source "{WORKSPACE_TERMINAL_SCRIPT_PATH}"
        source "{SCRIPT_PATH}"
        workspace_attention_reset "{attention_file}"
        preflight_record_browser_attention "{attention_file}" $'overall_state=recoverable\\nattention_kind=none\\nshared_runtime_state=recoverable\\nshared_port=9422'
        cat "{attention_file}"
        """
    )

    assert result.returncode == 0, result.stderr
    assert result.stdout == (
        "Browser automation shared Chrome needs recovery on port 9422.\t"
        "Impact: chrome-devtools is configured, but the shared browser runtime is not ready for this startup yet.\t"
        "Remediation: retry the browser task once; if the shared runtime does not recover, run 'make mcp-clean' and restart the workspace.\n"
    )


def test_unavailable_browser_runtime_is_promoted_to_startup_attention(
    tmp_path: Path,
) -> None:
    attention_file = tmp_path / "attention.log"

    result = _run_bash(
        f"""
        source "{WORKSPACE_TERMINAL_SCRIPT_PATH}"
        source "{SCRIPT_PATH}"
        workspace_attention_reset "{attention_file}"
        preflight_record_browser_attention "{attention_file}" $'overall_state=unavailable\\nattention_kind=unavailable\\nshared_runtime_state=unavailable\\nshared_port=9422'
        cat "{attention_file}"
        """
    )

    assert result.returncode == 0, result.stderr
    assert result.stdout == (
        "Browser automation shared Chrome is not responding on port 9422.\t"
        "Impact: chrome-devtools registration is present, but the shared browser runtime is unavailable.\t"
        "Remediation: run 'make mcp-clean' and retry the workspace startup.\n"
    )

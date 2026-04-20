from __future__ import annotations

import subprocess
from pathlib import Path


SCRIPT_PATH = Path(__file__).resolve().parent / "lib" / "chrome-devtools-status.sh"


def _run_bash(script: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["/bin/bash", "-lc", script],
        capture_output=True,
        text=True,
        check=False,
    )


def test_classify_ready_shared_runtime() -> None:
    result = _run_bash(
        f"""
        source "{SCRIPT_PATH}"
        chrome_devtools_status_classify "shared" "reachable" "safe" "1" "1" "9422"
        """
    )

    assert result.returncode == 0, result.stderr
    assert "overall_state=ready" in result.stdout
    assert "attention_kind=none" in result.stdout


def test_classify_degraded_shared_runtime() -> None:
    result = _run_bash(
        f"""
        source "{SCRIPT_PATH}"
        chrome_devtools_status_classify "shared" "reachable" "degraded" "1" "1" "9422"
        """
    )

    assert result.returncode == 0, result.stderr
    assert "overall_state=degraded" in result.stdout
    assert "attention_kind=pressure" in result.stdout


def test_classify_recoverable_shared_runtime_when_auto_launch_is_available() -> None:
    result = _run_bash(
        f"""
        source "{SCRIPT_PATH}"
        chrome_devtools_status_classify "shared" "missing" "safe" "1" "1" "9422"
        """
    )

    assert result.returncode == 0, result.stderr
    assert "overall_state=recoverable" in result.stdout
    assert "attention_kind=none" in result.stdout


def test_classify_unavailable_shared_runtime_without_recovery_path() -> None:
    result = _run_bash(
        f"""
        source "{SCRIPT_PATH}"
        chrome_devtools_status_classify "shared" "missing" "safe" "0" "1" "9422"
        """
    )

    assert result.returncode == 0, result.stderr
    assert "overall_state=unavailable" in result.stdout
    assert "attention_kind=unavailable" in result.stdout


def test_classify_unavailable_when_wrapper_smoke_check_fails() -> None:
    result = _run_bash(
        f"""
        source "{SCRIPT_PATH}"
        chrome_devtools_status_classify "shared" "missing" "safe" "1" "0" "9422"
        """
    )

    assert result.returncode == 0, result.stderr
    assert "overall_state=unavailable" in result.stdout
    assert "attention_kind=unavailable" in result.stdout

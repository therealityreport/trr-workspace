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
        chrome_devtools_status_classify "shared" "reachable" "safe" "1" "1" "9422" "2200.0" "2" "1" "0"
        """
    )

    assert result.returncode == 0, result.stderr
    assert "overall_state=ready" in result.stdout
    assert "attention_kind=none" in result.stdout
    assert "chrome_rss_mb=2200.0" in result.stdout
    assert "shared_clients=2" in result.stdout
    assert "managed_roots=1" in result.stdout
    assert "conflicts=0" in result.stdout


def test_classify_degraded_shared_runtime() -> None:
    result = _run_bash(
        f"""
        source "{SCRIPT_PATH}"
        chrome_devtools_status_classify "shared" "reachable" "degraded" "1" "1" "9422" "4415.5" "16" "1" "0"
        """
    )

    assert result.returncode == 0, result.stderr
    assert "overall_state=degraded" in result.stdout
    assert "attention_kind=pressure" in result.stdout
    assert "chrome_rss_mb=4415.5" in result.stdout
    assert "shared_clients=16" in result.stdout
    assert "managed_roots=1" in result.stdout
    assert "conflicts=0" in result.stdout


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


def test_transport_repair_classifies_unavailable_shared_runtime_as_repair() -> None:
    result = _run_bash(
        f"""
        source "{SCRIPT_PATH}"
        status_output=$'overall_state=unavailable\\nattention_kind=unavailable\\nshared_runtime_state=unavailable\\npressure_state=safe\\nshared_port=9422'
        chrome_devtools_transport_repair_classify "$status_output"
        """
    )

    assert result.returncode == 0, result.stderr
    assert "repair_action=repair" in result.stdout
    assert "repair_reason=shared_runtime_unavailable" in result.stdout
    assert "shared_port=9422" in result.stdout


def test_transport_repair_leaves_recoverable_auto_launch_alone() -> None:
    result = _run_bash(
        f"""
        source "{SCRIPT_PATH}"
        status_output=$'overall_state=recoverable\\nattention_kind=none\\nshared_runtime_state=recoverable\\npressure_state=safe\\nshared_port=9422'
        chrome_devtools_transport_repair_classify "$status_output"
        """
    )

    assert result.returncode == 0, result.stderr
    assert "repair_action=none" in result.stdout
    assert "repair_reason=recoverable_auto_launch" in result.stdout


def test_transport_repair_classifies_unsafe_pressure_as_repair() -> None:
    result = _run_bash(
        f"""
        source "{SCRIPT_PATH}"
        status_output=$'overall_state=degraded\\nattention_kind=pressure\\nshared_runtime_state=ready\\npressure_state=unsafe\\nshared_port=9222'
        chrome_devtools_transport_repair_classify "$status_output"
        """
    )

    assert result.returncode == 0, result.stderr
    assert "repair_action=repair" in result.stdout
    assert "repair_reason=unsafe_stale_runtime" in result.stdout


def test_transport_repair_leaves_degraded_nonblocking_pressure_alone() -> None:
    result = _run_bash(
        f"""
        source "{SCRIPT_PATH}"
        status_output=$'overall_state=degraded\\nattention_kind=pressure\\nshared_runtime_state=ready\\npressure_state=degraded\\nshared_port=9422'
        chrome_devtools_transport_repair_classify "$status_output"
        """
    )

    assert result.returncode == 0, result.stderr
    assert "repair_action=none" in result.stdout
    assert "repair_reason=degraded_nonblocking" in result.stdout

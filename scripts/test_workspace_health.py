from __future__ import annotations

import subprocess
from pathlib import Path


SCRIPT_PATH = Path(__file__).resolve().parent / "lib" / "workspace-health.sh"


def _run_bash(script: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["/bin/bash", "-lc", script],
        capture_output=True,
        text=True,
        check=False,
    )


def test_backend_health_urls_split_readiness_and_liveness() -> None:
    result = _run_bash(
        f"""
        source "{SCRIPT_PATH}"
        printf '%s\\n%s' "$(workspace_backend_readiness_url 8123)" "$(workspace_backend_liveness_url 8123)"
        """
    )

    assert result.returncode == 0, result.stderr
    assert result.stdout == "http://127.0.0.1:8123/health\nhttp://127.0.0.1:8123/health/live"


def test_watchdog_probe_target_uses_liveness_url() -> None:
    result = _run_bash(
        f"""
        source "{SCRIPT_PATH}"
        printf '%s' "$(workspace_backend_watchdog_url 9001)"
        """
    )

    assert result.returncode == 0, result.stderr
    assert result.stdout == "http://127.0.0.1:9001/health/live"


def test_status_outputs_keep_readiness_and_liveness_distinct() -> None:
    result = _run_bash(
        f"""
        source "{SCRIPT_PATH}"
        printf '%s\\n%s' "$(workspace_backend_status_readiness_url 7000)" "$(workspace_backend_status_liveness_url 7000)"
        """
    )

    assert result.returncode == 0, result.stderr
    assert result.stdout == "http://127.0.0.1:7000/health\nhttp://127.0.0.1:7000/health/live"


def test_backend_readiness_label_degrades_when_liveness_is_alive() -> None:
    result = _run_bash(
        f"""
        source "{SCRIPT_PATH}"
        printf '%s' "$(workspace_backend_readiness_label 0 1)"
        """
    )

    assert result.returncode == 0, result.stderr
    assert result.stdout == "degraded/slow"

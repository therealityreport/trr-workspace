from __future__ import annotations

import subprocess
from pathlib import Path


SCRIPT_PATH = Path(__file__).resolve().parent / "lib" / "preflight-env-contract.sh"


def _run_bash(script: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["/bin/bash", "-lc", script],
        capture_output=True,
        text=True,
        check=False,
    )


def test_env_contract_warns_and_continues_when_not_strict() -> None:
    result = _run_bash(
        f"""
        source "{SCRIPT_PATH}"
        set +e
        output="$(preflight_handle_env_contract_result 0 1 '[env-contract] ERROR: docs/workspace/env-contract.md is out of date.\n[env-contract] Run: make env-contract')"
        rc="$?"
        set -e
        printf 'rc=%s\\n%s' "$rc" "$output"
        """
    )

    assert result.returncode == 0, result.stderr
    assert "rc=0" in result.stdout
    assert "[preflight] WARNING: generated env contract is out of date; continuing because WORKSPACE_PREFLIGHT_STRICT=0." in result.stdout
    assert "[env-contract] ERROR: docs/workspace/env-contract.md is out of date." in result.stdout
    assert "[env-contract] Run: make env-contract" in result.stdout
    assert "Remediation: run 'make env-contract'" in result.stdout


def test_env_contract_fails_when_strict() -> None:
    result = _run_bash(
        f"""
        source "{SCRIPT_PATH}"
        set +e
        preflight_handle_env_contract_result 1 1 '[env-contract] ERROR: docs/workspace/env-contract.md is out of date.'
        rc="$?"
        set -e
        printf 'rc=%s' "$rc"
        """
    )

    assert result.returncode == 0, result.stderr
    assert result.stdout == "rc=1"


def test_env_contract_report_warns_and_continues_when_not_strict() -> None:
    result = _run_bash(
        f"""
        source "{SCRIPT_PATH}"
        set +e
        output="$(preflight_handle_env_contract_report_result 0 1 '[env-contract] deprecations-stale: docs/workspace/env-deprecations.md is out of date; regenerate it with scripts/env_contract_report.py write.')"
        rc="$?"
        set -e
        printf 'rc=%s\\n%s' "$rc" "$output"
        """
    )

    assert result.returncode == 0, result.stderr
    assert "rc=0" in result.stdout
    assert "[preflight] WARNING: env contract reports are out of date; continuing because WORKSPACE_PREFLIGHT_STRICT=0." in result.stdout
    assert "docs/workspace/env-deprecations.md is out of date" in result.stdout
    assert "Remediation: run 'make env-contract-report'" in result.stdout


def test_env_contract_report_fails_when_strict() -> None:
    result = _run_bash(
        f"""
        source "{SCRIPT_PATH}"
        set +e
        preflight_handle_env_contract_report_result 1 1 '[env-contract] inventory-stale: docs/workspace/env-contract-inventory.md is out of date.'
        rc="$?"
        set -e
        printf 'rc=%s' "$rc"
        """
    )

    assert result.returncode == 0, result.stderr
    assert result.stdout == "rc=1"

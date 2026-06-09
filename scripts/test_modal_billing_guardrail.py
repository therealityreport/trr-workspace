from __future__ import annotations

import os
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "modal-billing-guardrail.sh"


def _run_guardrail(**env_overrides: str) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    for key in (
        "TRR_MODAL_ALWAYS_ON_SCHEDULES_ENABLED",
        "TRR_MODAL_RUNTIME_SCHEDULER_ENABLED",
        "TRR_MODAL_MAINTENANCE_OWNER_REQUIRED",
        "TRR_MODAL_API_MIN_CONTAINERS",
        "TRR_MODAL_ADMIN_KEEP_WARM",
        "WORKSPACE_ALLOW_MODAL_ALWAYS_ON_BILLING",
        "TRR_MODAL_BACKEND_DIR",
        "TRR_MODAL_SOURCE_ENV",
    ):
        env.pop(key, None)
    env.update(env_overrides)
    return subprocess.run(
        ["bash", str(SCRIPT)],
        cwd=ROOT,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


def test_guardrail_passes_with_safe_defaults() -> None:
    result = _run_guardrail()

    assert result.returncode == 0
    assert "Guardrail OK" in result.stdout


def test_guardrail_blocks_deployed_cron_schedules() -> None:
    result = _run_guardrail(TRR_MODAL_ALWAYS_ON_SCHEDULES_ENABLED="1")

    assert result.returncode == 1
    assert "TRR_MODAL_ALWAYS_ON_SCHEDULES_ENABLED=1" in result.stderr
    assert "exactly one owner" in result.stderr


def test_guardrail_blocks_mixed_case_deployed_cron_schedules() -> None:
    result = _run_guardrail(TRR_MODAL_ALWAYS_ON_SCHEDULES_ENABLED="True")

    assert result.returncode == 1
    assert "TRR_MODAL_ALWAYS_ON_SCHEDULES_ENABLED=True" in result.stderr


def test_guardrail_blocks_warm_api_containers() -> None:
    result = _run_guardrail(TRR_MODAL_API_MIN_CONTAINERS="1")

    assert result.returncode == 1
    assert "TRR_MODAL_API_MIN_CONTAINERS=1" in result.stderr


def test_guardrail_blocks_missing_modal_maintenance_owner() -> None:
    result = _run_guardrail(TRR_MODAL_RUNTIME_SCHEDULER_ENABLED="0")

    assert result.returncode == 1
    assert "exactly one owner" in result.stderr
    assert "TRR_MODAL_RUNTIME_SCHEDULER_ENABLED=0" in result.stderr


def test_guardrail_blocks_disabled_modal_maintenance_owner_requirement() -> None:
    result = _run_guardrail(TRR_MODAL_MAINTENANCE_OWNER_REQUIRED="0")

    assert result.returncode == 1
    assert "would disable Modal maintenance owner enforcement" in result.stderr


def test_guardrail_blocks_always_on_values_from_source_env(tmp_path: Path) -> None:
    source_env = tmp_path / ".env"
    source_env.write_text(
        "\n".join(
            [
                "TRR_MODAL_ALWAYS_ON_SCHEDULES_ENABLED=True",
                "TRR_MODAL_API_MIN_CONTAINERS=2",
                "TRR_MODAL_ADMIN_KEEP_WARM=1",
            ]
        )
        + "\n",
        encoding="utf-8",
    )

    result = _run_guardrail(TRR_MODAL_SOURCE_ENV=str(source_env))

    assert result.returncode == 1
    assert f"TRR_MODAL_ALWAYS_ON_SCHEDULES_ENABLED=True from {source_env}" in result.stderr
    assert f"TRR_MODAL_API_MIN_CONTAINERS=2 from {source_env}" in result.stderr
    assert f"TRR_MODAL_ADMIN_KEEP_WARM=1 from {source_env}" in result.stderr


def test_guardrail_allows_explicit_time_boxed_override() -> None:
    result = _run_guardrail(
        WORKSPACE_ALLOW_MODAL_ALWAYS_ON_BILLING="1",
        TRR_MODAL_ALWAYS_ON_SCHEDULES_ENABLED="1",
        TRR_MODAL_RUNTIME_SCHEDULER_ENABLED="0",
        TRR_MODAL_API_MIN_CONTAINERS="1",
    )

    assert result.returncode == 0
    assert "runtime always-on settings are allowed" in result.stdout


def test_guardrail_blocks_break_glass_duplicate_modal_maintenance_owners() -> None:
    result = _run_guardrail(
        WORKSPACE_ALLOW_MODAL_ALWAYS_ON_BILLING="1",
        TRR_MODAL_ALWAYS_ON_SCHEDULES_ENABLED="1",
    )

    assert result.returncode == 1
    assert "exactly one owner" in result.stderr


def test_guardrail_checks_explicit_backend_deploy_tree(tmp_path: Path) -> None:
    backend_dir = tmp_path / "TRR-Backend-clean-deploy"
    (backend_dir / "trr_backend").mkdir(parents=True)
    (backend_dir / ".env.example").write_text(
        "\n".join(
            [
                "TRR_MODAL_ALWAYS_ON_SCHEDULES_ENABLED=0",
                "TRR_MODAL_RUNTIME_SCHEDULER_ENABLED=1",
                "TRR_MODAL_MAINTENANCE_OWNER_REQUIRED=1",
                "TRR_MODAL_API_MIN_CONTAINERS=0",
                "TRR_MODAL_ADMIN_KEEP_WARM=0",
            ]
        )
        + "\n",
        encoding="utf-8",
    )
    (backend_dir / "trr_backend" / "modal_jobs.py").write_text(
        "\n".join(
            [
                'os.getenv("TRR_MODAL_API_MIN_CONTAINERS", "0")',
                'os.getenv("TRR_MODAL_ADMIN_KEEP_WARM", "0")',
                '_env_flag("TRR_MODAL_ALWAYS_ON_SCHEDULES_ENABLED", default=False)',
                '_env_flag("TRR_MODAL_RUNTIME_SCHEDULER_ENABLED", default=False)',
                '_env_flag("TRR_MODAL_MAINTENANCE_OWNER_REQUIRED", default=False)',
            ]
        )
        + "\n",
        encoding="utf-8",
    )

    result = _run_guardrail(TRR_MODAL_BACKEND_DIR=str(backend_dir))

    assert result.returncode == 0
    assert "Guardrail OK" in result.stdout

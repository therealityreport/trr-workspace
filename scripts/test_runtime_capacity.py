from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import pytest

from scripts import runtime_capacity

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "docs" / "workspace" / "runtime-capacity.json"


def _profile(name: str) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw_line in (
        (ROOT / "profiles" / f"{name}.env").read_text(encoding="utf-8").splitlines()
    ):
        line = raw_line.split("#", 1)[0].strip()
        if not line or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key] = value
    return values


def test_capacity_manifest_keeps_dispatch_concurrency_and_stage_caps_distinct() -> None:
    payload = json.loads(MANIFEST.read_text(encoding="utf-8"))

    local = payload["contexts"]["local_workspace"]
    hybrid = payload["contexts"]["workspace_hybrid"]
    hosted = payload["contexts"]["hosted_modal"]

    assert local["dispatch_batch_size"] == 4
    assert local["container_job_concurrency"]["general_social"] == 4
    assert hybrid["dispatch_batch_size"] == 8
    assert hybrid["container_job_concurrency"]["general_social"] == 8
    assert hybrid["stage_caps"]["comments"] == 8
    assert hosted["dispatch_batch_size"] == 12
    assert hosted["container_job_concurrency"]["general_social"] == 8
    assert hosted["container_job_concurrency"]["comments"] == 4
    assert hosted["container_job_concurrency"]["comments_recovery"] == 4
    assert hosted["stage_caps"]["instagram_posts_comments_platform"] == 4


def test_enabled_profile_effective_values_are_preserved_from_pre_gate_baseline() -> (
    None
):
    """Only dormant defaults may change; enabled profile behavior remains 8/8."""

    pre_gate_enabled_profiles = {
        "local-lite": {
            "WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT": "8",
            "WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT": "8",
        }
    }

    for profile_name, expected in pre_gate_enabled_profiles.items():
        values = _profile(profile_name)
        assert values["WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS"] == "1"
        for key, expected_value in expected.items():
            assert values[key] == expected_value, (
                f"{profile_name} changed effective {key}"
            )


def test_local_lite_stage_caps_are_recorded_as_an_explicit_profile_override() -> None:
    payload = json.loads(MANIFEST.read_text(encoding="utf-8"))

    assert payload["profile_overrides"]["local-lite"] == {
        "remote_social_enabled": True,
        "stage_caps": {
            "posts": 2,
            "comments": 2,
            "media_mirror": 1,
            "comment_media_mirror": 1,
        },
    }


def test_hybrid_and_hosted_enabled_lane_values_are_preserved() -> None:
    makefile = (ROOT / "Makefile").read_text(encoding="utf-8")
    modal_jobs = (ROOT / "TRR-Backend" / "trr_backend" / "modal_jobs.py").read_text(
        encoding="utf-8"
    )

    hybrid = makefile[
        makefile.index("\ndev-hybrid:") : makefile.index(
            "\n# Post-recovery", makefile.index("\ndev-hybrid:")
        )
    ]
    assert "WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT=8" in hybrid
    assert "WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT=8" in hybrid

    assert '"SOCIAL_MODAL_DISPATCH_LIMIT": "12"' in modal_jobs
    assert '"TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT": "8"' in modal_jobs
    assert '"TRR_MODAL_SOCIAL_COMMENTS_JOB_CONCURRENCY_LIMIT": "4"' in modal_jobs
    assert (
        '"TRR_MODAL_SOCIAL_COMMENTS_RECOVERY_JOB_CONCURRENCY_LIMIT": "4"' in modal_jobs
    )


def test_runtime_capacity_projection_check_passes() -> None:
    completed = subprocess.run(
        [sys.executable, str(ROOT / "scripts" / "runtime_capacity.py"), "check"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )

    assert completed.returncode == 0, completed.stderr or completed.stdout
    assert "runtime-capacity: OK" in completed.stdout


def test_missing_profile_override_uses_capacity_contract_error(tmp_path: Path) -> None:
    payload = json.loads(MANIFEST.read_text(encoding="utf-8"))
    payload["profile_contexts"] = {}
    payload["profile_overrides"] = {
        "missing": {
            "remote_social_enabled": False,
            "stage_caps": {
                "posts": 0,
                "comments": 0,
                "media_mirror": 0,
                "comment_media_mirror": 0,
            },
        }
    }

    with pytest.raises(
        runtime_capacity.CapacityContractError,
        match=r"unable to read profile .*missing\.env",
    ):
        runtime_capacity.validate_projections(payload, root=tmp_path)

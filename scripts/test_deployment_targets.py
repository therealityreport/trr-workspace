from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import pytest

from scripts import deployment_targets


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "docs" / "workspace" / "deployment-targets.json"


def test_deployment_target_tuple_is_exact_and_secret_free() -> None:
    payload = json.loads(MANIFEST.read_text(encoding="utf-8"))

    assert payload["supabase"]["project_ref"] == "vwxfvzutyufrkhfgoeaa"
    assert payload["vercel"] == {
        "team_id": "team_EUsG2kN9TAvVDGOu4yZVEoCX",
        "team_slug": "the-reality-reports-projects",
        "project_id": "prj_MHpStkwr26rV5kjt0f80zqhwZpAs",
        "project_name": "trr-app",
        "production_aliases": ["https://trr-app.vercel.app"],
        "direct_deployment_urls": [
            "https://trr-4c2watu7j-the-reality-reports-projects.vercel.app"
        ],
    }
    assert payload["render"] == {
        "owner_id": "tea-d6pglsu3jp1c73cctvf0",
        "service_id": "srv-d6phk5vkijhs73fcsk7g",
        "service_name": "trr-backend-api",
        "repo": "therealityreport/trr-backend",
        "branch": "main",
        "direct_url": "https://trr-backend-api.onrender.com",
        "credential_env": "TRR_RENDER_API_KEY",
    }
    assert payload["modal"] == {
        "profile": "admin-56995",
        "workspace": "admin-56995",
        "environment": "main",
        "app_name": "trr-backend-jobs",
        "app_ref": "trr_backend.modal_jobs",
    }

    serialized = json.dumps(payload).lower()
    assert "bearer " not in serialized
    assert "password" not in serialized
    assert "service_role" not in serialized


def test_deployment_target_projection_check_passes() -> None:
    completed = subprocess.run(
        [sys.executable, str(ROOT / "scripts" / "deployment_targets.py"), "check"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )

    assert completed.returncode == 0, completed.stderr or completed.stdout
    assert "deployment-targets: OK" in completed.stdout


def test_render_snapshot_checkpoint_is_metadata_only_and_open() -> None:
    payload = json.loads(MANIFEST.read_text(encoding="utf-8"))
    checkpoint = payload["security_checkpoints"]["render_env_snapshot"]

    assert (
        checkpoint["path"]
        == ".artifacts/env-inventory/20260330-173748/render/env-vars.json"
    )
    assert checkpoint["inspection_policy"] == "metadata_only_never_read_values"
    assert checkpoint["status"] == "operator_review_required"
    assert checkpoint["permissions_mode"] == "0600"
    assert (
        checkpoint["live_review_condition"]
        == "operator_action_required_missing_TRR_RENDER_API_KEY"
    )
    assert checkpoint["production_cutover"] == "blocked_until_closed"


def test_render_snapshot_permissions_fail_closed_when_local_snapshot_exists(
    tmp_path: Path,
) -> None:
    snapshot = tmp_path / "snapshot.json"
    snapshot.write_text("{}\n", encoding="utf-8")
    payload = {
        "security_checkpoints": {"render_env_snapshot": {"path": "snapshot.json"}}
    }

    snapshot.chmod(0o644)
    with pytest.raises(
        deployment_targets.DeploymentTargetError,
        match="permissions are too broad: 0644",
    ):
        deployment_targets.validate_snapshot_permissions(payload, root=tmp_path)

    snapshot.chmod(0o600)
    deployment_targets.validate_snapshot_permissions(payload, root=tmp_path)


def test_deployment_evidence_policy_never_records_environment_values() -> None:
    payload = json.loads(MANIFEST.read_text(encoding="utf-8"))

    assert payload["evidence_policy"] == {
        "environment_values": "prohibited",
        "allowed_artifacts": [
            "safe_identifiers",
            "redacted_key_metadata",
            "hashes",
        ],
        "credential_output": "never",
    }


def test_literal_assignment_parse_errors_use_deployment_target_error(
    tmp_path: Path,
) -> None:
    malformed = tmp_path / "malformed.py"
    malformed.write_text("if:\n", encoding="utf-8")

    with pytest.raises(
        deployment_targets.DeploymentTargetError,
        match=r"unable to parse .*malformed\.py",
    ):
        deployment_targets._literal_assignments(malformed)

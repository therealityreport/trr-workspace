#!/usr/bin/env python3
from __future__ import annotations

import argparse
import ast
import json
import re
import stat
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "docs" / "workspace" / "deployment-targets.json"

EXPECTED = {
    "supabase": {
        "project_ref": "vwxfvzutyufrkhfgoeaa",
        "credential_env": "TRR_SUPABASE_ACCESS_TOKEN",
    },
    "vercel": {
        "team_id": "team_EUsG2kN9TAvVDGOu4yZVEoCX",
        "team_slug": "the-reality-reports-projects",
        "project_id": "prj_MHpStkwr26rV5kjt0f80zqhwZpAs",
        "project_name": "trr-app",
        "production_aliases": ["https://trr-app.vercel.app"],
        "direct_deployment_urls": [
            "https://trr-4c2watu7j-the-reality-reports-projects.vercel.app"
        ],
    },
    "render": {
        "owner_id": "tea-d6pglsu3jp1c73cctvf0",
        "service_id": "srv-d6phk5vkijhs73fcsk7g",
        "service_name": "trr-backend-api",
        "repo": "therealityreport/trr-backend",
        "branch": "main",
        "direct_url": "https://trr-backend-api.onrender.com",
        "credential_env": "TRR_RENDER_API_KEY",
    },
    "modal": {
        "profile": "admin-56995",
        "workspace": "admin-56995",
        "environment": "main",
        "app_name": "trr-backend-jobs",
        "app_ref": "trr_backend.modal_jobs",
    },
}


class DeploymentTargetError(RuntimeError):
    pass


def _read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        raise DeploymentTargetError(f"unable to read {path}: {exc}") from exc


def load_manifest(path: Path = DEFAULT_MANIFEST) -> dict[str, Any]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise DeploymentTargetError(f"unable to load {path}: {exc}") from exc
    if not isinstance(payload, dict):
        raise DeploymentTargetError("deployment-targets manifest must be a JSON object")
    return payload


def _literal_assignments(path: Path) -> dict[str, Any]:
    try:
        tree = ast.parse(_read_text(path), filename=str(path))
    except SyntaxError as exc:
        raise DeploymentTargetError(f"unable to parse {path}: {exc}") from exc
    values: dict[str, Any] = {}
    for node in tree.body:
        if (
            isinstance(node, ast.Assign)
            and len(node.targets) == 1
            and isinstance(node.targets[0], ast.Name)
        ):
            try:
                values[node.targets[0].id] = ast.literal_eval(node.value)
            except (ValueError, TypeError):
                continue
        if (
            isinstance(node, ast.AnnAssign)
            and isinstance(node.target, ast.Name)
            and node.value is not None
        ):
            try:
                values[node.target.id] = ast.literal_eval(node.value)
            except (ValueError, TypeError):
                continue
    return values


def validate_manifest(payload: dict[str, Any]) -> None:
    if payload.get("version") != 1:
        raise DeploymentTargetError("deployment-targets version must be 1")
    for plane, expected in EXPECTED.items():
        if payload.get(plane) != expected:
            raise DeploymentTargetError(
                f"{plane} target tuple does not match the approved TRR identity"
            )

    serialized = json.dumps(payload).lower()
    for forbidden in ("bearer ", "password", "service_role", "private_key"):
        if forbidden in serialized:
            raise DeploymentTargetError(
                f"manifest contains forbidden secret-like content: {forbidden.strip()}"
            )

    checkpoint = (payload.get("security_checkpoints") or {}).get(
        "render_env_snapshot"
    ) or {}
    if checkpoint.get("inspection_policy") != "metadata_only_never_read_values":
        raise DeploymentTargetError("Render env snapshot must remain metadata-only")
    if checkpoint.get("production_cutover") != "blocked_until_closed":
        raise DeploymentTargetError(
            "Render env snapshot checkpoint must block production cutover until closed"
        )
    if checkpoint.get("permissions_mode") != "0600":
        raise DeploymentTargetError(
            "Render env snapshot checkpoint must declare mode 0600"
        )
    if (
        checkpoint.get("live_review_condition")
        != "operator_action_required_missing_TRR_RENDER_API_KEY"
    ):
        raise DeploymentTargetError(
            "Render env snapshot checkpoint must record the current operator action"
        )

    expected_evidence_policy = {
        "environment_values": "prohibited",
        "allowed_artifacts": [
            "safe_identifiers",
            "redacted_key_metadata",
            "hashes",
        ],
        "credential_output": "never",
    }
    if payload.get("evidence_policy") != expected_evidence_policy:
        raise DeploymentTargetError(
            "deployment evidence policy must prohibit environment and credential values"
        )


def validate_snapshot_permissions(payload: dict[str, Any], root: Path = ROOT) -> None:
    checkpoint = (payload.get("security_checkpoints") or {}).get(
        "render_env_snapshot"
    ) or {}
    relative_path = checkpoint.get("path")
    if not isinstance(relative_path, str) or not relative_path.strip():
        raise DeploymentTargetError("Render env snapshot checkpoint path is required")
    snapshot = root / relative_path
    try:
        if not snapshot.exists():
            return
        if not snapshot.is_file():
            raise DeploymentTargetError(
                "Render env snapshot checkpoint path is not a file"
            )
        mode = stat.S_IMODE(snapshot.stat().st_mode)
    except OSError as exc:
        raise DeploymentTargetError(
            f"unable to inspect Render env snapshot: {exc}"
        ) from exc
    if mode & 0o077:
        raise DeploymentTargetError(
            f"Render env snapshot permissions are too broad: {mode:04o}"
        )


def validate_projections(payload: dict[str, Any], root: Path = ROOT) -> None:
    supabase = _literal_assignments(root / "scripts" / "check-supabase-mcp-access.py")
    if supabase.get("DEFAULT_PROJECT_REF") != payload["supabase"]["project_ref"]:
        raise DeploymentTargetError(
            "Supabase access guard project ref differs from deployment target"
        )
    if supabase.get("DEFAULT_TOKEN_ENV") != payload["supabase"]["credential_env"]:
        raise DeploymentTargetError(
            "Supabase access guard token env differs from deployment target"
        )

    vercel = _literal_assignments(root / "scripts" / "vercel-project-guard.py")
    vercel_expected = {
        "DEFAULT_EXPECTED_NAME": payload["vercel"]["project_name"],
        "DEFAULT_EXPECTED_ID": payload["vercel"]["project_id"],
        "DEFAULT_TEAM_SLUG": payload["vercel"]["team_slug"],
        "DEFAULT_TEAM_ID": payload["vercel"]["team_id"],
    }
    for key, expected in vercel_expected.items():
        if vercel.get(key) != expected:
            raise DeploymentTargetError(
                f"Vercel guard {key} differs from deployment target"
            )

    modal = _literal_assignments(
        root / "TRR-Backend" / "scripts" / "modal" / "deploy_backend.py"
    )
    modal_expected = {
        "DEFAULT_APP_REF": payload["modal"]["app_ref"],
        "DEFAULT_APP_NAME": payload["modal"]["app_name"],
        "REQUIRED_MODAL_PROFILE": payload["modal"]["profile"],
        "REQUIRED_MODAL_WORKSPACE": payload["modal"]["workspace"],
        "REQUIRED_MODAL_ENVIRONMENT": payload["modal"]["environment"],
    }
    for key, expected in modal_expected.items():
        if modal.get(key) != expected:
            raise DeploymentTargetError(
                f"Modal guard {key} differs from deployment target"
            )

    render_yaml = _read_text(root / "TRR-Backend" / "render.yaml")
    for expected_line in (
        f"name: {payload['render']['service_name']}",
        "repo: https://github.com/therealityreport/trr-backend.git",
        f"branch: {payload['render']['branch']}",
        "autoDeploy: false",
    ):
        if expected_line not in render_yaml:
            raise DeploymentTargetError(
                f"render.yaml missing target projection: {expected_line}"
            )

    render_wrapper = root / "scripts" / "render_trr.py"
    if not render_wrapper.is_file():
        raise DeploymentTargetError(
            "missing guarded Render implementation: scripts/render_trr.py"
        )
    wrapper_text = _read_text(render_wrapper)
    for value in (
        payload["render"]["owner_id"],
        payload["render"]["service_id"],
        payload["render"]["service_name"],
        payload["render"]["repo"],
        payload["render"]["branch"],
    ):
        if not re.search(re.escape(value), wrapper_text):
            raise DeploymentTargetError(
                f"Render wrapper does not pin target value: {value}"
            )


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate the non-secret TRR deployment target tuple."
    )
    parser.add_argument("command", choices=("check",))
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        payload = load_manifest(args.manifest)
        validate_manifest(payload)
        validate_snapshot_permissions(payload)
        validate_projections(payload)
    except DeploymentTargetError as exc:
        print(f"deployment-targets: ERROR: {exc}", file=sys.stderr)
        return 1
    print("deployment-targets: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path


SCRIPT_PATH = Path(__file__).resolve().parent / "workspace" / "env_hygiene.py"


def _load_module():
    spec = importlib.util.spec_from_file_location("env_hygiene_under_test", SCRIPT_PATH)
    assert spec is not None
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def _write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def _manifest() -> dict:
    return {
        "canonical": {
            "TRR_DB_URL": {"owner": "workspace-ops"},
            "TRR_DB_APPLICATION_NAME": {"owner": "backend"},
            "POSTGRES_POOL_MAX": {"owner": "app"},
            "TRR_INTERNAL_ADMIN_SHARED_SECRET": {"owner": "workspace-ops"},
            "TRR_CORE_SUPABASE_SERVICE_ROLE_KEY": {"owner": "app"},
            "SUPABASE_URL": {"owner": "backend-shared-schema"},
            "SUPABASE_ANON_KEY": {"owner": "backend-shared-schema"},
            "SUPABASE_SERVICE_ROLE_KEY": {"owner": "backend-shared-schema"},
            "SUPABASE_JWT_SECRET": {"owner": "backend-shared-schema"},
            "DATABASE_URL": {"owner": "workspace-ops", "lifecycle": "compatibility-only"},
        },
        "transitional": {
            "TRR_SCREENALYTICS_ALLOW_SERVICE_TOKEN_FALLBACK": {
                "owner": "backend-shared-schema",
                "screenalytics_retirement": "retire",
            },
            "SCREENALYTICS_OBJECT_STORAGE_BUCKET": {
                "owner": "backend-shared-schema",
                "screenalytics_retirement": "rename",
                "replacement": "TRR_CAST_SCREENTIME_ARTIFACT_BUCKET",
            },
        },
        "shared_key_patterns": [
            {"pattern": "TRR_*", "owner": "workspace-ops"},
            {"pattern": "SCREENALYTICS_*", "owner": "backend-shared-schema"},
        ],
        "authority_surfaces": {
            "runtime_profile_adapters": ["profiles/default.env"],
            "surface_setup_adapters": ["TRR-APP/apps/web/.env.example"],
            "local_secret_adapters": ["TRR-APP/apps/web/.env.local", "TRR-Backend/.env"],
            "retired_env_surfaces": ["screenalytics/.env"],
            "evidence_snapshots": [".logs/workspace/pids.env"],
        },
        "retired_screenalytics_env": {
            "retain": ["TRR_DB_URL"],
            "rename": [
                {
                    "key": "SCREENALYTICS_OBJECT_STORAGE_BUCKET",
                    "replacement": "TRR_CAST_SCREENTIME_ARTIFACT_BUCKET",
                }
            ],
            "retire": [
                "SUPABASE_DB_HOST",
                "TRR_SCREENALYTICS_ALLOW_SERVICE_TOKEN_FALLBACK",
            ],
        },
        "repo_validation": {
            "TRR-APP": {
                "env_example": "TRR-APP/apps/web/.env.example",
                "required_env_example_keys": ["TRR_DB_URL"],
            }
        },
    }


def test_deprecated_runtime_name_fails_in_authority_surface(tmp_path: Path, monkeypatch) -> None:
    module = _load_module()
    monkeypatch.setattr(module, "ROOT", tmp_path)
    _write(tmp_path / "profiles/default.env", "DATABASE_URL=postgresql://secret\n")
    _write(tmp_path / "TRR-APP/apps/web/.env.example", "TRR_DB_URL=\n")

    findings, _counts = module._collect_findings(_manifest())

    assert any(finding.severity == "error" and finding.key == "DATABASE_URL" for finding in findings)


def test_snapshot_env_values_are_not_authority_errors(tmp_path: Path, monkeypatch) -> None:
    module = _load_module()
    monkeypatch.setattr(module, "ROOT", tmp_path)
    _write(tmp_path / "profiles/default.env", "TRR_DB_URL=\n")
    _write(tmp_path / "TRR-APP/apps/web/.env.example", "TRR_DB_URL=\n")
    _write(tmp_path / ".logs/workspace/pids.env", "DATABASE_URL=postgresql://secret\n")

    findings, counts = module._collect_findings(_manifest())

    assert counts["evidence_snapshots"] == 1
    assert not [finding for finding in findings if finding.severity == "error"]


def test_text_report_redacts_local_secret_values(tmp_path: Path, monkeypatch) -> None:
    module = _load_module()
    monkeypatch.setattr(module, "ROOT", tmp_path)
    _write(tmp_path / "profiles/default.env", "TRR_DB_URL=\n")
    _write(tmp_path / "TRR-APP/apps/web/.env.example", "TRR_DB_URL=\n")
    _write(tmp_path / "TRR-APP/apps/web/.env.local", "SUPABASE_URL=super-secret-value\n")
    _write(tmp_path / "TRR-Backend/.env", "SUPABASE_URL=another-secret-value\n")

    findings, counts = module._collect_findings(_manifest())
    actions = module._collect_cleanup_actions(_manifest())
    report = module._render_text(findings, counts, actions)

    assert "SUPABASE_URL" in report
    assert "super-secret-value" not in report
    assert "another-secret-value" not in report
    assert "DRY-RUN REMOVE: local_secret_adapters: TRR-APP/apps/web/.env.local: SUPABASE_URL" in report
    assert "DRY-RUN KEEP: local_secret_adapters: TRR-Backend/.env: SUPABASE_URL" in report


def test_cleanup_actions_classify_app_supabase_and_postgres_keys(tmp_path: Path, monkeypatch) -> None:
    module = _load_module()
    monkeypatch.setattr(module, "ROOT", tmp_path)
    _write(tmp_path / "TRR-APP/apps/web/.env.local", "\n".join([
        "SUPABASE_SERVICE_ROLE_KEY=legacy",
        "SUPABASE_JWT_SECRET=backend-only",
        "TRR_CORE_SUPABASE_SERVICE_ROLE_KEY=canonical",
        "POSTGRES_POOL_MAX=1",
        "TRR_DB_APPLICATION_NAME=backend-only",
        "DATABASE_URL=postgresql://secret",
        "",
    ]))

    actions = {
        (action.key, action.status, action.reason)
        for action in module._collect_cleanup_actions(_manifest())
    }

    assert ("SUPABASE_SERVICE_ROLE_KEY", "remove", "legacy app-local Supabase key; TRR-APP uses TRR_CORE_SUPABASE_*") in actions
    assert ("SUPABASE_JWT_SECRET", "remove", "legacy app-local Supabase key; TRR-APP uses TRR_CORE_SUPABASE_*") in actions
    assert ("TRR_CORE_SUPABASE_SERVICE_ROLE_KEY", "keep", "TRR-APP server/admin Supabase contract") in actions
    assert ("POSTGRES_POOL_MAX", "keep", "TRR-APP Postgres pool/application-name control") in actions
    assert ("TRR_DB_APPLICATION_NAME", "remove", "backend-only DB application-name label") in actions
    assert ("DATABASE_URL", "remove", "deprecated runtime name; use TRR_DB_* lanes instead") in actions


def test_duplicate_warning_includes_cleanup_statuses(tmp_path: Path, monkeypatch) -> None:
    module = _load_module()
    monkeypatch.setattr(module, "ROOT", tmp_path)
    _write(tmp_path / "profiles/default.env", "TRR_DB_URL=\n")
    _write(tmp_path / "TRR-APP/apps/web/.env.example", "TRR_DB_URL=\n")
    _write(tmp_path / "TRR-APP/apps/web/.env.local", "SUPABASE_URL=legacy-app\n")
    _write(tmp_path / "TRR-Backend/.env", "SUPABASE_URL=backend\n")

    findings, _counts = module._collect_findings(_manifest())
    warning = next(finding for finding in findings if finding.severity == "warn" and finding.key == "SUPABASE_URL")

    assert "TRR-APP/apps/web/.env.local=remove" in warning.message
    assert "TRR-Backend/.env=keep" in warning.message


def test_cleanup_actions_classify_screenalytics_legacy_supabase_db_parts(tmp_path: Path, monkeypatch) -> None:
    module = _load_module()
    monkeypatch.setattr(module, "ROOT", tmp_path)
    monkeypatch.setenv("WORKSPACE_ENV_HYGIENE_INCLUDE_ADJACENT", "1")
    manifest = _manifest()
    _write(tmp_path / "screenalytics/.env", "\n".join([
        "SUPABASE_DB_HOST=db.example.supabase.co",
        "TRR_DB_URL=postgresql://canonical",
        "SCREENALYTICS_OBJECT_STORAGE_BUCKET=bucket",
        "TRR_SCREENALYTICS_ALLOW_SERVICE_TOKEN_FALLBACK=1",
        "",
    ]))

    actions = {
        (action.authority, action.key, action.status, action.reason)
        for action in module._collect_cleanup_actions(manifest)
    }

    assert ("retired_env_surfaces", "SUPABASE_DB_HOST", "remove", "retired Screenalytics env surface; key is not current TRR workspace authority") in actions
    assert ("retired_env_surfaces", "TRR_DB_URL", "keep", "retired Screenalytics env surface; retained key is owned by workspace-ops") in actions
    assert ("retired_env_surfaces", "SCREENALYTICS_OBJECT_STORAGE_BUCKET", "move", "retired Screenalytics env surface; legacy key should be renamed; use TRR_CAST_SCREENTIME_ARTIFACT_BUCKET for new configuration") in actions
    assert ("retired_env_surfaces", "TRR_SCREENALYTICS_ALLOW_SERVICE_TOKEN_FALLBACK", "remove", "retired Screenalytics env surface; key is not current TRR workspace authority") in actions


def test_retired_screenalytics_env_is_not_current_local_secret_authority(tmp_path: Path, monkeypatch) -> None:
    module = _load_module()
    monkeypatch.setattr(module, "ROOT", tmp_path)
    monkeypatch.setenv("WORKSPACE_ENV_HYGIENE_INCLUDE_ADJACENT", "1")
    _write(tmp_path / "profiles/default.env", "TRR_DB_URL=\n")
    _write(tmp_path / "TRR-APP/apps/web/.env.example", "TRR_DB_URL=\n")
    _write(tmp_path / "TRR-APP/apps/web/.env.local", "TRR_DB_URL=postgresql://app\n")
    _write(tmp_path / "screenalytics/.env", "TRR_DB_URL=postgresql://retired\n")

    findings, counts = module._collect_findings(_manifest())

    assert counts["local_secret_adapters"] == 1
    assert counts["retired_env_surfaces"] == 1
    assert not any("screenalytics/.env" in finding.surface for finding in findings)


def test_retired_screenalytics_env_is_excluded_by_default(tmp_path: Path, monkeypatch) -> None:
    module = _load_module()
    monkeypatch.setattr(module, "ROOT", tmp_path)
    monkeypatch.delenv("WORKSPACE_ENV_HYGIENE_INCLUDE_ADJACENT", raising=False)
    _write(tmp_path / "profiles/default.env", "TRR_DB_URL=\n")
    _write(tmp_path / "TRR-APP/apps/web/.env.example", "TRR_DB_URL=\n")
    _write(tmp_path / "screenalytics/.env", "TRR_DB_URL=postgresql://retired\n")

    findings, counts = module._collect_findings(_manifest())
    actions = module._collect_cleanup_actions(_manifest())

    assert counts["retired_env_surfaces"] == 0
    assert not any("screenalytics/.env" in finding.surface for finding in findings)
    assert not any("screenalytics/.env" in action.surface for action in actions)


def test_cleanup_actions_cover_all_env_file_authority_classes(tmp_path: Path, monkeypatch) -> None:
    module = _load_module()
    monkeypatch.setattr(module, "ROOT", tmp_path)
    monkeypatch.setenv("WORKSPACE_ENV_HYGIENE_INCLUDE_ADJACENT", "1")
    _write(tmp_path / "profiles/default.env", "TRR_DB_URL=\n")
    _write(tmp_path / "TRR-APP/apps/web/.env.example", "NEXTAUTH_SECRET=\n")
    _write(tmp_path / "TRR-APP/apps/web/.env.local", "LOCAL_ONLY_KEY=value\n")
    _write(tmp_path / "screenalytics/.env", "SCREENALYTICS_LOCAL_ONLY=value\n")
    _write(tmp_path / ".logs/workspace/pids.env", "WORKSPACE_MANAGER_PID=123\n")

    actions = {
        (action.authority, action.surface, action.key, action.status, action.reason)
        for action in module._collect_cleanup_actions(_manifest())
    }

    assert ("runtime_profile_adapters", "profiles/default.env", "TRR_DB_URL", "keep", "checked-in profile/setup adapter key") in actions
    assert ("surface_setup_adapters", "TRR-APP/apps/web/.env.example", "NEXTAUTH_SECRET", "keep", "checked-in profile/setup adapter key") in actions
    assert ("local_secret_adapters", "TRR-APP/apps/web/.env.local", "LOCAL_ONLY_KEY", "keep", "surface-local key is not part of the shared TRR env contract") in actions
    assert ("retired_env_surfaces", "screenalytics/.env", "SCREENALYTICS_LOCAL_ONLY", "remove", "retired Screenalytics env surface; unclassified Screenalytics-prefixed key should not become current authority") in actions
    assert ("evidence_snapshots", ".logs/workspace/pids.env", "WORKSPACE_MANAGER_PID", "keep", "evidence snapshot; report only and do not edit generated/pulled env evidence") in actions

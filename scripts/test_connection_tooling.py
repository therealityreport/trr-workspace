from __future__ import annotations

import importlib.util
import io
import os
import subprocess
import sys
import tomllib
import urllib.error
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def run_script(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["python3", *args],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )


def write_vercel_project(project_dir: Path, *, name: str, project_id: str) -> None:
    vercel_dir = project_dir / ".vercel"
    vercel_dir.mkdir(parents=True)
    (vercel_dir / "project.json").write_text(
        (
            "{\n"
            f'  "projectName": "{name}",\n'
            f'  "projectId": "{project_id}",\n'
            '  "orgId": "team_test"\n'
            "}\n"
        ),
        encoding="utf-8",
    )


def run_vercel_wrapper(
    tmp_path: Path,
    *args: str,
    allow_prod: bool = False,
) -> subprocess.CompletedProcess[str]:
    fake_guard = tmp_path / "fake-vercel-project-guard.py"
    fake_guard.write_text(
        (
            "#!/usr/bin/env python3\n"
            "import sys\n"
            "print('[fake-vercel-project-guard] OK ' + ' '.join(sys.argv[1:]))\n"
            "raise SystemExit(0)\n"
        ),
        encoding="utf-8",
    )
    fake_guard.chmod(0o755)
    env = os.environ.copy()
    env["TRR_VERCEL_GUARD_ONLY"] = "1"
    env["TRR_VERCEL_PROJECT_GUARD"] = str(fake_guard)
    if allow_prod:
        env["TRR_VERCEL_ALLOW_PROD"] = "1"
    else:
        env.pop("TRR_VERCEL_ALLOW_PROD", None)

    return subprocess.run(
        ["bash", "TRR-APP/scripts/vercel.sh", *args],
        cwd=ROOT,
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )


def test_redacted_env_inventory_keeps_connection_values_shape_only(tmp_path: Path) -> None:
    env_file = tmp_path / ".env"
    env_file.write_text(
        "\n".join(
            [
                "TRR_DB_URL=postgresql://postgres.ref:super-secret@aws-1-us-east-1.pooler.supabase.com:5432/postgres",
                "TRR_CORE_SUPABASE_SERVICE_ROLE_KEY=secret-key",
                "POSTGRES_APPLICATION_NAME=trr-app:test",
            ]
        )
        + "\n",
        encoding="utf-8",
    )

    result = run_script(
        "scripts/redact-env-inventory.py",
        "--surface",
        f"test={env_file}",
        "--key",
        "TRR_DB_URL",
        "--key",
        "TRR_CORE_SUPABASE_SERVICE_ROLE_KEY",
        "--key",
        "POSTGRES_APPLICATION_NAME",
    )

    assert result.returncode == 0, result.stderr
    assert "supavisor-session:5432" in result.stdout
    assert "present-redacted-secret" in result.stdout
    assert "super-secret" not in result.stdout
    assert "secret-key" not in result.stdout


def test_vercel_project_guard_passes_project_of_record(tmp_path: Path) -> None:
    project_dir = tmp_path / "TRR-APP"
    write_vercel_project(
        project_dir,
        name="trr-app",
        project_id="prj_MHpStkwr26rV5kjt0f80zqhwZpAs",
    )

    result = run_script("scripts/vercel-project-guard.py", "--project-dir", str(project_dir))

    assert result.returncode == 0, result.stderr
    assert "trr-app" in result.stdout


def test_vercel_project_guard_blocks_nested_stale_project(tmp_path: Path) -> None:
    project_dir = tmp_path / "TRR-APP" / "apps" / "web"
    write_vercel_project(
        project_dir,
        name="web",
        project_id="prj_0nWn8xpm9ikhcvhzE3ma4jUXTe1p",
    )

    result = run_script("scripts/vercel-project-guard.py", "--project-dir", str(project_dir))

    assert result.returncode == 1
    assert "sandbox/stale-nested-project" in result.stderr
    assert "production env mutation is blocked" in result.stderr


def test_vercel_project_guard_explains_missing_local_project_link(tmp_path: Path) -> None:
    project_dir = tmp_path / "TRR-APP"

    result = run_script("scripts/vercel-project-guard.py", "--project-dir", str(project_dir))

    assert result.returncode == 1
    assert "classification=missing-project-link" in result.stderr
    assert "expected trr-app (prj_MHpStkwr26rV5kjt0f80zqhwZpAs)" in result.stderr
    assert "./scripts/vercel.sh link-trr" in result.stderr


def test_vercel_wrapper_allows_preview_deploy_after_project_guard(tmp_path: Path) -> None:
    result = run_vercel_wrapper(tmp_path, "deploy")

    assert result.returncode == 0, result.stderr
    assert "[fake-vercel-project-guard] OK" in result.stdout
    assert "guard-only: command accepted" in result.stdout


def test_vercel_wrapper_blocks_production_deploy_without_explicit_opt_in(tmp_path: Path) -> None:
    result = run_vercel_wrapper(tmp_path, "deploy", "--prod")

    assert result.returncode == 1
    assert "[fake-vercel-project-guard] OK" in result.stdout
    assert "TRR_VERCEL_ALLOW_PROD=1" in result.stderr
    assert "production deploys need explicit current approval" in result.stderr


def test_vercel_wrapper_allows_production_deploy_with_explicit_opt_in(tmp_path: Path) -> None:
    result = run_vercel_wrapper(tmp_path, "deploy", "--target", "production", allow_prod=True)

    assert result.returncode == 0, result.stderr
    assert "[fake-vercel-project-guard] OK" in result.stdout
    assert "guard-only: command accepted" in result.stdout


def test_vercel_wrapper_preview_ready_checks_project_guard(tmp_path: Path) -> None:
    result = run_vercel_wrapper(tmp_path, "preview-ready")

    assert result.returncode == 0, result.stderr
    assert "[fake-vercel-project-guard] OK" in result.stdout
    assert "preview-ready: guard-only accepted" in result.stdout


def test_next_devtools_mcp_registration_is_project_local() -> None:
    config = tomllib.loads((ROOT / ".codex" / "config.toml").read_text(encoding="utf-8"))
    server = config["mcp_servers"]["next-devtools"]

    assert server["command"] == "npx"
    assert server["args"] == ["-y", "next-devtools-mcp@latest"]
    assert server["env"]["NEXT_TELEMETRY_DISABLED"] == "1"
    assert server["startup_timeout_ms"] >= 20_000


def test_migration_ownership_lint_uses_allowlist() -> None:
    result = run_script("scripts/migration-ownership-lint.py")

    assert result.returncode == 0, result.stderr
    assert "[migration-ownership-lint] OK" in result.stdout


def test_app_direct_sql_inventory_emits_owner_aliases_and_retained_exception_contract(tmp_path: Path) -> None:
    output_path = tmp_path / "app-direct-sql-inventory.md"
    result = run_script("scripts/app-direct-sql-inventory.py", "--output", str(output_path))

    assert result.returncode == 0, result.stderr
    rendered = output_path.read_text(encoding="utf-8")
    assert "## Owner Aliases" in rendered
    assert "## Retained High-Fan-Out Exceptions" in rendered
    assert "`backend-shared-schema`" in rendered
    assert "| n/a | n/a | n/a | n/a | n/a |" in rendered
    assert "New high-fanout app direct-SQL rows must include an exception owner" in rendered
    assert "needs owner label" not in rendered


def load_supabase_mcp_access_module():
    module_path = ROOT / "scripts" / "check-supabase-mcp-access.py"
    spec = importlib.util.spec_from_file_location("check_supabase_mcp_access", module_path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def load_supabase_advisor_snapshot_module():
    module_path = ROOT / "scripts" / "capture-supabase-advisor-snapshot.py"
    spec = importlib.util.spec_from_file_location("capture_supabase_advisor_snapshot", module_path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def load_supabase_preview_branch_cleanup_module():
    module_path = ROOT / "scripts" / "supabase-preview-branch-cleanup.py"
    spec = importlib.util.spec_from_file_location("supabase_preview_branch_cleanup", module_path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def test_vercel_cleanup_doctor_finds_stale_web_project_link(tmp_path: Path) -> None:
    app_root = tmp_path / "TRR-APP"
    write_vercel_project(
        app_root,
        name="trr-app",
        project_id="prj_MHpStkwr26rV5kjt0f80zqhwZpAs",
    )
    write_vercel_project(
        app_root / "apps" / "web",
        name="web",
        project_id="prj_0nWn8xpm9ikhcvhzE3ma4jUXTe1p",
    )

    result = run_script("scripts/vercel-cleanup-doctor.py", "--scan-root", str(app_root))

    assert result.returncode == 1
    assert "classification=project-of-record" in result.stdout
    assert "classification=stale-old-web-project" in result.stdout
    assert "rm -rf" in result.stdout
    assert "apps/web/.vercel" in result.stdout


def test_vercel_cleanup_doctor_passes_clean_project_link(tmp_path: Path) -> None:
    app_root = tmp_path / "TRR-APP"
    write_vercel_project(
        app_root,
        name="trr-app",
        project_id="prj_MHpStkwr26rV5kjt0f80zqhwZpAs",
    )

    result = run_script("scripts/vercel-cleanup-doctor.py", "--scan-root", str(app_root))

    assert result.returncode == 0, result.stdout
    assert "no stale local Vercel links found" in result.stdout


def test_vercel_wrapper_runs_cleanup_doctor(tmp_path: Path) -> None:
    env = os.environ.copy()

    result = subprocess.run(
        ["bash", "TRR-APP/scripts/vercel.sh", "cleanup-doctor", "--scan-root", str(tmp_path / "missing")],
        cwd=ROOT,
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )

    assert result.returncode == 1
    assert "[vercel-cleanup-doctor] ERROR: no local Vercel project links found." in result.stdout


def test_supabase_mcp_access_loads_project_specific_token_env(tmp_path: Path) -> None:
    module = load_supabase_mcp_access_module()
    config = tmp_path / "config.toml"
    config.write_text(
        """
[mcp_servers.supabase]
url = "https://mcp.supabase.com/mcp?project_ref=vwxfvzutyufrkhfgoeaa&features=database"
bearer_token_env_var = "TRR_SUPABASE_ACCESS_TOKEN"
""".strip()
        + "\n",
        encoding="utf-8",
    )

    loaded = module.load_config(config)

    assert loaded.project_ref == "vwxfvzutyufrkhfgoeaa"
    assert loaded.token_env == "TRR_SUPABASE_ACCESS_TOKEN"


def test_supabase_mcp_access_reports_permission_block_without_leaking_token() -> None:
    module = load_supabase_mcp_access_module()

    def fake_opener(request, timeout):
        assert request.headers["User-agent"] == "TRR supabase-mcp-access/1.0"
        raise urllib.error.HTTPError(
            request.full_url,
            403,
            "Forbidden",
            {},
            io.BytesIO(b'{"message":"no project access"}'),
        )

    result = module.check_project_access(
        project_ref="vwxfvzutyufrkhfgoeaa",
        token_env="TRR_SUPABASE_ACCESS_TOKEN",
        token="secret-token-value",
        timeout=1.0,
        opener=fake_opener,
    )
    rendered = module.render_human(result)

    assert result.state == "permission_blocked"
    assert result.exit_code == 3
    assert "MCP error -32600" in rendered
    assert "secret-token-value" not in rendered


def test_supabase_mcp_access_missing_trr_token_ignores_generic_token() -> None:
    module = load_supabase_mcp_access_module()

    result = module.check_project_access(
        project_ref="vwxfvzutyufrkhfgoeaa",
        token_env="TRR_SUPABASE_ACCESS_TOKEN",
        token="",
        timeout=1.0,
        legacy_generic_token_present=True,
    )
    rendered = module.render_human(result)

    assert result.state == "missing_token"
    assert "SUPABASE_ACCESS_TOKEN is set but TRR ignores it" in rendered


def test_supabase_advisor_snapshot_writes_dated_json_artifacts(tmp_path: Path) -> None:
    module = load_supabase_advisor_snapshot_module()
    requested_urls: list[str] = []

    class FakeResponse:
        status = 200

        def __init__(self, body: bytes) -> None:
            self.body = body

        def __enter__(self):
            return self

        def __exit__(self, *args):
            return None

        def read(self) -> bytes:
            return self.body

    def fake_opener(request, timeout):
        assert request.headers["User-agent"] == "TRR supabase-advisor-snapshot/1.0"
        assert request.headers["Authorization"] == "Bearer secret-token-value"
        requested_urls.append(request.full_url)
        advisor_type = request.full_url.rsplit("/", 1)[-1]
        return FakeResponse(
            (
                '{"lints":[{"name":"'
                + advisor_type
                + '_lint","level":"WARN"}],"source":"test"}'
            ).encode("utf-8")
        )

    result = module.capture_snapshot(
        project_ref="vwxfvzutyufrkhfgoeaa",
        token_env="TRR_SUPABASE_ACCESS_TOKEN",
        token="secret-token-value",
        output_root=tmp_path,
        snapshot_date="2026-04-28",
        timeout=1.0,
        opener=fake_opener,
    )

    assert result.exit_code == 0
    assert requested_urls == [
        "https://api.supabase.com/v1/projects/vwxfvzutyufrkhfgoeaa/advisors/performance",
        "https://api.supabase.com/v1/projects/vwxfvzutyufrkhfgoeaa/advisors/security",
    ]
    assert (tmp_path / "2026-04-28" / "performance.json").exists()
    assert (tmp_path / "2026-04-28" / "security.json").exists()
    summary = (tmp_path / "2026-04-28" / "summary.md").read_text(encoding="utf-8")
    manifest = (tmp_path / "2026-04-28" / "manifest.json").read_text(encoding="utf-8")
    assert "TRR_SUPABASE_ACCESS_TOKEN" in manifest
    assert "secret-token-value" not in manifest
    assert '"lint_count": 1' in manifest
    assert "make supabase-advisor-snapshot" in summary
    assert "TRR_SUPABASE_ACCESS_TOKEN" in summary


def test_supabase_advisor_snapshot_reports_missing_trr_token_without_network(tmp_path: Path) -> None:
    env = os.environ.copy()
    env.pop("TRR_SUPABASE_ACCESS_TOKEN", None)
    env["SUPABASE_ACCESS_TOKEN"] = "generic-token-that-must-not-be-used"
    result = subprocess.run(
        [
            "python3",
            "scripts/capture-supabase-advisor-snapshot.py",
            "--output-dir",
            str(tmp_path),
            "--date",
            "2026-04-28",
        ],
        cwd=ROOT,
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )

    assert result.returncode == 2
    assert "TRR_SUPABASE_ACCESS_TOKEN is not set" in result.stderr
    assert "SUPABASE_ACCESS_TOKEN is set but TRR ignores it" in result.stderr
    assert "advisors_read" in result.stderr
    assert not (tmp_path / "2026-04-28").exists()


def test_supabase_preview_branch_cleanup_selects_old_nonpersistent_branches() -> None:
    module = load_supabase_preview_branch_cleanup_module()
    now = module.datetime(2026, 6, 17, tzinfo=module.timezone.utc)
    branches = [
        {
            "id": "main-id",
            "name": "main",
            "is_default": True,
            "persistent": False,
            "updated_at": "2026-03-18T01:01:13+00:00",
        },
        {
            "id": "staging-id",
            "name": "staging",
            "is_default": False,
            "persistent": True,
            "updated_at": "2026-03-18T01:01:13+00:00",
        },
        {
            "id": "schema-id",
            "name": "schema-docs-0199",
            "is_default": False,
            "persistent": False,
            "status": "MIGRATIONS_FAILED",
            "project_ref": "previewref",
            "updated_at": "2026-03-18T01:01:13+00:00",
        },
        {
            "id": "fresh-id",
            "name": "migration-20260617-social-index",
            "is_default": False,
            "persistent": False,
            "updated_at": "2026-06-16T01:01:13+00:00",
        },
    ]

    candidates = module.select_cleanup_candidates(
        branches,
        now=now,
        older_than_days=30,
        names=set(),
    )

    assert [candidate.name for candidate in candidates] == ["schema-docs-0199"]
    assert candidates[0].status == "MIGRATIONS_FAILED"
    assert candidates[0].reason == "older-than-30-days"


def test_supabase_preview_branch_cleanup_name_filter_allows_targeted_branch() -> None:
    module = load_supabase_preview_branch_cleanup_module()
    now = module.datetime(2026, 6, 17, tzinfo=module.timezone.utc)
    branches = [
        {
            "id": "fresh-id",
            "name": "migration-20260617-social-index",
            "is_default": False,
            "persistent": False,
            "status": "FUNCTIONS_DEPLOYED",
            "updated_at": "2026-06-16T01:01:13+00:00",
        }
    ]

    candidates = module.select_cleanup_candidates(
        branches,
        now=now,
        older_than_days=30,
        names={"fresh-id"},
    )

    assert [candidate.id for candidate in candidates] == ["fresh-id"]
    assert candidates[0].reason == "explicit-name"

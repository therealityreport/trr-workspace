from __future__ import annotations

import importlib.util
import io
import subprocess
import sys
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


def test_vercel_project_guard_passes_project_of_record() -> None:
    result = run_script("scripts/vercel-project-guard.py", "--project-dir", "TRR-APP")

    assert result.returncode == 0, result.stderr
    assert "trr-app" in result.stdout


def test_vercel_project_guard_blocks_nested_stale_project() -> None:
    result = run_script("scripts/vercel-project-guard.py", "--project-dir", "TRR-APP/apps/web")

    assert result.returncode == 1
    assert "sandbox/stale-nested-project" in result.stderr
    assert "production env mutation is blocked" in result.stderr


def test_migration_ownership_lint_uses_allowlist() -> None:
    result = run_script("scripts/migration-ownership-lint.py")

    assert result.returncode == 0, result.stderr
    assert "[migration-ownership-lint] OK" in result.stdout


def test_app_direct_sql_inventory_emits_owner_aliases_and_exception_dates(tmp_path: Path) -> None:
    output_path = tmp_path / "app-direct-sql-inventory.md"
    result = run_script("scripts/app-direct-sql-inventory.py", "--output", str(output_path))

    assert result.returncode == 0, result.stderr
    rendered = output_path.read_text(encoding="utf-8")
    assert "## Owner Aliases" in rendered
    assert "## Retained High-Fan-Out Exceptions" in rendered
    assert "`backend-shared-schema`" in rendered
    assert "`2026-05-27`" in rendered
    assert "needs owner label" not in rendered


def load_supabase_mcp_access_module():
    module_path = ROOT / "scripts" / "check-supabase-mcp-access.py"
    spec = importlib.util.spec_from_file_location("check_supabase_mcp_access", module_path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


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

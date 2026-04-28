from __future__ import annotations

import subprocess
from pathlib import Path


SCRIPT_PATH = Path(__file__).resolve().parent / "lib" / "runtime-db-env.sh"


def _run_bash(script: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["/bin/bash", "-lc", script],
        capture_output=True,
        text=True,
        check=False,
    )


def test_export_env_value_from_file_if_unset_exports_missing_value(tmp_path: Path) -> None:
    env_file = tmp_path / ".env"
    env_file.write_text("SUPABASE_JWT_SECRET=from-dotenv\n", encoding="utf-8")

    result = _run_bash(
        f"""
        unset SUPABASE_JWT_SECRET
        source "{SCRIPT_PATH}"
        trr_export_env_value_from_file_if_unset "{env_file}" "SUPABASE_JWT_SECRET"
        printf '%s' "${{SUPABASE_JWT_SECRET:-}}"
        """
    )

    assert result.returncode == 0, result.stderr
    assert result.stdout == "from-dotenv"


def test_export_env_value_from_file_if_unset_preserves_existing_value(tmp_path: Path) -> None:
    env_file = tmp_path / ".env"
    env_file.write_text("SUPABASE_JWT_SECRET=from-dotenv\n", encoding="utf-8")

    result = _run_bash(
        f"""
        export SUPABASE_JWT_SECRET="already-set"
        source "{SCRIPT_PATH}"
        trr_export_env_value_from_file_if_unset "{env_file}" "SUPABASE_JWT_SECRET"
        printf '%s' "${{SUPABASE_JWT_SECRET:-}}"
        """
    )

    assert result.returncode == 0, result.stderr
    assert result.stdout == "already-set"


def test_runtime_db_resolver_prefers_direct_url_from_app_env(tmp_path: Path) -> None:
    root = tmp_path
    app_env = root / "TRR-APP" / "apps" / "web" / ".env.local"
    app_env.parent.mkdir(parents=True)
    app_env.write_text(
        "\n".join(
            [
                "TRR_DB_DIRECT_URL=postgresql://direct",
                "TRR_DB_SESSION_URL=postgresql://session",
                "TRR_DB_URL=postgresql://compat",
            ]
        )
        + "\n",
        encoding="utf-8",
    )

    result = _run_bash(
        f"""
        unset TRR_DB_DIRECT_URL TRR_DB_SESSION_URL TRR_DB_URL
        source "{SCRIPT_PATH}"
        printf '%s\\n%s' "$(trr_runtime_db_resolve_local_app_source "{root}")" "$(trr_runtime_db_resolve_local_app_url "{root}")"
        """
    )

    assert result.returncode == 0, result.stderr
    assert result.stdout == "TRR_DB_DIRECT_URL\npostgresql://direct"


def test_runtime_db_resolver_prefers_app_direct_over_exported_session(tmp_path: Path) -> None:
    root = tmp_path
    app_env = root / "TRR-APP" / "apps" / "web" / ".env.local"
    app_env.parent.mkdir(parents=True)
    app_env.write_text("TRR_DB_DIRECT_URL=postgresql://direct\n", encoding="utf-8")

    result = _run_bash(
        f"""
        unset TRR_DB_DIRECT_URL TRR_DB_URL
        export TRR_DB_SESSION_URL=postgresql://session
        source "{SCRIPT_PATH}"
        printf '%s\\n%s' "$(trr_runtime_db_resolve_local_app_source "{root}")" "$(trr_runtime_db_resolve_local_app_url "{root}")"
        """
    )

    assert result.returncode == 0, result.stderr
    assert result.stdout == "TRR_DB_DIRECT_URL\npostgresql://direct"


def test_local_resolver_derives_direct_uri_from_validated_pooler_url(tmp_path: Path) -> None:
    root = tmp_path
    app_env = root / "TRR-APP" / "apps" / "web" / ".env.local"
    app_env.parent.mkdir(parents=True)
    app_env.write_text(
        "TRR_DB_URL=postgresql://postgres.abcdefghijklmnopqrst:secret@aws-0-us-east-1.pooler.supabase.com:5432/postgres\n",
        encoding="utf-8",
    )

    result = _run_bash(
        f"""
        unset TRR_DB_DIRECT_URL TRR_DB_SESSION_URL TRR_DB_URL WORKSPACE_TRR_DB_LANE
        export TRR_SUPABASE_PROJECT_REF=abcdefghijklmnopqrst
        source "{SCRIPT_PATH}"
        printf '%s\\n%s' "$(trr_runtime_db_resolve_local_app_source "{root}" local)" "$(trr_runtime_db_resolve_local_app_url "{root}" local)"
        """
    )

    assert result.returncode == 0, result.stderr
    assert result.stdout == (
        "derived_direct_uri\n"
        "postgresql://postgres:secret@db.abcdefghijklmnopqrst.supabase.co:5432/postgres"
    )


def test_local_resolver_fails_closed_without_valid_direct_lane(tmp_path: Path) -> None:
    root = tmp_path
    app_env = root / "TRR-APP" / "apps" / "web" / ".env.local"
    app_env.parent.mkdir(parents=True)
    app_env.write_text(
        "TRR_DB_URL=postgresql://postgres.otherref:secret@aws-0-us-east-1.pooler.supabase.com:5432/postgres\n",
        encoding="utf-8",
    )

    result = _run_bash(
        f"""
        unset TRR_DB_DIRECT_URL TRR_DB_SESSION_URL TRR_DB_URL WORKSPACE_TRR_DB_LANE
        source "{SCRIPT_PATH}"
        trr_runtime_db_resolve_local_app_url "{root}" local
        """
    )

    assert result.returncode != 0


def test_local_resolver_allows_explicit_session_escape_hatch(tmp_path: Path) -> None:
    root = tmp_path
    app_env = root / "TRR-APP" / "apps" / "web" / ".env.local"
    app_env.parent.mkdir(parents=True)
    app_env.write_text("TRR_DB_SESSION_URL=postgresql://session\n", encoding="utf-8")

    result = _run_bash(
        f"""
        unset TRR_DB_DIRECT_URL TRR_DB_URL
        export WORKSPACE_TRR_DB_LANE=session
        source "{SCRIPT_PATH}"
        printf '%s\\n%s' "$(trr_runtime_db_resolve_local_app_source "{root}" local)" "$(trr_runtime_db_resolve_local_app_url "{root}" local)"
        """
    )

    assert result.returncode == 0, result.stderr
    assert result.stdout == "TRR_DB_SESSION_URL\npostgresql://session"


def test_remote_worker_resolver_uses_session_lane_not_direct(tmp_path: Path) -> None:
    root = tmp_path
    app_env = root / "TRR-APP" / "apps" / "web" / ".env.local"
    app_env.parent.mkdir(parents=True)
    app_env.write_text(
        "TRR_DB_DIRECT_URL=postgresql://direct\nTRR_DB_SESSION_URL=postgresql://session\n",
        encoding="utf-8",
    )

    result = _run_bash(
        f"""
        unset TRR_DB_DIRECT_URL TRR_DB_SESSION_URL TRR_DB_URL
        source "{SCRIPT_PATH}"
        printf '%s\\n%s' "$(trr_runtime_db_resolve_remote_worker_source "{root}" hybrid)" "$(trr_runtime_db_resolve_remote_worker_url "{root}" hybrid)"
        """
    )

    assert result.returncode == 0, result.stderr
    assert result.stdout == "TRR_DB_SESSION_URL\npostgresql://session"


def test_cloud_local_resolver_uses_session_lane_not_exported_direct(tmp_path: Path) -> None:
    root = tmp_path
    app_env = root / "TRR-APP" / "apps" / "web" / ".env.local"
    app_env.parent.mkdir(parents=True)
    app_env.write_text("TRR_DB_SESSION_URL=postgresql://session\n", encoding="utf-8")

    result = _run_bash(
        f"""
        export TRR_DB_DIRECT_URL=postgresql://direct
        unset TRR_DB_URL
        source "{SCRIPT_PATH}"
        printf '%s\\n%s' "$(trr_runtime_db_resolve_local_app_source "{root}" cloud)" "$(trr_runtime_db_resolve_local_app_url "{root}" cloud)"
        """
    )

    assert result.returncode == 0, result.stderr
    assert result.stdout == "TRR_DB_SESSION_URL\npostgresql://session"

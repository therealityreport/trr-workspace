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

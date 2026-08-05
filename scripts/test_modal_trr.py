from __future__ import annotations

import json
import os
import stat
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WRAPPER = ROOT / "scripts" / "modal-trr.sh"
ARCHITECTURE_PROFILE = ROOT / "profiles" / "architecture-refactor.env"
ARCHITECTURE_PREFLIGHT = ROOT / "scripts" / "architecture-refactor-preflight.sh"


def _fake_modal(tmp_path: Path) -> tuple[Path, Path]:
    log = tmp_path / "modal.json"
    executable = tmp_path / "modal"
    executable.write_text(
        "#!/usr/bin/env python3\n"
        "import json, os, sys\n"
        f"json.dump({{'argv': sys.argv[1:], 'profile': os.getenv('MODAL_PROFILE'), "
        f"'workspace': os.getenv('MODAL_WORKSPACE'), 'environment': os.getenv('MODAL_ENVIRONMENT'), "
        f"'app': os.getenv('TRR_MODAL_APP_NAME')}}, open({str(log)!r}, 'w'))\n",
        encoding="utf-8",
    )
    executable.chmod(executable.stat().st_mode | stat.S_IXUSR)
    return executable, log


def _fake_modal_with_identity(
    tmp_path: Path,
    rows: list[dict[str, object]],
) -> tuple[Path, Path, Path]:
    log = tmp_path / "modal.json"
    identity_check = tmp_path / "profile-checked"
    executable = tmp_path / "modal"
    executable.write_text(
        "#!/usr/bin/env python3\n"
        "import json, os, sys\n"
        f"rows = json.loads({json.dumps(rows)!r})\n"
        "if sys.argv[1:] == ['profile', 'list', '--json']:\n"
        f"    open({str(identity_check)!r}, 'w').write('checked')\n"
        "    print(json.dumps(rows))\n"
        "    raise SystemExit(0)\n"
        f"json.dump({{'argv': sys.argv[1:], 'profile': os.getenv('MODAL_PROFILE'), "
        f"'workspace': os.getenv('MODAL_WORKSPACE'), 'environment': os.getenv('MODAL_ENVIRONMENT'), "
        f"'app': os.getenv('TRR_MODAL_APP_NAME')}}, open({str(log)!r}, 'w'))\n",
        encoding="utf-8",
    )
    executable.chmod(executable.stat().st_mode | stat.S_IXUSR)
    return executable, log, identity_check


def test_modal_read_wrapper_pins_full_identity(tmp_path: Path) -> None:
    executable, log = _fake_modal(tmp_path)
    env = os.environ.copy()
    env.update(
        {
            "MODAL_BIN": str(executable),
            "MODAL_PROFILE": "wrong-profile",
            "MODAL_WORKSPACE": "wrong-workspace",
            "MODAL_ENVIRONMENT": "staging",
            "TRR_MODAL_APP_NAME": "wrong-app",
        }
    )

    completed = subprocess.run(
        ["bash", str(WRAPPER), "app", "history", "trr-backend-jobs", "--json"],
        cwd=ROOT,
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )

    assert completed.returncode == 0, completed.stderr
    payload = json.loads(log.read_text(encoding="utf-8"))
    assert payload == {
        "argv": ["app", "history", "trr-backend-jobs", "--json"],
        "profile": "admin-56995",
        "workspace": "admin-56995",
        "environment": "main",
        "app": "trr-backend-jobs",
    }


def test_modal_read_wrapper_rejects_mutation_commands_before_exec(
    tmp_path: Path,
) -> None:
    executable, log = _fake_modal(tmp_path)
    env = {**os.environ, "MODAL_BIN": str(executable)}

    for command in (
        ("deploy", "-m", "trr_backend.modal_jobs"),
        ("run", "-m", "trr_backend.modal_jobs"),
        ("secret", "create", "trr-backend-runtime"),
        ("secret", "delete", "trr-backend-runtime"),
        ("app", "stop", "trr-backend-jobs"),
        ("profile", "activate", "other"),
    ):
        completed = subprocess.run(
            ["bash", str(WRAPPER), *command],
            cwd=ROOT,
            env=env,
            capture_output=True,
            text=True,
            check=False,
        )
        assert completed.returncode != 0
        assert "read-only" in completed.stderr

    assert not log.exists()


def test_modal_read_wrapper_rejects_other_app(tmp_path: Path) -> None:
    executable, log = _fake_modal(tmp_path)
    completed = subprocess.run(
        ["bash", str(WRAPPER), "app", "logs", "other-app"],
        cwd=ROOT,
        env={**os.environ, "MODAL_BIN": str(executable)},
        capture_output=True,
        text=True,
        check=False,
    )

    assert completed.returncode != 0
    assert "trr-backend-jobs" in completed.stderr
    assert not log.exists()


def test_modal_read_wrapper_rejects_cli_identity_overrides_before_exec(
    tmp_path: Path,
) -> None:
    executable, log = _fake_modal(tmp_path)
    env = {**os.environ, "MODAL_BIN": str(executable)}

    for command in (
        ("app", "history", "trr-backend-jobs", "--env", "staging"),
        ("app", "history", "trr-backend-jobs", "--env=staging"),
        ("app", "logs", "trr-backend-jobs", "-e", "staging"),
        ("app", "logs", "trr-backend-jobs", "-estaging"),
        ("app", "logs", "trr-backend-jobs", "-fe", "staging"),
        ("profile", "current", "--environment", "staging"),
        ("profile", "current", "--environment=staging"),
        ("profile", "current", "--profile", "other"),
        ("profile", "current", "--profile=other"),
        ("profile", "current", "-p", "other"),
        ("profile", "current", "-pother"),
        ("profile", "current", "-fp", "other"),
        ("profile", "current", "--workspace", "other"),
        ("profile", "current", "--workspace=other"),
        ("profile", "current", "-w", "other"),
        ("profile", "current", "-wother"),
        ("profile", "current", "-fw", "other"),
    ):
        completed = subprocess.run(
            ["bash", str(WRAPPER), *command],
            cwd=ROOT,
            env=env,
            capture_output=True,
            text=True,
            check=False,
        )
        assert completed.returncode == 2, command
        assert "CLI identity override" in completed.stderr

    assert not log.exists()


def test_modal_rollback_dry_run_records_exact_pinned_target_without_exec(
    tmp_path: Path,
) -> None:
    executable, log = _fake_modal(tmp_path)
    completed = subprocess.run(
        ["bash", str(WRAPPER), "rollback", "--version", "v7"],
        cwd=ROOT,
        env={**os.environ, "MODAL_BIN": str(executable)},
        capture_output=True,
        text=True,
        check=False,
    )

    assert completed.returncode == 0, completed.stderr
    payload = json.loads(completed.stdout)
    assert payload == {
        "app": "trr-backend-jobs",
        "command": [
            "app",
            "rollback",
            "trr-backend-jobs",
            "v7",
            "--env",
            "main",
        ],
        "environment": "main",
        "execute": False,
        "operation": "rollback",
        "profile": "admin-56995",
        "targetVersion": "v7",
        "workspace": "admin-56995",
    }
    assert not log.exists()


def test_modal_evidence_dry_run_requires_no_provider_auth(tmp_path: Path) -> None:
    executable, log = _fake_modal(tmp_path)
    completed = subprocess.run(
        ["bash", str(WRAPPER), "evidence"],
        cwd=ROOT,
        env={**os.environ, "MODAL_BIN": str(executable)},
        capture_output=True,
        text=True,
        check=False,
    )

    assert completed.returncode == 0, completed.stderr
    payload = json.loads(completed.stdout)
    assert payload["operation"] == "evidence"
    assert payload["execute"] is False
    assert payload["command"] == [
        "app",
        "history",
        "trr-backend-jobs",
        "--env",
        "main",
        "--json",
    ]
    assert not log.exists()


def test_modal_rollback_rejects_invalid_version_before_exec(tmp_path: Path) -> None:
    executable, log = _fake_modal(tmp_path)
    completed = subprocess.run(
        ["bash", str(WRAPPER), "rollback", "--version", "latest"],
        cwd=ROOT,
        env={**os.environ, "MODAL_BIN": str(executable)},
        capture_output=True,
        text=True,
        check=False,
    )

    assert completed.returncode == 2
    assert "exact Modal version like v7" in completed.stderr
    assert not log.exists()


def test_modal_rollback_execute_requires_current_approval_before_exec(
    tmp_path: Path,
) -> None:
    executable, log = _fake_modal(tmp_path)
    env = {**os.environ, "MODAL_BIN": str(executable)}
    env.pop("TRR_MODAL_ROLLBACK_APPROVED", None)
    completed = subprocess.run(
        ["bash", str(WRAPPER), "rollback", "--version", "v7", "--execute"],
        cwd=ROOT,
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )

    assert completed.returncode == 2
    assert "TRR_MODAL_ROLLBACK_APPROVED=1" in completed.stderr
    assert not log.exists()


def test_modal_rollback_execute_verifies_workspace_then_uses_exact_target(
    tmp_path: Path,
) -> None:
    executable, log, identity_check = _fake_modal_with_identity(
        tmp_path,
        [{"name": "admin-56995", "workspace": "admin-56995", "active": True}],
    )
    completed = subprocess.run(
        ["bash", str(WRAPPER), "rollback", "--version", "v7", "--execute"],
        cwd=ROOT,
        env={
            **os.environ,
            "MODAL_BIN": str(executable),
            "TRR_MODAL_ROLLBACK_APPROVED": "1",
        },
        capture_output=True,
        text=True,
        check=False,
    )

    assert completed.returncode == 0, completed.stderr
    assert identity_check.is_file()
    assert json.loads(log.read_text(encoding="utf-8")) == {
        "argv": ["app", "rollback", "trr-backend-jobs", "v7", "--env", "main"],
        "profile": "admin-56995",
        "workspace": "admin-56995",
        "environment": "main",
        "app": "trr-backend-jobs",
    }


def test_modal_rollback_execute_stops_on_workspace_identity_mismatch(
    tmp_path: Path,
) -> None:
    executable, log, identity_check = _fake_modal_with_identity(
        tmp_path,
        [{"name": "admin-56995", "workspace": "wrong-workspace", "active": True}],
    )
    completed = subprocess.run(
        ["bash", str(WRAPPER), "rollback", "--version", "v7", "--execute"],
        cwd=ROOT,
        env={
            **os.environ,
            "MODAL_BIN": str(executable),
            "TRR_MODAL_ROLLBACK_APPROVED": "1",
        },
        capture_output=True,
        text=True,
        check=False,
    )

    assert completed.returncode == 2
    assert identity_check.is_file()
    assert "expected active profile/workspace admin-56995/admin-56995" in completed.stderr
    assert not log.exists()


def test_architecture_profile_owns_an_explicit_loopback_database_target() -> None:
    profile = ARCHITECTURE_PROFILE.read_text(encoding="utf-8")

    assert (
        "TRR_DB_DIRECT_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres"
        in profile
    )
    assert "WORKSPACE_TRR_DB_LANE=direct" in profile


def test_architecture_preflight_forces_loopback_and_intercepts_no_provider_command(
    tmp_path: Path,
) -> None:
    intercept_dir = tmp_path / "bin"
    intercept_dir.mkdir()
    log = tmp_path / "commands.log"
    for name in ("modal", "vercel", "render", "supabase", "curl"):
        command = intercept_dir / name
        command.write_text(
            f"#!/usr/bin/env bash\nprintf '%s\\n' {name!r} >> {str(log)!r}\nexit 97\n",
            encoding="utf-8",
        )
        command.chmod(command.stat().st_mode | stat.S_IXUSR)

    env = os.environ.copy()
    env.update(
        {
            "PATH": f"{intercept_dir}:{env['PATH']}",
            "TRR_DB_DIRECT_URL": "postgresql://remote:opaque@db.example.com:5432/postgres",
            "TRR_DB_SESSION_URL": "postgresql://remote:opaque@pooler.example.com:5432/postgres",
            "TRR_DB_URL": "postgresql://remote:opaque@pooler.example.com:5432/postgres",
            "TRR_DB_FALLBACK_URL": "postgresql://remote:opaque@pooler.example.com:5432/postgres",
        }
    )

    completed = subprocess.run(
        ["bash", str(ARCHITECTURE_PREFLIGHT)],
        cwd=ROOT,
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )

    assert completed.returncode == 0, completed.stderr
    assert "db_host_class=local" in completed.stdout
    assert "db_source=TRR_DB_DIRECT_URL" in completed.stdout
    assert "db_apply=off" in completed.stdout
    assert "remote_workers=off" in completed.stdout
    assert not log.exists(), f"intercepted prohibited command(s): {log.read_text()}"

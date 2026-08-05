from __future__ import annotations

import os
import stat
import subprocess
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[1]
DEV_SCRIPT = ROOT / "scripts" / "dev-workspace.sh"


def _make_interceptor(path: Path, name: str, log: Path) -> None:
    command = path / name
    command.write_text(
        f"#!/usr/bin/env bash\nprintf '%s\\n' {name!r} >> {str(log)!r}\nexit 97\n",
        encoding="utf-8",
    )
    command.chmod(command.stat().st_mode | stat.S_IXUSR)


def test_architecture_refactor_assertion_intercepts_no_remote_or_mutation_commands(
    tmp_path: Path,
) -> None:
    intercept_dir = tmp_path / "bin"
    intercept_dir.mkdir()
    log = tmp_path / "commands.log"
    for name in ("modal", "vercel", "render", "supabase", "curl"):
        _make_interceptor(intercept_dir, name, log)

    env = os.environ.copy()
    env.update(
        {
            "PATH": f"{intercept_dir}:{env['PATH']}",
            "PROFILE": "architecture-refactor",
            "TRR_DB_DIRECT_URL": "postgresql://local-user:local-password@127.0.0.1:54322/postgres",
            "WORKSPACE_TRR_DB_LANE": "direct",
            # Deliberately hostile inherited values must not weaken the profile.
            "WORKSPACE_DEV_MODE": "hybrid",
            "WORKSPACE_TRR_MODAL_ENABLED": "1",
            "WORKSPACE_TRR_REMOTE_WORKERS_ENABLED": "1",
            "WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS": "1",
            "WORKSPACE_RUNTIME_RECONCILE_ENABLED": "1",
            "WORKSPACE_RUNTIME_DB_AUTO_APPLY_ENABLED": "1",
            "WORKSPACE_RUNTIME_MODAL_AUTO_DEPLOY": "1",
            "WORKSPACE_RUNTIME_EXTERNAL_VERIFY_ENABLED": "1",
        }
    )

    completed = subprocess.run(
        ["bash", str(DEV_SCRIPT), "--assert-no-side-effects"],
        cwd=ROOT,
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )

    assert completed.returncode == 0, completed.stderr
    assert "db_apply=off" in completed.stdout
    assert "db_host_class=local" in completed.stdout
    assert "db_source=TRR_DB_DIRECT_URL" in completed.stdout
    assert "reconcile=off" in completed.stdout
    assert "modal_deploy=off" in completed.stdout
    assert "render_mutation=off" in completed.stdout
    assert "vercel_mutation=off" in completed.stdout
    assert "remote_workers=off" in completed.stdout
    assert not log.exists(), f"intercepted prohibited command(s): {log.read_text()}"


def test_architecture_refactor_profile_declares_every_mutation_guard() -> None:
    text = (ROOT / "profiles" / "architecture-refactor.env").read_text(encoding="utf-8")
    for assignment in (
        "WORKSPACE_ARCHITECTURE_DB_TARGET=loopback-only",
        "WORKSPACE_TRR_MODAL_ENABLED=0",
        "WORKSPACE_TRR_REMOTE_WORKERS_ENABLED=0",
        "WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS=0",
        "WORKSPACE_RUNTIME_RECONCILE_ENABLED=0",
        "WORKSPACE_RUNTIME_DB_AUTO_APPLY_ENABLED=0",
        "WORKSPACE_RUNTIME_MODAL_AUTO_DEPLOY=0",
        "WORKSPACE_RUNTIME_EXTERNAL_VERIFY_ENABLED=0",
    ):
        assert assignment in text


@pytest.mark.parametrize(
    ("url", "host_class"),
    [
        (
            "postgresql://user:opaque@db.vwxfvzutyufrkhfgoeaa.supabase.co:5432/postgres",
            "direct",
        ),
        (
            "postgresql://user:opaque@aws-0-us-east-1.pooler.supabase.com:5432/postgres",
            "session",
        ),
    ],
)
def test_architecture_refactor_rejects_remote_database_hosts(
    url: str,
    host_class: str,
) -> None:
    env = os.environ.copy()
    env.update(
        {
            "PROFILE": "architecture-refactor",
            "TRR_DB_DIRECT_URL": url,
            "WORKSPACE_TRR_DB_LANE": "direct",
        }
    )

    completed = subprocess.run(
        ["bash", str(DEV_SCRIPT), "--assert-no-side-effects"],
        cwd=ROOT,
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )

    assert completed.returncode != 0
    assert f"host_class={host_class}" in completed.stderr
    assert "source=TRR_DB_DIRECT_URL" in completed.stderr
    assert url not in completed.stdout
    assert url not in completed.stderr


def test_dev_hybrid_delegates_architecture_profile_before_hybrid_overrides() -> None:
    text = (ROOT / "Makefile").read_text(encoding="utf-8")
    target = text[
        text.index("\ndev-hybrid:") : text.index(
            "\n# Post-recovery", text.index("\ndev-hybrid:")
        )
    ]

    assert 'if [ "$${PROFILE:-}" = "architecture-refactor" ]' in target
    assert "dev-architecture-refactor" in target
    assert target.index("dev-architecture-refactor") < target.index(
        "WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS=1"
    )

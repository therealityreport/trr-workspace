from __future__ import annotations

import subprocess
import time
from pathlib import Path

from scripts import instagram_auth_freshness as cli


def test_check_instagram_auth_freshness_reports_ok_without_side_effects(
    tmp_path: Path,
    monkeypatch,
) -> None:
    cookie_file = tmp_path / "instagram_cookies.json"
    cookie_file.write_text("{}", encoding="utf-8")
    now = time.time()
    monkeypatch.setattr(cli, "DEFAULT_COOKIE_FILES", (cookie_file,))
    monkeypatch.setattr(cli, "_cookie_file_status", lambda now=None: [{"path": str(cookie_file), "present": True, "age_seconds": 12}])
    monkeypatch.setattr(cli, "_python_command", lambda: "python")
    monkeypatch.setattr(cli, "BACKEND_ROOT", tmp_path)
    monkeypatch.setattr(cli, "_max_age_seconds", lambda: 14 * 24 * 60 * 60)

    def fake_run(*_args, **_kwargs):
        return subprocess.CompletedProcess(
            ["python"],
            0,
            stdout='{"ok": true, "failure_reason": null, "modal_secret_apply_reached": false, "modal_deploy_reached": false, "remote_verify_reached": false}\n',
            stderr="",
        )

    monkeypatch.setattr(cli.subprocess, "run", fake_run)

    payload = cli.check_instagram_auth_freshness()

    assert now
    assert payload["state"] == "ok"
    assert payload["ok"] is True
    assert payload["side_effects"] == {
        "cookie_refresh": False,
        "modal_secret_apply": False,
        "modal_deploy": False,
        "remote_verify": False,
    }
    assert "Instagram auth freshness OK" in cli.render_summary(payload)


def test_check_instagram_auth_freshness_advises_on_validation_failure(tmp_path: Path, monkeypatch) -> None:
    monkeypatch.setattr(cli, "_cookie_file_status", lambda now=None: [])
    monkeypatch.setattr(cli, "_python_command", lambda: "python")
    monkeypatch.setattr(cli, "BACKEND_ROOT", tmp_path)

    def fake_run(*_args, **_kwargs):
        return subprocess.CompletedProcess(
            ["python"],
            1,
            stdout='{"ok": false, "failure_reason": "manual_checkpoint_required"}\n',
            stderr="",
        )

    monkeypatch.setattr(cli.subprocess, "run", fake_run)

    payload = cli.check_instagram_auth_freshness()

    assert payload["state"] == "advisory"
    assert payload["reason"] == "manual_checkpoint_required"
    assert "no refresh attempted" in cli.render_summary(payload)


def test_env_configured_cookie_file_takes_precedence_and_dedupes(tmp_path: Path, monkeypatch) -> None:
    env_cookie_file = tmp_path / "active" / "cookies.json"
    env_cookie_file.parent.mkdir(parents=True)
    env_cookie_file.write_text("{}", encoding="utf-8")
    default_cookie_file = tmp_path / "default-cookies.json"
    default_cookie_file.write_text("{}", encoding="utf-8")
    monkeypatch.setattr(cli, "ROOT", tmp_path)
    monkeypatch.setattr(cli, "DEFAULT_COOKIE_FILES", (default_cookie_file,))
    monkeypatch.setenv("SOCIAL_INSTAGRAM_COOKIES_FILE", str(env_cookie_file))
    monkeypatch.setenv("INSTAGRAM_COOKIES_FILE", str(env_cookie_file))

    statuses = cli._cookie_file_status(now=env_cookie_file.stat().st_mtime + 10)

    assert [item["path"] for item in statuses] == [str(env_cookie_file)]
    assert statuses[0]["present"] is True
    assert statuses[0]["age_seconds"] == 10


def test_missing_env_configured_cookie_file_does_not_fall_back(tmp_path: Path, monkeypatch) -> None:
    missing_cookie_file = tmp_path / "missing-cookies.json"
    default_cookie_file = tmp_path / "default-cookies.json"
    default_cookie_file.write_text("{}", encoding="utf-8")
    monkeypatch.setattr(cli, "ROOT", tmp_path)
    monkeypatch.setattr(cli, "BACKEND_ROOT", tmp_path)
    monkeypatch.setattr(cli, "DEFAULT_COOKIE_FILES", (default_cookie_file,))
    monkeypatch.setattr(cli, "_python_command", lambda: "python")
    monkeypatch.setattr(cli, "_max_age_seconds", lambda: 14 * 24 * 60 * 60)
    monkeypatch.setenv("SOCIAL_INSTAGRAM_COOKIES_FILE", str(missing_cookie_file))

    def fake_run(*_args, **_kwargs):
        return subprocess.CompletedProcess(
            ["python"],
            0,
            stdout='{"ok": true, "failure_reason": null}\n',
            stderr="",
        )

    monkeypatch.setattr(cli.subprocess, "run", fake_run)

    payload = cli.check_instagram_auth_freshness()

    assert payload["state"] == "advisory"
    assert payload["reason"] == "instagram_auth_cookie_file_missing"
    assert payload["missing_cookie_files"] == [str(missing_cookie_file)]


def test_main_only_fails_strict_mode_for_advisory(monkeypatch, capsys) -> None:
    monkeypatch.setattr(
        cli,
        "check_instagram_auth_freshness",
        lambda: {"state": "advisory", "ok": False, "reason": "manual_checkpoint_required"},
    )
    monkeypatch.delenv("WORKSPACE_PREFLIGHT_STRICT", raising=False)

    assert cli.main([]) == 0
    assert "ADVISORY" in capsys.readouterr().out

    monkeypatch.setenv("WORKSPACE_PREFLIGHT_STRICT", "1")
    assert cli.main([]) == 1

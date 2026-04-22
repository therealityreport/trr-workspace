from __future__ import annotations

import json

from scripts import workspace_runtime_reconcile as cli


def test_load_json_file_defaults_when_artifact_missing(tmp_path) -> None:
    artifact = cli.load_json_file(tmp_path / "missing.json")

    assert artifact["overall_state"] == "ok"
    assert artifact["render"]["verify_only"] is True
    assert artifact["decodo"]["verify_only"] is True


def test_compute_overall_state_prefers_blocked() -> None:
    artifact = cli.default_artifact()
    artifact["db"]["state"] = "blocked"
    artifact["db"]["reason"] = "remote_only_history"
    artifact["render"]["state"] = "advisory"
    artifact["render"]["reason"] = "render_contract_mismatch"

    result = cli.compute_overall_state(artifact)

    assert result["overall_state"] == "blocked"
    assert result["summary"] == "remote_only_history"


def test_compute_overall_state_keeps_advisory_non_blocking() -> None:
    artifact = cli.default_artifact()
    artifact["render"]["state"] = "advisory"
    artifact["render"]["reason"] = "render_contract_mismatch"

    result = cli.compute_overall_state(artifact)

    assert result["overall_state"] == "advisory"
    assert result["summary"] == "render_contract_mismatch"
    assert cli.render_preflight_summary(result) == (
        "[preflight] Runtime reconcile ADVISORY (render_contract_mismatch; see make status)"
    )


def test_compute_overall_state_renders_fixed_summary() -> None:
    artifact = cli.default_artifact()
    artifact["db"]["state"] = "fixed"
    artifact["db"]["applied_versions"] = ["20260422094500", "20260422111500"]
    artifact["modal"]["state"] = "fixed"

    result = cli.compute_overall_state(artifact)

    assert result["overall_state"] == "fixed"
    assert result["summary"] == "db=applied 2 migrations, modal=redeployed"
    assert cli.render_preflight_summary(result) == (
        "[preflight] Runtime reconcile FIXED (db=applied 2 migrations, modal=redeployed)"
    )


def test_main_writes_artifact_and_returns_nonzero_for_blocked(tmp_path, monkeypatch) -> None:
    artifact_path = tmp_path / "runtime-reconcile.json"
    blocked = cli.default_artifact()
    blocked["db"]["state"] = "blocked"
    blocked["db"]["reason"] = "remote_only_history"
    blocked = cli.compute_overall_state(blocked)

    monkeypatch.setattr(cli, "ARTIFACT_PATH", artifact_path)
    monkeypatch.setattr(cli, "run_runtime_reconcile", lambda: blocked)

    rc = cli.main(["--json"])

    assert rc == 1
    saved = json.loads(artifact_path.read_text(encoding="utf-8"))
    assert saved["overall_state"] == "blocked"
    assert saved["summary"] == "remote_only_history"

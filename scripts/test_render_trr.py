from __future__ import annotations

import os
import subprocess
from pathlib import Path

import pytest

from scripts import render_trr


ROOT = Path(__file__).resolve().parents[1]
SERVICE_ID = "srv-d6phk5vkijhs73fcsk7g"
PREVIOUS_DEPLOY_ID = "dpl_previous"
PREVIOUS_COMMIT = "a" * 40
CANDIDATE_COMMIT = "b" * 40


class FakeClient:
    def __init__(self) -> None:
        self.calls: list[tuple[str, str, object | None]] = []
        self.service = {
            "id": SERVICE_ID,
            "ownerId": "tea-d6pglsu3jp1c73cctvf0",
            "name": "trr-backend-api",
            "repo": "https://github.com/therealityreport/trr-backend.git",
            "branch": "main",
            "serviceDetails": {"url": "https://trr-backend-api.onrender.com"},
        }
        self.deploys = [
            {
                "deploy": {
                    "id": PREVIOUS_DEPLOY_ID,
                    "status": "live",
                    "commit": {"id": PREVIOUS_COMMIT},
                }
            }
        ]

    def get(self, path: str):
        self.calls.append(("GET", path, None))
        if path == f"/v1/services/{SERVICE_ID}":
            return self.service
        if path == f"/v1/services/{SERVICE_ID}/deploys?limit=20":
            return self.deploys
        if path == f"/v1/services/{SERVICE_ID}/deploys/{PREVIOUS_DEPLOY_ID}":
            return self.deploys[0]["deploy"]
        raise AssertionError(f"unexpected GET {path}")

    def post(self, path: str, payload: dict[str, str]):
        self.calls.append(("POST", path, payload))
        if path.endswith("/deploys"):
            return {
                "id": "dpl_candidate",
                "status": "created",
                "commit": {"id": payload["commitId"]},
            }
        if path.endswith("/rollback"):
            return {"id": "dpl_rollback", "status": "created"}
        raise AssertionError(f"unexpected POST {path}")


def _git_verify(commit: str) -> None:
    assert commit in {CANDIDATE_COMMIT, PREVIOUS_COMMIT}


def test_preflight_validates_full_target_and_previous_deployment_without_mutation() -> (
    None
):
    client = FakeClient()

    result = render_trr.preflight(
        client=client,
        target=render_trr.load_target(),
        service_id=SERVICE_ID,
        commit=CANDIDATE_COMMIT,
        git_verify=_git_verify,
    )

    assert result["ok"] is True
    assert result["service_id"] == SERVICE_ID
    assert result["candidate_commit"] == CANDIDATE_COMMIT
    assert result["previous_deploy_id"] == PREVIOUS_DEPLOY_ID
    assert result["previous_commit"] == PREVIOUS_COMMIT
    assert all(method == "GET" for method, _path, _body in client.calls)


def test_preflight_rejects_wrong_service_before_any_api_call() -> None:
    client = FakeClient()

    with pytest.raises(render_trr.RenderGuardError, match="service-id"):
        render_trr.preflight(
            client=client,
            target=render_trr.load_target(),
            service_id="srv_other",
            commit=CANDIDATE_COMMIT,
            git_verify=_git_verify,
        )

    assert client.calls == []


def test_deploy_requires_explicit_mutation_opt_in_and_previous_deploy_match() -> None:
    client = FakeClient()
    target = render_trr.load_target()

    with pytest.raises(
        render_trr.RenderGuardError, match="TRR_RENDER_ALLOW_MUTATION=1"
    ):
        render_trr.deploy(
            client=client,
            target=target,
            service_id=SERVICE_ID,
            commit=CANDIDATE_COMMIT,
            previous_deploy_id=PREVIOUS_DEPLOY_ID,
            environ={},
            git_verify=_git_verify,
        )
    assert all(method == "GET" for method, _path, _body in client.calls)

    client = FakeClient()
    result = render_trr.deploy(
        client=client,
        target=target,
        service_id=SERVICE_ID,
        commit=CANDIDATE_COMMIT,
        previous_deploy_id=PREVIOUS_DEPLOY_ID,
        environ={"TRR_RENDER_ALLOW_MUTATION": "1"},
        git_verify=_git_verify,
    )

    assert result["deploy_id"] == "dpl_candidate"
    assert client.calls[-1] == (
        "POST",
        f"/v1/services/{SERVICE_ID}/deploys",
        {"commitId": CANDIDATE_COMMIT, "clearCache": "do_not_clear"},
    )


def test_status_verifies_deploy_commit_and_never_posts() -> None:
    client = FakeClient()

    result = render_trr.status(
        client=client,
        target=render_trr.load_target(),
        service_id=SERVICE_ID,
        deploy_id=PREVIOUS_DEPLOY_ID,
        commit=PREVIOUS_COMMIT,
        git_verify=_git_verify,
    )

    assert result["deploy_id"] == PREVIOUS_DEPLOY_ID
    assert result["commit"] == PREVIOUS_COMMIT
    assert result["status"] == "live"
    assert all(method == "GET" for method, _path, _body in client.calls)


def test_status_rejects_unsafe_deploy_id_before_any_api_call() -> None:
    client = FakeClient()

    with pytest.raises(render_trr.RenderGuardError, match="deploy ID"):
        render_trr.status(
            client=client,
            target=render_trr.load_target(),
            service_id=SERVICE_ID,
            deploy_id="../other-service",
            commit=PREVIOUS_COMMIT,
            git_verify=_git_verify,
        )

    assert client.calls == []


def test_rollback_requires_two_explicit_opt_ins_and_validates_target_deploy() -> None:
    client = FakeClient()
    target = render_trr.load_target()

    with pytest.raises(
        render_trr.RenderGuardError, match="TRR_RENDER_ALLOW_ROLLBACK=1"
    ):
        render_trr.rollback(
            client=client,
            target=target,
            service_id=SERVICE_ID,
            deploy_id=PREVIOUS_DEPLOY_ID,
            commit=PREVIOUS_COMMIT,
            environ={"TRR_RENDER_ALLOW_MUTATION": "1"},
            git_verify=_git_verify,
        )

    client = FakeClient()
    result = render_trr.rollback(
        client=client,
        target=target,
        service_id=SERVICE_ID,
        deploy_id=PREVIOUS_DEPLOY_ID,
        commit=PREVIOUS_COMMIT,
        environ={
            "TRR_RENDER_ALLOW_MUTATION": "1",
            "TRR_RENDER_ALLOW_ROLLBACK": "1",
        },
        git_verify=_git_verify,
    )

    assert result["rollback_deploy_id"] == "dpl_rollback"
    assert client.calls[-1] == (
        "POST",
        f"/v1/services/{SERVICE_ID}/rollback",
        {"deployId": PREVIOUS_DEPLOY_ID},
    )


def test_rollback_rejects_unsuccessful_deployment_without_posting() -> None:
    client = FakeClient()
    client.deploys[0]["deploy"]["status"] = "build_failed"

    with pytest.raises(render_trr.RenderGuardError, match="previously successful"):
        render_trr.rollback(
            client=client,
            target=render_trr.load_target(),
            service_id=SERVICE_ID,
            deploy_id=PREVIOUS_DEPLOY_ID,
            commit=PREVIOUS_COMMIT,
            environ={
                "TRR_RENDER_ALLOW_MUTATION": "1",
                "TRR_RENDER_ALLOW_ROLLBACK": "1",
            },
            git_verify=_git_verify,
        )

    assert all(method == "GET" for method, _path, _body in client.calls)


def test_shell_wrapper_exposes_only_guarded_commands() -> None:
    completed = subprocess.run(
        ["bash", str(ROOT / "scripts" / "render-trr.sh"), "--help"],
        cwd=ROOT,
        env=os.environ.copy(),
        capture_output=True,
        text=True,
        check=False,
    )

    assert completed.returncode == 0
    for command in ("preflight", "deploy", "status", "rollback"):
        assert command in completed.stdout

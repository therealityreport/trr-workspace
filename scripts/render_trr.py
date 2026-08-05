#!/usr/bin/env python3
"""Fail-closed Render preflight, deploy, status, and rollback guard for TRR."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any, Callable, Mapping, Protocol


ROOT = Path(__file__).resolve().parents[1]
BACKEND_ROOT = ROOT / "TRR-Backend"
DEFAULT_MANIFEST = ROOT / "docs" / "workspace" / "deployment-targets.json"
API_BASE_URL = "https://api.render.com"

# Literal pins are intentionally duplicated from the checked manifest and
# validated by scripts/deployment_targets.py before any provider request.
EXPECTED_OWNER_ID = "tea-d6pglsu3jp1c73cctvf0"
EXPECTED_SERVICE_ID = "srv-d6phk5vkijhs73fcsk7g"
EXPECTED_SERVICE_NAME = "trr-backend-api"
EXPECTED_REPO = "therealityreport/trr-backend"
EXPECTED_BRANCH = "main"
EXPECTED_DIRECT_URL = "https://trr-backend-api.onrender.com"
EXPECTED_CREDENTIAL_ENV = "TRR_RENDER_API_KEY"
COMMIT_PATTERN = re.compile(r"^[0-9a-f]{40}$")
DEPLOY_ID_PATTERN = re.compile(r"^[A-Za-z0-9_-]+$")


class RenderGuardError(RuntimeError):
    pass


class RenderClient(Protocol):
    def get(self, path: str) -> Any: ...

    def post(self, path: str, payload: dict[str, str]) -> Any: ...


class RenderApiClient:
    def __init__(self, api_key: str) -> None:
        if not api_key:
            raise RenderGuardError(
                f"{EXPECTED_CREDENTIAL_ENV} is required for Render API access"
            )
        self._api_key = api_key

    def _request(
        self, method: str, path: str, payload: dict[str, str] | None = None
    ) -> Any:
        body = json.dumps(payload).encode("utf-8") if payload is not None else None
        request = urllib.request.Request(
            f"{API_BASE_URL}{path}",
            data=body,
            method=method,
            headers={
                "Accept": "application/json",
                "Authorization": f"Bearer {self._api_key}",
                "Content-Type": "application/json",
                "User-Agent": "TRR render deployment guard/1.0",
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                raw = response.read()
        except urllib.error.HTTPError as exc:
            raise RenderGuardError(
                f"Render API {method} {path} failed with HTTP {exc.code}"
            ) from exc
        except urllib.error.URLError as exc:
            raise RenderGuardError(
                f"Render API {method} {path} failed: {exc.reason}"
            ) from exc
        try:
            return json.loads(raw.decode("utf-8") or "{}")
        except json.JSONDecodeError as exc:
            raise RenderGuardError(
                f"Render API {method} {path} returned invalid JSON"
            ) from exc

    def get(self, path: str) -> Any:
        return self._request("GET", path)

    def post(self, path: str, payload: dict[str, str]) -> Any:
        return self._request("POST", path, payload)


def load_target(path: Path = DEFAULT_MANIFEST) -> dict[str, str]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise RenderGuardError(
            f"unable to read deployment target manifest: {exc}"
        ) from exc
    target = payload.get("render") if isinstance(payload, dict) else None
    if not isinstance(target, dict):
        raise RenderGuardError("deployment target manifest is missing render target")
    expected = {
        "owner_id": EXPECTED_OWNER_ID,
        "service_id": EXPECTED_SERVICE_ID,
        "service_name": EXPECTED_SERVICE_NAME,
        "repo": EXPECTED_REPO,
        "branch": EXPECTED_BRANCH,
        "direct_url": EXPECTED_DIRECT_URL,
        "credential_env": EXPECTED_CREDENTIAL_ENV,
    }
    normalized = {key: str(target.get(key) or "") for key in expected}
    if normalized != expected:
        raise RenderGuardError(
            "Render manifest target does not match the immutable TRR target tuple"
        )
    return normalized


def _normalize_repo(value: Any) -> str:
    repo = str(value or "").strip().removesuffix(".git").rstrip("/")
    for prefix in ("https://github.com/", "http://github.com/", "git@github.com:"):
        if repo.startswith(prefix):
            repo = repo[len(prefix) :]
            break
    return repo


def _unwrap(value: Any, key: str) -> dict[str, Any]:
    if isinstance(value, dict) and isinstance(value.get(key), dict):
        return dict(value[key])
    if isinstance(value, dict):
        return dict(value)
    raise RenderGuardError(f"Render API returned an invalid {key} object")


def _deploy_rows(value: Any) -> list[dict[str, Any]]:
    if not isinstance(value, list):
        raise RenderGuardError("Render deploy list response is not an array")
    return [_unwrap(row, "deploy") for row in value]


def _deploy_commit(deploy: Mapping[str, Any]) -> str:
    commit = deploy.get("commit")
    if isinstance(commit, dict):
        return str(commit.get("id") or commit.get("commitId") or "").strip().lower()
    return str(deploy.get("commitId") or commit or "").strip().lower()


def _validate_commit(commit: str, label: str) -> str:
    normalized = str(commit or "").strip().lower()
    if not COMMIT_PATTERN.fullmatch(normalized):
        raise RenderGuardError(f"{label} must be a full 40-character lowercase Git SHA")
    return normalized


def _validate_deploy_id(deploy_id: str, label: str) -> str:
    normalized = str(deploy_id or "").strip()
    if not DEPLOY_ID_PATTERN.fullmatch(normalized):
        raise RenderGuardError(f"{label} must be a non-empty Render deployment ID")
    return normalized


def verify_local_commit(commit: str) -> None:
    completed = subprocess.run(
        ["git", "-C", str(BACKEND_ROOT), "cat-file", "-e", f"{commit}^{{commit}}"],
        capture_output=True,
        text=True,
        check=False,
    )
    if completed.returncode != 0:
        raise RenderGuardError(f"commit is not present in TRR-Backend: {commit}")


def _guard_service_id(target: Mapping[str, str], service_id: str) -> None:
    if service_id != target["service_id"]:
        raise RenderGuardError(
            f"Render service-id mismatch: got {service_id or '<empty>'}; expected {target['service_id']}"
        )


def _verify_service(
    client: RenderClient, target: Mapping[str, str], service_id: str
) -> dict[str, Any]:
    _guard_service_id(target, service_id)
    service = _unwrap(client.get(f"/v1/services/{service_id}"), "service")
    service_details = service.get("serviceDetails")
    if not isinstance(service_details, dict):
        raise RenderGuardError("Render service response is missing serviceDetails")
    observed = {
        "service_id": str(service.get("id") or ""),
        "owner_id": str(service.get("ownerId") or service.get("owner_id") or ""),
        "service_name": str(service.get("name") or ""),
        "repo": _normalize_repo(service.get("repo")),
        "branch": str(service.get("branch") or ""),
        "direct_url": str(service_details.get("url") or "").rstrip("/"),
    }
    expected = {key: target[key] for key in observed}
    if observed != expected:
        mismatches = [key for key in expected if observed[key] != expected[key]]
        raise RenderGuardError(
            f"Render service target mismatch: {', '.join(mismatches)}"
        )
    return service


GitVerifier = Callable[[str], None]


def preflight(
    *,
    client: RenderClient,
    target: Mapping[str, str],
    service_id: str,
    commit: str,
    git_verify: GitVerifier = verify_local_commit,
) -> dict[str, Any]:
    _guard_service_id(target, service_id)
    candidate = _validate_commit(commit, "candidate commit")
    git_verify(candidate)
    _verify_service(client, target, service_id)
    deploys = _deploy_rows(client.get(f"/v1/services/{service_id}/deploys?limit=20"))
    previous = next(
        (row for row in deploys if str(row.get("status") or "").lower() == "live"), None
    )
    if previous is None:
        raise RenderGuardError(
            "Render preflight could not identify the current live deployment"
        )
    previous_deploy_id = str(previous.get("id") or "").strip()
    previous_commit = _validate_commit(
        _deploy_commit(previous), "previous deployment commit"
    )
    previous_deploy_id = _validate_deploy_id(
        previous_deploy_id, "current live deployment ID"
    )
    git_verify(previous_commit)
    return {
        "ok": True,
        "owner_id": target["owner_id"],
        "service_id": service_id,
        "service_name": target["service_name"],
        "repo": target["repo"],
        "branch": target["branch"],
        "direct_url": target["direct_url"],
        "candidate_commit": candidate,
        "previous_deploy_id": previous_deploy_id,
        "previous_commit": previous_commit,
    }


def _require_mutation(environ: Mapping[str, str]) -> None:
    if environ.get("TRR_RENDER_ALLOW_MUTATION") != "1":
        raise RenderGuardError(
            "Render mutation blocked: set TRR_RENDER_ALLOW_MUTATION=1 after current-chat approval"
        )


def deploy(
    *,
    client: RenderClient,
    target: Mapping[str, str],
    service_id: str,
    commit: str,
    previous_deploy_id: str,
    environ: Mapping[str, str] = os.environ,
    git_verify: GitVerifier = verify_local_commit,
) -> dict[str, Any]:
    proof = preflight(
        client=client,
        target=target,
        service_id=service_id,
        commit=commit,
        git_verify=git_verify,
    )
    if previous_deploy_id != proof["previous_deploy_id"]:
        raise RenderGuardError(
            "Render previous deployment changed: "
            f"got {previous_deploy_id or '<empty>'}; live is {proof['previous_deploy_id']}"
        )
    _require_mutation(environ)
    response = _unwrap(
        client.post(
            f"/v1/services/{service_id}/deploys",
            {"commitId": proof["candidate_commit"], "clearCache": "do_not_clear"},
        ),
        "deploy",
    )
    deploy_id = str(response.get("id") or "").strip()
    if not deploy_id:
        raise RenderGuardError("Render deploy response did not include a deployment ID")
    return {
        **proof,
        "deploy_id": deploy_id,
        "deploy_status": str(response.get("status") or "created"),
    }


def status(
    *,
    client: RenderClient,
    target: Mapping[str, str],
    service_id: str,
    deploy_id: str,
    commit: str,
    git_verify: GitVerifier = verify_local_commit,
) -> dict[str, Any]:
    _guard_service_id(target, service_id)
    deploy_id = _validate_deploy_id(deploy_id, "deploy ID")
    expected_commit = _validate_commit(commit, "deploy commit")
    git_verify(expected_commit)
    _verify_service(client, target, service_id)
    deploy_record = _unwrap(
        client.get(f"/v1/services/{service_id}/deploys/{deploy_id}"), "deploy"
    )
    observed_id = str(deploy_record.get("id") or "").strip()
    observed_commit = _validate_commit(
        _deploy_commit(deploy_record), "observed deploy commit"
    )
    if observed_id != deploy_id:
        raise RenderGuardError(
            f"Render deploy ID mismatch: got {observed_id or '<empty>'}; expected {deploy_id}"
        )
    if observed_commit != expected_commit:
        raise RenderGuardError(
            f"Render deploy commit mismatch: got {observed_commit}; expected {expected_commit}"
        )
    return {
        "ok": True,
        "service_id": service_id,
        "deploy_id": deploy_id,
        "commit": observed_commit,
        "status": str(deploy_record.get("status") or "unknown"),
        "direct_url": target["direct_url"],
    }


def rollback(
    *,
    client: RenderClient,
    target: Mapping[str, str],
    service_id: str,
    deploy_id: str,
    commit: str,
    environ: Mapping[str, str] = os.environ,
    git_verify: GitVerifier = verify_local_commit,
) -> dict[str, Any]:
    proof = status(
        client=client,
        target=target,
        service_id=service_id,
        deploy_id=deploy_id,
        commit=commit,
        git_verify=git_verify,
    )
    if proof["status"] not in {"live", "deactivated"}:
        raise RenderGuardError(
            "Render rollback target must be a previously successful deployment"
        )
    _require_mutation(environ)
    if environ.get("TRR_RENDER_ALLOW_ROLLBACK") != "1":
        raise RenderGuardError(
            "Render rollback blocked: set TRR_RENDER_ALLOW_ROLLBACK=1 after rollback approval"
        )
    response = _unwrap(
        client.post(f"/v1/services/{service_id}/rollback", {"deployId": deploy_id}),
        "deploy",
    )
    rollback_deploy_id = str(response.get("id") or "").strip()
    if not rollback_deploy_id:
        raise RenderGuardError(
            "Render rollback response did not include a deployment ID"
        )
    return {
        **proof,
        "rollback_deploy_id": rollback_deploy_id,
        "rollback_status": str(response.get("status") or "created"),
    }


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    subparsers = parser.add_subparsers(dest="command", required=True)

    preflight_parser = subparsers.add_parser("preflight")
    preflight_parser.add_argument("--service-id", required=True)
    preflight_parser.add_argument("--commit", required=True)

    deploy_parser = subparsers.add_parser("deploy")
    deploy_parser.add_argument("--service-id", required=True)
    deploy_parser.add_argument("--commit", required=True)
    deploy_parser.add_argument("--previous-deploy-id", required=True)

    status_parser = subparsers.add_parser("status")
    status_parser.add_argument("--service-id", required=True)
    status_parser.add_argument("--deploy-id", required=True)
    status_parser.add_argument("--commit", required=True)

    rollback_parser = subparsers.add_parser("rollback")
    rollback_parser.add_argument("--service-id", required=True)
    rollback_parser.add_argument("--deploy-id", required=True)
    rollback_parser.add_argument("--commit", required=True)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        target = load_target(args.manifest)
        api_key = str(os.getenv(target["credential_env"]) or "")
        client = RenderApiClient(api_key)
        if args.command == "preflight":
            result = preflight(
                client=client,
                target=target,
                service_id=args.service_id,
                commit=args.commit,
            )
        elif args.command == "deploy":
            result = deploy(
                client=client,
                target=target,
                service_id=args.service_id,
                commit=args.commit,
                previous_deploy_id=args.previous_deploy_id,
            )
        elif args.command == "status":
            result = status(
                client=client,
                target=target,
                service_id=args.service_id,
                deploy_id=args.deploy_id,
                commit=args.commit,
            )
        else:
            result = rollback(
                client=client,
                target=target,
                service_id=args.service_id,
                deploy_id=args.deploy_id,
                commit=args.commit,
            )
    except RenderGuardError as exc:
        print(f"render-trr: ERROR: {exc}", file=sys.stderr)
        return 1
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

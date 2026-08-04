from __future__ import annotations

import importlib.util
import hashlib
import json
import subprocess
import sys
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "scripts" / "architecture" / "check-release-manifests.py"
REQUIRED_LOCAL_PACKET_IDS = (
    "local-foundation-runtime-guards",
    "local-identity-canonical-routes",
    "local-covered-shows",
    "local-networks-streaming",
    "local-recent-people-external-ids",
    "local-person-media",
    "local-season-survey-roles",
    "local-social-freshness",
    "local-show-presentation-extractions",
)


def load_module():
    spec = importlib.util.spec_from_file_location("check_release_manifests_under_test", SCRIPT)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def evidence() -> dict:
    return {
        "schema_version": 1,
        "evidence_id": "ev.packet-1.quick",
        "packet_id": "packet-1",
        "gate": "gate-2",
        "truth_scope": "local",
        "command": {
            "argv": ["python3", "-m", "pytest"],
            "cwd": "/workspace",
            "mutating": False,
            "environment_variable_names": [],
        },
        "started_at": "2026-07-16T00:00:00Z",
        "finished_at": "2026-07-16T00:00:01Z",
        "exit_code": 0,
        "expected_result": "Tests pass",
        "result": "pass",
        "output": {"sha256": "a" * 64, "size_bytes": 12, "stored_path": None},
        "artifacts": [],
        "target_observations": [],
        "approval": {
            "required": False,
            "approval_id": None,
            "status": "not_required",
            "current_chat": False,
        },
        "redaction": {
            "status": "verified_clean",
            "scanner": "architecture release manifest check",
            "safe_to_store": True,
            "credential_values_included": False,
            "environment_values_included": False,
        },
    }


def dirty_counts(*, tracked_modified: int = 1, untracked: int = 0) -> dict:
    return {
        "tracked_modified": tracked_modified,
        "tracked_added": 0,
        "tracked_deleted": 0,
        "tracked_renamed": 0,
        "tracked_copied": 0,
        "unmerged": 0,
        "untracked": untracked,
        "total": tracked_modified + untracked,
    }


def local_revision(*owned_paths: str) -> dict:
    return {
        "revision_type": "local_dirty_checkpoint",
        "base_sha": "a" * 40,
        "candidate_sha": None,
        "owned_paths": list(owned_paths),
        "owned_path_manifest_sha256": "c" * 64,
        "binary_tracked_diff_sha256": "d" * 64,
        "dirty_counts": dirty_counts(tracked_modified=1 if owned_paths else 0),
        "candidate_commit_required_before_gate_4": True,
    }


def committed_revision(*owned_paths: str) -> dict:
    return {
        "revision_type": "committed_candidate",
        "base_sha": "a" * 40,
        "candidate_sha": "b" * 40,
        "owned_paths": list(owned_paths),
        "owned_path_manifest_sha256": "c" * 64,
        "binary_tracked_diff_sha256": "d" * 64,
        "dirty_counts": dirty_counts(tracked_modified=0),
        "candidate_commit_required_before_gate_4": False,
    }


def packet() -> dict:
    compatibility = [
        {
            "app_revision": app,
            "backend_revision": backend,
            "status": "pass",
            "evidence_ids": ["ev.packet-1.quick"],
        }
        for app, backend in (("N", "N"), ("N", "N+1"), ("N+1", "N"), ("N+1", "N+1"))
    ]
    return {
        "schema_version": 2,
        "packet_id": "packet-1",
        "capability": "Example capability",
        "created_at": "2026-07-16T00:00:00Z",
        "updated_at": "2026-07-16T00:00:01Z",
        "state": "in_progress",
        "truth_scope": "local",
        "repositories": {
            "workspace": local_revision("example"),
            "app": local_revision(),
            "backend": local_revision(),
        },
        "owned_paths": [
            {
                "repository": "workspace",
                "path": "example",
                "task_id": 3,
                "reviewers": ["reviewer"],
            }
        ],
        "contracts": {
            "openapi_sha256": None,
            "generated_types_sha256": None,
            "compatibility_matrix": compatibility,
        },
        "migrations": {
            "expected_pending": [],
            "backfill": {
                "required": False,
                "idempotent": True,
                "resumable": True,
                "batch_size": None,
                "validation": {
                    "row_counts": False,
                    "checksums": False,
                    "evidence_ids": [],
                },
            },
            "rls_grants": {"expected_change": False, "evidence_ids": []},
        },
        "direct_sql_delta": {
            "status": "not_applicable",
            "before": None,
            "after": None,
            "delta": 0,
            "evidence_ids": [],
        },
        "targets": {
            "preview": {
                "status": "pending_gate_4",
                "database_url_env": "TRR_PREVIEW_DATABASE_URL",
                "project_ref_env": "TRR_PREVIEW_SUPABASE_PROJECT_REF",
            },
            "production": {
                "status": "pending_gate_4",
                "database_url_env": "TRR_PRODUCTION_DATABASE_URL",
                "project_ref": "vwxfvzutyufrkhfgoeaa",
            },
        },
        "affected": {key: [] for key in ("routes", "jobs", "schedules", "data_sets", "aliases")},
        "validation": {
            "quick": {"status": "pass", "evidence_ids": ["ev.packet-1.quick"]},
            "full": {"status": "pending", "evidence_ids": []},
            "app_build": {
                "status": "pending_gate_4",
                "current_chat_approval_id": None,
                "evidence_ids": [],
            },
            "browser": {"status": "pending_gate_4", "evidence_ids": []},
            "evidence_ids": ["ev.packet-1.quick"],
        },
        "deployments": {
            "render": {
                "status": "pending_gate_4",
                "service_id": "srv-example",
                "candidate_sha": None,
                "deployment_id": None,
                "previous_deployment_id": None,
                "direct_url": "https://api.example.invalid",
                "evidence_ids": [],
            },
            "modal": {
                "status": "pending_gate_4",
                "profile": "profile",
                "workspace": "workspace",
                "app_name": "app",
                "app_ref": "module.app",
                "candidate_sha": None,
                "affected_functions": [],
                "evidence_ids": [],
            },
            "vercel": {
                "status": "pending_gate_4",
                "team_id": "team-example",
                "project_id": "project-example",
                "candidate_sha": None,
                "deployment_id": None,
                "previous_deployment_id": None,
                "aliases": ["https://app.example.invalid"],
                "evidence_ids": [],
            },
        },
        "rollback": {
            "backend_commands": [["render", "rollback"]],
            "app_commands": [["vercel", "rollback"]],
            "data_recovery": "No data mutation",
            "evidence_ids": [],
        },
        "observation": {
            "baselines": [
                {
                    "name": "errors",
                    "value": 0,
                    "unit": "count",
                    "window": "30m",
                    "evidence_ids": [],
                }
            ],
            "abort_thresholds": [
                {
                    "name": "errors",
                    "value": 1,
                    "unit": "count",
                    "window": "30m",
                    "evidence_ids": [],
                }
            ],
            "active_canary_minutes": 30,
            "passive_monitoring_hours": 24,
            "gate5_minimum_days": 7,
            "status": "not_started",
        },
        "review": {
            "verdict": "accepted_local",
            "reviewers": ["reviewer"],
            "basis": "Focused local validation",
            "evidence_ids": ["ev.packet-1.quick"],
        },
        "gate_4": {
            key: "pending_gate_4"
            for key in (
                "candidate_commits",
                "preview",
                "production",
                "app_build",
                "browser",
                "deployments",
            )
        },
        "approvals": [],
    }


def program_complete_packet() -> dict:
    packet_data = packet()
    evidence_id = "ev.packet-1.quick"
    packet_data["created_at"] = "2026-07-01T00:00:00Z"
    packet_data["updated_at"] = "2026-07-16T00:00:02Z"
    packet_data["state"] = "program_complete"
    packet_data["truth_scope"] = "production"
    packet_data["repositories"] = {
        "workspace": committed_revision("example"),
        "app": committed_revision(),
        "backend": committed_revision(),
    }
    for target in packet_data["targets"].values():
        target["status"] = "verified"
    packet_data["validation"]["full"] = {
        "status": "pass",
        "evidence_ids": [evidence_id],
    }
    packet_data["validation"]["app_build"] = {
        "status": "passed",
        "current_chat_approval_id": "approval-build",
        "evidence_ids": [evidence_id],
    }
    packet_data["validation"]["browser"] = {
        "status": "pass",
        "evidence_ids": [evidence_id],
    }
    for deployment in packet_data["deployments"].values():
        deployment["status"] = "verified"
        deployment["candidate_sha"] = "b" * 40
        deployment["evidence_ids"] = [evidence_id]
    packet_data["gate_4"] = {
        key: "verified"
        for key in (
            "candidate_commits",
            "preview",
            "production",
            "app_build",
            "browser",
            "deployments",
        )
    }
    packet_data["observation"].update(
        {
            "started_at": "2026-07-08T00:00:00Z",
            "ends_at": "2026-07-15T00:00:00Z",
            "status": "passed",
        }
    )
    for metric in [
        *packet_data["observation"]["baselines"],
        *packet_data["observation"]["abort_thresholds"],
    ]:
        metric["evidence_ids"] = [evidence_id]
    packet_data["approvals"] = [
        {
            "approval_id": "approval-build",
            "kind": "full_app_build",
            "status": "approved",
            "scope": "Build the app for packet-1",
            "approved_by": "user",
            "approved_at": "2026-07-15T00:00:00Z",
        }
    ]
    return packet_data


def parked_manifest() -> dict:
    return {
        "schema_version": 1,
        "manifest_id": "parked-unaccepted-local-work",
        "truth_scope": "local",
        "captured_at": "2026-07-16T00:00:01Z",
        "repositories": {
            name: {"base_sha": "a" * 40} for name in ("workspace", "app", "backend")
        },
        "entries": [],
        "excluded_non_architecture_paths": [],
        "promotion_policy": "Parked entries cannot promote or be silently absorbed.",
    }


def write_workspace(tmp_path: Path, packet_data: dict, evidence_data: dict) -> tuple[Path, Path]:
    schema_dir = tmp_path / "docs" / "workspace"
    schema_dir.mkdir(parents=True)
    for name in ("release-packet.schema.json", "architecture-evidence.schema.json"):
        (schema_dir / name).write_text((ROOT / "docs" / "workspace" / name).read_text())
    packet_path = tmp_path / "packet.json"
    evidence_path = tmp_path / "evidence.json"
    packet_path.write_text(json.dumps(packet_data))
    evidence_path.write_text(json.dumps(evidence_data))
    return packet_path, evidence_path


def write_r0_workspace(tmp_path: Path) -> tuple[list[Path], list[Path], Path]:
    schema_dir = tmp_path / "docs" / "workspace"
    packet_dir = schema_dir / "release-packets"
    evidence_dir = schema_dir / "architecture-evidence"
    packet_dir.mkdir(parents=True)
    evidence_dir.mkdir(parents=True)
    for name in ("release-packet.schema.json", "architecture-evidence.schema.json"):
        (schema_dir / name).write_text(
            (ROOT / "docs" / "workspace" / name).read_text(encoding="utf-8"),
            encoding="utf-8",
        )
    packet_paths: list[Path] = []
    evidence_paths: list[Path] = []
    for packet_id in REQUIRED_LOCAL_PACKET_IDS:
        packet_data = packet()
        evidence_data = evidence()
        evidence_id = f"ev.{packet_id}.quick"
        packet_data["packet_id"] = packet_id
        packet_data["state"] = "implementation_complete_parked"
        packet_data["repositories"]["workspace"]["owned_paths"] = [packet_id]
        packet_data["owned_paths"][0]["path"] = packet_id
        packet_data["validation"]["quick"]["evidence_ids"] = [evidence_id]
        packet_data["validation"]["evidence_ids"] = [evidence_id]
        packet_data["review"]["evidence_ids"] = [evidence_id]
        for case in packet_data["contracts"]["compatibility_matrix"]:
            case["evidence_ids"] = [evidence_id]
        evidence_data["packet_id"] = packet_id
        evidence_data["evidence_id"] = evidence_id
        packet_path = packet_dir / f"{packet_id}.json"
        evidence_path = evidence_dir / f"{packet_id}.quick.json"
        packet_path.write_text(json.dumps(packet_data), encoding="utf-8")
        evidence_path.write_text(json.dumps(evidence_data), encoding="utf-8")
        packet_paths.append(packet_path)
        evidence_paths.append(evidence_path)
    parked_path = schema_dir / "parked-unaccepted-local-work.json"
    parked_path.write_text(json.dumps(parked_manifest()), encoding="utf-8")
    return packet_paths, evidence_paths, parked_path


def write_live_r0_workspace(tmp_path: Path) -> tuple[dict[str, Path], dict[str, str]]:
    module = load_module()
    schema_dir = tmp_path / "docs" / "workspace"
    packet_dir = schema_dir / "release-packets"
    evidence_dir = schema_dir / "architecture-evidence"
    packet_dir.mkdir(parents=True)
    evidence_dir.mkdir(parents=True)
    for name in ("release-packet.schema.json", "architecture-evidence.schema.json"):
        (schema_dir / name).write_text(
            (ROOT / "docs" / "workspace" / name).read_text(encoding="utf-8"),
            encoding="utf-8",
        )

    git(tmp_path, "init", "-q")
    git(tmp_path, "config", "user.email", "test@example.invalid")
    git(tmp_path, "config", "user.name", "Test User")
    (tmp_path / "seed.txt").write_text("seed\n", encoding="utf-8")
    git(tmp_path, "add", "seed.txt")
    git(tmp_path, "commit", "-qm", "seed")
    (tmp_path / ".gitignore").write_text("TRR-APP/\nTRR-Backend/\n", encoding="utf-8")
    owned_paths = {
        packet_id: f"owned/{packet_id}.txt" for packet_id in REQUIRED_LOCAL_PACKET_IDS
    }
    for relative_path in owned_paths.values():
        path = tmp_path / relative_path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("base\n", encoding="utf-8")
    git(tmp_path, "add", ".gitignore", "docs", "owned")
    git(tmp_path, "commit", "-qm", "base")

    repository_roots = {
        "workspace": tmp_path,
        "app": tmp_path / "TRR-APP",
        "backend": tmp_path / "TRR-Backend",
    }
    for repository in ("app", "backend"):
        repo = repository_roots[repository]
        repo.mkdir()
        git(repo, "init", "-q")
        git(repo, "config", "user.email", "test@example.invalid")
        git(repo, "config", "user.name", "Test User")
        (repo / "seed.txt").write_text("seed\n", encoding="utf-8")
        git(repo, "add", "seed.txt")
        git(repo, "commit", "-qm", "base")
    base_shas = {
        repository: git(repo, "rev-parse", "HEAD")
        for repository, repo in repository_roots.items()
    }
    for relative_path in owned_paths.values():
        (tmp_path / relative_path).write_text("local checkpoint\n", encoding="utf-8")

    packet_paths: dict[str, Path] = {}
    for packet_id, relative_path in owned_paths.items():
        packet_data = packet()
        evidence_data = evidence()
        evidence_id = f"ev.{packet_id}.quick"
        packet_data["packet_id"] = packet_id
        packet_data["state"] = "implementation_complete_parked"
        packet_data["repositories"] = {
            "workspace": module.capture_local_dirty_checkpoint(
                tmp_path,
                base_shas["workspace"],
                [relative_path],
            ),
            "app": module.capture_local_dirty_checkpoint(
                repository_roots["app"],
                base_shas["app"],
                [],
            ),
            "backend": module.capture_local_dirty_checkpoint(
                repository_roots["backend"],
                base_shas["backend"],
                [],
            ),
        }
        packet_data["owned_paths"][0]["path"] = relative_path
        packet_data["validation"]["quick"]["evidence_ids"] = [evidence_id]
        packet_data["validation"]["evidence_ids"] = [evidence_id]
        packet_data["review"]["evidence_ids"] = [evidence_id]
        for case in packet_data["contracts"]["compatibility_matrix"]:
            case["evidence_ids"] = [evidence_id]
        evidence_data["packet_id"] = packet_id
        evidence_data["evidence_id"] = evidence_id
        packet_path = packet_dir / f"{packet_id}.json"
        packet_path.write_text(json.dumps(packet_data), encoding="utf-8")
        (evidence_dir / f"{packet_id}.quick.json").write_text(
            json.dumps(evidence_data),
            encoding="utf-8",
        )
        packet_paths[packet_id] = packet_path

    parked = parked_manifest()
    parked["repositories"] = {
        repository: {"base_sha": base_sha}
        for repository, base_sha in base_shas.items()
    }
    (schema_dir / "parked-unaccepted-local-work.json").write_text(
        json.dumps(parked),
        encoding="utf-8",
    )
    return packet_paths, owned_paths


def git(repo: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(repo), *args],
        check=True,
        stdout=subprocess.PIPE,
        text=True,
    )
    return result.stdout.strip()


def run_checker(root: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--root", str(root), *args],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )


def write_promotable_packet(
    tmp_path: Path,
    *,
    include_untracked_owned_path: bool = False,
) -> tuple[Path, str]:
    module = load_module()
    git(tmp_path, "init", "-q")
    git(tmp_path, "config", "user.email", "test@example.invalid")
    git(tmp_path, "config", "user.name", "Test User")
    (tmp_path / "seed.txt").write_text("seed\n", encoding="utf-8")
    git(tmp_path, "add", "seed.txt")
    git(tmp_path, "commit", "-qm", "seed")
    (tmp_path / "tracked.txt").write_text("original\n", encoding="utf-8")
    git(tmp_path, "add", "tracked.txt")
    git(tmp_path, "commit", "-qm", "base")
    base_sha = git(tmp_path, "rev-parse", "HEAD")
    (tmp_path / "tracked.txt").write_text("candidate\n", encoding="utf-8")
    owned_paths = ["tracked.txt"]
    if include_untracked_owned_path:
        (tmp_path / "untracked.txt").write_text("new candidate file\n", encoding="utf-8")
        owned_paths.append("untracked.txt")

    packet_data = packet()
    packet_data["repositories"]["workspace"] = module.capture_local_dirty_checkpoint(
        tmp_path,
        base_sha,
        owned_paths,
    )
    packet_data["owned_paths"] = [
        {
            "repository": "workspace",
            "path": relative_path,
            "task_id": 3,
            "reviewers": ["reviewer"],
        }
        for relative_path in owned_paths
    ]
    packet_path, _ = write_workspace(tmp_path, packet_data, evidence())
    git(tmp_path, "add", *owned_paths)
    git(tmp_path, "commit", "-qm", "candidate")
    return packet_path, git(tmp_path, "rev-parse", "HEAD")


def commit_unrelated_change(repo: Path) -> None:
    (repo / "unrelated.txt").write_text("unrelated\n", encoding="utf-8")
    git(repo, "add", "unrelated.txt")
    git(repo, "commit", "-qm", "unrelated")


def test_valid_packet_and_evidence_pass(tmp_path: Path) -> None:
    module = load_module()
    packet_path, evidence_path = write_workspace(tmp_path, packet(), evidence())

    counts = module.validate_manifests(tmp_path, [packet_path], [evidence_path], require_packets=True)

    assert counts == (1, 1)


def test_cli_candidate_promotion_is_a_dry_run_by_default(tmp_path: Path) -> None:
    packet_path, candidate_sha = write_promotable_packet(tmp_path)
    before = packet_path.read_bytes()

    result = run_checker(
        tmp_path,
        "--packet",
        packet_path.relative_to(tmp_path).as_posix(),
        "--promote-packet",
        "packet-1",
        "--repository",
        "workspace",
        "--candidate-sha",
        candidate_sha,
    )

    assert result.returncode == 0, result.stdout + result.stderr
    assert "DRY-RUN" in result.stdout
    assert packet_path.read_bytes() == before


def test_cli_candidate_promotion_write_mutates_only_named_revision_and_updated_at(
    tmp_path: Path,
) -> None:
    packet_path, candidate_sha = write_promotable_packet(tmp_path)
    before = json.loads(packet_path.read_text(encoding="utf-8"))

    result = run_checker(
        tmp_path,
        "--packet",
        packet_path.relative_to(tmp_path).as_posix(),
        "--promote-packet",
        "packet-1",
        "--repository",
        "workspace",
        "--candidate-sha",
        candidate_sha,
        "--write",
    )

    assert result.returncode == 0, result.stdout + result.stderr
    assert "UPDATED" in result.stdout
    after = json.loads(packet_path.read_text(encoding="utf-8"))
    assert after["updated_at"] != before["updated_at"]
    assert after["repositories"]["workspace"]["revision_type"] == "committed_candidate"
    assert after["repositories"]["workspace"]["candidate_sha"] == candidate_sha
    assert after == {
        **before,
        "updated_at": after["updated_at"],
        "repositories": {
            **before["repositories"],
            "workspace": after["repositories"]["workspace"],
        },
    }


def test_cli_candidate_promotion_recomputes_binary_diff_for_untracked_owned_file(
    tmp_path: Path,
) -> None:
    packet_path, candidate_sha = write_promotable_packet(
        tmp_path,
        include_untracked_owned_path=True,
    )
    before = json.loads(packet_path.read_text(encoding="utf-8"))
    local_revision = before["repositories"]["workspace"]

    result = run_checker(
        tmp_path,
        "--packet",
        packet_path.relative_to(tmp_path).as_posix(),
        "--promote-packet",
        "packet-1",
        "--repository",
        "workspace",
        "--candidate-sha",
        candidate_sha,
        "--write",
    )

    assert result.returncode == 0, result.stdout + result.stderr
    after = json.loads(packet_path.read_text(encoding="utf-8"))
    promoted_revision = after["repositories"]["workspace"]
    candidate_diff = subprocess.run(
        [
            "git",
            "-C",
            str(tmp_path),
            "diff",
            "--binary",
            "--full-index",
            "--no-ext-diff",
            "--no-renames",
            local_revision["base_sha"],
            candidate_sha,
            "--",
            *local_revision["owned_paths"],
        ],
        check=True,
        stdout=subprocess.PIPE,
    ).stdout
    assert (
        promoted_revision["owned_path_manifest_sha256"]
        == local_revision["owned_path_manifest_sha256"]
    )
    assert (
        promoted_revision["binary_tracked_diff_sha256"]
        == hashlib.sha256(candidate_diff).hexdigest()
    )
    assert (
        promoted_revision["binary_tracked_diff_sha256"]
        != local_revision["binary_tracked_diff_sha256"]
    )


def test_cli_candidate_promotion_rejects_candidate_off_current_history(
    tmp_path: Path,
) -> None:
    packet_path, current_candidate_sha = write_promotable_packet(tmp_path)
    before = packet_path.read_bytes()
    base_sha = json.loads(packet_path.read_text(encoding="utf-8"))["repositories"][
        "workspace"
    ]["base_sha"]
    git(tmp_path, "switch", "-q", "--detach", base_sha)
    (tmp_path / "tracked.txt").write_text("candidate\n", encoding="utf-8")
    git(tmp_path, "add", "tracked.txt")
    git(tmp_path, "commit", "-qm", "off-history candidate")
    wrong_candidate_sha = git(tmp_path, "rev-parse", "HEAD")
    git(tmp_path, "switch", "-q", "--detach", current_candidate_sha)

    result = run_checker(
        tmp_path,
        "--packet",
        packet_path.relative_to(tmp_path).as_posix(),
        "--promote-packet",
        "packet-1",
        "--repository",
        "workspace",
        "--candidate-sha",
        wrong_candidate_sha,
        "--write",
    )

    assert result.returncode == 1
    assert "candidate_sha is not an ancestor of current HEAD" in result.stdout
    assert packet_path.read_bytes() == before


def test_cli_candidate_promotion_rejects_non_descendant_candidate(
    tmp_path: Path,
) -> None:
    packet_path, current_candidate_sha = write_promotable_packet(tmp_path)
    before = packet_path.read_bytes()
    base_sha = json.loads(packet_path.read_text(encoding="utf-8"))["repositories"][
        "workspace"
    ]["base_sha"]
    git(tmp_path, "switch", "-q", "--detach", f"{base_sha}^")
    (tmp_path / "tracked.txt").write_text("candidate\n", encoding="utf-8")
    git(tmp_path, "add", "tracked.txt")
    git(tmp_path, "commit", "-qm", "non-descendant candidate")
    non_descendant_sha = git(tmp_path, "rev-parse", "HEAD")
    git(tmp_path, "switch", "-q", "--detach", current_candidate_sha)

    result = run_checker(
        tmp_path,
        "--packet",
        packet_path.relative_to(tmp_path).as_posix(),
        "--promote-packet",
        "packet-1",
        "--repository",
        "workspace",
        "--candidate-sha",
        non_descendant_sha,
        "--write",
    )

    assert result.returncode == 1
    assert "candidate_sha is not descended from base_sha" in result.stdout
    assert packet_path.read_bytes() == before


def test_cli_candidate_promotion_rejects_mismatched_candidate_contents(
    tmp_path: Path,
) -> None:
    packet_path, _ = write_promotable_packet(tmp_path)
    before = packet_path.read_bytes()
    (tmp_path / "tracked.txt").write_text("different candidate\n", encoding="utf-8")
    git(tmp_path, "add", "tracked.txt")
    git(tmp_path, "commit", "-qm", "mismatched candidate")
    mismatched_sha = git(tmp_path, "rev-parse", "HEAD")

    result = run_checker(
        tmp_path,
        "--packet",
        packet_path.relative_to(tmp_path).as_posix(),
        "--promote-packet",
        "packet-1",
        "--repository",
        "workspace",
        "--candidate-sha",
        mismatched_sha,
        "--write",
    )

    assert result.returncode == 1
    assert "candidate owned-path manifest" in result.stdout
    assert packet_path.read_bytes() == before


def test_cli_candidate_promotion_rejects_dirty_owned_paths_after_candidate(
    tmp_path: Path,
) -> None:
    packet_path, candidate_sha = write_promotable_packet(tmp_path)
    before = packet_path.read_bytes()
    (tmp_path / "tracked.txt").write_text("post-candidate drift\n", encoding="utf-8")

    result = run_checker(
        tmp_path,
        "--packet",
        packet_path.relative_to(tmp_path).as_posix(),
        "--promote-packet",
        "packet-1",
        "--repository",
        "workspace",
        "--candidate-sha",
        candidate_sha,
        "--write",
    )

    assert result.returncode == 1
    assert "candidate owned paths are dirty in the current working tree" in result.stdout
    assert packet_path.read_bytes() == before


def test_default_cli_accepts_candidate_commit_then_metadata_receipt_commit(
    tmp_path: Path,
) -> None:
    packet_paths, owned_paths = write_live_r0_workspace(tmp_path)
    packet_id = REQUIRED_LOCAL_PACKET_IDS[0]
    git(tmp_path, "add", owned_paths[packet_id])
    git(tmp_path, "commit", "-qm", "candidate")
    candidate_sha = git(tmp_path, "rev-parse", "HEAD")

    promotion = run_checker(
        tmp_path,
        "--promote-packet",
        packet_id,
        "--repository",
        "workspace",
        "--candidate-sha",
        candidate_sha,
        "--write",
    )
    assert promotion.returncode == 0, promotion.stdout + promotion.stderr
    promoted = json.loads(packet_paths[packet_id].read_text(encoding="utf-8"))
    assert promoted["repositories"]["workspace"]["revision_type"] == "committed_candidate"
    git(
        tmp_path,
        "add",
        packet_paths[packet_id].relative_to(tmp_path).as_posix(),
    )
    git(tmp_path, "commit", "-qm", "candidate metadata receipt")
    assert git(tmp_path, "rev-parse", "HEAD") != candidate_sha

    validation = run_checker(tmp_path)

    assert validation.returncode == 0, validation.stdout + validation.stderr
    assert "architecture-release-manifests: OK packets=9 evidence=9" in validation.stdout


def test_cli_can_promote_app_and_backend_before_gate_4_deployment_receipts(
    tmp_path: Path,
) -> None:
    packet_paths, _ = write_live_r0_workspace(tmp_path)
    packet_id = REQUIRED_LOCAL_PACKET_IDS[0]
    candidate_shas = {
        "app": git(tmp_path / "TRR-APP", "rev-parse", "HEAD"),
        "backend": git(tmp_path / "TRR-Backend", "rev-parse", "HEAD"),
    }

    for repository, candidate_sha in candidate_shas.items():
        promotion = run_checker(
            tmp_path,
            "--promote-packet",
            packet_id,
            "--repository",
            repository,
            "--candidate-sha",
            candidate_sha,
            "--write",
        )
        assert promotion.returncode == 0, promotion.stdout + promotion.stderr

    promoted = json.loads(packet_paths[packet_id].read_text(encoding="utf-8"))
    assert promoted["repositories"]["app"]["candidate_sha"] == candidate_shas["app"]
    assert (
        promoted["repositories"]["backend"]["candidate_sha"]
        == candidate_shas["backend"]
    )
    assert promoted["deployments"]["vercel"]["candidate_sha"] is None
    assert promoted["deployments"]["render"]["candidate_sha"] is None
    assert promoted["deployments"]["modal"]["candidate_sha"] is None

    validation = run_checker(tmp_path)
    assert validation.returncode == 0, validation.stdout + validation.stderr


def test_default_cli_keeps_local_checkpoints_valid_after_unrelated_commit(
    tmp_path: Path,
) -> None:
    write_live_r0_workspace(tmp_path)
    commit_unrelated_change(tmp_path)

    validation = run_checker(tmp_path)

    assert validation.returncode == 0, validation.stdout + validation.stderr


def test_default_cli_rejects_local_checkpoint_content_drift_after_unrelated_commit(
    tmp_path: Path,
) -> None:
    _, owned_paths = write_live_r0_workspace(tmp_path)
    commit_unrelated_change(tmp_path)
    packet_id = REQUIRED_LOCAL_PACKET_IDS[0]
    (tmp_path / owned_paths[packet_id]).write_text("content drift\n", encoding="utf-8")

    validation = run_checker(tmp_path)

    assert validation.returncode == 1
    assert "owned-path manifest SHA-256" in validation.stdout


def test_default_cli_rejects_local_checkpoint_status_drift_after_unrelated_commit(
    tmp_path: Path,
) -> None:
    _, owned_paths = write_live_r0_workspace(tmp_path)
    commit_unrelated_change(tmp_path)
    packet_id = REQUIRED_LOCAL_PACKET_IDS[0]
    git(tmp_path, "add", owned_paths[packet_id])
    git(tmp_path, "commit", "-qm", "unpromoted owned path")

    validation = run_checker(tmp_path)

    assert validation.returncode == 1
    assert "dirty counts" in validation.stdout


def test_default_cli_rejects_local_checkpoint_digest_drift_after_unrelated_commit(
    tmp_path: Path,
) -> None:
    packet_paths, _ = write_live_r0_workspace(tmp_path)
    commit_unrelated_change(tmp_path)
    packet_id = REQUIRED_LOCAL_PACKET_IDS[0]
    packet_data = json.loads(packet_paths[packet_id].read_text(encoding="utf-8"))
    packet_data["repositories"]["workspace"]["owned_path_manifest_sha256"] = "0" * 64
    packet_paths[packet_id].write_text(json.dumps(packet_data), encoding="utf-8")

    validation = run_checker(tmp_path)

    assert validation.returncode == 1
    assert "owned-path manifest SHA-256" in validation.stdout


def test_default_cli_rejects_divergent_local_checkpoint_base(tmp_path: Path) -> None:
    packet_paths, _ = write_live_r0_workspace(tmp_path)
    first_packet = json.loads(
        packet_paths[REQUIRED_LOCAL_PACKET_IDS[0]].read_text(encoding="utf-8")
    )
    base_sha = first_packet["repositories"]["workspace"]["base_sha"]
    seed_sha = git(tmp_path, "rev-parse", f"{base_sha}^")
    tree_sha = git(tmp_path, "rev-parse", f"{base_sha}^{{tree}}")
    divergent_sha = git(
        tmp_path,
        "commit-tree",
        tree_sha,
        "-p",
        seed_sha,
        "-m",
        "divergent base",
    )
    for packet_path in packet_paths.values():
        packet_data = json.loads(packet_path.read_text(encoding="utf-8"))
        packet_data["repositories"]["workspace"]["base_sha"] = divergent_sha
        packet_path.write_text(json.dumps(packet_data), encoding="utf-8")
    parked_path = tmp_path / "docs/workspace/parked-unaccepted-local-work.json"
    parked = json.loads(parked_path.read_text(encoding="utf-8"))
    parked["repositories"]["workspace"]["base_sha"] = divergent_sha
    parked_path.write_text(json.dumps(parked), encoding="utf-8")

    validation = run_checker(tmp_path)

    assert validation.returncode == 1
    assert "local checkpoint base_sha is not an ancestor of current HEAD" in validation.stdout


@pytest.mark.parametrize(
    ("claim_kind", "evidence_defect", "expected_label"),
    [
        ("quick", "failing", "quick validation"),
        ("quick", "nonlocal", "quick validation"),
        ("compatibility", "failing", "compatibility N/N"),
        ("compatibility", "nonlocal", "compatibility N/N"),
    ],
)
def test_cli_rejects_nonpassing_or_nonlocal_evidence_for_pass_claims(
    tmp_path: Path,
    claim_kind: str,
    evidence_defect: str,
    expected_label: str,
) -> None:
    packet_data = packet()
    claimed_evidence = evidence()
    claimed_evidence["evidence_id"] = "ev.packet-1.claimed"
    if evidence_defect == "failing":
        claimed_evidence["result"] = "fail"
        claimed_evidence["exit_code"] = 1
    else:
        claimed_evidence["truth_scope"] = "preview"
    if claim_kind == "quick":
        packet_data["validation"]["quick"]["evidence_ids"] = [
            claimed_evidence["evidence_id"]
        ]
    else:
        packet_data["contracts"]["compatibility_matrix"][0]["evidence_ids"] = [
            claimed_evidence["evidence_id"]
        ]
    packet_path, passing_evidence_path = write_workspace(
        tmp_path,
        packet_data,
        evidence(),
    )
    claimed_evidence_path = tmp_path / "claimed-evidence.json"
    claimed_evidence_path.write_text(json.dumps(claimed_evidence), encoding="utf-8")

    validation = run_checker(
        tmp_path,
        "--packet",
        packet_path.relative_to(tmp_path).as_posix(),
        "--evidence",
        passing_evidence_path.relative_to(tmp_path).as_posix(),
        "--evidence",
        claimed_evidence_path.relative_to(tmp_path).as_posix(),
        "--allow-partial",
        "--no-verify-current",
    )

    assert validation.returncode == 1
    assert (
        f"{expected_label} requires passing evidence at local truth scope"
        in validation.stdout
    )


def test_secret_like_value_is_rejected(tmp_path: Path) -> None:
    module = load_module()
    evidence_data = evidence()
    evidence_data["expected_result"] = "token=actual-secret-value"
    packet_path, evidence_path = write_workspace(tmp_path, packet(), evidence_data)

    with pytest.raises(module.ManifestValidationError, match="possible credential"):
        module.validate_manifests(tmp_path, [packet_path], [evidence_path])


def test_missing_evidence_reference_is_rejected(tmp_path: Path) -> None:
    module = load_module()
    packet_data = packet()
    packet_data["validation"]["quick"]["evidence_ids"].append("ev.packet-1.missing")
    packet_path, evidence_path = write_workspace(tmp_path, packet_data, evidence())

    with pytest.raises(module.ManifestValidationError, match="missing referenced evidence"):
        module.validate_manifests(tmp_path, [packet_path], [evidence_path])


def test_incomplete_compatibility_matrix_is_rejected(tmp_path: Path) -> None:
    module = load_module()
    packet_data = packet()
    packet_data["contracts"]["compatibility_matrix"].pop()
    packet_path, evidence_path = write_workspace(tmp_path, packet_data, evidence())

    with pytest.raises(module.ManifestValidationError, match="each N/N\\+1 pairing"):
        module.validate_manifests(tmp_path, [packet_path], [evidence_path])


def test_group_readable_evidence_artifact_is_rejected(tmp_path: Path) -> None:
    module = load_module()
    evidence_data = evidence()
    evidence_data["artifacts"] = [
        {
            "path": "artifacts/log.txt",
            "sha256": "c" * 64,
            "size_bytes": 1,
            "mode": "0640",
            "redacted": True,
        }
    ]
    packet_path, evidence_path = write_workspace(tmp_path, packet(), evidence_data)

    with pytest.raises(module.ManifestValidationError, match="group/world accessible"):
        module.validate_manifests(tmp_path, [packet_path], [evidence_path])


def test_manifest_path_cannot_escape_workspace(tmp_path: Path) -> None:
    module = load_module()
    packet_path, evidence_path = write_workspace(tmp_path, packet(), evidence())
    outside_path = tmp_path.parent / f"{tmp_path.name}-outside-packet.json"
    outside_path.write_text(packet_path.read_text(encoding="utf-8"), encoding="utf-8")

    with pytest.raises(module.ManifestValidationError, match="escapes workspace"):
        module.validate_manifests(tmp_path, [outside_path], [evidence_path])


def test_failed_redaction_status_is_rejected(tmp_path: Path) -> None:
    module = load_module()
    evidence_data = evidence()
    evidence_data["redaction"]["status"] = "failed"
    packet_path, evidence_path = write_workspace(tmp_path, packet(), evidence_data)

    with pytest.raises(module.ManifestValidationError, match="redaction.status"):
        module.validate_manifests(tmp_path, [packet_path], [evidence_path])


def test_target_observation_must_fall_inside_evidence_window(tmp_path: Path) -> None:
    module = load_module()
    evidence_data = evidence()
    evidence_data["target_observations"] = [
        {
            "target_type": "render",
            "target_id": "srv-example",
            "observed_at": "2026-07-16T00:00:02Z",
            "status": "pass",
            "facts": [],
        }
    ]
    packet_path, evidence_path = write_workspace(tmp_path, packet(), evidence_data)

    with pytest.raises(module.ManifestValidationError, match="outside started_at/finished_at"):
        module.validate_manifests(tmp_path, [packet_path], [evidence_path])


def test_program_complete_requires_evidence_for_every_completion_claim(tmp_path: Path) -> None:
    module = load_module()
    packet_data = program_complete_packet()
    packet_data["validation"]["full"]["evidence_ids"] = []
    packet_path, evidence_path = write_workspace(tmp_path, packet_data, evidence())

    with pytest.raises(module.ManifestValidationError, match="full validation requires evidence"):
        module.validate_manifests(tmp_path, [packet_path], [evidence_path])


def test_program_complete_rejects_failing_compatibility_case(tmp_path: Path) -> None:
    module = load_module()
    packet_data = program_complete_packet()
    packet_data["contracts"]["compatibility_matrix"][0]["status"] = "fail"
    packet_path, evidence_path = write_workspace(tmp_path, packet_data, evidence())

    with pytest.raises(module.ManifestValidationError, match="compatibility cases must pass"):
        module.validate_manifests(tmp_path, [packet_path], [evidence_path])


def test_program_complete_enforces_observation_duration(tmp_path: Path) -> None:
    module = load_module()
    packet_data = program_complete_packet()
    packet_data["observation"]["ends_at"] = "2026-07-14T23:59:59Z"
    packet_path, evidence_path = write_workspace(tmp_path, packet_data, evidence())

    with pytest.raises(module.ManifestValidationError, match="minimum 7-day window"):
        module.validate_manifests(tmp_path, [packet_path], [evidence_path])


def test_program_complete_claims_require_passing_evidence(tmp_path: Path) -> None:
    module = load_module()
    evidence_data = evidence()
    evidence_data["result"] = "fail"
    evidence_data["exit_code"] = 1
    packet_path, evidence_path = write_workspace(
        tmp_path,
        program_complete_packet(),
        evidence_data,
    )

    with pytest.raises(module.ManifestValidationError, match="requires passing evidence"):
        module.validate_manifests(tmp_path, [packet_path], [evidence_path])


def test_valid_program_complete_packet_passes(tmp_path: Path) -> None:
    module = load_module()
    packet_path, evidence_path = write_workspace(
        tmp_path,
        program_complete_packet(),
        evidence(),
    )

    counts = module.validate_manifests(tmp_path, [packet_path], [evidence_path])

    assert counts == (1, 1)


def test_program_complete_evidence_cannot_postdate_packet_update(tmp_path: Path) -> None:
    module = load_module()
    evidence_data = evidence()
    evidence_data["finished_at"] = "2026-07-16T00:00:03Z"
    packet_path, evidence_path = write_workspace(
        tmp_path,
        program_complete_packet(),
        evidence_data,
    )

    with pytest.raises(module.ManifestValidationError, match="postdates packet updated_at"):
        module.validate_manifests(tmp_path, [packet_path], [evidence_path])


def test_embedded_colon_secret_assignment_is_rejected(tmp_path: Path) -> None:
    module = load_module()
    evidence_data = evidence()
    evidence_data["expected_result"] = "token: actual-secret-value"
    packet_path, evidence_path = write_workspace(tmp_path, packet(), evidence_data)

    with pytest.raises(module.ManifestValidationError, match="possible credential"):
        module.validate_manifests(tmp_path, [packet_path], [evidence_path])


def test_packet_cannot_borrow_evidence_from_another_packet(tmp_path: Path) -> None:
    module = load_module()
    packet_one = packet()
    packet_one["validation"]["quick"]["evidence_ids"].append("ev.packet-2.quick")
    packet_one_path, evidence_one_path = write_workspace(tmp_path, packet_one, evidence())

    packet_two = json.loads(json.dumps(packet()).replace("packet-1", "packet-2"))
    evidence_two = json.loads(json.dumps(evidence()).replace("packet-1", "packet-2"))
    packet_two_path = tmp_path / "packet-2.json"
    evidence_two_path = tmp_path / "evidence-2.json"
    packet_two_path.write_text(json.dumps(packet_two), encoding="utf-8")
    evidence_two_path.write_text(json.dumps(evidence_two), encoding="utf-8")

    with pytest.raises(module.ManifestValidationError, match="evidence for another packet"):
        module.validate_manifests(
            tmp_path,
            [packet_one_path, packet_two_path],
            [evidence_one_path, evidence_two_path],
        )


def test_local_dirty_checkpoint_hashes_tracked_and_untracked_owned_paths(tmp_path: Path) -> None:
    module = load_module()
    repo = tmp_path / "repo"
    repo.mkdir()
    git(repo, "init", "-q")
    git(repo, "config", "user.email", "test@example.invalid")
    git(repo, "config", "user.name", "Test User")
    (repo / "tracked.txt").write_text("original\n", encoding="utf-8")
    git(repo, "add", "tracked.txt")
    git(repo, "commit", "-qm", "base")
    base_sha = git(repo, "rev-parse", "HEAD")
    (repo / "tracked.txt").write_text("changed\n", encoding="utf-8")
    (repo / "untracked.txt").write_text("new\n", encoding="utf-8")

    checkpoint = module.capture_local_dirty_checkpoint(
        repo,
        base_sha,
        ["untracked.txt", "tracked.txt"],
    )

    assert checkpoint == {
        "revision_type": "local_dirty_checkpoint",
        "base_sha": base_sha,
        "candidate_sha": None,
        "owned_paths": ["tracked.txt", "untracked.txt"],
        "owned_path_manifest_sha256": (
            "44e59baab0ef0fbb912170300b8d7001a77d3abf9b78c2ec6b95577fd6ee339a"
        ),
        "binary_tracked_diff_sha256": (
            "32a6e8cc0e7b3e944d6c5bc03bfffdf9fd5e6765d44af33eb14fa56d0a1bfa41"
        ),
        "dirty_counts": dirty_counts(tracked_modified=1, untracked=1),
        "candidate_commit_required_before_gate_4": True,
    }


def test_local_dirty_checkpoint_detects_owned_path_drift(tmp_path: Path) -> None:
    module = load_module()
    repo = tmp_path / "repo"
    repo.mkdir()
    git(repo, "init", "-q")
    git(repo, "config", "user.email", "test@example.invalid")
    git(repo, "config", "user.name", "Test User")
    (repo / "tracked.txt").write_text("original\n", encoding="utf-8")
    git(repo, "add", "tracked.txt")
    git(repo, "commit", "-qm", "base")
    base_sha = git(repo, "rev-parse", "HEAD")
    (repo / "tracked.txt").write_text("changed\n", encoding="utf-8")
    checkpoint = module.capture_local_dirty_checkpoint(repo, base_sha, ["tracked.txt"])
    (repo / "tracked.txt").write_text("changed again\n", encoding="utf-8")

    with pytest.raises(module.ManifestValidationError, match="owned-path manifest SHA-256"):
        module.validate_local_dirty_checkpoint(repo, checkpoint, Path("packet.json"))


def test_committed_candidate_reproduces_local_owned_path_manifest(tmp_path: Path) -> None:
    module = load_module()
    repo = tmp_path / "repo"
    repo.mkdir()
    git(repo, "init", "-q")
    git(repo, "config", "user.email", "test@example.invalid")
    git(repo, "config", "user.name", "Test User")
    (repo / "tracked.txt").write_text("original\n", encoding="utf-8")
    git(repo, "add", "tracked.txt")
    git(repo, "commit", "-qm", "base")
    base_sha = git(repo, "rev-parse", "HEAD")
    (repo / "tracked.txt").write_text("changed\n", encoding="utf-8")
    (repo / "untracked.txt").write_text("new\n", encoding="utf-8")
    local_checkpoint = module.capture_local_dirty_checkpoint(
        repo,
        base_sha,
        ["tracked.txt", "untracked.txt"],
    )
    git(repo, "add", "tracked.txt", "untracked.txt")
    git(repo, "commit", "-qm", "candidate")
    candidate_sha = git(repo, "rev-parse", "HEAD")

    committed = module.capture_committed_candidate(
        repo,
        base_sha,
        candidate_sha,
        ["tracked.txt", "untracked.txt"],
    )

    assert (
        committed["owned_path_manifest_sha256"]
        == local_checkpoint["owned_path_manifest_sha256"]
    )
    module.validate_committed_candidate(repo, committed, Path("packet.json"))


def test_committed_candidate_rejects_nonreproducing_owned_contents(tmp_path: Path) -> None:
    module = load_module()
    repo = tmp_path / "repo"
    repo.mkdir()
    git(repo, "init", "-q")
    git(repo, "config", "user.email", "test@example.invalid")
    git(repo, "config", "user.name", "Test User")
    (repo / "tracked.txt").write_text("original\n", encoding="utf-8")
    git(repo, "add", "tracked.txt")
    git(repo, "commit", "-qm", "base")
    base_sha = git(repo, "rev-parse", "HEAD")
    (repo / "tracked.txt").write_text("candidate\n", encoding="utf-8")
    git(repo, "add", "tracked.txt")
    git(repo, "commit", "-qm", "candidate")
    candidate_sha = git(repo, "rev-parse", "HEAD")
    committed = module.capture_committed_candidate(
        repo,
        base_sha,
        candidate_sha,
        ["tracked.txt"],
    )
    committed["owned_path_manifest_sha256"] = "0" * 64

    with pytest.raises(module.ManifestValidationError, match="candidate owned-path manifest"):
        module.validate_committed_candidate(repo, committed, Path("packet.json"))


def test_local_dirty_checkpoint_requires_sorted_owned_paths(tmp_path: Path) -> None:
    module = load_module()
    packet_data = packet()
    packet_data["repositories"]["workspace"]["owned_paths"] = ["z", "a"]
    packet_path, evidence_path = write_workspace(tmp_path, packet_data, evidence())

    with pytest.raises(module.ManifestValidationError, match="owned_paths must be sorted"):
        module.validate_manifests(tmp_path, [packet_path], [evidence_path])


def test_gate_4_state_requires_committed_candidate_shas(tmp_path: Path) -> None:
    module = load_module()
    packet_data = packet()
    packet_data["state"] = "approved_for_cutover"
    packet_path, evidence_path = write_workspace(tmp_path, packet_data, evidence())

    with pytest.raises(module.ManifestValidationError, match="committed candidate_sha"):
        module.validate_manifests(tmp_path, [packet_path], [evidence_path])


def test_r0_requires_all_nine_exact_local_packet_ids(tmp_path: Path) -> None:
    module = load_module()
    packet_paths, evidence_paths, parked_path = write_r0_workspace(tmp_path)
    missing_packet = packet_paths.pop()
    missing_packet.unlink()
    missing_evidence = evidence_paths.pop()
    missing_evidence.unlink()

    with pytest.raises(module.ManifestValidationError, match="missing required local packet IDs"):
        module.validate_manifests(
            tmp_path,
            packet_paths,
            evidence_paths,
            require_r0_local_set=True,
            parked_path=parked_path,
        )


def test_r0_requires_parked_unaccepted_work_manifest(tmp_path: Path) -> None:
    module = load_module()
    packet_paths, evidence_paths, parked_path = write_r0_workspace(tmp_path)
    parked_path.unlink()

    with pytest.raises(module.ManifestValidationError, match="parked-unaccepted-local-work"):
        module.validate_manifests(
            tmp_path,
            packet_paths,
            evidence_paths,
            require_r0_local_set=True,
            parked_path=parked_path,
        )


def test_parked_entry_requires_owner_reason_missing_proof_and_next_action(tmp_path: Path) -> None:
    module = load_module()
    packet_paths, evidence_paths, parked_path = write_r0_workspace(tmp_path)
    parked = parked_manifest()
    parked["entries"] = [{"repository": "workspace", "path": "unowned.py"}]
    parked_path.write_text(json.dumps(parked), encoding="utf-8")

    with pytest.raises(
        module.ManifestValidationError,
        match="missing .*missing_proof.*next_action.*owner.*reason.*status",
    ):
        module.validate_manifests(
            tmp_path,
            packet_paths,
            evidence_paths,
            require_r0_local_set=True,
            parked_path=parked_path,
        )


def test_direct_sql_delta_schema_requires_status_specific_measurements(
    tmp_path: Path,
) -> None:
    module = load_module()
    observed = packet()
    observed["direct_sql_delta"] = {
        "status": "observed",
        "before": None,
        "after": 3,
        "delta": 3,
        "evidence_ids": ["ev.packet-1.quick"],
    }
    observed_path, observed_evidence_path = write_workspace(
        tmp_path / "observed", observed, evidence()
    )

    with pytest.raises(module.ManifestValidationError, match="direct_sql_delta"):
        module.validate_manifests(
            tmp_path / "observed", [observed_path], [observed_evidence_path]
        )

    pending = packet()
    pending["direct_sql_delta"] = {
        "status": "pending_local_measurement",
        "before": 0,
        "after": None,
        "delta": None,
        "evidence_ids": [],
    }
    pending_path, pending_evidence_path = write_workspace(
        tmp_path / "pending", pending, evidence()
    )

    with pytest.raises(module.ManifestValidationError, match="direct_sql_delta"):
        module.validate_manifests(
            tmp_path / "pending", [pending_path], [pending_evidence_path]
        )


def test_observed_direct_sql_delta_enforces_arithmetic(tmp_path: Path) -> None:
    module = load_module()
    packet_data = packet()
    packet_data["direct_sql_delta"] = {
        "status": "observed",
        "before": 2,
        "after": 5,
        "delta": 2,
        "evidence_ids": ["ev.packet-1.quick"],
    }
    packet_path, evidence_path = write_workspace(tmp_path, packet_data, evidence())

    with pytest.raises(module.ManifestValidationError, match="equal after minus before"):
        module.validate_manifests(tmp_path, [packet_path], [evidence_path])


def test_owned_app_routes_must_be_declared_in_affected_routes(tmp_path: Path) -> None:
    module = load_module()
    packet_data = packet()
    owned_route = "apps/web/src/app/api/admin/trr-api/people/[personId]/import-fandom/commit/route.ts"
    packet_data["repositories"]["app"] = local_revision(owned_route)
    packet_data["owned_paths"].append(
        {
            "repository": "app",
            "path": owned_route,
            "task_id": 3,
            "reviewers": ["reviewer"],
        }
    )
    packet_path, evidence_path = write_workspace(tmp_path, packet_data, evidence())

    with pytest.raises(module.ManifestValidationError, match="missing from affected.routes"):
        module.validate_manifests(tmp_path, [packet_path], [evidence_path])

    assert (
        module._app_route_for_owned_path(owned_route)
        == "/api/admin/trr-api/people/{personId}/import-fandom/commit"
    )


def test_workspace_vercel_rollback_command_uses_the_supported_wrapper_form(
    tmp_path: Path,
) -> None:
    module = load_module()
    packet_data = packet()
    packet_data["rollback"]["app_commands"] = [
        [
            "TRR-APP/scripts/vercel.sh",
            "rollback",
            "<gate-4-previous-deployment>",
        ]
    ]
    packet_path, evidence_path = write_workspace(tmp_path, packet_data, evidence())

    with pytest.raises(module.ManifestValidationError, match="guarded Vercel rollback form"):
        module.validate_manifests(tmp_path, [packet_path], [evidence_path])


def test_historical_parked_manifest_does_not_classify_the_current_checkout(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    module = load_module()
    packets = {}
    workspace_paths: set[str] = set()
    for index, packet_id in enumerate(sorted(module.REQUIRED_LOCAL_PACKET_IDS)):
        packet_data = packet()
        owned_path = f"owned-{index}.txt"
        packet_data["packet_id"] = packet_id
        packet_data["repositories"]["workspace"] = local_revision(owned_path)
        packet_data["owned_paths"][0]["path"] = owned_path
        packets[packet_id] = (packet_data, tmp_path / f"{packet_id}.json")
        workspace_paths.add(owned_path)

    parked = parked_manifest()
    parked["entries"] = [
        {
            "repository": "workspace",
            "path": "stale-capture.txt",
            "status": "modified",
            "owner": "unassigned",
            "reason": "Captured before current ownership was assigned.",
            "missing_proof": ["historical only"],
            "next_action": "Consult the replacement task lock.",
        }
    ]
    parked["lifecycle"] = {
        "state": "historical_snapshot",
        "reason": "A later task lock owns current-state classification.",
        "superseded_by": ["docs/workspace/architecture-task-locks.json"],
    }
    module.validate_parked_work_manifest(parked, tmp_path / "parked.json")

    monkeypatch.setattr(module, "validate_local_dirty_checkpoint", lambda *_: None)
    monkeypatch.setattr(
        module,
        "repository_dirty_paths",
        lambda repository: (
            {owned_path: "modified" for owned_path in workspace_paths}
            if repository.resolve() == tmp_path.resolve()
            else {}
        ),
    )

    module.validate_current_checkpoint(tmp_path, packets, parked)

#!/usr/bin/env python3
"""Validate TRR architecture release packets and their secret-free evidence."""

from __future__ import annotations

import argparse
from collections.abc import Iterable, Mapping
from datetime import datetime, timedelta, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
from typing import Any

from jsonschema import Draft202012Validator, FormatChecker


WORKSPACE_ROOT = Path(__file__).resolve().parents[2]
PACKET_SCHEMA = Path("docs/workspace/release-packet.schema.json")
EVIDENCE_SCHEMA = Path("docs/workspace/architecture-evidence.schema.json")
DEFAULT_PACKET_DIRECTORY = Path("docs/workspace/release-packets")
DEFAULT_EVIDENCE_DIRECTORY = Path("docs/workspace/architecture-evidence")
DEFAULT_PARKED_WORK_MANIFEST = Path("docs/workspace/parked-unaccepted-local-work.json")
REPOSITORY_PATHS = {
    "workspace": Path("."),
    "app": Path("TRR-APP"),
    "backend": Path("TRR-Backend"),
}
REQUIRED_LOCAL_PACKET_IDS = {
    "local-foundation-runtime-guards",
    "local-identity-canonical-routes",
    "local-covered-shows",
    "local-networks-streaming",
    "local-recent-people-external-ids",
    "local-person-media",
    "local-season-survey-roles",
    "local-social-freshness",
    "local-show-presentation-extractions",
}
GATE_4_STATES = {
    "approved_for_cutover",
    "cutover_in_progress",
    "cutover_complete_observing",
    "program_complete",
    "rolled_back",
}

ALLOWED_SENSITIVE_KEYS = {
    "credential_values_included",
    "database_url_env",
    "environment_values_included",
    "environment_variable_names",
    "project_ref_env",
}
SENSITIVE_KEY = re.compile(
    r"(?:api[_-]?key|authorization|cookie|credential|database[_-]?url|dsn|"
    r"password|private[_-]?key|secret|token)",
    re.IGNORECASE,
)
SENSITIVE_VALUE_PATTERNS = (
    re.compile(r"(?i)\bBearer\s+[A-Za-z0-9._~+/=-]{12,}"),
    re.compile(r"(?i)\b(?:gh[pousr]|xox[baprs])[-_][A-Za-z0-9_-]{12,}"),
    re.compile(r"(?i)\b(?:sk|rk)_(?:live|test)_[A-Za-z0-9]{8,}"),
    re.compile(r"(?i)\bpostgres(?:ql)?://"),
    re.compile(r"(?i)https://[^/\s:@]+:[^/\s@]+@"),
    re.compile(r"-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----"),
    re.compile(r"\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b"),
    re.compile(r"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b"),
    re.compile(
        r"(?i)\b(?:sk-(?:proj-)?[A-Za-z0-9_-]{20,}|sb_secret_[A-Za-z0-9_-]{16,})"
    ),
    re.compile(
        r"(?i)\b(?:api[_-]?key|authorization|cookie|database[_-]?url|dsn|password|"
        r"private[_-]?key|secret|token)\s*[:=]\s*"
        r"(?!\$|<|\{|redacted\b|none\b|null\b|false\b|true\b|\*{3})[^\s,;]+"
    ),
)
EXPECTED_COMPATIBILITY_CASES = {
    ("N", "N"),
    ("N", "N+1"),
    ("N+1", "N"),
    ("N+1", "N+1"),
}
DIRTY_COUNT_KEYS = (
    "tracked_modified",
    "tracked_added",
    "tracked_deleted",
    "tracked_renamed",
    "tracked_copied",
    "unmerged",
    "untracked",
)


class ManifestValidationError(ValueError):
    """Raised when a release manifest violates a schema or semantic contract."""


def _git_bytes(repository: Path, *args: str) -> bytes:
    try:
        result = subprocess.run(
            ["git", "-C", str(repository), *args],
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env={**os.environ, "GIT_OPTIONAL_LOCKS": "0"},
        )
    except OSError as exc:
        raise ManifestValidationError(
            f"{repository}: cannot execute git {' '.join(args)}: {exc}"
        ) from exc
    if result.returncode != 0:
        detail = result.stderr.decode("utf-8", errors="replace").strip()
        raise ManifestValidationError(
            f"{repository}: git {' '.join(args)} failed ({result.returncode}): {detail}"
        )
    return result.stdout


def _normalized_owned_paths(owned_paths: Iterable[str]) -> list[str]:
    normalized: list[str] = []
    for raw_path in owned_paths:
        if not isinstance(raw_path, str) or not raw_path:
            raise ManifestValidationError("owned paths must be non-empty strings")
        path = Path(raw_path)
        if path.is_absolute() or raw_path != path.as_posix() or ".." in path.parts:
            raise ManifestValidationError(
                f"owned path must be a normalized repository-relative path: {raw_path}"
            )
        if raw_path in {".", ""}:
            raise ManifestValidationError(f"owned path must identify a file: {raw_path}")
        normalized.append(raw_path)
    if len(normalized) != len(set(normalized)):
        raise ManifestValidationError("owned_paths contains duplicates")
    return sorted(normalized)


def _owned_path_record(repository: Path, relative_path: str) -> bytes:
    path = repository / relative_path
    if path.is_symlink():
        mode = "120000"
        content = os.readlink(path).encode("utf-8")
    elif path.is_file():
        mode = "100755" if path.stat().st_mode & 0o111 else "100644"
        content = path.read_bytes()
    elif not path.exists():
        mode = "000000"
        content = b""
    else:
        raise ManifestValidationError(
            f"{repository}: owned path must be a file, symlink, or tracked deletion: "
            f"{relative_path}"
        )
    content_sha256 = hashlib.sha256(content).hexdigest()
    return (
        relative_path.encode("utf-8")
        + b"\0"
        + mode.encode("ascii")
        + b"\0"
        + content_sha256.encode("ascii")
        + b"\n"
    )


def _owned_path_record_at_commit(
    repository: Path,
    candidate_sha: str,
    relative_path: str,
) -> bytes:
    tree_record = _git_bytes(
        repository,
        "ls-tree",
        "-z",
        candidate_sha,
        "--",
        relative_path,
    )
    if not tree_record:
        mode = "000000"
        content = b""
    else:
        record = tree_record.rstrip(b"\0")
        try:
            metadata, returned_path = record.split(b"\t", 1)
            mode_bytes, object_type, object_sha = metadata.split(b" ", 2)
        except ValueError as exc:
            raise ManifestValidationError(
                f"{repository}: cannot parse candidate tree record for {relative_path}"
            ) from exc
        if returned_path.decode("utf-8", errors="surrogateescape") != relative_path:
            raise ManifestValidationError(
                f"{repository}: candidate tree path mismatch for {relative_path}"
            )
        if object_type != b"blob":
            raise ManifestValidationError(
                f"{repository}: candidate owned path is not a blob: {relative_path}"
            )
        mode = mode_bytes.decode("ascii")
        content = _git_bytes(repository, "cat-file", "blob", object_sha.decode("ascii"))
    content_sha256 = hashlib.sha256(content).hexdigest()
    return (
        relative_path.encode("utf-8")
        + b"\0"
        + mode.encode("ascii")
        + b"\0"
        + content_sha256.encode("ascii")
        + b"\n"
    )


def _dirty_counts(repository: Path, owned_paths: list[str]) -> dict[str, int]:
    counts = {key: 0 for key in DIRTY_COUNT_KEYS}
    if not owned_paths:
        return {**counts, "total": 0}
    output = _git_bytes(
        repository,
        "status",
        "--porcelain=v1",
        "-z",
        "--untracked-files=all",
        "--",
        *owned_paths,
    )
    records = output.split(b"\0")
    index = 0
    while index < len(records):
        record = records[index]
        index += 1
        if not record:
            continue
        status = record[:2]
        if status == b"??":
            counts["untracked"] += 1
            continue
        if b"U" in status or status in {b"AA", b"DD"}:
            counts["unmerged"] += 1
        elif b"R" in status:
            counts["tracked_renamed"] += 1
            index += 1
        elif b"C" in status:
            counts["tracked_copied"] += 1
            index += 1
        elif b"D" in status:
            counts["tracked_deleted"] += 1
        elif b"A" in status:
            counts["tracked_added"] += 1
        else:
            counts["tracked_modified"] += 1
    return {**counts, "total": sum(counts.values())}


def capture_local_dirty_checkpoint(
    repository: Path,
    base_sha: str,
    owned_paths: Iterable[str],
) -> dict[str, Any]:
    """Capture deterministic, secret-free provenance for owned local work."""
    repository = repository.resolve()
    normalized_paths = _normalized_owned_paths(owned_paths)
    resolved_base = _git_bytes(
        repository,
        "rev-parse",
        "--verify",
        f"{base_sha}^{{commit}}",
    ).decode("ascii").strip()
    if resolved_base != base_sha:
        raise ManifestValidationError(
            f"{repository}: local checkpoint requires a full base SHA"
        )
    current_head = _git_bytes(repository, "rev-parse", "HEAD").decode("ascii").strip()
    merge_base = _git_bytes(
        repository,
        "merge-base",
        base_sha,
        current_head,
    ).decode("ascii").strip()
    if merge_base != base_sha:
        raise ManifestValidationError(
            f"{repository}: local checkpoint base_sha is not an ancestor of current HEAD"
        )
    manifest_bytes = b"".join(
        _owned_path_record(repository, relative_path)
        for relative_path in normalized_paths
    )
    if normalized_paths:
        tracked_diff = _git_bytes(
            repository,
            "diff",
            "--binary",
            "--full-index",
            "--no-ext-diff",
            "--no-renames",
            base_sha,
            "--",
            *normalized_paths,
        )
    else:
        tracked_diff = b""
    return {
        "revision_type": "local_dirty_checkpoint",
        "base_sha": base_sha,
        "candidate_sha": None,
        "owned_paths": normalized_paths,
        "owned_path_manifest_sha256": hashlib.sha256(manifest_bytes).hexdigest(),
        "binary_tracked_diff_sha256": hashlib.sha256(tracked_diff).hexdigest(),
        "dirty_counts": _dirty_counts(repository, normalized_paths),
        "candidate_commit_required_before_gate_4": True,
    }


def capture_committed_candidate(
    repository: Path,
    base_sha: str,
    candidate_sha: str,
    owned_paths: Iterable[str],
) -> dict[str, Any]:
    """Capture a committed candidate and its reproducible owned-path contents."""
    repository = repository.resolve()
    normalized_paths = _normalized_owned_paths(owned_paths)
    resolved_base = _git_bytes(
        repository,
        "rev-parse",
        "--verify",
        f"{base_sha}^{{commit}}",
    ).decode("ascii").strip()
    resolved_candidate = _git_bytes(
        repository,
        "rev-parse",
        "--verify",
        f"{candidate_sha}^{{commit}}",
    ).decode("ascii").strip()
    if resolved_base != base_sha or resolved_candidate != candidate_sha:
        raise ManifestValidationError(
            f"{repository}: committed candidate requires full base and candidate SHAs"
        )
    merge_base = _git_bytes(
        repository,
        "merge-base",
        base_sha,
        candidate_sha,
    ).decode("ascii").strip()
    if merge_base != base_sha:
        raise ManifestValidationError(
            f"{repository}: candidate_sha is not descended from base_sha"
        )
    manifest_bytes = b"".join(
        _owned_path_record_at_commit(repository, candidate_sha, relative_path)
        for relative_path in normalized_paths
    )
    if normalized_paths:
        tracked_diff = _git_bytes(
            repository,
            "diff",
            "--binary",
            "--full-index",
            "--no-ext-diff",
            "--no-renames",
            base_sha,
            candidate_sha,
            "--",
            *normalized_paths,
        )
    else:
        tracked_diff = b""
    clean_counts = {key: 0 for key in DIRTY_COUNT_KEYS}
    return {
        "revision_type": "committed_candidate",
        "base_sha": base_sha,
        "candidate_sha": candidate_sha,
        "owned_paths": normalized_paths,
        "owned_path_manifest_sha256": hashlib.sha256(manifest_bytes).hexdigest(),
        "binary_tracked_diff_sha256": hashlib.sha256(tracked_diff).hexdigest(),
        "dirty_counts": {**clean_counts, "total": 0},
        "candidate_commit_required_before_gate_4": False,
    }


def validate_local_dirty_checkpoint(
    repository: Path,
    checkpoint: Mapping[str, Any],
    packet_path: Path,
) -> None:
    expected = capture_local_dirty_checkpoint(
        repository,
        checkpoint["base_sha"],
        checkpoint["owned_paths"],
    )
    labels = {
        "owned_path_manifest_sha256": "owned-path manifest SHA-256",
        "binary_tracked_diff_sha256": "binary tracked-diff SHA-256",
        "dirty_counts": "dirty counts",
    }
    for key, label in labels.items():
        if checkpoint[key] != expected[key]:
            raise ManifestValidationError(
                f"{packet_path}: {label} does not match current repository state"
            )


def validate_committed_candidate(
    repository: Path,
    revision: Mapping[str, Any],
    packet_path: Path,
    *,
    require_current_clean: bool = False,
) -> None:
    expected = capture_committed_candidate(
        repository,
        revision["base_sha"],
        revision["candidate_sha"],
        revision["owned_paths"],
    )
    current_head = _git_bytes(repository, "rev-parse", "HEAD").decode("ascii").strip()
    merge_base = _git_bytes(
        repository,
        "merge-base",
        revision["candidate_sha"],
        current_head,
    ).decode("ascii").strip()
    if merge_base != revision["candidate_sha"]:
        raise ManifestValidationError(
            f"{packet_path}: candidate_sha is not an ancestor of current HEAD"
        )
    if (
        require_current_clean
        and _dirty_counts(repository, revision["owned_paths"])["total"] != 0
    ):
        raise ManifestValidationError(
            f"{packet_path}: candidate owned paths are dirty in the current working tree"
        )
    if revision["owned_path_manifest_sha256"] != expected["owned_path_manifest_sha256"]:
        raise ManifestValidationError(
            f"{packet_path}: candidate owned-path manifest does not reproduce the "
            "recorded local contents"
        )
    if revision["binary_tracked_diff_sha256"] != expected["binary_tracked_diff_sha256"]:
        raise ManifestValidationError(
            f"{packet_path}: candidate binary tracked-diff SHA-256 does not match "
            "base-to-candidate diff"
        )
    if revision["dirty_counts"] != expected["dirty_counts"]:
        raise ManifestValidationError(
            f"{packet_path}: committed candidate dirty counts must all be zero"
        )


def load_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ManifestValidationError(f"{path}: cannot read JSON: {exc}") from exc


def _json_path(parts: Iterable[Any]) -> str:
    rendered = "$"
    for part in parts:
        if isinstance(part, int):
            rendered += f"[{part}]"
        else:
            rendered += f".{part}"
    return rendered


def validate_schema(schema: Mapping[str, Any], path: Path) -> None:
    try:
        Draft202012Validator.check_schema(schema)
    except Exception as exc:  # jsonschema exposes several schema error subclasses
        raise ManifestValidationError(f"{path}: invalid JSON Schema: {exc}") from exc


def validate_document(
    document: Any,
    schema: Mapping[str, Any],
    path: Path,
) -> None:
    validator = Draft202012Validator(schema, format_checker=FormatChecker())
    errors = sorted(
        validator.iter_errors(document),
        key=lambda error: tuple(str(part) for part in error.absolute_path),
    )
    if not errors:
        return
    details = "; ".join(
        f"{_json_path(error.absolute_path)}: {error.message}" for error in errors[:10]
    )
    if len(errors) > 10:
        details += f"; ... {len(errors) - 10} additional error(s)"
    raise ManifestValidationError(f"{path}: schema validation failed: {details}")


def scan_secret_free(value: Any, path: tuple[Any, ...] = ()) -> None:
    if isinstance(value, Mapping):
        for key, child in value.items():
            key_text = str(key)
            normalized = key_text.lower()
            if (
                normalized not in ALLOWED_SENSITIVE_KEYS
                and not normalized.endswith("_env")
                and SENSITIVE_KEY.search(normalized)
            ):
                raise ManifestValidationError(
                    f"{_json_path((*path, key_text))}: sensitive key is forbidden"
                )
            scan_secret_free(child, (*path, key_text))
        return
    if isinstance(value, list):
        for index, child in enumerate(value):
            scan_secret_free(child, (*path, index))
        return
    if not isinstance(value, str):
        return
    for pattern in SENSITIVE_VALUE_PATTERNS:
        if pattern.search(value):
            raise ManifestValidationError(
                f"{_json_path(path)}: possible credential or environment value is forbidden"
            )


def _timestamp(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def _workspace_manifest_path(root: Path, raw_path: Path) -> Path:
    path = raw_path if raw_path.is_absolute() else root / raw_path
    if path.is_symlink():
        raise ManifestValidationError(f"manifest path must not be a symlink: {raw_path}")
    resolved = path.resolve()
    try:
        resolved.relative_to(root)
    except ValueError as exc:
        raise ManifestValidationError(f"manifest path escapes workspace: {raw_path}") from exc
    return resolved


def validate_evidence_semantics(evidence: Mapping[str, Any], path: Path) -> None:
    started_at = _timestamp(evidence["started_at"])
    finished_at = _timestamp(evidence["finished_at"])
    if finished_at < started_at:
        raise ManifestValidationError(f"{path}: finished_at precedes started_at")
    if evidence["result"] == "pass" and evidence["exit_code"] != 0:
        raise ManifestValidationError(f"{path}: passing evidence must have exit_code 0")

    approval = evidence["approval"]
    if not approval["required"]:
        expected = {
            "approval_id": None,
            "status": "not_required",
            "current_chat": False,
        }
        mismatches = [key for key, value in expected.items() if approval[key] != value]
        if mismatches:
            raise ManifestValidationError(
                f"{path}: non-required approval has inconsistent {', '.join(mismatches)}"
            )
    elif approval["status"] == "approved" and not approval["current_chat"]:
        raise ManifestValidationError(
            f"{path}: approved evidence must identify a current-chat approval"
        )

    if evidence["redaction"]["status"] == "failed":
        raise ManifestValidationError(f"{path}: redaction status failed; evidence is not safe to store")

    for observation in evidence["target_observations"]:
        observed_at = _timestamp(observation["observed_at"])
        if observed_at < started_at or observed_at > finished_at:
            raise ManifestValidationError(
                f"{path}: target observation {observation['target_type']} is outside "
                "started_at/finished_at"
            )

    for artifact in evidence["artifacts"]:
        if int(artifact["mode"], 8) & 0o077:
            raise ManifestValidationError(
                f"{path}: evidence artifact {artifact['path']} must not be group/world accessible"
            )


def packet_evidence_ids(packet: Mapping[str, Any]) -> set[str]:
    found: set[str] = set()

    def visit(value: Any, key: str | None = None) -> None:
        if key == "evidence_ids" and isinstance(value, list):
            found.update(item for item in value if isinstance(item, str))
        if isinstance(value, Mapping):
            for child_key, child in value.items():
                visit(child, str(child_key))
        elif isinstance(value, list):
            for child in value:
                visit(child)

    visit(packet)
    return found


def completion_evidence_claims(packet: Mapping[str, Any]) -> list[tuple[str, list[str]]]:
    claims = [
        ("quick validation", packet["validation"]["quick"]["evidence_ids"]),
        ("full validation", packet["validation"]["full"]["evidence_ids"]),
        ("app build", packet["validation"]["app_build"]["evidence_ids"]),
        ("browser validation", packet["validation"]["browser"]["evidence_ids"]),
        ("review", packet["review"]["evidence_ids"]),
    ]
    for case in packet["contracts"]["compatibility_matrix"]:
        if case["status"] == "pass":
            claims.append(
                (
                    f"compatibility {case['app_revision']}/{case['backend_revision']}",
                    case["evidence_ids"],
                )
            )
    for provider, deployment in packet["deployments"].items():
        if deployment["status"] == "verified":
            claims.append((f"{provider} deployment", deployment["evidence_ids"]))
    for metric_group in ("baselines", "abort_thresholds"):
        for metric in packet["observation"][metric_group]:
            claims.append((f"observation metric {metric['name']}", metric["evidence_ids"]))
    return claims


def validate_pass_claim_evidence(
    packet: Mapping[str, Any],
    path: Path,
    evidence: Mapping[str, tuple[Mapping[str, Any], Path]],
) -> None:
    claims: list[tuple[str, list[str]]] = []
    quick = packet["validation"]["quick"]
    if quick["status"] == "pass":
        claims.append(("quick validation", quick["evidence_ids"]))
    for case in packet["contracts"]["compatibility_matrix"]:
        if case["status"] == "pass":
            claims.append(
                (
                    f"compatibility {case['app_revision']}/{case['backend_revision']}",
                    case["evidence_ids"],
                )
            )

    for label, evidence_ids in claims:
        if not evidence_ids:
            raise ManifestValidationError(f"{path}: {label} requires evidence")
        invalid = [
            evidence_id
            for evidence_id in evidence_ids
            if evidence[evidence_id][0]["packet_id"] != packet["packet_id"]
            or evidence[evidence_id][0]["truth_scope"] != "local"
            or evidence[evidence_id][0]["result"] != "pass"
        ]
        if invalid:
            raise ManifestValidationError(
                f"{path}: {label} requires passing evidence at local truth scope: "
                f"{', '.join(invalid)}"
            )


def validate_packet_semantics(packet: Mapping[str, Any], path: Path) -> None:
    if _timestamp(packet["updated_at"]) < _timestamp(packet["created_at"]):
        raise ManifestValidationError(f"{path}: updated_at precedes created_at")

    global_owned_paths: dict[str, list[str]] = {
        repository: sorted(
            item["path"]
            for item in packet["owned_paths"]
            if item["repository"] == repository
        )
        for repository in REPOSITORY_PATHS
    }
    for repository, revision in packet["repositories"].items():
        owned_paths = revision["owned_paths"]
        if owned_paths != sorted(owned_paths):
            raise ManifestValidationError(
                f"{path}: {repository} repository owned_paths must be sorted"
            )
        if owned_paths != global_owned_paths[repository]:
            raise ManifestValidationError(
                f"{path}: {repository} repository owned_paths do not match packet owned_paths"
            )
        dirty_counts = revision["dirty_counts"]
        calculated_total = sum(dirty_counts[key] for key in DIRTY_COUNT_KEYS)
        if dirty_counts["total"] != calculated_total:
            raise ManifestValidationError(
                f"{path}: {repository} dirty_counts.total is inconsistent"
            )
        if revision["revision_type"] == "committed_candidate" and dirty_counts["total"] != 0:
            raise ManifestValidationError(
                f"{path}: {repository} committed candidate dirty counts must all be zero"
            )

    for supersession in packet.get("supersedes", []):
        superseded_paths = supersession["paths"]
        if superseded_paths != sorted(superseded_paths):
            raise ManifestValidationError(
                f"{path}: supersession paths must be sorted for "
                f"{supersession['repository']}:{supersession['packet_id']}"
            )
        retained_paths = [
            record["path"] for record in supersession.get("retained_path_records", [])
        ]
        if retained_paths != sorted(retained_paths):
            raise ManifestValidationError(
                f"{path}: retained predecessor path records must be sorted for "
                f"{supersession['repository']}:{supersession['packet_id']}"
            )

    if packet["state"] in GATE_4_STATES:
        missing_candidates = [
            repository
            for repository, revision in packet["repositories"].items()
            if revision["revision_type"] != "committed_candidate"
            or not revision["candidate_sha"]
        ]
        if missing_candidates:
            raise ManifestValidationError(
                f"{path}: Gate 4 state requires a committed candidate_sha for "
                f"{', '.join(missing_candidates)}"
            )

    direct_sql_delta = packet["direct_sql_delta"]
    if direct_sql_delta["status"] == "observed":
        before = direct_sql_delta["before"]
        after = direct_sql_delta["after"]
        delta = direct_sql_delta["delta"]
        if before is None or after is None or delta != after - before:
            raise ManifestValidationError(
                f"{path}: observed direct_sql_delta must equal after minus before"
            )
        if not direct_sql_delta["evidence_ids"]:
            raise ManifestValidationError(
                f"{path}: observed direct_sql_delta requires local evidence"
            )
    elif direct_sql_delta["status"] == "not_applicable":
        if (
            direct_sql_delta["before"] is not None
            or direct_sql_delta["after"] is not None
            or direct_sql_delta["delta"] != 0
        ):
            raise ManifestValidationError(
                f"{path}: not_applicable direct_sql_delta requires null counts and delta 0"
            )

    cases = {
        (case["app_revision"], case["backend_revision"])
        for case in packet["contracts"]["compatibility_matrix"]
    }
    if cases != EXPECTED_COMPATIBILITY_CASES:
        raise ManifestValidationError(
            f"{path}: compatibility_matrix must contain each N/N+1 pairing exactly once"
        )
    if len(packet["contracts"]["compatibility_matrix"]) != len(cases):
        raise ManifestValidationError(f"{path}: compatibility_matrix contains duplicates")

    backend_sha = packet["repositories"]["backend"]["candidate_sha"]
    app_sha = packet["repositories"]["app"]["candidate_sha"]
    for provider in ("render", "modal"):
        deployment_sha = packet["deployments"][provider]["candidate_sha"]
        if deployment_sha is not None and deployment_sha != backend_sha:
            raise ManifestValidationError(
                f"{path}: {provider} candidate_sha must match the backend candidate"
            )
        if packet["state"] in GATE_4_STATES and deployment_sha != backend_sha:
            raise ManifestValidationError(
                f"{path}: {provider} candidate_sha must match the backend candidate"
            )
    vercel_sha = packet["deployments"]["vercel"]["candidate_sha"]
    if vercel_sha is not None and vercel_sha != app_sha:
        raise ManifestValidationError(
            f"{path}: vercel candidate_sha must match the app candidate"
        )
    if packet["state"] in GATE_4_STATES and vercel_sha != app_sha:
        raise ManifestValidationError(
            f"{path}: vercel candidate_sha must match the app candidate"
        )

    if packet["truth_scope"] == "local":
        pending_fields = [
            name for name, status in packet["gate_4"].items() if status != "pending_gate_4"
        ]
        for target_name, target in packet["targets"].items():
            if target["status"] != "pending_gate_4":
                pending_fields.append(target_name)
        if packet["validation"]["app_build"]["status"] != "pending_gate_4":
            pending_fields.append("app_build")
        if packet["validation"]["browser"]["status"] != "pending_gate_4":
            pending_fields.append("browser")
        for provider, deployment in packet["deployments"].items():
            if deployment["status"] != "pending_gate_4":
                pending_fields.append(provider)
        if pending_fields:
            raise ManifestValidationError(
                f"{path}: local packet must leave Gate 4 proof pending_gate_4: "
                f"{', '.join(sorted(set(pending_fields)))}"
            )

    approvals = packet["approvals"]
    approval_ids = [approval["approval_id"] for approval in approvals]
    if len(approval_ids) != len(set(approval_ids)):
        raise ManifestValidationError(f"{path}: approval_id values must be unique")
    for approval in approvals:
        approved = approval["status"] == "approved"
        if approved != bool(approval["approved_by"] and approval["approved_at"]):
            raise ManifestValidationError(
                f"{path}: approval {approval['approval_id']} has inconsistent approver metadata"
            )

    app_build = packet["validation"]["app_build"]
    if app_build["status"] in {"approved_pending", "passed"}:
        approval_id = app_build["current_chat_approval_id"]
        matches = [
            approval
            for approval in approvals
            if approval["approval_id"] == approval_id
            and approval["kind"] == "full_app_build"
            and approval["status"] == "approved"
        ]
        if len(matches) != 1:
            raise ManifestValidationError(
                f"{path}: approved app build must reference one approved full_app_build approval"
            )

    if packet["state"] == "program_complete":
        if packet["validation"]["quick"]["status"] != "pass":
            raise ManifestValidationError(f"{path}: program_complete requires quick validation")
        if packet["validation"]["full"]["status"] != "pass":
            raise ManifestValidationError(f"{path}: program_complete requires full validation")
        if app_build["status"] != "passed":
            raise ManifestValidationError(f"{path}: program_complete requires app build proof")
        if packet["validation"]["browser"]["status"] != "pass":
            raise ManifestValidationError(f"{path}: program_complete requires browser proof")
        incomplete_gate_4 = [
            name for name, status in packet["gate_4"].items() if status != "verified"
        ]
        if incomplete_gate_4:
            raise ManifestValidationError(
                f"{path}: program_complete has incomplete Gate 4 proof: "
                f"{', '.join(incomplete_gate_4)}"
            )
        if packet["observation"]["status"] != "passed":
            raise ManifestValidationError(f"{path}: program_complete requires passed observation")
        invalid_deployments = [
            provider
            for provider, deployment in packet["deployments"].items()
            if deployment["status"] not in {"verified", "not_applicable"}
        ]
        if invalid_deployments:
            raise ManifestValidationError(
                f"{path}: program_complete has unverified deployments: "
                f"{', '.join(invalid_deployments)}"
            )
        invalid_compatibility = [
            f"{case['app_revision']}/{case['backend_revision']}={case['status']}"
            for case in packet["contracts"]["compatibility_matrix"]
            if case["status"] != "pass"
        ]
        if invalid_compatibility:
            raise ManifestValidationError(
                f"{path}: program_complete compatibility cases must pass: "
                f"{', '.join(invalid_compatibility)}"
            )

        observation = packet["observation"]
        observation_started = observation.get("started_at")
        observation_ends = observation.get("ends_at")
        if not isinstance(observation_started, str) or not isinstance(observation_ends, str):
            raise ManifestValidationError(
                f"{path}: program_complete requires observation started_at and ends_at"
            )
        observed_duration = _timestamp(observation_ends) - _timestamp(observation_started)
        minimum_duration = timedelta(days=observation["gate5_minimum_days"])
        if observed_duration < minimum_duration:
            raise ManifestValidationError(
                f"{path}: program_complete observation does not meet the minimum "
                f"{observation['gate5_minimum_days']}-day window"
            )
        if _timestamp(packet["updated_at"]) < _timestamp(observation_ends):
            raise ManifestValidationError(
                f"{path}: updated_at precedes completed observation window"
            )

        for label, evidence_ids in completion_evidence_claims(packet):
            if not evidence_ids:
                raise ManifestValidationError(
                    f"{path}: program_complete {label} requires evidence"
                )


def validate_completion_evidence(
    packet: Mapping[str, Any],
    path: Path,
    evidence: Mapping[str, tuple[Mapping[str, Any], Path]],
) -> None:
    if packet["state"] != "program_complete":
        return
    packet_updated_at = _timestamp(packet["updated_at"])
    for label, evidence_ids in completion_evidence_claims(packet):
        nonpassing = [
            evidence_id
            for evidence_id in evidence_ids
            if evidence[evidence_id][0]["result"] != "pass"
        ]
        if nonpassing:
            raise ManifestValidationError(
                f"{path}: program_complete {label} requires passing evidence: "
                f"{', '.join(nonpassing)}"
            )
        postdated = [
            evidence_id
            for evidence_id in evidence_ids
            if _timestamp(evidence[evidence_id][0]["finished_at"]) > packet_updated_at
        ]
        if postdated:
            raise ManifestValidationError(
                f"{path}: program_complete {label} evidence postdates packet updated_at: "
                f"{', '.join(postdated)}"
            )


def _validate_parked_path(value: Any, label: str) -> tuple[str, str]:
    if not isinstance(value, Mapping):
        raise ManifestValidationError(f"parked manifest {label} must be an object")
    repository = value.get("repository")
    relative_path = value.get("path")
    if repository not in REPOSITORY_PATHS:
        raise ManifestValidationError(
            f"parked manifest {label} has invalid repository: {repository}"
        )
    if not isinstance(relative_path, str):
        raise ManifestValidationError(f"parked manifest {label} path must be a string")
    normalized = _normalized_owned_paths([relative_path])[0]
    return str(repository), normalized


def validate_parked_work_manifest(
    document: Any,
    path: Path,
) -> Mapping[str, Any]:
    if not isinstance(document, Mapping):
        raise ManifestValidationError(f"{path}: parked manifest must be an object")
    required = {
        "schema_version",
        "manifest_id",
        "truth_scope",
        "captured_at",
        "repositories",
        "entries",
        "excluded_non_architecture_paths",
        "promotion_policy",
    }
    missing = sorted(required - document.keys())
    extra = sorted(document.keys() - required)
    if missing:
        raise ManifestValidationError(
            f"{path}: parked-unaccepted-local-work missing fields: {', '.join(missing)}"
        )
    if extra:
        raise ManifestValidationError(
            f"{path}: parked-unaccepted-local-work has unexpected fields: {', '.join(extra)}"
        )
    if document["schema_version"] != 1:
        raise ManifestValidationError(f"{path}: parked manifest schema_version must be 1")
    if document["manifest_id"] != "parked-unaccepted-local-work":
        raise ManifestValidationError(
            f"{path}: manifest_id must be parked-unaccepted-local-work"
        )
    if document["truth_scope"] != "local":
        raise ManifestValidationError(f"{path}: parked manifest truth_scope must be local")
    try:
        _timestamp(document["captured_at"])
    except (TypeError, ValueError) as exc:
        raise ManifestValidationError(f"{path}: captured_at must be a date-time") from exc
    repositories = document["repositories"]
    if not isinstance(repositories, Mapping) or set(repositories) != set(REPOSITORY_PATHS):
        raise ManifestValidationError(
            f"{path}: parked manifest repositories must be workspace, app, and backend"
        )
    for repository, revision in repositories.items():
        if not isinstance(revision, Mapping) or set(revision) != {"base_sha"}:
            raise ManifestValidationError(
                f"{path}: parked repository {repository} must contain only base_sha"
            )
        if not re.fullmatch(r"[0-9a-f]{40}", str(revision["base_sha"])):
            raise ManifestValidationError(
                f"{path}: parked repository {repository} has invalid base_sha"
            )

    entries = document["entries"]
    exclusions = document["excluded_non_architecture_paths"]
    if not isinstance(entries, list) or not isinstance(exclusions, list):
        raise ManifestValidationError(f"{path}: parked path collections must be arrays")
    entry_keys: list[tuple[str, str]] = []
    for index, entry in enumerate(entries):
        key = _validate_parked_path(entry, f"entries[{index}]")
        entry_keys.append(key)
        required_entry_fields = {"repository", "path", "status", "owner", "reason", "missing_proof", "next_action"}
        missing_entry_fields = sorted(required_entry_fields - entry.keys())
        if missing_entry_fields:
            raise ManifestValidationError(
                f"{path}: parked entry {key[0]}:{key[1]} missing "
                f"{', '.join(missing_entry_fields)}"
            )
        if set(entry) != required_entry_fields:
            unexpected = sorted(set(entry) - required_entry_fields)
            raise ManifestValidationError(
                f"{path}: parked entry {key[0]}:{key[1]} has unexpected fields: "
                f"{', '.join(unexpected)}"
            )
        if entry["status"] not in {
            "modified",
            "added",
            "deleted",
            "renamed",
            "copied",
            "unmerged",
            "untracked",
        }:
            raise ManifestValidationError(
                f"{path}: parked entry {key[0]}:{key[1]} has invalid status"
            )
        for field in ("owner", "reason", "next_action"):
            if not isinstance(entry[field], str) or not entry[field].strip():
                raise ManifestValidationError(
                    f"{path}: parked entry {key[0]}:{key[1]} requires {field}"
                )
        if (
            not isinstance(entry["missing_proof"], list)
            or not entry["missing_proof"]
            or any(
                not isinstance(item, str) or not item.strip()
                for item in entry["missing_proof"]
            )
        ):
            raise ManifestValidationError(
                f"{path}: parked entry {key[0]}:{key[1]} requires missing_proof"
            )

    exclusion_keys: list[tuple[str, str]] = []
    for index, exclusion in enumerate(exclusions):
        key = _validate_parked_path(
            exclusion,
            f"excluded_non_architecture_paths[{index}]",
        )
        exclusion_keys.append(key)
        if set(exclusion) != {"repository", "path", "status", "reason"}:
            raise ManifestValidationError(
                f"{path}: excluded path {key[0]}:{key[1]} must contain repository, "
                "path, status, and reason"
            )
        if not isinstance(exclusion["reason"], str) or not exclusion["reason"].strip():
            raise ManifestValidationError(
                f"{path}: excluded path {key[0]}:{key[1]} requires reason"
            )
    if entry_keys != sorted(entry_keys):
        raise ManifestValidationError(f"{path}: parked entries must be sorted")
    if exclusion_keys != sorted(exclusion_keys):
        raise ManifestValidationError(f"{path}: excluded paths must be sorted")
    if len(entry_keys) != len(set(entry_keys)) or len(exclusion_keys) != len(set(exclusion_keys)):
        raise ManifestValidationError(f"{path}: parked path collections contain duplicates")
    overlap = sorted(set(entry_keys) & set(exclusion_keys))
    if overlap:
        raise ManifestValidationError(
            f"{path}: paths cannot be both parked and excluded: "
            + ", ".join(f"{repository}:{item}" for repository, item in overlap)
        )
    if not isinstance(document["promotion_policy"], str) or not document["promotion_policy"].strip():
        raise ManifestValidationError(f"{path}: promotion_policy must be non-empty")
    return document


def validate_required_local_packet_set(
    packets: Mapping[str, tuple[Mapping[str, Any], Path]],
    evidence: Mapping[str, tuple[Mapping[str, Any], Path]],
) -> None:
    missing = sorted(REQUIRED_LOCAL_PACKET_IDS - packets.keys())
    if missing:
        raise ManifestValidationError(
            "missing required local packet IDs: " + ", ".join(missing)
        )
    for packet_id in sorted(REQUIRED_LOCAL_PACKET_IDS):
        packet, path = packets[packet_id]
        if packet["truth_scope"] != "local":
            raise ManifestValidationError(f"{path}: required local packet truth_scope must be local")
        if packet["state"] != "implementation_complete_parked":
            raise ManifestValidationError(
                f"{path}: required local packet state must be implementation_complete_parked"
            )
        if packet["validation"]["quick"]["status"] != "pass":
            raise ManifestValidationError(f"{path}: required local packet quick validation must pass")
        evidence_ids = packet["validation"]["evidence_ids"]
        if not evidence_ids:
            raise ManifestValidationError(f"{path}: required local packet has no evidence")
        invalid_evidence = [
            evidence_id
            for evidence_id in evidence_ids
            if evidence[evidence_id][0]["truth_scope"] != "local"
            or evidence[evidence_id][0]["result"] != "pass"
        ]
        if invalid_evidence:
            raise ManifestValidationError(
                f"{path}: required local packet evidence must pass at local truth scope: "
                f"{', '.join(invalid_evidence)}"
            )
        if packet["review"]["verdict"] not in {
            "accepted_local",
            "accepted_with_follow_up",
        }:
            raise ManifestValidationError(
                f"{path}: required local packet review verdict is not accepted"
            )


def _status_category(status: bytes) -> str:
    if status == b"??":
        return "untracked"
    if b"U" in status or status in {b"AA", b"DD"}:
        return "unmerged"
    if b"R" in status:
        return "renamed"
    if b"C" in status:
        return "copied"
    if b"D" in status:
        return "deleted"
    if b"A" in status:
        return "added"
    return "modified"


def repository_dirty_paths(repository: Path) -> dict[str, str]:
    output = _git_bytes(
        repository,
        "status",
        "--porcelain=v1",
        "-z",
        "--untracked-files=all",
    )
    dirty: dict[str, str] = {}
    records = output.split(b"\0")
    index = 0
    while index < len(records):
        record = records[index]
        index += 1
        if not record:
            continue
        status = record[:2]
        relative_path = record[3:].decode("utf-8", errors="surrogateescape")
        dirty[relative_path] = _status_category(status)
        if b"R" in status or b"C" in status:
            index += 1
    return dirty


def validate_packet_supersessions(
    packets: Mapping[str, tuple[Mapping[str, Any], Path]],
) -> tuple[
    dict[tuple[str, str, str], str],
    dict[tuple[str, str, str], str],
]:
    """Validate explicit path ownership handoffs and return superseded owners.

    The first returned mapping identifies transferred paths. The second holds
    per-path record hashes for local predecessor paths that remain live.
    Committed predecessors remain reproducible from their candidate trees.
    """
    ownership: dict[tuple[str, str], set[str]] = {}
    for packet_id, (packet, _) in packets.items():
        for repository, revision in packet["repositories"].items():
            for relative_path in revision["owned_paths"]:
                ownership.setdefault((repository, relative_path), set()).add(packet_id)

    claims: set[tuple[str, str, str, str]] = set()
    claim_paths: dict[tuple[str, str, str, str], Path] = {}
    handoff_claims: dict[tuple[str, str, str], set[str]] = {}
    handoff_records: dict[tuple[str, str, str], dict[str, str]] = {}
    handoff_paths: dict[tuple[str, str, str], Path] = {}
    for successor_id, (successor, successor_path) in packets.items():
        for supersession in successor.get("supersedes", []):
            predecessor_id = supersession["packet_id"]
            repository = supersession["repository"]
            if predecessor_id == successor_id:
                raise ManifestValidationError(
                    f"{successor_path}: packet cannot supersede itself"
                )
            predecessor_entry = packets.get(predecessor_id)
            if predecessor_entry is None:
                raise ManifestValidationError(
                    f"{successor_path}: supersession references unknown packet_id: "
                    f"{predecessor_id}"
                )
            predecessor = predecessor_entry[0]
            handoff_key = (predecessor_id, repository, successor_id)
            handoff_claims.setdefault(handoff_key, set())
            handoff_records.setdefault(handoff_key, {})
            handoff_paths[handoff_key] = successor_path
            successor_owned = set(successor["repositories"][repository]["owned_paths"])
            predecessor_owned = set(
                predecessor["repositories"][repository]["owned_paths"]
            )
            for relative_path in supersession["paths"]:
                if relative_path not in successor_owned or relative_path not in predecessor_owned:
                    raise ManifestValidationError(
                        f"{successor_path}: supersession path is not owned by both packets: "
                        f"{repository}:{relative_path}"
                    )
                claim = (successor_id, predecessor_id, repository, relative_path)
                if claim in claims:
                    raise ManifestValidationError(
                        f"{successor_path}: duplicate supersession claim for "
                        f"{predecessor_id}:{repository}:{relative_path}"
                    )
                claims.add(claim)
                claim_paths[claim] = successor_path
                handoff_claims[handoff_key].add(relative_path)
            for record in supersession.get("retained_path_records", []):
                record_path = record["path"]
                if record_path in handoff_records[handoff_key]:
                    raise ManifestValidationError(
                        f"{successor_path}: duplicate retained predecessor path record "
                        f"for {predecessor_id}:{repository}:{record_path}"
                    )
                handoff_records[handoff_key][record_path] = record["record_sha256"]

    for successor_id, predecessor_id, repository, relative_path in sorted(claims):
        reverse = (predecessor_id, successor_id, repository, relative_path)
        if reverse in claims:
            raise ManifestValidationError(
                f"{claim_paths[(successor_id, predecessor_id, repository, relative_path)]}: "
                "ambiguous mutual supersession for "
                f"{repository}:{relative_path} between {predecessor_id} and {successor_id}"
            )

    superseded: dict[tuple[str, str, str], str] = {}
    predecessor_by_successor: dict[tuple[str, str, str], str] = {}
    for successor_id, predecessor_id, repository, relative_path in sorted(claims):
        key = (predecessor_id, repository, relative_path)
        existing = superseded.get(key)
        if existing is not None and existing != successor_id:
            raise ManifestValidationError(
                "ambiguous supersession fork has multiple immediate successors for "
                f"{predecessor_id}:{repository}:{relative_path}: "
                f"{existing}, {successor_id}"
            )
        superseded[key] = successor_id
        successor_key = (successor_id, repository, relative_path)
        existing_predecessor = predecessor_by_successor.get(successor_key)
        if existing_predecessor is not None and existing_predecessor != predecessor_id:
            raise ManifestValidationError(
                "ambiguous supersession merge has multiple immediate predecessors for "
                f"{successor_id}:{repository}:{relative_path}: "
                f"{existing_predecessor}, {predecessor_id}"
            )
        predecessor_by_successor[successor_key] = predecessor_id

    for predecessor_id, repository, relative_path in sorted(superseded):
        current = predecessor_id
        visited: list[str] = []
        while current not in visited:
            visited.append(current)
            next_owner = superseded.get((current, repository, relative_path))
            if next_owner is None:
                break
            current = next_owner
        else:
            cycle_start = visited.index(current)
            cycle = [*visited[cycle_start:], current]
            raise ManifestValidationError(
                "supersession cycle detected for "
                f"{repository}:{relative_path}: {' -> '.join(cycle)}"
            )

    for successor_id, predecessor_id, repository, relative_path in sorted(claims):
        successor = packets[successor_id][0]
        predecessor = packets[predecessor_id][0]
        if _timestamp(successor["created_at"]) <= _timestamp(predecessor["created_at"]):
            raise ManifestValidationError(
                f"{claim_paths[(successor_id, predecessor_id, repository, relative_path)]}: "
                f"superseding packet must be newer than {predecessor_id}: "
                f"{repository}:{relative_path}"
            )

    def reaches(
        predecessor_id: str,
        successor_id: str,
        repository: str,
        relative_path: str,
    ) -> bool:
        current = predecessor_id
        visited: set[str] = set()
        while current not in visited:
            if current == successor_id:
                return True
            visited.add(current)
            next_owner = superseded.get((current, repository, relative_path))
            if next_owner is None:
                return False
            current = next_owner
        raise ManifestValidationError(
            "supersession cycle detected for "
            f"{repository}:{relative_path}: {', '.join(sorted(visited))}"
        )

    for (repository, relative_path), owners in sorted(ownership.items()):
        ordered_owners = sorted(owners)
        for index, first in enumerate(ordered_owners):
            for second in ordered_owners[index + 1 :]:
                if not reaches(first, second, repository, relative_path) and not reaches(
                    second,
                    first,
                    repository,
                    relative_path,
                ):
                    raise ManifestValidationError(
                        "silent owned-path overlap requires a connected supersession chain: "
                        f"{repository}:{relative_path} is owned by {first} and {second}"
                    )

    retained_records: dict[tuple[str, str, str], str] = {}
    handoffs_by_predecessor: dict[tuple[str, str], list[str]] = {}
    for predecessor_id, repository, successor_id in handoff_claims:
        handoffs_by_predecessor.setdefault((predecessor_id, repository), []).append(
            successor_id
        )

    for predecessor_id, repository in sorted(handoffs_by_predecessor):
        predecessor, predecessor_path = packets[predecessor_id]
        revision = predecessor["repositories"][repository]
        predecessor_owned_paths = set(revision["owned_paths"])
        retained_paths = set(revision["owned_paths"])
        ordered_successors = sorted(
            handoffs_by_predecessor[(predecessor_id, repository)],
            key=lambda successor_id: (
                _timestamp(packets[successor_id][0]["created_at"]),
                successor_id,
            ),
        )
        for successor_id in ordered_successors:
            handoff_key = (predecessor_id, repository, successor_id)
            claimed_paths = handoff_claims[handoff_key]
            actual_records = handoff_records[handoff_key]
            if revision["revision_type"] == "committed_candidate":
                if actual_records:
                    raise ManifestValidationError(
                        f"{predecessor_path}: committed predecessor must not use retained "
                        f"path records for {repository}"
                    )
                retained_paths -= claimed_paths
                continue

            for relative_path, record_sha256 in actual_records.items():
                if relative_path not in predecessor_owned_paths:
                    raise ManifestValidationError(
                        f"{handoff_paths[handoff_key]}: retained predecessor path record "
                        f"is not owned by {predecessor_id}: "
                        f"{repository}:{relative_path}"
                    )
                if relative_path in claimed_paths:
                    raise ManifestValidationError(
                        f"{handoff_paths[handoff_key]}: retained predecessor path record "
                        f"is claimed in the same handoff: "
                        f"{repository}:{relative_path}"
                    )
                if relative_path not in retained_paths:
                    raise ManifestValidationError(
                        f"{handoff_paths[handoff_key]}: retained predecessor path record "
                        f"was already transferred: {repository}:{relative_path}"
                    )
                record_key = (predecessor_id, repository, relative_path)
                previous_sha256 = retained_records.get(record_key)
                if previous_sha256 is not None and previous_sha256 != record_sha256:
                    raise ManifestValidationError(
                        f"{handoff_paths[handoff_key]}: retained predecessor path record "
                        f"conflicts with earlier handoff for "
                        f"{predecessor_id}:{repository}:{relative_path}"
                    )
                retained_records[record_key] = record_sha256
            for relative_path in claimed_paths:
                retained_records.pop((predecessor_id, repository, relative_path), None)
            retained_paths -= claimed_paths
        if revision["revision_type"] == "local_dirty_checkpoint":
            actual_retained_paths = {
                relative_path
                for packet_id, repository_name, relative_path in retained_records
                if packet_id == predecessor_id and repository_name == repository
            }
            if actual_retained_paths != retained_paths:
                missing = sorted(retained_paths - actual_retained_paths)
                unexpected = sorted(actual_retained_paths - retained_paths)
                details: list[str] = []
                if missing:
                    details.append("missing " + ", ".join(missing))
                if unexpected:
                    details.append("unexpected " + ", ".join(unexpected))
                raise ManifestValidationError(
                    f"{predecessor_path}: final retained predecessor path records "
                    f"must match the live retained set for {repository}: "
                    f"{'; '.join(details)}"
                )
    return superseded, retained_records


def validate_current_checkpoint(
    root: Path,
    packets: Mapping[str, tuple[Mapping[str, Any], Path]],
    parked: Mapping[str, Any],
    superseded: Mapping[tuple[str, str, str], str],
    retained_records: Mapping[tuple[str, str, str], str],
) -> None:
    local_dirty_paths: dict[str, set[str]] = {
        name: set() for name in REPOSITORY_PATHS
    }
    ordered_packet_ids = sorted(
        packets,
        key=lambda packet_id: (
            _timestamp(packets[packet_id][0]["created_at"]),
            packet_id,
        ),
    )
    for packet_id in ordered_packet_ids:
        packet, packet_path = packets[packet_id]
        for repository, revision in packet["repositories"].items():
            repository_root = (root / REPOSITORY_PATHS[repository]).resolve()
            superseded_paths = {
                relative_path
                for relative_path in revision["owned_paths"]
                if (packet_id, repository, relative_path) in superseded
            }
            if revision["revision_type"] == "local_dirty_checkpoint":
                retained_paths = set(revision["owned_paths"]) - superseded_paths
                if superseded_paths:
                    for relative_path in sorted(retained_paths):
                        actual_record_sha256 = hashlib.sha256(
                            _owned_path_record(repository_root, relative_path)
                        ).hexdigest()
                        expected_record_sha256 = retained_records[
                            (packet_id, repository, relative_path)
                        ]
                        if actual_record_sha256 != expected_record_sha256:
                            raise ManifestValidationError(
                                f"{packet_path}: retained predecessor path record does "
                                f"not match current repository state: "
                                f"{repository}:{relative_path}"
                            )
                try:
                    validate_local_dirty_checkpoint(repository_root, revision, packet_path)
                except ManifestValidationError:
                    if not superseded_paths:
                        raise
                local_dirty_paths[repository].update(retained_paths)
            else:
                validate_committed_candidate(repository_root, revision, packet_path)

    parked_paths = {
        repository: {
            entry["path"]: entry["status"]
            for entry in parked["entries"]
            if entry["repository"] == repository
        }
        for repository in REPOSITORY_PATHS
    }
    excluded_paths = {
        repository: {
            entry["path"]: entry["status"]
            for entry in parked["excluded_non_architecture_paths"]
            if entry["repository"] == repository
        }
        for repository in REPOSITORY_PATHS
    }
    auto_classified_workspace = {
        DEFAULT_PARKED_WORK_MANIFEST.as_posix(),
        *(
            path.relative_to(root).as_posix()
            for path in discover_json(root / DEFAULT_PACKET_DIRECTORY)
        ),
        *(
            path.relative_to(root).as_posix()
            for path in discover_json(root / DEFAULT_EVIDENCE_DIRECTORY)
        ),
    }
    for repository, repository_path in REPOSITORY_PATHS.items():
        repository_root = (root / repository_path).resolve()
        actual = repository_dirty_paths(repository_root)
        classified = local_dirty_paths[repository] | set(parked_paths[repository]) | set(excluded_paths[repository])
        if repository == "workspace":
            classified |= auto_classified_workspace
        unclassified = sorted(set(actual) - classified)
        if unclassified:
            raise ManifestValidationError(
                f"unclassified architecture dirty paths in {repository}: "
                + ", ".join(unclassified)
            )
        stale = sorted(classified - set(actual))
        stale = [path for path in stale if path not in auto_classified_workspace]
        if stale:
            raise ManifestValidationError(
                f"classified paths are not currently dirty in {repository}: "
                + ", ".join(stale)
            )
        for relative_path, expected_status in {
            **parked_paths[repository],
            **excluded_paths[repository],
        }.items():
            if actual.get(relative_path) != expected_status:
                raise ManifestValidationError(
                    f"{repository}:{relative_path} status changed from "
                    f"{expected_status} to {actual.get(relative_path)}"
                )


def validate_clean_candidate_checkpoint(
    root: Path,
    packets: Mapping[str, tuple[Mapping[str, Any], Path]],
) -> None:
    """Validate exact committed candidates without requiring parked live dirt."""
    for packet_id in sorted(packets):
        packet, packet_path = packets[packet_id]
        for repository, revision in packet["repositories"].items():
            if revision["revision_type"] != "committed_candidate":
                raise ManifestValidationError(
                    f"{packet_path}: clean-candidate mode requires a committed "
                    f"candidate revision for {repository}"
                )
            repository_root = (root / REPOSITORY_PATHS[repository]).resolve()
            validate_committed_candidate(
                repository_root,
                revision,
                packet_path,
                require_current_clean=True,
            )


def discover_json(directory: Path) -> list[Path]:
    return sorted(directory.rglob("*.json")) if directory.is_dir() else []


def prepare_candidate_promotion(
    root: Path,
    packet_paths: Iterable[Path],
    packet_id: str,
    repository: str,
    candidate_sha: str,
) -> tuple[Path, dict[str, Any]]:
    """Build and validate one packet-repository candidate promotion in memory."""
    root = root.resolve()
    packet_schema_path = _workspace_manifest_path(root, PACKET_SCHEMA)
    packet_schema = load_json(packet_schema_path)
    validate_schema(packet_schema, packet_schema_path)

    matches: list[tuple[Path, Mapping[str, Any]]] = []
    for raw_path in packet_paths:
        path = _workspace_manifest_path(root, raw_path)
        document = load_json(path)
        validate_document(document, packet_schema, path)
        scan_secret_free(document)
        validate_packet_semantics(document, path)
        if document["packet_id"] == packet_id:
            matches.append((path, document))
    if not matches:
        raise ManifestValidationError(f"packet_id not found for promotion: {packet_id}")
    if len(matches) != 1:
        raise ManifestValidationError(
            f"packet_id is not unique for promotion: {packet_id}"
        )

    packet_path, packet = matches[0]
    revision = packet["repositories"][repository]
    if revision["revision_type"] != "local_dirty_checkpoint":
        raise ManifestValidationError(
            f"{packet_path}: {repository} revision is not a local_dirty_checkpoint"
        )

    repository_root = (root / REPOSITORY_PATHS[repository]).resolve()
    captured = capture_committed_candidate(
        repository_root,
        revision["base_sha"],
        candidate_sha,
        revision["owned_paths"],
    )
    promoted_revision = {
        **captured,
        "owned_path_manifest_sha256": revision["owned_path_manifest_sha256"],
    }
    validate_committed_candidate(
        repository_root,
        promoted_revision,
        packet_path,
        require_current_clean=True,
    )

    now = datetime.now(timezone.utc)
    previous_updated_at = _timestamp(packet["updated_at"])
    if now <= previous_updated_at:
        now = previous_updated_at + timedelta(seconds=1)
    promoted_packet = {
        **packet,
        "updated_at": now.isoformat(timespec="seconds").replace("+00:00", "Z"),
        "repositories": {
            **packet["repositories"],
            repository: promoted_revision,
        },
    }
    validate_document(promoted_packet, packet_schema, packet_path)
    scan_secret_free(promoted_packet)
    validate_packet_semantics(promoted_packet, packet_path)
    return packet_path, promoted_packet


def validate_manifests(
    root: Path,
    packet_paths: Iterable[Path],
    evidence_paths: Iterable[Path],
    *,
    require_packets: bool = False,
    require_r0_local_set: bool = False,
    parked_path: Path | None = None,
    verify_current: bool = False,
    verify_clean_candidate: bool = False,
) -> tuple[int, int]:
    if verify_current and verify_clean_candidate:
        raise ManifestValidationError(
            "cannot validate both live workspace and clean-candidate checkpoints"
        )
    if verify_clean_candidate and not require_r0_local_set:
        raise ManifestValidationError(
            "clean-candidate validation requires the complete required R0 packet set"
        )
    root = root.resolve()
    packet_schema_path = _workspace_manifest_path(root, PACKET_SCHEMA)
    evidence_schema_path = _workspace_manifest_path(root, EVIDENCE_SCHEMA)
    packet_schema = load_json(packet_schema_path)
    evidence_schema = load_json(evidence_schema_path)
    validate_schema(packet_schema, packet_schema_path)
    validate_schema(evidence_schema, evidence_schema_path)

    packets: dict[str, tuple[Mapping[str, Any], Path]] = {}
    evidence: dict[str, tuple[Mapping[str, Any], Path]] = {}
    for raw_path in packet_paths:
        path = _workspace_manifest_path(root, raw_path)
        document = load_json(path)
        validate_document(document, packet_schema, path)
        scan_secret_free(document)
        validate_packet_semantics(document, path)
        packet_id = document["packet_id"]
        if packet_id in packets:
            raise ManifestValidationError(f"duplicate packet_id: {packet_id}")
        packets[packet_id] = (document, path)

    superseded, retained_records = validate_packet_supersessions(packets)

    for raw_path in evidence_paths:
        path = _workspace_manifest_path(root, raw_path)
        document = load_json(path)
        validate_document(document, evidence_schema, path)
        scan_secret_free(document)
        validate_evidence_semantics(document, path)
        evidence_id = document["evidence_id"]
        if evidence_id in evidence:
            raise ManifestValidationError(f"duplicate evidence_id: {evidence_id}")
        evidence[evidence_id] = (document, path)

    if require_packets and not packets:
        raise ManifestValidationError("no release packets were found")

    for packet_id, (packet, path) in packets.items():
        referenced_evidence = packet_evidence_ids(packet)
        missing = sorted(referenced_evidence - evidence.keys())
        if missing:
            raise ManifestValidationError(
                f"{path}: missing referenced evidence: {', '.join(missing)}"
            )
        foreign = sorted(
            evidence_id
            for evidence_id in referenced_evidence
            if evidence[evidence_id][0]["packet_id"] != packet_id
        )
        if foreign:
            owners = ", ".join(
                f"{evidence_id} for {evidence[evidence_id][0]['packet_id']}"
                for evidence_id in foreign
            )
            raise ManifestValidationError(
                f"{path}: packet references evidence for another packet: {owners}"
            )
        validate_pass_claim_evidence(packet, path, evidence)
        validate_completion_evidence(packet, path, evidence)
        mismatched = sorted(
            evidence_id
            for evidence_id, (item, _) in evidence.items()
            if item["packet_id"] == packet_id and evidence_id not in referenced_evidence
        )
        if mismatched:
            raise ManifestValidationError(
                f"{path}: packet does not reference its evidence: {', '.join(mismatched)}"
            )

    orphaned = sorted(
        evidence_id
        for evidence_id, (item, _) in evidence.items()
        if item["packet_id"] not in packets
    )
    if orphaned:
        raise ManifestValidationError(
            f"evidence references unknown packets: {', '.join(orphaned)}"
        )

    if require_r0_local_set:
        validate_required_local_packet_set(packets, evidence)
        raw_parked_path = parked_path or DEFAULT_PARKED_WORK_MANIFEST
        resolved_parked_path = _workspace_manifest_path(root, raw_parked_path)
        if not resolved_parked_path.is_file():
            raise ManifestValidationError(
                f"required parked-unaccepted-local-work manifest is missing: "
                f"{raw_parked_path}"
            )
        parked = validate_parked_work_manifest(
            load_json(resolved_parked_path),
            resolved_parked_path,
        )
        scan_secret_free(parked)
        for packet_id in sorted(REQUIRED_LOCAL_PACKET_IDS):
            packet, packet_path = packets[packet_id]
            mismatched_bases = [
                repository
                for repository in REPOSITORY_PATHS
                if packet["repositories"][repository]["base_sha"]
                != parked["repositories"][repository]["base_sha"]
            ]
            if mismatched_bases:
                raise ManifestValidationError(
                    f"{packet_path}: base_sha does not match parked manifest for "
                    f"{', '.join(mismatched_bases)}"
                )
        if verify_current:
            validate_current_checkpoint(
                root,
                packets,
                parked,
                superseded,
                retained_records,
            )
        elif verify_clean_candidate:
            validate_clean_candidate_checkpoint(root, packets)
    return len(packets), len(evidence)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=WORKSPACE_ROOT)
    parser.add_argument("--packet", type=Path, action="append", default=[])
    parser.add_argument("--evidence", type=Path, action="append", default=[])
    parser.add_argument("--require-packets", action="store_true")
    parser.add_argument(
        "--allow-partial",
        action="store_true",
        help="Validate an explicitly incomplete packet set instead of the required R0 set.",
    )
    parser.add_argument(
        "--clean-candidate",
        action="store_true",
        help=(
            "Explicitly validate committed candidates without requiring the parked "
            "live-workspace dirt to be present."
        ),
    )
    parser.add_argument(
        "--promote-packet",
        help="Validate promotion of one named packet from a local checkpoint.",
    )
    parser.add_argument(
        "--repository",
        choices=sorted(REPOSITORY_PATHS),
        help="Repository revision to promote within the named packet.",
    )
    parser.add_argument(
        "--candidate-sha",
        help="Explicit full candidate commit SHA for promotion.",
    )
    parser.add_argument(
        "--write",
        action="store_true",
        help="Write a validated candidate promotion; otherwise promotion is a dry-run.",
    )
    args = parser.parse_args()

    root = args.root.resolve()
    packet_paths = args.packet or discover_json(root / DEFAULT_PACKET_DIRECTORY)
    evidence_paths = args.evidence or discover_json(root / DEFAULT_EVIDENCE_DIRECTORY)
    try:
        if args.clean_candidate and args.allow_partial:
            raise ManifestValidationError(
                "--clean-candidate cannot be combined with --allow-partial"
            )
        if args.promote_packet:
            if args.clean_candidate:
                raise ManifestValidationError(
                    "--clean-candidate cannot be combined with --promote-packet"
                )
            if not args.repository or not args.candidate_sha:
                raise ManifestValidationError(
                    "--promote-packet requires --repository and --candidate-sha"
                )
            packet_path, promoted_packet = prepare_candidate_promotion(
                root,
                packet_paths,
                args.promote_packet,
                args.repository,
                args.candidate_sha,
            )
            if args.write:
                packet_path.write_text(
                    json.dumps(promoted_packet, indent=2) + "\n",
                    encoding="utf-8",
                )
                action = "UPDATED"
            else:
                action = "DRY-RUN"
            print(
                f"architecture-release-manifests: {action} promotion "
                f"packet={args.promote_packet} repository={args.repository} "
                f"candidate_sha={args.candidate_sha} path={packet_path}"
            )
            return 0
        if args.repository or args.candidate_sha or args.write:
            raise ManifestValidationError(
                "--repository, --candidate-sha, and --write require --promote-packet"
            )
        packet_count, evidence_count = validate_manifests(
            root,
            packet_paths,
            evidence_paths,
            require_packets=args.require_packets,
            require_r0_local_set=not args.allow_partial,
            parked_path=DEFAULT_PARKED_WORK_MANIFEST,
            verify_current=not args.clean_candidate,
            verify_clean_candidate=args.clean_candidate,
        )
    except ManifestValidationError as exc:
        print(f"architecture-release-manifests: ERROR {exc}")
        return 1
    mode = "clean-candidate " if args.clean_candidate else ""
    print(f"architecture-release-manifests: OK {mode}packets={packet_count} evidence={evidence_count}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

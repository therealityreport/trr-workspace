#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any


DEFAULT_PROJECT_REF = "vwxfvzutyufrkhfgoeaa"
DEFAULT_TOKEN_ENV = "TRR_SUPABASE_ACCESS_TOKEN"
DEFAULT_OLDER_THAN_DAYS = 30
PROTECTED_BRANCH_NAMES = {"main", "production", "prod", "staging", "stage"}


@dataclass(frozen=True)
class CleanupCandidate:
    id: str
    name: str
    status: str
    project_ref: str
    age_days: int | None
    reason: str


def _parse_timestamp(value: Any) -> datetime | None:
    if not isinstance(value, str) or not value:
        return None
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def branch_age_days(branch: dict[str, Any], now: datetime) -> int | None:
    timestamp = _parse_timestamp(branch.get("updated_at")) or _parse_timestamp(branch.get("created_at"))
    if timestamp is None:
        return None
    return max(0, (now.astimezone(timezone.utc) - timestamp).days)


def select_cleanup_candidates(
    branches: list[dict[str, Any]],
    *,
    now: datetime,
    older_than_days: int,
    names: set[str],
) -> list[CleanupCandidate]:
    candidates: list[CleanupCandidate] = []

    for branch in branches:
        name = str(branch.get("name") or "")
        branch_id = str(branch.get("id") or "")
        if not name or not branch_id:
            continue
        if branch.get("is_default"):
            continue
        if branch.get("persistent"):
            continue
        if name in PROTECTED_BRANCH_NAMES:
            continue
        if names and name not in names and branch_id not in names:
            continue

        age_days = branch_age_days(branch, now)
        if names:
            reason = "explicit-name"
        elif age_days is None:
            continue
        elif age_days >= older_than_days:
            reason = f"older-than-{older_than_days}-days"
        else:
            continue

        candidates.append(
            CleanupCandidate(
                id=branch_id,
                name=name,
                status=str(branch.get("status") or "unknown"),
                project_ref=str(branch.get("project_ref") or ""),
                age_days=age_days,
                reason=reason,
            )
        )

    return sorted(candidates, key=lambda candidate: (candidate.name, candidate.id))


def _run_supabase(
    args: list[str],
    *,
    project_ref: str,
    token: str,
    timeout: float,
) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    # The CLI reads SUPABASE_ACCESS_TOKEN. Keep TRR's public contract on the
    # project-specific token and map it only into this child process.
    env["SUPABASE_ACCESS_TOKEN"] = token
    with tempfile.TemporaryDirectory(prefix="trr-supabase-branch-cleanup-") as workdir:
        return subprocess.run(
            ["supabase", *args, "--project-ref", project_ref, "--output", "json", "--workdir", workdir],
            env=env,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )


def list_branches(*, project_ref: str, token_env: str, token: str, timeout: float) -> list[dict[str, Any]]:
    result = _run_supabase(
        ["branches", "list"],
        project_ref=project_ref,
        token=token,
        timeout=timeout,
    )
    if result.returncode != 0:
        raise SystemExit(
            "[supabase-preview-branch-cleanup] ERROR: supabase branches list failed\n"
            + result.stderr.strip()
        )
    try:
        parsed = json.loads(result.stdout or "[]")
    except json.JSONDecodeError as exc:
        raise SystemExit(f"[supabase-preview-branch-cleanup] ERROR: invalid CLI JSON: {exc}") from exc
    if not isinstance(parsed, list):
        raise SystemExit("[supabase-preview-branch-cleanup] ERROR: expected branch list JSON")
    return [branch for branch in parsed if isinstance(branch, dict)]


def delete_branch(
    *,
    branch_id: str,
    project_ref: str,
    token_env: str,
    token: str,
    timeout: float,
) -> None:
    result = _run_supabase(
        ["branches", "delete", branch_id, "--yes"],
        project_ref=project_ref,
        token=token,
        timeout=timeout,
    )
    if result.returncode != 0:
        raise SystemExit(
            f"[supabase-preview-branch-cleanup] ERROR: failed to delete branch {branch_id}\n"
            + result.stderr.strip()
        )


def _render_human(candidates: list[CleanupCandidate], *, delete: bool) -> str:
    if not candidates:
        return "[supabase-preview-branch-cleanup] OK: no cleanup candidates found."

    action = "deleted" if delete else "dry-run"
    lines = [f"[supabase-preview-branch-cleanup] {action}: {len(candidates)} candidate(s)"]
    for candidate in candidates:
        age = "unknown-age" if candidate.age_days is None else f"{candidate.age_days}d"
        lines.append(
            "- "
            + f"{candidate.name} id={candidate.id} status={candidate.status} "
            + f"age={age} reason={candidate.reason}"
        )
    if not delete:
        lines.append(
            "[supabase-preview-branch-cleanup] Set DELETE=1 or pass --delete to remove these branches."
        )
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Dry-run-first cleanup for TRR Supabase preview branches.")
    parser.add_argument("--project-ref", default=DEFAULT_PROJECT_REF)
    parser.add_argument("--token-env", default=DEFAULT_TOKEN_ENV)
    parser.add_argument("--older-than-days", type=int, default=DEFAULT_OLDER_THAN_DAYS)
    parser.add_argument("--name", action="append", default=[], help="Only consider this branch name or branch ID.")
    parser.add_argument("--delete", action="store_true", help="Delete selected cleanup candidates.")
    parser.add_argument("--json", action="store_true", help="Emit JSON summary.")
    parser.add_argument("--timeout", type=float, default=60.0)
    args = parser.parse_args(argv)

    token = os.environ.get(args.token_env, "")
    if not token:
        legacy_note = ""
        if args.token_env != "SUPABASE_ACCESS_TOKEN" and os.environ.get("SUPABASE_ACCESS_TOKEN"):
            legacy_note = " SUPABASE_ACCESS_TOKEN is set but TRR cleanup uses TRR_SUPABASE_ACCESS_TOKEN."
        raise SystemExit(
            f"[supabase-preview-branch-cleanup] ERROR: {args.token_env} is not set.{legacy_note}"
        )

    names = {str(name) for name in args.name if str(name)}
    branches = list_branches(
        project_ref=args.project_ref,
        token_env=args.token_env,
        token=token,
        timeout=args.timeout,
    )
    candidates = select_cleanup_candidates(
        branches,
        now=datetime.now(timezone.utc),
        older_than_days=args.older_than_days,
        names=names,
    )

    deleted: list[str] = []
    if args.delete:
        for candidate in candidates:
            delete_branch(
                branch_id=candidate.id,
                project_ref=args.project_ref,
                token_env=args.token_env,
                token=token,
                timeout=args.timeout,
            )
            deleted.append(candidate.id)

    payload = {
        "project_ref": args.project_ref,
        "dry_run": not args.delete,
        "older_than_days": args.older_than_days,
        "candidates": [candidate.__dict__ for candidate in candidates],
        "deleted_branch_ids": deleted,
    }
    if args.json:
        print(json.dumps(payload, indent=2, sort_keys=True))
    else:
        print(_render_human(candidates, delete=args.delete))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

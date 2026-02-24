#!/usr/bin/env python3
"""Orchestrate multi-repo commit -> PR -> checks -> merge -> main sync."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import time
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

DEFAULT_CHECK_POLL_SECONDS = 8
MAX_FOLLOWUP_CYCLES = 5
TRR_ORDER = ["TRR-Backend", "screenalytics", "TRR-APP"]
FAIL_CONCLUSIONS = {"FAILURE", "FAILED", "TIMED_OUT", "CANCELLED", "ACTION_REQUIRED", "STARTUP_FAILURE"}
PASS_CONCLUSIONS = {"SUCCESS", "NEUTRAL", "SKIPPED"}
EXCLUDED_DIR_NAMES = {
    ".git",
    ".logs",
    ".venv",
    "node_modules",
    "dist",
    "build",
    ".next",
    ".cache",
    "__pycache__",
}


class OrchestrationError(Exception):
    """Raised when orchestration cannot continue."""


@dataclass(frozen=True)
class RepoTarget:
    name: str
    path: Path


def log(message: str) -> None:
    print(message, flush=True)


def now_iso() -> str:
    return datetime.now(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def parse_bool(value: str) -> bool:
    lowered = value.strip().lower()
    if lowered in {"1", "true", "yes", "y", "on"}:
        return True
    if lowered in {"0", "false", "no", "n", "off"}:
        return False
    raise argparse.ArgumentTypeError(f"Invalid boolean value: {value}")


def slugify(value: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
    return re.sub(r"-+", "-", slug)


def run_cmd(
    args: list[str],
    *,
    cwd: Path | None = None,
    check: bool = True,
    text: bool = True,
) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        args,
        cwd=str(cwd) if cwd else None,
        text=text,
        capture_output=True,
    )
    if check and result.returncode != 0:
        stderr = (result.stderr or "").strip()
        stdout = (result.stdout or "").strip()
        detail = stderr or stdout or f"exit {result.returncode}"
        raise OrchestrationError(f"Command failed: {' '.join(args)}\n{detail}")
    return result


def write_json_report(path: Path | None, report: dict[str, Any]) -> None:
    if not path:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")


def discover_repos(workspace_root: Path, explicit_repos: list[str] | None) -> list[RepoTarget]:
    repos: list[RepoTarget] = []

    def repo_root(path: Path) -> Path | None:
        if not path.exists() or not path.is_dir():
            return None
        probe = run_cmd(["git", "-C", str(path), "rev-parse", "--show-toplevel"], check=False)
        if probe.returncode != 0:
            return None
        value = (probe.stdout or "").strip()
        if not value:
            return None
        return Path(value).resolve()

    def to_repo(path: Path, *, allow_nested_path: bool) -> RepoTarget | None:
        top = repo_root(path)
        if top is None:
            return None
        resolved = path.resolve()
        if not allow_nested_path and top != resolved:
            return None
        return RepoTarget(name=top.name, path=top)

    if explicit_repos:
        for raw in explicit_repos:
            candidate = Path(raw)
            if not candidate.is_absolute():
                candidate = workspace_root / candidate
            repo = to_repo(candidate, allow_nested_path=True)
            if repo is None:
                raise OrchestrationError(f"Explicit repo is not a git repository: {raw}")
            repos.append(repo)
    else:
        root_repo = to_repo(workspace_root, allow_nested_path=False)
        if root_repo is not None:
            repos.append(root_repo)
        for child in sorted(workspace_root.iterdir(), key=lambda p: p.name.lower()):
            if not child.is_dir():
                continue
            if child.name.startswith("."):
                continue
            if child.name in EXCLUDED_DIR_NAMES:
                continue
            repo = to_repo(child, allow_nested_path=False)
            if repo is not None:
                repos.append(repo)

    if not repos:
        raise OrchestrationError(f"No git repositories found under {workspace_root}")
    unique: dict[str, RepoTarget] = {}
    for repo in repos:
        unique[str(repo.path)] = repo
    return list(unique.values())


def order_repos(repos: list[RepoTarget], mode: str) -> list[RepoTarget]:
    if mode == "alpha":
        return sorted(repos, key=lambda r: r.name.lower())

    by_name = {repo.name: repo for repo in repos}
    ordered: list[RepoTarget] = []
    for name in TRR_ORDER:
        repo = by_name.get(name)
        if repo:
            ordered.append(repo)

    trr_names = {repo.name for repo in ordered}
    remaining = sorted([repo for repo in repos if repo.name not in trr_names], key=lambda r: r.name.lower())
    return ordered + remaining


def parse_pr_number(url: str) -> int:
    m = re.search(r"/pull/(\d+)", url)
    if not m:
        raise OrchestrationError(f"Could not parse PR number from URL: {url}")
    return int(m.group(1))


def extract_run_ids(checks: list[dict[str, Any]]) -> list[int]:
    run_ids: set[int] = set()
    for check in checks:
        details = check.get("details_url") or ""
        m = re.search(r"/actions/runs/(\d+)", details)
        if m:
            run_ids.add(int(m.group(1)))
    return sorted(run_ids)


def get_current_branch(repo: RepoTarget) -> str:
    result = run_cmd(["git", "-C", str(repo.path), "branch", "--show-current"])
    return result.stdout.strip()


def working_tree_dirty(repo: RepoTarget) -> bool:
    result = run_cmd(["git", "-C", str(repo.path), "status", "--porcelain"])
    return bool(result.stdout.strip())


def preflight(repos: list[RepoTarget], base_branch: str) -> None:
    log("[preflight] Verifying gh auth status...")
    run_cmd(["gh", "auth", "status"])
    for repo in repos:
        log(f"[preflight] {repo.name}: checking origin and fetching {base_branch}...")
        run_cmd(["git", "-C", str(repo.path), "remote", "get-url", "origin"])
        fetch = run_cmd(["git", "-C", str(repo.path), "fetch", "origin", base_branch], check=False)
        if fetch.returncode != 0:
            raise OrchestrationError(
                f"{repo.name}: cannot fetch origin/{base_branch}.\n{(fetch.stderr or fetch.stdout).strip()}"
            )


def ensure_branch(repo: RepoTarget, branch_name: str, base_branch: str) -> None:
    dirty = working_tree_dirty(repo)
    current = get_current_branch(repo)
    remote_branch_probe = run_cmd(["git", "-C", str(repo.path), "ls-remote", "--heads", "origin", branch_name], check=False)
    remote_branch_has_ref = remote_branch_probe.returncode == 0 and bool(remote_branch_probe.stdout.strip())

    if not dirty:
        if current not in {base_branch, branch_name}:
            run_cmd(["git", "-C", str(repo.path), "checkout", base_branch])
        run_cmd(["git", "-C", str(repo.path), "pull", "--ff-only", "origin", base_branch])
    if remote_branch_has_ref:
        run_cmd(["git", "-C", str(repo.path), "fetch", "origin", branch_name])
        if current != branch_name:
            run_cmd(["git", "-C", str(repo.path), "checkout", "-B", branch_name, f"origin/{branch_name}"])
    else:
        run_cmd(["git", "-C", str(repo.path), "checkout", "-B", branch_name])


def stage_and_commit(
    repo: RepoTarget,
    *,
    create_noop: bool,
    commit_message: str,
    noop_commit_message: str,
) -> dict[str, Any]:
    run_cmd(["git", "-C", str(repo.path), "add", "-A"])
    staged = run_cmd(["git", "-C", str(repo.path), "diff", "--cached", "--quiet"], check=False)

    out: dict[str, Any] = {"created_commit": False, "noop_commit": False, "skipped_clean": False}
    if staged.returncode == 0:
        if not create_noop:
            out["skipped_clean"] = True
            return out
        run_cmd(["git", "-C", str(repo.path), "commit", "--allow-empty", "-m", noop_commit_message])
        out["created_commit"] = True
        out["noop_commit"] = True
        return out

    run_cmd(["git", "-C", str(repo.path), "commit", "-m", commit_message])
    out["created_commit"] = True
    return out


def push_branch(repo: RepoTarget, branch_name: str) -> None:
    run_cmd(["git", "-C", str(repo.path), "push", "-u", "origin", branch_name])


def get_or_create_pr(repo: RepoTarget, branch_name: str, base_branch: str) -> tuple[int, str]:
    existing = run_cmd(
        [
            "gh",
            "pr",
            "list",
            "--repo",
            _repo_slug(repo),
            "--head",
            branch_name,
            "--base",
            base_branch,
            "--state",
            "open",
            "--json",
            "number,url",
        ]
    )
    items = json.loads(existing.stdout or "[]")
    if items:
        item = items[0]
        return int(item["number"]), str(item["url"])

    title = f"chore: workspace sync for {repo.name}"
    body = (
        "## Summary\n"
        "- automated multi-repo sync PR\n"
        "- commits all staged workspace changes for this repository\n"
        "\n"
        "## Validation\n"
        "- CI checks pending"
    )
    created = run_cmd(
        [
            "gh",
            "pr",
            "create",
            "--repo",
            _repo_slug(repo),
            "--base",
            base_branch,
            "--head",
            branch_name,
            "--title",
            title,
            "--body",
            body,
        ]
    )
    url = (created.stdout or "").strip().splitlines()[-1].strip()
    return parse_pr_number(url), url


def _repo_slug(repo: RepoTarget) -> str:
    # Works for standard GitHub remotes like https://github.com/org/repo.git
    remote = run_cmd(["git", "-C", str(repo.path), "remote", "get-url", "origin"]).stdout.strip()
    m = re.search(r"github\.com[:/](.+?)(?:\.git)?$", remote)
    if not m:
        raise OrchestrationError(f"{repo.name}: unable to derive GitHub repo slug from origin URL: {remote}")
    return m.group(1)


def fetch_checks(repo: RepoTarget, pr_number: int) -> list[dict[str, Any]]:
    raw = run_cmd(
        ["gh", "pr", "view", str(pr_number), "--repo", _repo_slug(repo), "--json", "statusCheckRollup"]
    )
    payload = json.loads(raw.stdout or "{}")
    checks = payload.get("statusCheckRollup") or []

    out: list[dict[str, Any]] = []
    for check in checks:
        t = check.get("__typename")
        if t == "CheckRun":
            name = str(check.get("name") or "")
            status = str(check.get("status") or "").upper()
            conclusion = str(check.get("conclusion") or "").upper()
            details_url = check.get("detailsUrl")
            completed = status == "COMPLETED"
            success = completed and conclusion in PASS_CONCLUSIONS
            failed = completed and conclusion in FAIL_CONCLUSIONS
        else:
            # StatusContext
            name = str(check.get("context") or check.get("name") or "")
            state = str(check.get("state") or "").upper()
            details_url = check.get("targetUrl")
            completed = state in {"SUCCESS", "FAILURE", "ERROR"}
            success = state == "SUCCESS"
            failed = state in {"FAILURE", "ERROR"}
            status = "COMPLETED" if completed else "IN_PROGRESS"
            conclusion = state

        out.append(
            {
                "name": name,
                "status": status,
                "conclusion": conclusion,
                "details_url": details_url,
                "completed": completed,
                "success": success,
                "failed": failed,
            }
        )
    return out


def checks_snapshot(checks: list[dict[str, Any]]) -> str:
    if not checks:
        return "NO_CHECKS"
    compact = sorted([(c["name"], c["status"], c["conclusion"]) for c in checks], key=lambda x: x[0])
    return json.dumps(compact, separators=(",", ":"))


def rerun_stalled_runs(repo: RepoTarget, checks: list[dict[str, Any]]) -> dict[str, Any]:
    actions: list[dict[str, Any]] = []
    run_ids = extract_run_ids(checks)
    if not run_ids:
        actions.append({"action": "rerun", "result": "skipped", "reason": "no_github_actions_run_ids"})
        return {"actions": actions, "executed": False, "run_ids": []}

    for run_id in run_ids:
        cancel_cmd = ["gh", "run", "cancel", str(run_id), "--repo", _repo_slug(repo)]
        rerun_cmd = ["gh", "run", "rerun", str(run_id), "--repo", _repo_slug(repo)]

        cancel = run_cmd(cancel_cmd, check=False)
        actions.append(
            {
                "action": "cancel",
                "run_id": run_id,
                "ok": cancel.returncode == 0,
                "message": (cancel.stderr or cancel.stdout).strip(),
            }
        )
        time.sleep(1)
        rerun = run_cmd(rerun_cmd, check=False)
        actions.append(
            {
                "action": "rerun",
                "run_id": run_id,
                "ok": rerun.returncode == 0,
                "message": (rerun.stderr or rerun.stdout).strip(),
            }
        )
    return {"actions": actions, "executed": True, "run_ids": run_ids}


def fetch_run_progress(repo: RepoTarget, checks: list[dict[str, Any]]) -> list[dict[str, Any]]:
    progress: list[dict[str, Any]] = []
    for run_id in extract_run_ids(checks):
        viewed = run_cmd(
            [
                "gh",
                "run",
                "view",
                str(run_id),
                "--repo",
                _repo_slug(repo),
                "--json",
                "status,conclusion,updatedAt,createdAt,url,workflowName,jobs",
            ],
            check=False,
        )
        if viewed.returncode != 0:
            progress.append(
                {
                    "run_id": run_id,
                    "error": (viewed.stderr or viewed.stdout).strip() or f"exit {viewed.returncode}",
                }
            )
            continue
        payload = json.loads(viewed.stdout or "{}")
        jobs = payload.get("jobs") or []
        in_progress_jobs = []
        for job in jobs:
            status = str(job.get("status") or "")
            if status not in {"in_progress", "queued"}:
                continue
            in_progress_jobs.append(
                {
                    "name": job.get("name"),
                    "status": status,
                    "started_at": job.get("startedAt"),
                }
            )
        progress.append(
            {
                "run_id": run_id,
                "workflow_name": payload.get("workflowName"),
                "status": payload.get("status"),
                "conclusion": payload.get("conclusion"),
                "updated_at": payload.get("updatedAt"),
                "created_at": payload.get("createdAt"),
                "url": payload.get("url"),
                "in_progress_jobs": in_progress_jobs,
            }
        )
    return progress


def wait_for_checks(
    repo: RepoTarget,
    pr_number: int,
    *,
    ci_timeout_min: int,
    hung_threshold_min: int,
    stall_threshold_min: int,
    stall_reruns: int,
    check_poll_seconds: int,
    allow_admin_merge_on_stall: bool,
) -> dict[str, Any]:
    start = time.time()
    last_change = start
    last_snapshot = ""
    reruns_used = 0
    rerun_events: list[dict[str, Any]] = []

    while True:
        checks = fetch_checks(repo, pr_number)
        snapshot = checks_snapshot(checks)
        if snapshot != last_snapshot:
            last_snapshot = snapshot
            last_change = time.time()

        failed = [check for check in checks if check["failed"]]
        if failed:
            return {
                "result": "needs_fix",
                "checks": checks,
                "failing_checks": failed,
                "reruns_used": reruns_used,
                "rerun_events": rerun_events,
            }

        if checks and all(check["completed"] and check["success"] for check in checks):
            return {
                "result": "passed",
                "checks": checks,
                "failing_checks": [],
                "reruns_used": reruns_used,
                "rerun_events": rerun_events,
            }

        elapsed = time.time() - start
        since_change = time.time() - last_change
        checks_in_flight = not checks or any(not check["completed"] for check in checks)

        if elapsed >= ci_timeout_min * 60:
            return {
                "result": "stalled_admin_fallback" if allow_admin_merge_on_stall else "stalled_no_admin",
                "checks": checks,
                "failing_checks": [],
                "reruns_used": reruns_used,
                "rerun_events": rerun_events,
                "reason": "ci_timeout",
            }

        if checks_in_flight and since_change >= hung_threshold_min * 60 and reruns_used < stall_reruns:
            run_progress = fetch_run_progress(repo, checks)
            rerun_payload = rerun_stalled_runs(repo, checks)
            if rerun_payload.get("executed"):
                reruns_used += 1
                rerun_events.append(
                    {
                        "timestamp": now_iso(),
                        "trigger": "hung_candidate",
                        "since_change_seconds": int(since_change),
                        "rerun_index": reruns_used,
                        "run_progress": run_progress,
                        "actions": rerun_payload.get("actions", []),
                    }
                )
                last_change = time.time()
                time.sleep(3)
                continue

        if since_change >= stall_threshold_min * 60:
            if reruns_used < stall_reruns:
                run_progress = fetch_run_progress(repo, checks)
                rerun_payload = rerun_stalled_runs(repo, checks)
                if rerun_payload.get("executed"):
                    reruns_used += 1
                    rerun_events.append(
                        {
                            "timestamp": now_iso(),
                            "trigger": "stall_threshold",
                            "since_change_seconds": int(since_change),
                            "rerun_index": reruns_used,
                            "run_progress": run_progress,
                            "actions": rerun_payload.get("actions", []),
                        }
                    )
                    last_change = time.time()
                    time.sleep(3)
                    continue
                # No run IDs were available to rerun, so treat this as a hard stall.
                return {
                    "result": "stalled_admin_fallback" if allow_admin_merge_on_stall else "stalled_no_admin",
                    "checks": checks,
                    "failing_checks": [],
                    "reruns_used": reruns_used,
                    "rerun_events": rerun_events,
                    "reason": "stalled_checks_no_rerunnable_runs",
                }
            else:
                return {
                    "result": "stalled_admin_fallback" if allow_admin_merge_on_stall else "stalled_no_admin",
                    "checks": checks,
                    "failing_checks": [],
                    "reruns_used": reruns_used,
                    "rerun_events": rerun_events,
                    "reason": "stalled_checks",
                }

        time.sleep(check_poll_seconds)


def merge_pr(repo: RepoTarget, pr_number: int, *, admin: bool) -> dict[str, Any]:
    args = ["gh", "pr", "merge", str(pr_number), "--repo", _repo_slug(repo), "--merge", "--delete-branch"]
    if admin:
        args.insert(-1, "--admin")
    result = run_cmd(args, check=False)
    text = (result.stdout or "") + "\n" + (result.stderr or "")
    ok = result.returncode == 0 or "already merged" in text.lower()
    return {
        "ok": ok,
        "used_admin": admin,
        "output": text.strip(),
    }


def sync_main(repo: RepoTarget, base_branch: str) -> dict[str, Any]:
    run_cmd(["git", "-C", str(repo.path), "checkout", base_branch])
    run_cmd(["git", "-C", str(repo.path), "fetch", "origin", base_branch])
    run_cmd(["git", "-C", str(repo.path), "pull", "--ff-only", "origin", base_branch])

    local_sha = run_cmd(["git", "-C", str(repo.path), "rev-parse", "HEAD"]).stdout.strip()
    remote_sha = run_cmd(["git", "-C", str(repo.path), "rev-parse", f"origin/{base_branch}"]).stdout.strip()
    dirty = working_tree_dirty(repo)

    return {
        "local_sha": local_sha,
        "origin_sha": remote_sha,
        "in_sync": local_sha == remote_sha,
        "working_tree_dirty": dirty,
    }


def process_repo(
    repo: RepoTarget,
    *,
    cycle_index: int,
    args: argparse.Namespace,
    dry_run: bool,
) -> dict[str, Any]:
    log(f"[repo:{repo.name}] cycle={cycle_index}")
    base_branch = args.base_branch
    date_tag = datetime.now(UTC).strftime("%Y-%m-%d")
    base_branch_name = f"{args.branch_prefix}/{date_tag}-{slugify(repo.name)}-sync"

    result: dict[str, Any] = {
        "name": repo.name,
        "path": str(repo.path),
        "cycle": cycle_index,
        "status": "pending",
        "branch": None,
        "commit_sha": None,
        "pr_number": None,
        "pr_url": None,
        "checks": None,
        "check_result": None,
        "merge": None,
    }

    dirty = working_tree_dirty(repo)
    result["initial_working_tree_dirty"] = dirty

    if dry_run:
        result["status"] = "planned"
        result["planned_branch"] = base_branch_name
        result["planned_actions"] = [
            "ensure_branch",
            "git_add",
            "commit_or_noop",
            "push_branch",
            "create_pr",
            "wait_checks",
            "merge",
            "sync_main",
        ]
        return result

    branch_name = base_branch_name
    result["branch"] = branch_name

    ensure_branch(repo, branch_name, base_branch)
    commit_outcome = stage_and_commit(
        repo,
        create_noop=args.create_noop_pr_for_clean,
        commit_message=f"chore: workspace sync updates ({repo.name})",
        noop_commit_message="chore: no-op sync PR for repository alignment",
    )
    result["commit"] = commit_outcome

    if commit_outcome.get("skipped_clean"):
        result["status"] = "skipped_clean"
        return result

    result["commit_sha"] = run_cmd(["git", "-C", str(repo.path), "rev-parse", "HEAD"]).stdout.strip()
    push_branch(repo, branch_name)

    pr_number, pr_url = get_or_create_pr(repo, branch_name, base_branch)
    result["pr_number"] = pr_number
    result["pr_url"] = pr_url

    check_outcome = wait_for_checks(
        repo,
        pr_number,
        ci_timeout_min=args.ci_timeout_min,
        hung_threshold_min=args.hung_threshold_min,
        stall_threshold_min=args.stall_threshold_min,
        stall_reruns=args.stall_reruns,
        check_poll_seconds=args.check_poll_seconds,
        allow_admin_merge_on_stall=args.allow_admin_merge_on_stall,
    )
    result["checks"] = check_outcome.get("checks")
    result["check_result"] = check_outcome

    check_result = check_outcome["result"]
    if check_result == "needs_fix":
        result["status"] = "needs_fix"
        return result
    if check_result == "stalled_no_admin":
        result["status"] = "stalled_no_admin"
        return result

    merge_admin = check_result == "stalled_admin_fallback"
    merge_outcome = merge_pr(repo, pr_number, admin=merge_admin)
    result["merge"] = merge_outcome
    if not merge_outcome["ok"]:
        result["status"] = "merge_failed"
        return result

    result["status"] = "merged"
    return result


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Commit/PR/merge multiple repositories with check monitoring.")
    parser.add_argument("--workspace-root", required=True, help="Absolute path to workspace root.")
    parser.add_argument("--base-branch", default="main")
    parser.add_argument("--branch-prefix", default="codex")
    parser.add_argument("--repo-order", default="auto", choices=["auto", "alpha"])
    parser.add_argument("--check-poll-seconds", type=int, default=DEFAULT_CHECK_POLL_SECONDS)
    parser.add_argument("--ci-timeout-min", type=int, default=45)
    parser.add_argument("--hung-threshold-min", type=int, default=5)
    parser.add_argument("--stall-threshold-min", type=int, default=15)
    parser.add_argument("--stall-reruns", type=int, default=1)
    parser.add_argument("--allow-admin-merge-on-stall", type=parse_bool, default=True)
    parser.add_argument("--create-noop-pr-for-clean", type=parse_bool, default=True)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--json-report", default="")
    parser.add_argument("--repos", default="", help="Comma-separated repo paths (absolute or relative to workspace root).")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    if args.check_poll_seconds < 2:
        raise OrchestrationError("--check-poll-seconds must be >= 2")
    if args.hung_threshold_min < 1:
        raise OrchestrationError("--hung-threshold-min must be >= 1")
    if args.stall_threshold_min < args.hung_threshold_min:
        raise OrchestrationError("--stall-threshold-min must be >= --hung-threshold-min")

    workspace_root = Path(args.workspace_root).resolve()
    if not workspace_root.is_absolute():
        raise OrchestrationError("--workspace-root must be an absolute path")
    if not workspace_root.exists():
        raise OrchestrationError(f"workspace root does not exist: {workspace_root}")

    explicit_repos = [item.strip() for item in args.repos.split(",") if item.strip()] if args.repos else None

    report: dict[str, Any] = {
        "tool": "multi-repo-pr-merge-sync",
        "started_at": now_iso(),
        "workspace_root": str(workspace_root),
        "base_branch": args.base_branch,
        "options": {
            "branch_prefix": args.branch_prefix,
            "repo_order": args.repo_order,
            "check_poll_seconds": args.check_poll_seconds,
            "ci_timeout_min": args.ci_timeout_min,
            "hung_threshold_min": args.hung_threshold_min,
            "stall_threshold_min": args.stall_threshold_min,
            "stall_reruns": args.stall_reruns,
            "allow_admin_merge_on_stall": args.allow_admin_merge_on_stall,
            "create_noop_pr_for_clean": args.create_noop_pr_for_clean,
            "dry_run": args.dry_run,
        },
        "repos_discovered": [],
        "cycles": [],
        "final_sync": [],
        "success": False,
    }

    report_path = Path(args.json_report).resolve() if args.json_report else None

    try:
        repos = discover_repos(workspace_root, explicit_repos)
        repos = order_repos(repos, args.repo_order)
        report["repos_discovered"] = [{"name": r.name, "path": str(r.path)} for r in repos]

        preflight(repos, args.base_branch)

        repos_to_process = repos
        cycle = 1

        while repos_to_process and cycle <= MAX_FOLLOWUP_CYCLES:
            cycle_payload: dict[str, Any] = {"cycle_index": cycle, "repos": []}
            report["cycles"].append(cycle_payload)

            had_blocking_issue = False
            for repo in repos_to_process:
                repo_result = process_repo(repo, cycle_index=cycle, args=args, dry_run=args.dry_run)
                cycle_payload["repos"].append(repo_result)

                if repo_result["status"] in {"needs_fix", "stalled_no_admin", "merge_failed"}:
                    had_blocking_issue = True
                    break

            if had_blocking_issue:
                report["success"] = False
                report["ended_at"] = now_iso()
                write_json_report(report_path, report)
                log("[result] Blocking issue encountered. Review JSON report for required fixes.")
                return 2

            if args.dry_run:
                report["success"] = True
                report["ended_at"] = now_iso()
                write_json_report(report_path, report)
                log("[result] Dry run complete.")
                return 0

            sync_payload: list[dict[str, Any]] = []
            dirty_after_sync: list[RepoTarget] = []
            for repo in repos:
                sync_info = {"name": repo.name, "path": str(repo.path)}
                details = sync_main(repo, args.base_branch)
                sync_info.update(details)
                sync_payload.append(sync_info)
                if details["working_tree_dirty"]:
                    dirty_after_sync.append(repo)
                if not details["in_sync"]:
                    raise OrchestrationError(
                        f"{repo.name}: local {args.base_branch} does not match origin/{args.base_branch}"
                    )
            report["final_sync"] = sync_payload

            if not dirty_after_sync:
                report["success"] = True
                report["ended_at"] = now_iso()
                write_json_report(report_path, report)
                log("[result] Success: all repos merged and local/remote main are in sync.")
                return 0

            cycle += 1
            repos_to_process = dirty_after_sync
            log(
                "[follow-up] Newly surfaced changes detected after merge on: "
                + ", ".join(repo.name for repo in repos_to_process)
            )

        report["success"] = False
        report["ended_at"] = now_iso()
        report["error"] = "Exceeded follow-up cycle limit before achieving clean sync state"
        write_json_report(report_path, report)
        return 3

    except OrchestrationError as exc:
        report["success"] = False
        report["ended_at"] = now_iso()
        report["error"] = str(exc)
        write_json_report(report_path, report)
        log(f"[error] {exc}")
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

---
name: multi-repo-pr-merge-sync
description: Commit and push all changes across multiple git repositories in a workspace, create one PR per repo (including optional no-op PRs for clean repos), handle failing checks immediately, rerun hung checks without waiting the full stall window, merge to main, and verify local main equals origin/main at the end. Use when the user asks for end-to-end multi-repo GitHub commit/PR/check/merge synchronization.
---

# Multi-Repo PR Merge Sync

## Overview
Use this skill to run a deterministic multi-repo release loop: detect repos, commit, open PRs, monitor checks, handle stalled CI, merge, and enforce final `main` parity.

Run the orchestrator script instead of manually repeating git/gh steps.

## Preconditions
- Verify `gh auth status` succeeds with `repo` and `workflow` scopes.
- Verify the workspace root is an absolute path.
- Expect base branch `main` unless explicitly overridden.

## Primary Command
```bash
python scripts/orchestrate_multi_repo_pr_merge_sync.py \
  --workspace-root /absolute/workspace/path \
  --base-branch main \
  --branch-prefix codex \
  --repo-order auto \
  --check-poll-seconds 8 \
  --ci-timeout-min 45 \
  --hung-threshold-min 5 \
  --stall-threshold-min 15 \
  --stall-reruns 1 \
  --allow-admin-merge-on-stall true \
  --create-noop-pr-for-clean true \
  --json-report /tmp/multi-repo-sync-report.json
```

## CLI Contract
Required:
- `--workspace-root <abs-path>`

Optional:
- `--base-branch main`
- `--branch-prefix codex`
- `--repo-order auto|alpha`
- `--check-poll-seconds 8`
- `--ci-timeout-min 45`
- `--hung-threshold-min 5`
- `--stall-threshold-min 15`
- `--stall-reruns 1`
- `--allow-admin-merge-on-stall true|false`
- `--create-noop-pr-for-clean true|false`
- `--dry-run`
- `--json-report <path>`
- `--repos <comma-separated paths>`

## Execution Workflow
1. Discover actual git repo roots in the workspace root (or use `--repos` override).
2. Include the workspace root itself when it is a git repo.
3. Order repos:
- Auto mode enforces `TRR-Backend -> screenalytics -> TRR-APP` when present.
- Otherwise use alphabetical ordering.
4. Run preflight (`gh auth`, `origin`, `fetch origin/main`).
5. For each repo:
- Create/switch sync branch.
- Reuse the same deterministic branch/PR for follow-up commits in the same run (one PR per repo).
- Stage all changes and commit.
- Create no-op commit if clean and no-op mode enabled.
- Push branch and create/reuse PR.
- Monitor checks until pass, fail, or stall timeout.
6. Handle check states:
- `needs_fix`: stop and return structured failure details.
- `hung_candidate`: no state progress for `hung-threshold-min`, rerun/cancel immediately (no long passive wait).
- `stalled_admin_fallback`: merge with `--admin` only if allowed.
- `passed`: normal merge.
7. Sync each repo back to `main`, pull `origin/main`, enforce SHA parity.
8. If post-merge local changes appear, automatically open follow-up PR cycles until clean/synced or cycle cap reached.

## Fix Loop Contract
When the script returns `needs_fix`:
1. Read JSON report for repo, PR URL, and failing checks.
2. Implement fixes in the affected repo.
3. Commit and push updates to the same PR branch.
4. Re-run this skill scoped to that repo:
```bash
python scripts/orchestrate_multi_repo_pr_merge_sync.py \
  --workspace-root /absolute/workspace/path \
  --repos repo-name-or-path \
  --json-report /tmp/multi-repo-sync-report.json
```
5. Repeat until merge succeeds.

## Output Contract
The script prints human-readable progress and writes a machine-readable JSON report containing:
- discovered repos
- per-repo branch, commit SHA, PR URL/number
- check states, failures, reruns, stall events
- merge result
- final local vs `origin/main` parity

## Guardrails
- Never force-push `main`.
- Never run destructive git reset/checkout operations.
- Use admin merge only after stall detection and rerun exhaustion.
- Always report per-repo PR URLs and final SHA parity.

## References
- For stall policy details, read `references/ci-stall-handling.md`.
- For TRR ordering and cross-repo constraints, read `references/trr-ordering-and-guards.md`.

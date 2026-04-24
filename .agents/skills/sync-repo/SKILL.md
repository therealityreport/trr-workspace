---
name: sync-repo
description: Commit and push changes across one or more git repositories in a workspace, create one PR per repo, wait for checks, process bot feedback, resolve base-branch conflicts, push revisions, merge to main, and enforce final local main parity with only main branch remaining locally.
---

# sync-repo

## Overview
Use this skill to run an end-to-end PR merge sync loop for one repo or a repo set:
1. Detect repos and enforce TRR ordering.
2. Commit all repo changes and create/reuse one PR per repo.
3. Wait for CI checks, rerun stalled checks, and process bot feedback.
4. Apply automated revisions through a configured revision command.
5. Resolve base-branch conflicts by updating PR branches.
6. Merge each PR, sync local `main` to `origin/main`, and remove non-`main` local branches.

## Primary Command
```bash
python3.11 .agents/skills/sync-repo/scripts/orchestrate_multi_repo_pr_merge_sync.py \
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
  --revision-command '<your auto-fix command>' \
  --max-revision-cycles 5 \
  --delete-non-main-local-branches true \
  --json-report /tmp/repo-pr-sync-report.json
```

Single repo:
```bash
python3.11 .agents/skills/sync-repo/scripts/orchestrate_multi_repo_pr_merge_sync.py \
  --workspace-root /Users/thomashulihan/Projects/TRR \
  --repos TRR-APP \
  --dry-run \
  --json-report /tmp/repo-pr-sync-single.json
```

Multi repo:
```bash
python3.11 .agents/skills/sync-repo/scripts/orchestrate_multi_repo_pr_merge_sync.py \
  --workspace-root /Users/thomashulihan/Projects/TRR \
  --repos TRR-Backend,TRR-APP \
  --dry-run \
  --json-report /tmp/repo-pr-sync-multi.json
```

Workspace wrapper:
```bash
make workspace-pr-agent
```

Wrapper default:
- auto-discovers the workspace root repo plus child repos
- set `WORKSPACE_PR_AGENT_REPOS='<repo>'` for a single-repo run
- set `WORKSPACE_PR_AGENT_REPOS='<comma-separated repos>'` to narrow a multi-repo run

Single repo through the wrapper:
```bash
WORKSPACE_PR_AGENT_REPOS='TRR-APP' make workspace-pr-agent
```

Workspace-wide multi repo through the wrapper:
```bash
make workspace-pr-agent
```

Default wrapper revision command:
- `python3 /Users/thomashulihan/Projects/TRR/scripts/workspace-pr-agent-revision.py`
- disable with `WORKSPACE_PR_AGENT_REVISION_COMMAND=none`
- disable Codex assist inside revision helper with `WORKSPACE_PR_AGENT_REVISION_USE_CODEX=0`
- MCP-first revision mode (default on):
  - `WORKSPACE_PR_AGENT_REVISION_USE_GITHUB_MCP=1`
  - `WORKSPACE_PR_AGENT_REVISION_REQUIRE_GITHUB_MCP=1` to fail fast when MCP auth is unavailable

## Revision Command Contract
`--revision-command` is optional but required for full autonomous fix loops.

The command runs in the target repo working directory and receives:
- `WORKSPACE_AGENT_REPO_NAME`
- `WORKSPACE_AGENT_REPO_PATH`
- `WORKSPACE_AGENT_BRANCH`
- `WORKSPACE_AGENT_PR_NUMBER`
- `WORKSPACE_AGENT_REASON` (`failing_checks|bot_feedback|merge_conflict`)
- `WORKSPACE_AGENT_CONTEXT_FILE` (JSON payload with details)

If the revision command edits files, the orchestrator auto-commits and pushes updates to the same PR branch.

## CLI Contract
Required:
- `--workspace-root <abs-path>`

Common options:
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
- `--revision-command '<command>'`
- `--max-revision-cycles 5`
- `--delete-non-main-local-branches true|false`
- `--dry-run`
- `--json-report <path>`
- `--repos <repo-or-comma-separated-paths>`

## Guardrails
- Never force-push `main`.
- Keep one active PR per repo and push follow-up fixes to that same PR.
- Use admin merge only after stall detection and rerun exhaustion.
- Do not merge with unresolved bot feedback when revision automation is enabled.
- Enforce final state per repo:
  1. checked out on `main`
  2. `HEAD == origin/main`
  3. clean working tree
  4. no local branches other than `main` (or configured base branch)

## Output Contract
JSON report includes:
- discovered repos and processing order
- PR metadata and status-check outcomes
- bot feedback events and revision attempts
- conflict/base-update events
- merge attempts
- final sync and local branch cleanup results

## Failure Contract
Blocking statuses include:
- `needs_fix`
- `needs_bot_revision`
- `conflict_needs_fix`
- `revision_cycle_limit`
- `stalled_no_admin`
- `merge_failed`

When blocked, inspect the JSON report and re-run after fixing or adjusting `--revision-command`.

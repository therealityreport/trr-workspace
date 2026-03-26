#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PYTHON_BIN="${PYTHON_BIN:-python3}"
ORCHESTRATOR="$ROOT/.agents/skills/multi-repo-pr-merge-sync/scripts/orchestrate_multi_repo_pr_merge_sync.py"
JSON_REPORT="${WORKSPACE_PR_AGENT_JSON_REPORT:-$ROOT/.logs/workspace/pr-agent-report.json}"
TARGET_REPOS="${WORKSPACE_PR_AGENT_REPOS:-TRR-Backend,screenalytics,TRR-APP}"
REVISION_COMMAND="${WORKSPACE_PR_AGENT_REVISION_COMMAND:-python3 $ROOT/scripts/workspace-pr-agent-revision.py}"

cmd=(
  "$PYTHON_BIN"
  "$ORCHESTRATOR"
  --workspace-root "$ROOT"
  --base-branch "${WORKSPACE_PR_AGENT_BASE_BRANCH:-main}"
  --branch-prefix "${WORKSPACE_PR_AGENT_BRANCH_PREFIX:-codex}"
  --repo-order "${WORKSPACE_PR_AGENT_REPO_ORDER:-auto}"
  --check-poll-seconds "${WORKSPACE_PR_AGENT_CHECK_POLL_SECONDS:-8}"
  --ci-timeout-min "${WORKSPACE_PR_AGENT_CI_TIMEOUT_MIN:-45}"
  --hung-threshold-min "${WORKSPACE_PR_AGENT_HUNG_THRESHOLD_MIN:-5}"
  --stall-threshold-min "${WORKSPACE_PR_AGENT_STALL_THRESHOLD_MIN:-15}"
  --stall-reruns "${WORKSPACE_PR_AGENT_STALL_RERUNS:-1}"
  --allow-admin-merge-on-stall "${WORKSPACE_PR_AGENT_ALLOW_ADMIN_MERGE_ON_STALL:-true}"
  --create-noop-pr-for-clean "${WORKSPACE_PR_AGENT_CREATE_NOOP_PR_FOR_CLEAN:-true}"
  --max-revision-cycles "${WORKSPACE_PR_AGENT_MAX_REVISION_CYCLES:-5}"
  --delete-non-main-local-branches "${WORKSPACE_PR_AGENT_DELETE_NON_MAIN_LOCAL_BRANCHES:-true}"
  --json-report "$JSON_REPORT"
  --repos "$TARGET_REPOS"
)

if [[ "$REVISION_COMMAND" != "none" ]]; then
  cmd+=(--revision-command "$REVISION_COMMAND")
fi

if [[ "${WORKSPACE_PR_AGENT_DRY_RUN:-0}" == "1" ]]; then
  cmd+=(--dry-run)
fi

echo "[workspace-pr-agent] workspace: $ROOT"
echo "[workspace-pr-agent] report: $JSON_REPORT"
echo "[workspace-pr-agent] revision-command: $REVISION_COMMAND"
echo "[workspace-pr-agent] revision-use-github-mcp: ${WORKSPACE_PR_AGENT_REVISION_USE_GITHUB_MCP:-1}"
echo "[workspace-pr-agent] revision-require-github-mcp: ${WORKSPACE_PR_AGENT_REVISION_REQUIRE_GITHUB_MCP:-0}"
echo "[workspace-pr-agent] running handoff closeout sync before orchestration"
bash "$ROOT/scripts/handoff-lifecycle.sh" closeout
"${cmd[@]}"

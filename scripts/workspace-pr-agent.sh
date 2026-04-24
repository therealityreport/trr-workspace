#!/usr/bin/env bash
set -euo pipefail

resolve_bash_4_bin() {
  local configured="${BASH_BIN:-}"
  local candidate path

  for candidate in "$configured" /opt/homebrew/bin/bash bash /bin/bash; do
    [[ -n "$candidate" ]] || continue
    if [[ -x "$candidate" ]]; then
      path="$candidate"
    elif command -v "$candidate" >/dev/null 2>&1; then
      path="$(command -v "$candidate")"
    else
      continue
    fi

    if "$path" -lc '[[ "${BASH_VERSINFO[0]}" -ge 4 ]]' >/dev/null 2>&1; then
      echo "$path"
      return 0
    fi
  done

  echo "bash"
}

BASH_BIN="$(resolve_bash_4_bin)"
if [[ "${WORKSPACE_PR_AGENT_BASH_REEXEC:-0}" != "1" ]] && ! [[ "${BASH_VERSINFO[0]}" -ge 4 ]]; then
  export WORKSPACE_PR_AGENT_BASH_REEXEC=1
  exec "$BASH_BIN" "$0" "$@"
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ "$BASH_BIN" = /* ]]; then
  export PATH="$(dirname "$BASH_BIN"):$PATH"
fi

PYTHON_BIN="${PYTHON_BIN:-python3.11}"
ORCHESTRATOR="$ROOT/.agents/skills/sync-repo/scripts/orchestrate_multi_repo_pr_merge_sync.py"
JSON_REPORT="${WORKSPACE_PR_AGENT_JSON_REPORT:-$ROOT/.logs/workspace/pr-agent-report.json}"
TARGET_REPOS="${WORKSPACE_PR_AGENT_REPOS:-}"
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
)

if [[ "$REVISION_COMMAND" != "none" ]]; then
  cmd+=(--revision-command "$REVISION_COMMAND")
fi

if [[ -n "$TARGET_REPOS" ]]; then
  cmd+=(--repos "$TARGET_REPOS")
fi

if [[ "${WORKSPACE_PR_AGENT_DRY_RUN:-0}" == "1" ]]; then
  cmd+=(--dry-run)
fi

echo "[workspace-pr-agent] workspace: $ROOT"
echo "[workspace-pr-agent] report: $JSON_REPORT"
echo "[workspace-pr-agent] revision-command: $REVISION_COMMAND"
if [[ -n "$TARGET_REPOS" ]]; then
  echo "[workspace-pr-agent] repos: $TARGET_REPOS"
else
  echo "[workspace-pr-agent] repos: auto-discover workspace root + child repos"
fi
echo "[workspace-pr-agent] revision-use-github-mcp: ${WORKSPACE_PR_AGENT_REVISION_USE_GITHUB_MCP:-1}"
echo "[workspace-pr-agent] revision-require-github-mcp: ${WORKSPACE_PR_AGENT_REVISION_REQUIRE_GITHUB_MCP:-0}"
echo "[workspace-pr-agent] revision-use-vercel-mcp: ${WORKSPACE_PR_AGENT_REVISION_USE_VERCEL_MCP:-1}"
echo "[workspace-pr-agent] running handoff closeout sync before orchestration"
"$BASH_BIN" "$ROOT/scripts/handoff-lifecycle.sh" closeout
"${cmd[@]}"

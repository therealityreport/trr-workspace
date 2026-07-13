#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/workspace-test-contracts.sh"

cd "$ROOT"

changed_tmp="$(mktemp)"
trap 'rm -f "$changed_tmp"' EXIT

{
  git diff --name-only
  git diff --name-only --cached
  git ls-files --others --exclude-standard
} | awk 'NF' | sort -u > "$changed_tmp"

if [[ ! -s "$changed_tmp" ]]; then
  echo "[test-changed] No changed files found; running test-fast baseline."
  exec bash "$ROOT/scripts/test-fast.sh"
fi

run_backend=0
run_app=0
run_baseline=0

run_workspace_checks() {
  echo "[test-changed] Workspace changes detected; running workspace policy and contract checks."
  bash "$ROOT/scripts/check-policy.sh"
  bash "$ROOT/scripts/check-workspace-contract.sh"
  env CHROME_DEVTOOLS_MCP_STATUS_MODE=summary bash "$ROOT/scripts/chrome-devtools-mcp-status.sh"

  echo "[test-changed] Root script contract tests..."
  trr_workspace_pytest_contracts "$ROOT"
}

if rg -q '^TRR-Backend/' "$changed_tmp"; then
  run_backend=1
fi
if rg -q '^TRR-APP/' "$changed_tmp"; then
  run_app=1
fi
if rg -q '^(AGENTS\.md|CLAUDE\.md|Makefile|scripts/|docs/|profiles/)' "$changed_tmp"; then
  run_baseline=1
fi

if [[ "$run_baseline" == "1" ]]; then
  if [[ "$run_backend" == "0" && "$run_app" == "0" ]]; then
    run_workspace_checks
    echo "[test-changed] Done."
    exit 0
  fi
  echo "[test-changed] Root/scripts/docs/policy changes detected; running test-fast baseline."
  exec bash "$ROOT/scripts/test-fast.sh"
fi

if [[ "$run_backend" == "0" && "$run_app" == "0" ]]; then
  echo "[test-changed] No repo-scoped runtime changes detected; running test-fast baseline."
  exec bash "$ROOT/scripts/test-fast.sh"
fi

if [[ "$run_backend" == "1" ]]; then
  bash "$ROOT/scripts/test-fast.sh" --backend-only
fi
if [[ "$run_app" == "1" ]]; then
  bash "$ROOT/scripts/test-fast.sh" --app-only
fi

echo "[test-changed] Done."

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "[preflight] Running workspace doctor..."
bash "$ROOT/scripts/doctor.sh"

echo "[preflight] Validating generated env contract..."
bash "$ROOT/scripts/workspace-env-contract.sh" --check

echo "[preflight] Checking policy drift rules..."
bash "$ROOT/scripts/check-policy.sh"

echo "[preflight] Checking managed Chrome agent status (warn-only)..."
if ! bash "$ROOT/scripts/chrome-agent-status.sh"; then
  echo "[preflight] WARNING: chrome-agent-status check failed." >&2
fi

if [[ -d "$ROOT/.playwright-mcp" ]]; then
  echo "[preflight] NOTE: '$ROOT/.playwright-mcp' exists and is treated as legacy/local-only." >&2
  echo "[preflight] NOTE: Workspace policy is Chrome DevTools MCP only." >&2
fi

echo "[preflight] OK"

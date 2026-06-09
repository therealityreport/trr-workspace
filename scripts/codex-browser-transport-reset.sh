#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "[codex-browser-transport-reset] Cleaning stale in-app Browser execution markers..."
NODE_REPL_CLEAN_PROJECT_OWNED=1 \
NODE_REPL_PROJECT_ROOT="$ROOT" \
  bash "${ROOT}/scripts/node-repl-mcp-clean-stale.sh"

echo "[codex-browser-transport-reset] Cleaning stale Chrome/browser MCP state..."
bash "${ROOT}/scripts/mcp-clean.sh"

echo "[codex-browser-transport-reset] Complete. If browser-control calls still report 'Transport closed', refresh the Codex tool session or restart Codex."

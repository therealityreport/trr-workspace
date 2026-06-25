#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "[chrome-repair] Cleaning stale Browser/Chrome MCP state..."
bash "$ROOT/scripts/mcp-clean.sh"

echo "[chrome-repair] Ensuring shared managed Chrome is running..."
CODEX_CHROME_MODE="${CODEX_CHROME_MODE:-shared}" bash "$ROOT/scripts/ensure-managed-chrome.sh"

echo "[chrome-repair] Checking Chrome DevTools MCP status..."
bash "$ROOT/scripts/chrome-devtools-mcp-status.sh"

cat >&2 <<'EOF'
[chrome-repair] MCP reload hint: if chrome-devtools tool calls in this already-open chat still return "Transport closed", the local Chrome runtime is repaired but the loaded MCP transport is stale. Restart the Codex session/thread to reload MCP registrations.
EOF

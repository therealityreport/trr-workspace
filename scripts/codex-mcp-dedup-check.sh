#!/usr/bin/env bash
set -euo pipefail

# Checks whether a wrapper for the same browser port is already alive and healthy
# before starting a new one. Called from the main codex-chrome-devtools-mcp.sh wrapper.
#
# Usage: codex-mcp-dedup-check.sh <port>
#
# Exit codes:
#   0: REUSE {pid}     - PID is alive and endpoint reachable
#   1: UNHEALTHY {pid} - PID is alive but endpoint NOT reachable
#   2: STALE           - PID is dead
#   3: FRESH           - No session file exists

ROOT="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Source runtime libraries
. "${ROOT}/scripts/lib/mcp-runtime.sh"
. "${ROOT}/scripts/lib/chrome-runtime.sh"

LOG_DIR="${ROOT}/.logs/workspace"
PORT="${1:-}"

# Validation
if [[ -z "$PORT" || ! "$PORT" =~ ^[0-9]+$ ]]; then
  echo "[codex-mcp-dedup-check] ERROR: port must be a valid integer" >&2
  exit 3
fi

SESSION_FILE="${LOG_DIR}/codex-chrome-session-${PORT}.env"

# Check if session file exists
if [[ ! -f "$SESSION_FILE" ]]; then
  echo "FRESH"
  exit 3
fi

# Extract WRAPPER_PID from session file
WRAPPER_PID=""
if [[ -f "$SESSION_FILE" ]]; then
  WRAPPER_PID="$(sed -n 's/^WRAPPER_PID=//p' "$SESSION_FILE" | head -n 1)"
fi

# If no PID found in file, it's fresh
if [[ -z "$WRAPPER_PID" || ! "$WRAPPER_PID" =~ ^[0-9]+$ ]]; then
  echo "FRESH"
  exit 3
fi

# Check if the PID is still alive
if ! kill -0 "$WRAPPER_PID" >/dev/null 2>&1; then
  echo "STALE"
  exit 2
fi

# PID is alive, check if the endpoint is reachable
if chrome_endpoint_reachable "$PORT"; then
  echo "REUSE $WRAPPER_PID"
  exit 0
else
  echo "UNHEALTHY $WRAPPER_PID"
  exit 1
fi

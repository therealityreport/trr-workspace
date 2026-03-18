#!/usr/bin/env bash
# mcp-browser-singleton.sh — manual MCP singleton experiment helper
#
# Experimental helper for one-off operator cleanup experiments.
# This script is NOT the supported runtime entrypoint for Codex or Claude
# in the TRR workspace. Normal MCP registrations must use
# `scripts/codex-chrome-devtools-mcp.sh` for chrome-devtools and the
# repo-managed default commands for other MCPs.
#
# Usage:
#   mcp-browser-singleton.sh <group-name> <mcp-command...>
#
# Examples:
#   mcp-browser-singleton.sh chrome-devtools npx -y chrome-devtools-mcp@0.20.0 --browserUrl http://127.0.0.1:9222
#   mcp-browser-singleton.sh playwright npx -y @playwright/mcp --browser chrome --user-data-dir ~/.chrome-profiles/playwright-agent
#
# How it works:
#   1. On startup: kills ALL other processes whose command line matches
#      the MCP binary name (e.g. "chrome-devtools-mcp" or "playwright-mcp"),
#      EXCLUDING our own PID. This catches instances launched by Claude Code,
#      Codex, or any other tool — regardless of wrapper script.
#   2. Records our PID in a lockfile.
#   3. Runs the MCP command with stdio forwarded (required for MCP protocol).
#   4. On exit: attempts cleanup when the wrapper shell remains alive.
#
# Warning:
#   Because the normal happy path ends in `exec`, this script should not be
#   relied on as a lifecycle manager for production MCP registrations.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${ROOT}/.logs/workspace"
mkdir -p "$LOG_DIR"

# ── Args ──────────────────────────────────────────────────────────────
if [[ $# -lt 2 ]]; then
  echo "Usage: mcp-browser-singleton.sh <group-name> <mcp-command...>" >&2
  exit 1
fi

GROUP_NAME="$1"; shift
MCP_CMD=("$@")

LOCKFILE="${LOG_DIR}/mcp-singleton-${GROUP_NAME}.pid"
SCRIPT_PID="$$"
CLEANUP_DONE=0

# ── Logging ───────────────────────────────────────────────────────────
log() { echo "[mcp-singleton:${GROUP_NAME}] $*" >&2; }

# ── Determine kill pattern ────────────────────────────────────────────
# Build a grep/pkill pattern from the MCP binary name.  We search for
# the node binary name (e.g. "chrome-devtools-mcp" or "playwright-mcp")
# in the process command line, which catches both npx-launched and
# direct-node-launched instances.
mcp_binary_pattern() {
  case "$GROUP_NAME" in
    chrome-devtools) echo "chrome-devtools-mcp" ;;
    playwright)      echo "playwright-mcp" ;;
    *)               echo "$GROUP_NAME" ;;
  esac
}

KILL_PATTERN="$(mcp_binary_pattern)"

# ── Kill previous instances ───────────────────────────────────────────
kill_previous() {
  local pattern="$1"
  local my_pid="$2"
  local pids=""
  local pid

  # Find all PIDs matching the pattern, excluding:
  #   - our own PID and our parent
  #   - grep/pkill itself
  pids="$(pgrep -f "$pattern" 2>/dev/null || true)"

  if [[ -z "$pids" ]]; then
    return 0
  fi

  local killed=0
  while IFS= read -r pid; do
    # Skip self, parent, and empty lines
    if [[ -z "$pid" || "$pid" == "$my_pid" || "$pid" == "$$" || "$pid" == "$PPID" ]]; then
      continue
    fi
    # Verify the process actually matches (pgrep can be noisy)
    local cmd
    cmd="$(ps -p "$pid" -o command= 2>/dev/null || true)"
    if [[ -z "$cmd" ]] || [[ "$cmd" == *"mcp-browser-singleton"* && "$cmd" == *"$GROUP_NAME"* ]]; then
      # This is another wrapper — skip it, we'll get its children
      # Actually, kill the wrapper too so its children die
      :
    fi
    log "Killing previous instance pid=$pid"
    kill -TERM "$pid" 2>/dev/null || true
    killed=$((killed + 1))
  done <<< "$pids"

  if (( killed > 0 )); then
    # Give processes a moment to exit gracefully
    sleep 0.5
    # Force-kill any stragglers
    while IFS= read -r pid; do
      if [[ -z "$pid" || "$pid" == "$my_pid" || "$pid" == "$$" || "$pid" == "$PPID" ]]; then
        continue
      fi
      kill -KILL "$pid" 2>/dev/null || true
    done <<< "$(pgrep -f "$pattern" 2>/dev/null || true)"
    log "Killed $killed previous instance(s)"
  fi
}

# Also kill telemetry watchdog processes left by chrome-devtools-mcp
kill_watchdogs() {
  local pids
  pids="$(pgrep -f "telemetry/watchdog/main.js" 2>/dev/null || true)"
  if [[ -n "$pids" ]]; then
    local pid
    while IFS= read -r pid; do
      if [[ -n "$pid" ]]; then
        kill -TERM "$pid" 2>/dev/null || true
      fi
    done <<< "$pids"
  fi
}

# ── Cleanup ───────────────────────────────────────────────────────────
cleanup() {
  if [[ "$CLEANUP_DONE" == "1" ]]; then return 0; fi
  CLEANUP_DONE=1

  # Kill all child processes
  local child
  for child in $(pgrep -P "$$" 2>/dev/null || true); do
    kill -TERM "$child" 2>/dev/null || true
  done
  sleep 0.3
  for child in $(pgrep -P "$$" 2>/dev/null || true); do
    kill -KILL "$child" 2>/dev/null || true
  done

  # Remove lockfile if it's ours
  if [[ -f "$LOCKFILE" ]]; then
    local recorded
    recorded="$(cat "$LOCKFILE" 2>/dev/null || true)"
    if [[ "$recorded" == "$SCRIPT_PID" ]]; then
      rm -f "$LOCKFILE"
    fi
  fi
}

trap 'cleanup' EXIT
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 129' HUP
trap 'cleanup; exit 143' TERM

# ── Purge old logs ────────────────────────────────────────────────────
MCP_LOG_DIR="${LOG_DIR}/chrome-devtools-mcp"
if [[ -d "$MCP_LOG_DIR" ]]; then
  find "$MCP_LOG_DIR" -name "npm-exec-*.stderr" -mmin +60 -delete 2>/dev/null || true
  find "$MCP_LOG_DIR" -name "npm-exec-*.stderr.fifo" -mmin +60 -delete 2>/dev/null || true
fi

# ── Main ──────────────────────────────────────────────────────────────

# 1. Kill all previous instances of this MCP type
kill_previous "$KILL_PATTERN" "$SCRIPT_PID"

# Also clean up orphaned watchdog processes (chrome-devtools specific)
if [[ "$GROUP_NAME" == "chrome-devtools" ]]; then
  kill_watchdogs
fi

# 2. Record our PID
echo "$SCRIPT_PID" > "$LOCKFILE"
log "Starting (pid=$SCRIPT_PID)"

# 3. Exec the MCP command — replaces this shell, so stdio is forwarded
#    directly to the MCP server (required for MCP protocol handshake).
exec "${MCP_CMD[@]}"

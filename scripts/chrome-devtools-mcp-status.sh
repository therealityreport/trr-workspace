#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${CODEX_CONFIG_FILE:-${HOME}/.codex/config.toml}"
EXPECTED_COMMAND="${ROOT}/scripts/codex-chrome-devtools-mcp.sh"
LOG_DIR="${ROOT}/.logs/workspace"

fail() {
  echo "[chrome-devtools-mcp] ERROR: $*" >&2
  exit 1
}

warn() {
  echo "[chrome-devtools-mcp] WARNING: $*" >&2
}

endpoint_state() {
  local port="$1"
  if curl -sf "http://127.0.0.1:${port}/json/version" >/dev/null 2>&1; then
    echo "reachable"
  else
    echo "unreachable"
  fi
}

report_stale_runtime() {
  local stale_count=0
  local reserve
  local pidfile
  local statefile
  local owner_pid
  local browser_pid

  shopt -s nullglob
  for reserve in "${LOG_DIR}"/codex-chrome-port-*.reserve; do
    owner_pid="$(cat "$reserve" 2>/dev/null || true)"
    if [[ -z "$owner_pid" ]] || ! kill -0 "$owner_pid" >/dev/null 2>&1; then
      echo "[chrome-devtools-mcp] Stale reserve: $(basename "$reserve") owner=${owner_pid:-missing}"
      stale_count=$((stale_count + 1))
    fi
  done

  for pidfile in "${LOG_DIR}"/chrome-agent-*.pid; do
    browser_pid="$(cat "$pidfile" 2>/dev/null || true)"
    if [[ -z "$browser_pid" ]] || ! kill -0 "$browser_pid" >/dev/null 2>&1; then
      echo "[chrome-devtools-mcp] Stale pidfile: $(basename "$pidfile") pid=${browser_pid:-missing}"
      stale_count=$((stale_count + 1))
    fi
  done

  for statefile in "${LOG_DIR}"/chrome-agent-*.env; do
    pidfile="${statefile%.env}.pid"
    if [[ ! -f "$pidfile" ]]; then
      echo "[chrome-devtools-mcp] Orphaned statefile: $(basename "$statefile")"
      stale_count=$((stale_count + 1))
    fi
  done
  shopt -u nullglob

  if [[ "$stale_count" -eq 0 ]]; then
    echo "[chrome-devtools-mcp] Stale runtime artifacts: none"
  else
    echo "[chrome-devtools-mcp] Stale runtime artifacts: ${stale_count}"
  fi
}

if [[ ! -f "$CONFIG_FILE" ]]; then
  fail "Codex config not found at ${CONFIG_FILE}"
fi

if [[ ! -x "$EXPECTED_COMMAND" ]]; then
  fail "Wrapper is missing or not executable: ${EXPECTED_COMMAND}"
fi

chrome_section="$(
  awk '
    BEGIN { in_section = 0 }
    /^\[mcp_servers\.chrome-devtools\]/ { in_section = 1; print; next }
    /^\[mcp_servers\./ { if (in_section) exit; next }
    { if (in_section) print }
  ' "$CONFIG_FILE"
)"

if [[ -z "$chrome_section" ]]; then
  fail "Missing [mcp_servers.chrome-devtools] section in ${CONFIG_FILE}"
fi

configured_command="$(printf '%s\n' "$chrome_section" | awk -F' = ' '/^command = / {gsub(/^"|"$/, "", $2); print $2; exit}')"
configured_enabled="$(printf '%s\n' "$chrome_section" | awk -F' = ' '/^enabled = / {print $2; exit}')"

if [[ "$configured_enabled" != "true" ]]; then
  fail "chrome-devtools MCP is not enabled in ${CONFIG_FILE}"
fi

if [[ "$configured_command" != "$EXPECTED_COMMAND" ]]; then
  warn "Configured command differs from workspace wrapper: ${configured_command}"
fi

seed_profile="${CODEX_CHROME_SEED_PROFILE_DIR:-${HOME}/.chrome-profiles/claude-agent}"
seed_profile_state="present"
if [[ ! -d "$seed_profile" ]]; then
  seed_profile_state="missing"
  warn "Seed profile not found at ${seed_profile}; isolated chats may fail if no cloned profile already exists."
fi

echo "[chrome-devtools-mcp] Config OK: ${CONFIG_FILE}"
echo "[chrome-devtools-mcp] Wrapper OK: ${EXPECTED_COMMAND}"
echo "[chrome-devtools-mcp] Seed profile: ${seed_profile} (${seed_profile_state})"
echo "[chrome-devtools-mcp] Shared 9222 endpoint: $(endpoint_state 9222)"
report_stale_runtime
echo "[chrome-devtools-mcp] Running wrapper smoke check..."

if ! CODEX_CHROME_SKIP_BROWSER_BOOT=1 "$EXPECTED_COMMAND" --help >/dev/null; then
  fail "Wrapper smoke check failed"
fi

echo "[chrome-devtools-mcp] Smoke check passed."
echo "[chrome-devtools-mcp] If the tool still does not appear in an already-open Codex chat, restart the Codex session/thread to reload MCP registrations."

#!/usr/bin/env bash
set -euo pipefail

# Ensure Homebrew paths are available — Claude Code ships a minimal PATH
# (/usr/bin:/bin:/usr/sbin:/sbin) that excludes Homebrew.
for _dir in /opt/homebrew/bin /usr/local/bin; do
  [[ -d "$_dir" ]] && [[ ":$PATH:" != *":$_dir:"* ]] && export PATH="$_dir:$PATH"
done
unset _dir

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT}/scripts/lib/node-baseline.sh"
if [[ -f "${ROOT}/scripts/lib/codex-session-identity.sh" ]]; then
  # Optional helper for richer session ownership metadata.
  source "${ROOT}/scripts/lib/codex-session-identity.sh"
fi

LOG_DIR="${ROOT}/.logs/workspace"
PORT_LOCKFILE="${LOG_DIR}/codex-chrome-port.lock"
MCP_CACHE_DIR="${CODEX_CHROME_MCP_CACHE_DIR:-${ROOT}/.tmp/chrome-devtools-mcp/npm-cache}"
MCP_RUN_LOG_DIR="${LOG_DIR}/chrome-devtools-mcp"
MCP_VERSION="${CHROME_DEVTOOLS_MCP_VERSION:-0.20.0}"
MCP_PACKAGE="chrome-devtools-mcp@${MCP_VERSION}"
MODE="${CODEX_CHROME_MODE:-isolated}"
SHARED_SINGLETON="${CODEX_CHROME_SHARED_SINGLETON:-0}"
START_PORT="${CODEX_CHROME_PORT_RANGE_START:-9333}"
END_PORT="${CODEX_CHROME_PORT_RANGE_END:-9399}"
FORCED_PORT="${CODEX_CHROME_PORT:-}"
# Default seed profile is codex-agent (codex@thereality.report).
# The claude-agent profile (admin@thereality.report) is prohibited for agent use.
# Override with CODEX_CHROME_SEED_PROFILE_DIR only with explicit user permission.
SEED_PROFILE_DIR="${CODEX_CHROME_SEED_PROFILE_DIR:-${HOME}/.chrome-profiles/codex-agent}"
ISOLATED_HEADLESS="${CODEX_CHROME_ISOLATED_HEADLESS:-1}"
SHARED_HEADLESS="${CODEX_CHROME_SHARED_HEADLESS:-1}"
SKIP_BROWSER_BOOT="${CODEX_CHROME_SKIP_BROWSER_BOOT:-0}"
DIAGNOSTIC_ONLY="${CODEX_CHROME_DIAGNOSTIC_ONLY:-0}"
TAB_CAP="${CODEX_CHROME_TAB_CAP:-3}"
TAB_TARGET="${CODEX_CHROME_TAB_TARGET:-1}"
TAB_WATCH_INTERVAL="${CODEX_CHROME_TAB_WATCH_INTERVAL_SEC:-2}"
ENABLE_TAB_WATCH="${CODEX_CHROME_ENABLE_TAB_WATCH:-1}"
BROWSER_READY_TIMEOUT_SEC="${CODEX_CHROME_BROWSER_READY_TIMEOUT_SEC:-20}"
BROWSER_WATCH_INTERVAL_SEC="${CODEX_CHROME_BROWSER_WATCH_INTERVAL_SEC:-5}"
BROWSER_WATCH_MISS_THRESHOLD="${CODEX_CHROME_BROWSER_WATCH_MISS_THRESHOLD:-2}"
MAX_ISOLATED_SESSIONS="${CODEX_CHROME_MAX_SESSIONS:-1}"
MEMORY_GUARD_MB="${CODEX_CHROME_MEMORY_GUARD_MB:-2048}"
MANAGED_CHROME_ROOT_LIMIT="${CODEX_CHROME_MANAGED_ROOT_LIMIT:-3}"
HEADFUL_CONFLICT_ALLOWED="${CODEX_CHROME_ALLOW_HEADFUL_CONFLICT:-0}"

BROWSER_PORT=""
RESERVATION_FILE=""
STOP_ON_EXIT=0
CLEANUP_DONE=0
MCP_PID=""
MCP_PGID=""
MCP_TEE_PID=""
WATCHDOG_PID=""
TAB_WATCH_PID=""
BROWSER_WATCH_PID=""
STDIN_WATCH_PID=""
SCRIPT_PID="${BASHPID:-$$}"
SCRIPT_PGID=""
ORIGINAL_PPID=""
SHARED_WRAPPER_PIDFILE=""
SESSION_FILE=""
PAGE_ORDER_FILE=""
VISIBLE_BROWSER_OWNER_FILE="${LOG_DIR}/chrome-devtools-visible-browser-owner.env"
SIGNAL_LOG_FILE=""
SETSID_BIN=""

mkdir -p "$LOG_DIR" "$MCP_CACHE_DIR" "$MCP_RUN_LOG_DIR"

# Avoid colliding with macOS `/usr/bin/log` during wrapper bootstrap.
chrome_mcp_log() {
  echo "[codex-chrome-mcp] $*" >&2
}

fail() {
  chrome_mcp_log "ERROR: $*"
  exit 1
}

SETSID_BIN="$(command -v setsid 2>/dev/null || true)"

ensure_private_session_for_shared_mode() {
  local current_pid="${BASHPID:-$$}"
  local current_pgid=""

  if [[ "$MODE" != "shared" || "${CODEX_CHROME_PRIVATE_SESSION:-0}" == "1" ]]; then
    return 0
  fi

  current_pgid="$(ps -o pgid= -p "$current_pid" 2>/dev/null | tr -d ' ' || true)"
  if [[ -n "$current_pgid" && "$current_pgid" == "$current_pid" ]]; then
    export CODEX_CHROME_PRIVATE_SESSION=1
    return 0
  fi

  if [[ -z "$SETSID_BIN" ]]; then
    echo "[codex-chrome-mcp] ERROR: shared mode requires setsid so the wrapper owns a private session before any kill logic runs." >&2
    exit 1
  fi

  export CODEX_CHROME_PRIVATE_SESSION=1
  exec "$SETSID_BIN" "$BASH" "$0" "$@"
}

ensure_private_session_for_shared_mode "$@"
SCRIPT_PID="${BASHPID:-$$}"
SIGNAL_LOG_FILE="${MCP_RUN_LOG_DIR}/signal-path-${SCRIPT_PID}.log"

log_signal_path() {
  local event="$1"
  shift || true
  local metadata="$*"
  local timestamp
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '%s event=%s mode=%s wrapper_pid=%s wrapper_pgid=%s mcp_pid=%s mcp_pgid=%s %s\n' \
    "$timestamp" \
    "$event" \
    "$MODE" \
    "$SCRIPT_PID" \
    "${SCRIPT_PGID:-unknown}" \
    "${MCP_PID:-none}" \
    "${MCP_PGID:-none}" \
    "$metadata" >>"$SIGNAL_LOG_FILE"
  chrome_mcp_log "signal-path event=${event} mode=${MODE} wrapper_pid=${SCRIPT_PID} wrapper_pgid=${SCRIPT_PGID:-unknown} mcp_pid=${MCP_PID:-none} mcp_pgid=${MCP_PGID:-none} ${metadata}"
}

headful_mode_enabled() {
  if [[ "$MODE" == "shared" ]]; then
    [[ "$SHARED_HEADLESS" != "1" ]]
    return 0
  fi
  [[ "$ISOLATED_HEADLESS" != "1" ]]
}

visible_owner_field() {
  local key="$1"
  if [[ ! -f "$VISIBLE_BROWSER_OWNER_FILE" ]]; then
    return 0
  fi
  sed -n "s/^${key}=//p" "$VISIBLE_BROWSER_OWNER_FILE" | head -n 1
}

port_listener_pid() {
  local port="$1"
  lsof -nP -iTCP:"${port}" -sTCP:LISTEN -t 2>/dev/null | head -n 1 || true
}

pid_alive() {
  local pid="$1"
  [[ -n "$pid" && "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" >/dev/null 2>&1
}

process_parent_pid() {
  local pid="$1"
  ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ' || true
}

process_command() {
  local pid="$1"
  ps -o command= -p "$pid" 2>/dev/null || true
}

process_has_live_ancestor_matching() {
  local pid="$1"
  local regex="$2"
  local current="$pid"
  local depth=0
  local cmd=""

  while [[ -n "$current" && "$current" =~ ^[0-9]+$ && "$current" != "0" && "$depth" -lt 24 ]]; do
    cmd="$(process_command "$current")"
    if [[ -n "$cmd" && "$cmd" =~ $regex ]] && pid_alive "$current"; then
      return 0
    fi
    current="$(process_parent_pid "$current")"
    depth=$((depth + 1))
  done

  return 1
}

visible_owner_browser_pid() {
  local pid
  pid="$(visible_owner_field BROWSER_PID)"
  if [[ -n "$pid" ]]; then
    printf '%s\n' "$pid"
    return 0
  fi
  visible_owner_field OWNER_PID
}

visible_owner_wrapper_pid() {
  visible_owner_field WRAPPER_PID
}

clear_stale_visible_browser_owner() {
  [[ -f "$VISIBLE_BROWSER_OWNER_FILE" ]] || return 0

  local owner_browser_pid
  local owner_port
  local listener_pid

  owner_browser_pid="$(visible_owner_browser_pid)"
  owner_port="$(visible_owner_field PORT)"
  listener_pid=""
  if [[ -n "$owner_port" ]]; then
    listener_pid="$(port_listener_pid "$owner_port")"
  fi

  if [[ -n "$owner_browser_pid" ]] && pid_alive "$owner_browser_pid"; then
    return 0
  fi
  if [[ -n "$listener_pid" ]] && is_browser_endpoint_ready "$owner_port"; then
    return 0
  fi

  rm -f "$VISIBLE_BROWSER_OWNER_FILE"
}

write_visible_browser_owner_file() {
  local browser_pid="$1"
  local identity_metadata=""

  if declare -F codex_session_metadata >/dev/null 2>&1; then
    identity_metadata="$(codex_session_metadata "${BROWSER_PORT:-0}" | sed '/^WRAPPER_PID=/d')"
  fi

  {
    cat <<EOF
OWNER_PID=${browser_pid}
WRAPPER_PID=${SCRIPT_PID}
BROWSER_PID=${browser_pid}
MODE=${MODE}
PORT=${BROWSER_PORT:-unknown}
HEADLESS=0
CLAIMED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
USER=${USER:-unknown}
EOF
    if [[ -n "$identity_metadata" ]]; then
      printf '%s\n' "$identity_metadata"
    fi
  } >"$VISIBLE_BROWSER_OWNER_FILE"
}

claim_visible_browser_owner() {
  local browser_pid="$1"
  local existing_browser_pid=""
  local existing_wrapper_pid=""
  local existing_mode=""
  local existing_port=""
  local existing_claimed_at=""
  local existing_browser_alive=0
  local existing_wrapper_alive=0
  local existing_listener_pid=""

  headful_mode_enabled || return 0
  [[ -n "$browser_pid" ]] || fail "Cannot claim visible browser ownership without a live browser PID."

  clear_stale_visible_browser_owner

  existing_browser_pid="$(visible_owner_browser_pid)"
  existing_wrapper_pid="$(visible_owner_wrapper_pid)"
  existing_mode="$(visible_owner_field MODE)"
  existing_port="$(visible_owner_field PORT)"
  existing_claimed_at="$(visible_owner_field CLAIMED_AT)"

  if [[ -n "$existing_port" ]]; then
    existing_listener_pid="$(port_listener_pid "$existing_port")"
  fi
  if [[ -n "$existing_browser_pid" ]] && pid_alive "$existing_browser_pid"; then
    existing_browser_alive=1
  elif [[ -n "$existing_listener_pid" ]] && is_browser_endpoint_ready "$existing_port"; then
    existing_browser_pid="$existing_listener_pid"
    existing_browser_alive=1
  fi
  if [[ -n "$existing_wrapper_pid" ]] && pid_alive "$existing_wrapper_pid"; then
    existing_wrapper_alive=1
  fi

  if (( existing_browser_alive == 1 )) && [[ "$existing_port" == "$BROWSER_PORT" ]] && [[ "$existing_mode" == "$MODE" ]] && (( existing_wrapper_alive == 0 )); then
    chrome_mcp_log "Refreshing visible browser owner metadata for persistent browser pid=${existing_browser_pid} on port ${existing_port} after wrapper pid=${existing_wrapper_pid:-missing} exited."
    write_visible_browser_owner_file "$browser_pid"
    return 0
  fi

  if (( existing_browser_alive == 1 )) && [[ "$existing_browser_pid" != "$browser_pid" || "$existing_port" != "$BROWSER_PORT" ]]; then
    if [[ "$HEADFUL_CONFLICT_ALLOWED" != "1" ]]; then
      fail "Visible browser already owned by browser pid=${existing_browser_pid} wrapper pid=${existing_wrapper_pid:-missing} mode=${existing_mode:-unknown} port=${existing_port:-unknown} since ${existing_claimed_at:-unknown}. Close that session first or set CODEX_CHROME_ALLOW_HEADFUL_CONFLICT=1 to override."
    fi
    chrome_mcp_log "Overriding visible browser owner browser_pid=${existing_browser_pid} wrapper_pid=${existing_wrapper_pid:-missing} because CODEX_CHROME_ALLOW_HEADFUL_CONFLICT=1."
  fi

  if (( existing_browser_alive == 1 )) && (( existing_wrapper_alive == 1 )) && [[ "$existing_wrapper_pid" != "$SCRIPT_PID" ]] && [[ "$existing_port" == "$BROWSER_PORT" ]] && [[ "$HEADFUL_CONFLICT_ALLOWED" != "1" ]]; then
    fail "Visible browser already has a live owner wrapper pid=${existing_wrapper_pid} for browser pid=${existing_browser_pid} on port ${existing_port}. Close that session first or set CODEX_CHROME_ALLOW_HEADFUL_CONFLICT=1 to override."
  fi

  write_visible_browser_owner_file "$browser_pid"
}

release_visible_browser_owner() {
  local owner_wrapper_pid=""
  local owner_browser_pid=""
  local owner_port=""
  [[ -f "$VISIBLE_BROWSER_OWNER_FILE" ]] || return 0
  owner_wrapper_pid="$(visible_owner_wrapper_pid)"
  owner_browser_pid="$(visible_owner_browser_pid)"
  owner_port="$(visible_owner_field PORT)"
  if [[ "$owner_wrapper_pid" != "$SCRIPT_PID" ]]; then
    return 0
  fi
  if [[ "$MODE" == "shared" ]] && headful_mode_enabled && pid_alive "$owner_browser_pid" && is_browser_endpoint_ready "${owner_port:-${BROWSER_PORT:-9422}}"; then
    return 0
  fi
  if [[ "$owner_wrapper_pid" == "$SCRIPT_PID" ]]; then
    rm -f "$VISIBLE_BROWSER_OWNER_FILE"
  fi
}

# Purge stderr logs older than 1 hour to prevent accumulation
find "$MCP_RUN_LOG_DIR" -name "npm-exec-*.stderr" -mmin +60 -delete 2>/dev/null || true
find "$MCP_RUN_LOG_DIR" -name "npm-exec-*.stderr.fifo" -mmin +60 -delete 2>/dev/null || true

# Unblock an external reader (e.g. Codex's tail) stuck on a named pipe by
# opening the write end with O_NONBLOCK.  This returns immediately with ENXIO
# if no reader has the fifo open, avoiding the blocking-forever pitfall of a
# normal open().  If a reader IS blocked, the write end opens instantly, we
# send a newline (causing the reader to see EOF after we close), then exit.
_unblock_fifo() {
  local fifo="$1"
  [[ -p "$fifo" ]] || return 0
  perl -e '
    use Fcntl;
    sysopen(my $fh, $ARGV[0], O_WRONLY | O_NONBLOCK) or exit 0;
    print $fh "\n";
    close $fh;
  ' "$fifo" 2>/dev/null || true
}

# Sweep for stale session artifacts left behind by dead wrapper processes.
# This catches cases where the wrapper was SIGKILL'd and neither cleanup()
# nor the orphan watchdog could run file-level cleanup.
_sweep_stale_mcp_sessions() {
  local stderr_file owner_pid fifo_file
  for stderr_file in "${MCP_RUN_LOG_DIR}"/npm-exec-*.stderr; do
    [[ -f "$stderr_file" ]] || continue
    # Don't process fifo companions here; handle them with their stderr file.
    [[ "$stderr_file" == *.fifo ]] && continue
    owner_pid="${stderr_file##*/npm-exec-}"
    owner_pid="${owner_pid%.stderr}"
    [[ "$owner_pid" =~ ^[0-9]+$ ]] || continue
    # Skip if session owner is still alive
    if kill -0 "$owner_pid" 2>/dev/null; then
      continue
    fi
    fifo_file="${stderr_file}.fifo"
    _unblock_fifo "$fifo_file"
    rm -f "$fifo_file" "$stderr_file"
  done
  # Kill orphaned telemetry watchdogs whose monitored parent is dead.
  local wd_pid wd_parent
  while IFS= read -r wd_pid; do
    [[ -n "$wd_pid" ]] || continue
    wd_parent="$(ps -o command= -p "$wd_pid" 2>/dev/null | sed -n 's/.*--parent-pid=\([0-9][0-9]*\).*/\1/p' || true)"
    if [[ -n "$wd_parent" ]] && ! kill -0 "$wd_parent" 2>/dev/null; then
      kill "$wd_pid" 2>/dev/null || true
    fi
  done < <(pgrep -f "chrome-devtools-mcp.*telemetry/watchdog" 2>/dev/null || true)

  # Kill orphaned Chrome browsers from dead isolated sessions.
  # Each isolated session writes a codex-chrome-session-<port>.env file with
  # WRAPPER_PID.  If the wrapper is dead, the Chrome on that port is a zombie
  # (since chrome-agent.sh detaches Chrome via nohup, it survives wrapper death).
  local session_env wrapper_pid session_port
  for session_env in "${LOG_DIR}"/codex-chrome-session-*.env; do
    [[ -f "$session_env" ]] || continue
    wrapper_pid="$(sed -n 's/^WRAPPER_PID=//p' "$session_env" 2>/dev/null || true)"
    [[ -n "$wrapper_pid" && "$wrapper_pid" =~ ^[0-9]+$ ]] || continue
    # Skip sessions whose wrapper is still alive
    if kill -0 "$wrapper_pid" 2>/dev/null; then
      continue
    fi
    # Extract port from filename: codex-chrome-session-<port>.env
    session_port="${session_env##*/codex-chrome-session-}"
    session_port="${session_port%.env}"
    [[ "$session_port" =~ ^[0-9]+$ ]] || continue
    chrome_mcp_log "Cleaning up orphaned Chrome session on port ${session_port} (dead wrapper PID ${wrapper_pid})"
    CHROME_AGENT_DEBUG_PORT="$session_port" bash "${ROOT}/scripts/stop-chrome-agent.sh" >/dev/null 2>&1 || true
    rm -f "$session_env"
    rm -f "${session_env%.env}.pages"
    rm -f "${LOG_DIR}/codex-chrome-port-${session_port}.reserve"
  done
}
_sweep_stale_mcp_sessions

# Stop non-isolated Playwright MCP processes that would compete on a shared
# Chrome port.  Playwright with --isolated launches its own Chromium and does
# not conflict; only bare `playwright-mcp` or `@playwright/mcp` without
# --isolated is a problem only when the visible/manual 9222 exception path is in use.
_stop_playwright_conflicts_on_port() {
  local port="$1"
  local pw_pid
  while IFS= read -r pw_pid; do
    [[ -n "$pw_pid" ]] || continue
    # Skip self and parent
    [[ "$pw_pid" == "$SCRIPT_PID" || "$pw_pid" == "$$" ]] && continue
    local pw_cmd
    pw_cmd="$(ps -o command= -p "$pw_pid" 2>/dev/null || true)"
    # Skip Playwright running with --isolated (own Chromium, no port overlap)
    if [[ "$pw_cmd" == *"--isolated"* ]]; then
      continue
    fi
    # Check if this Playwright process has a TCP connection to our port
    if lsof -nP -iTCP:"${port}" -a -p "$pw_pid" 2>/dev/null | grep -q .; then
      chrome_mcp_log "Stopping Playwright MCP (PID ${pw_pid}) competing on port ${port}"
      kill -TERM "$pw_pid" 2>/dev/null || true
      sleep 0.5
      kill -0 "$pw_pid" 2>/dev/null && kill -KILL "$pw_pid" 2>/dev/null || true
    fi
  done < <(pgrep -f '@playwright/mcp|playwright-mcp' 2>/dev/null || true)
}

if ! [[ "$BROWSER_READY_TIMEOUT_SEC" =~ ^[0-9]+$ ]] || (( BROWSER_READY_TIMEOUT_SEC < 1 )); then
  BROWSER_READY_TIMEOUT_SEC=20
fi

if ! [[ "$BROWSER_WATCH_MISS_THRESHOLD" =~ ^[0-9]+$ ]] || (( BROWSER_WATCH_MISS_THRESHOLD < 1 )); then
  BROWSER_WATCH_MISS_THRESHOLD=2
fi

pgid_for_pid() {
  local pid="$1"
  ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ' || true
}

kill_process_group() {
  local pgid="$1"
  local signal="${2:-TERM}"
  if [[ -z "$pgid" ]]; then
    return 0
  fi
  kill "-${signal}" -- "-${pgid}" 2>/dev/null || true
}

collect_descendants() {
  local pid="$1"
  local child

  for child in $(pgrep -P "$pid" 2>/dev/null || true); do
    collect_descendants "$child"
    printf '%s\n' "$child"
  done
}

terminate_descendants() {
  local pid="$1"
  local signal="${2:-TERM}"
  local child

  while IFS= read -r child; do
    if [[ -n "$child" ]]; then
      kill "-${signal}" "$child" 2>/dev/null || true
    fi
  done < <(collect_descendants "$pid" | awk '!seen[$0]++')
}

refresh_mcp_identity() {
  local pid="${1:-${MCP_PID:-}}"
  if [[ -z "$pid" || ! "$pid" =~ ^[0-9]+$ ]]; then
    return 0
  fi

  MCP_PID="$pid"
  MCP_PGID="$(pgid_for_pid "$pid")"
  if [[ -z "$MCP_PGID" ]]; then
    MCP_PGID="$pid"
  fi
}

kill_mcp_watchdogs_for_parent() {
  local parent_pid="$1"
  local signal="${2:-TERM}"
  local watchdog_pid=""
  local watchdog_parent=""

  [[ -n "$parent_pid" && "$parent_pid" =~ ^[0-9]+$ ]] || return 0

  while IFS= read -r watchdog_pid; do
    [[ -n "$watchdog_pid" ]] || continue
    watchdog_parent="$(ps -o command= -p "$watchdog_pid" 2>/dev/null | sed -n 's/.*--parent-pid=\([0-9][0-9]*\).*/\1/p' || true)"
    if [[ "$watchdog_parent" == "$parent_pid" ]]; then
      kill "-${signal}" "$watchdog_pid" 2>/dev/null || true
    fi
  done < <(pgrep -f "chrome-devtools-mcp.*telemetry/watchdog" 2>/dev/null || true)
}

terminate_mcp_runtime() {
  local reason="${1:-cleanup}"

  if [[ -n "$MCP_PID" ]]; then
    refresh_mcp_identity "$MCP_PID"
  fi

  if [[ -n "$MCP_PGID" ]]; then
    log_signal_path "kill-mcp-group-term" "reason=${reason}"
    kill_process_group "$MCP_PGID" TERM
    sleep 0.2
    if pid_alive "$MCP_PID"; then
      log_signal_path "kill-mcp-group-kill" "reason=${reason}"
      kill_process_group "$MCP_PGID" KILL
    fi
  elif [[ -n "$MCP_PID" ]]; then
    log_signal_path "kill-mcp-pid-term" "reason=${reason}"
    kill -TERM "$MCP_PID" 2>/dev/null || true
    sleep 0.2
    if pid_alive "$MCP_PID"; then
      log_signal_path "kill-mcp-pid-kill" "reason=${reason}"
      kill -KILL "$MCP_PID" 2>/dev/null || true
    fi
  fi

  if [[ -n "$MCP_PID" ]]; then
    kill_mcp_watchdogs_for_parent "$MCP_PID" TERM
    sleep 0.1
    kill_mcp_watchdogs_for_parent "$MCP_PID" KILL
  fi
}

cleanup_runtime_files() {
  if [[ -n "$RESERVATION_FILE" ]]; then
    rm -f "$RESERVATION_FILE"
  fi
  if [[ -n "$SHARED_WRAPPER_PIDFILE" && -f "$SHARED_WRAPPER_PIDFILE" ]]; then
    local recorded_pid=""
    recorded_pid="$(cat "$SHARED_WRAPPER_PIDFILE" 2>/dev/null || true)"
    if [[ "$recorded_pid" == "$SCRIPT_PID" ]]; then
      rm -f "$SHARED_WRAPPER_PIDFILE"
    fi
  fi
  if [[ -n "$SESSION_FILE" ]]; then
    rm -f "$SESSION_FILE"
  fi
  if [[ -n "$PAGE_ORDER_FILE" ]]; then
    rm -f "$PAGE_ORDER_FILE"
  fi
  release_visible_browser_owner
  local _cleanup_fifo="${MCP_RUN_LOG_DIR}/npm-exec-${SCRIPT_PID}.stderr.fifo"
  _unblock_fifo "$_cleanup_fifo"
  rm -f "${MCP_RUN_LOG_DIR}/npm-exec-${SCRIPT_PID}.stderr"
  rm -f "$_cleanup_fifo"
}

shared_browser_remediation() {
  local port="$1"
  cat >&2 <<EOF
[codex-chrome-mcp] Shared managed Chrome is not available on http://127.0.0.1:${port}.
[codex-chrome-mcp] Shared mode attempted to auto-launch Chrome, but the DevTools endpoint never became ready.
[codex-chrome-mcp] Remediation:
[codex-chrome-mcp]   CHROME_AGENT_DEBUG_PORT=${port} CHROME_AGENT_PROFILE_DIR=\${HOME}/.chrome-profiles/codex-agent bash "${ROOT}/scripts/chrome-agent.sh"
[codex-chrome-mcp] Then run: make chrome-devtools-mcp-status
[codex-chrome-mcp] If the tool is still missing in this chat after that, restart the Codex session.
EOF
}

ensure_node_baseline_or_fail() {
  local required_major
  required_major="$(trr_node_required_major "$ROOT")"
  if trr_ensure_node_baseline "$ROOT"; then
    return 0
  fi

  chrome_mcp_log "ERROR: Node $(trr_node_version_string) does not satisfy required ${required_major}.x baseline."
  chrome_mcp_log "ERROR: Remediation: source ~/.nvm/nvm.sh && nvm use ${required_major}"
  exit 1
}

clear_mcp_exec_cache() {
  rm -rf "$MCP_CACHE_DIR"
  mkdir -p "$MCP_CACHE_DIR"
}

start_parent_watchdog() {
  [[ -n "$ORIGINAL_PPID" && -n "$MCP_PID" ]] || return 0
  if [[ -n "$WATCHDOG_PID" ]] && pid_alive "$WATCHDOG_PID"; then
    return 0
  fi

  (
    exec </dev/null >/dev/null 2>&1
    _sweep_counter=0
    while sleep 5; do
      if ! kill -0 "$SCRIPT_PID" 2>/dev/null; then
        exit 0
      fi

      current_ppid="$(ps -o ppid= -p "$SCRIPT_PID" 2>/dev/null | tr -d ' ' || true)"
      _parent_alive=1
      if [[ -z "$current_ppid" ]]; then
        _parent_alive=0
      elif [[ "$ORIGINAL_PPID" != "1" && "$current_ppid" != "$ORIGINAL_PPID" ]]; then
        _parent_alive=0
      elif [[ "$ORIGINAL_PPID" != "1" ]] && ! kill -0 "$ORIGINAL_PPID" 2>/dev/null; then
        _parent_alive=0
      fi

      _sweep_counter=$((_sweep_counter + 1))
      if (( _sweep_counter >= 60 )); then
        _sweep_counter=0
        _sweep_stale_mcp_sessions 2>/dev/null || true
      fi

      if [[ "$_parent_alive" == "0" ]]; then
        log_signal_path "orphan-watchdog-parent-dead" "original_ppid=${ORIGINAL_PPID} current_ppid=${current_ppid:-missing}"
        kill -TERM "$SCRIPT_PID" 2>/dev/null || true
        sleep 1
        if kill -0 "$SCRIPT_PID" 2>/dev/null; then
          terminate_mcp_runtime "orphan_watchdog"
          log_signal_path "orphan-watchdog-kill-wrapper" "wrapper_still_alive=1"
          kill -KILL "$SCRIPT_PID" 2>/dev/null || true
          cleanup_runtime_files
        fi
        exit 0
      fi
    done
  ) &
  WATCHDOG_PID=$!
}

run_chrome_devtools_mcp() {
  local attempt=1
  local stderr_file="${MCP_RUN_LOG_DIR}/npm-exec-${SCRIPT_PID}.stderr"
  local status
  local mcp_pid=""
  local stdin_fd=9

  while true; do
    : >"$stderr_file"
    if [[ "${CODEX_CHROME_MCP_TEST_FORCE_ENOTEMPTY_ONCE:-0}" == "1" && "$attempt" -eq 1 ]]; then
      printf 'npm error code ENOTEMPTY\nnpm error ENOTEMPTY: simulated workspace cache corruption\n' | tee "$stderr_file" >&2 >/dev/null
      status=190
    else
      # Use a named pipe instead of process substitution to avoid orphaned
      # tee processes.  The tee runs as a tracked background job so cleanup()
      # can kill it reliably.
      local stderr_fifo="${stderr_file}.fifo"
      rm -f "$stderr_fifo"
      mkfifo "$stderr_fifo"
      tee "$stderr_file" < "$stderr_fifo" >&2 &
      MCP_TEE_PID=$!

      # Background jobs in a non-interactive shell are otherwise given stdin
      # from /dev/null, which breaks the MCP stdio handshake. Duplicate the
      # wrapper stdin first so the child keeps the live transport. Use a fixed
      # FD for Bash 3.2 compatibility on macOS.
      exec 9<&0
      # Keep the wrapper shell alive while the MCP child runs so TERM/HUP traps
      # can forward signals and clean up the full npm/node subtree.
      if [[ -n "$SETSID_BIN" ]]; then
        NPM_CONFIG_UPDATE_NOTIFIER=false NPM_CONFIG_FUND=false "$SETSID_BIN" npm exec --yes --cache "$MCP_CACHE_DIR" --package "$MCP_PACKAGE" -- chrome-devtools-mcp "$@" \
          <&9 2>"$stderr_fifo" &
        mcp_pid=$!
      else
        NPM_CONFIG_UPDATE_NOTIFIER=false NPM_CONFIG_FUND=false npm exec --yes --cache "$MCP_CACHE_DIR" --package "$MCP_PACKAGE" -- chrome-devtools-mcp "$@" \
          <&9 2>"$stderr_fifo" &
        mcp_pid=$!
      fi
      refresh_mcp_identity "$mcp_pid"
      log_signal_path "spawn-mcp" "stderr_fifo=${stderr_fifo}"
      start_parent_watchdog

      if wait "$mcp_pid"; then
        kill "$MCP_TEE_PID" 2>/dev/null || true
        wait "$MCP_TEE_PID" 2>/dev/null || true
        MCP_TEE_PID=""
        if [[ -n "$WATCHDOG_PID" ]]; then
          kill "$WATCHDOG_PID" 2>/dev/null || true
          wait "$WATCHDOG_PID" 2>/dev/null || true
          WATCHDOG_PID=""
        fi
        exec 9<&-
        rm -f "$stderr_file" "$stderr_fifo"
        return 0
      else
        status=$?
      fi
      kill "$MCP_TEE_PID" 2>/dev/null || true
      wait "$MCP_TEE_PID" 2>/dev/null || true
      MCP_TEE_PID=""
      if [[ -n "$WATCHDOG_PID" ]]; then
        kill "$WATCHDOG_PID" 2>/dev/null || true
        wait "$WATCHDOG_PID" 2>/dev/null || true
        WATCHDOG_PID=""
      fi
      exec 9<&-
      rm -f "$stderr_fifo"
      if [[ "$status" == "0" ]]; then
        rm -f "$stderr_file"
        return 0
      fi
    fi

    if (( attempt >= 2 )) || ! grep -q 'ENOTEMPTY' "$stderr_file"; then
      rm -f "$stderr_file"
      return "$status"
    fi

    chrome_mcp_log "Detected corrupt workspace npm exec cache at ${MCP_CACHE_DIR}; clearing and retrying once."
    clear_mcp_exec_cache
    attempt=$((attempt + 1))
  done
}

is_info_invocation() {
  if [[ "$#" -eq 0 ]]; then
    return 1
  fi

  local arg
  for arg in "$@"; do
    case "$arg" in
      --help|-h|help|--version|-v|-V|version)
        ;;
      *)
        return 1
        ;;
    esac
  done

  return 0
}

is_port_listening() {
  local port="$1"
  if command -v lsof >/dev/null 2>&1; then
    if lsof -nP -iTCP:"${port}" -sTCP:LISTEN -t >/dev/null 2>&1; then
      return 0
    fi
    return 1
  fi

  curl -sf "http://127.0.0.1:${port}/json/version" >/dev/null 2>&1
}

is_browser_endpoint_ready() {
  local port="$1"
  curl -sf "http://127.0.0.1:${port}/json/version" >/dev/null 2>&1
}

available_memory_mb() {
  local page_size
  local pages_free
  local pages_inactive

  page_size="$(vm_stat | awk '/page size of/ {gsub(/[^0-9]/, "", $8); print $8; exit}')"
  [[ -n "$page_size" ]] || page_size=4096
  pages_free="$(vm_stat | awk '/Pages free/ {gsub("\\.", "", $3); print $3; exit}')"
  pages_inactive="$(vm_stat | awk '/Pages inactive/ {gsub("\\.", "", $3); print $3; exit}')"
  [[ -n "$pages_free" ]] || pages_free=0
  [[ -n "$pages_inactive" ]] || pages_inactive=0
  echo $((((pages_free + pages_inactive) * page_size) / 1024 / 1024))
}

managed_chrome_root_count() {
  local port
  local sessionfile
  {
    port_listener_pid "9222"
    port_listener_pid "9422"
    shopt -s nullglob
    for sessionfile in "${LOG_DIR}"/codex-chrome-session-*.env; do
      port="$(sed -n 's/^PORT=//p' "$sessionfile" | head -n 1)"
      [[ -n "$port" ]] || continue
      port_listener_pid "$port"
    done
    shopt -u nullglob
  } | sed '/^$/d' | awk '!seen[$0]++' | wc -l | tr -d ' '
}

enforce_browser_pressure_guard() {
  local launch_kind="$1"
  local free_mb
  local managed_roots

  managed_roots="$(managed_chrome_root_count)"
  if [[ "$managed_roots" =~ ^[0-9]+$ ]] && (( managed_roots >= MANAGED_CHROME_ROOT_LIMIT )) && [[ "$launch_kind" == "isolated" ]]; then
    fail "Managed Chrome root count is ${managed_roots}, at or above the safe limit ${MANAGED_CHROME_ROOT_LIMIT}. Refusing another isolated browser launch. Run: make mcp-clean or switch to shared mode."
  fi

  free_mb="$(available_memory_mb)"
  if [[ "$free_mb" =~ ^[0-9]+$ ]] && (( free_mb < MEMORY_GUARD_MB )); then
    fail "Only ${free_mb}MB free memory remains; refusing to launch ${launch_kind} browser work below ${MEMORY_GUARD_MB}MB. Use shared mode or run make mcp-clean."
  fi
}

enforce_memory_budget_for_isolated() {
  enforce_browser_pressure_guard "isolated"
}

wait_for_browser_endpoint() {
  local port="$1"
  local timeout_sec="${2:-20}"
  local attempts=1
  local i

  if ! [[ "$timeout_sec" =~ ^[0-9]+$ ]] || (( timeout_sec < 1 )); then
    timeout_sec=20
  fi

  attempts=$((timeout_sec * 4))
  if (( attempts < 1 )); then
    attempts=1
  fi

  for ((i = 1; i <= attempts; i++)); do
    if is_browser_endpoint_ready "$port"; then
      return 0
    fi
    sleep 0.25
  done

  return 1
}

ensure_isolated_browser_ready_or_fail() {
  local port="$1"
  local profile_dir="$2"
  local log_file="${LOG_DIR}/chrome-agent-${port}.log"

  if wait_for_browser_endpoint "$port" "$BROWSER_READY_TIMEOUT_SEC"; then
    return 0
  fi

  chrome_mcp_log "Isolated Chrome on ${port} did not expose DevTools within ${BROWSER_READY_TIMEOUT_SEC}s; restarting once."
  CHROME_AGENT_DEBUG_PORT="$port" bash "${ROOT}/scripts/stop-chrome-agent.sh" >/dev/null 2>&1 || true
  CHROME_AGENT_PROFILE_DIR="$profile_dir" CHROME_AGENT_DEBUG_PORT="$port" CHROME_AGENT_HEADLESS="$ISOLATED_HEADLESS" bash "${ROOT}/scripts/chrome-agent.sh" >/dev/null

  if wait_for_browser_endpoint "$port" "$BROWSER_READY_TIMEOUT_SEC"; then
    return 0
  fi

  fail "Unable to reach isolated Chrome endpoint http://127.0.0.1:${port}/json/version after retry. Check ${log_file}."
}

cleanup_stale_state_for_port() {
  local port="$1"
  local pidfile="${LOG_DIR}/chrome-agent-${port}.pid"
  local statefile="${LOG_DIR}/chrome-agent-${port}.env"
  local reservefile="${LOG_DIR}/codex-chrome-port-${port}.reserve"
  local listener_pid=""

  if [[ -f "$pidfile" ]]; then
    local pid
    pid="$(cat "$pidfile" 2>/dev/null || true)"
    listener_pid="$(lsof -nP -iTCP:"${port}" -sTCP:LISTEN -t 2>/dev/null | head -n 1 || true)"
    if [[ -z "$listener_pid" ]] && ! is_browser_endpoint_ready "$port"; then
      rm -f "$pidfile" "$statefile"
    elif [[ -n "$listener_pid" && "$listener_pid" != "$pid" ]]; then
      printf '%s\n' "$listener_pid" >"$pidfile"
    fi
  fi

  if [[ -f "$reservefile" ]]; then
    local owner_pid
    owner_pid="$(cat "$reservefile" 2>/dev/null || true)"
    if [[ -z "$owner_pid" ]] || ! kill -0 "$owner_pid" >/dev/null 2>&1; then
      rm -f "$reservefile"
    fi
  fi
}

count_live_isolated_sessions() {
  local sessionfile
  local port
  local count=0

  shopt -s nullglob
  for sessionfile in "${LOG_DIR}"/codex-chrome-session-*.env; do
    port="$(sed -n 's/^PORT=//p' "$sessionfile" | head -n 1)"
    [[ -n "$port" ]] || continue
    if is_browser_endpoint_ready "$port"; then
      count=$((count + 1))
    fi
  done
  shopt -u nullglob
  echo "$count"
}

enforce_isolated_session_cap() {
  local live_sessions
  live_sessions="$(count_live_isolated_sessions)"
  if [[ "$live_sessions" =~ ^[0-9]+$ ]] && (( live_sessions >= MAX_ISOLATED_SESSIONS )); then
    fail "Refusing to launch isolated Chrome session ${live_sessions}/${MAX_ISOLATED_SESSIONS}. Close or reap an older session, or use shared mode."
  fi
}

pick_available_port() {
  local start="$1"
  local end="$2"
  local port
  for port in $(seq "$start" "$end"); do
    cleanup_stale_state_for_port "$port"
    if [[ -f "${LOG_DIR}/chrome-agent-${port}.pid" ]]; then
      continue
    fi
    if [[ -f "${LOG_DIR}/codex-chrome-port-${port}.reserve" ]]; then
      continue
    fi
    if is_port_listening "$port"; then
      continue
    fi
    echo "$port"
    return 0
  done
  return 1
}

reserve_port_with_lock() {
  local selected=""

  if command -v flock >/dev/null 2>&1; then
    exec 8>"$PORT_LOCKFILE"
    flock -x 8
    selected="$(pick_available_port "$START_PORT" "$END_PORT" || true)"
    if [[ -n "$selected" ]]; then
      RESERVATION_FILE="${LOG_DIR}/codex-chrome-port-${selected}.reserve"
      echo "$$" >"$RESERVATION_FILE"
    fi
    flock -u 8
    exec 8>&-
  else
    local spin=0
    local dir_lock="${PORT_LOCKFILE}.d"
    while true; do
      if mkdir "$dir_lock" 2>/dev/null; then
        echo "$$" >"${dir_lock}/pid"
        break
      fi

      local owner_pid=""
      if [[ -f "${dir_lock}/pid" ]]; then
        owner_pid="$(cat "${dir_lock}/pid" 2>/dev/null || true)"
      fi
      if [[ -n "$owner_pid" ]] && ! kill -0 "$owner_pid" >/dev/null 2>&1; then
        rm -rf "$dir_lock"
        continue
      fi

      sleep 0.2
      spin=$((spin + 1))
      if (( spin > 50 )); then
        fail "Timed out waiting for lock ${dir_lock}. Remove stale lock and retry."
      fi
    done
    selected="$(pick_available_port "$START_PORT" "$END_PORT" || true)"
    if [[ -n "$selected" ]]; then
      RESERVATION_FILE="${LOG_DIR}/codex-chrome-port-${selected}.reserve"
      echo "$$" >"$RESERVATION_FILE"
    fi
    rm -rf "$dir_lock"
  fi

  if [[ -z "$selected" ]]; then
    fail "No free Chrome debug ports in range ${START_PORT}-${END_PORT}. Adjust CODEX_CHROME_PORT_RANGE_*."
  fi

  echo "$selected"
}

seed_profile_if_needed() {
  local profile_dir="$1"
  if [[ -d "$profile_dir" ]] && [[ -n "$(ls -A "$profile_dir" 2>/dev/null || true)" ]]; then
    return 0
  fi

  if [[ ! -d "$SEED_PROFILE_DIR" ]]; then
    fail "Seed profile not found at ${SEED_PROFILE_DIR}. Start shared profile once and sign in."
  fi
  if ! command -v rsync >/dev/null 2>&1; then
    fail "rsync is required for profile seeding."
  fi

  mkdir -p "$profile_dir"
  chrome_mcp_log "Seeding profile ${profile_dir} from ${SEED_PROFILE_DIR}"
  rsync -a \
    --exclude='Cache/' \
    --exclude='Code Cache/' \
    --exclude='GPUCache/' \
    --exclude='GrShaderCache/' \
    --exclude='DawnCache/' \
    --exclude='ShaderCache/' \
    --exclude='Crashpad/' \
    --exclude='Singleton*' \
    "${SEED_PROFILE_DIR}/" \
    "${profile_dir}/"
}

cleanup() {
  if [[ "$CLEANUP_DONE" == "1" ]]; then
    return 0
  fi
  CLEANUP_DONE=1
  # Disable errexit inside cleanup so a single failure doesn't abort the
  # entire teardown chain, leaving processes or files behind.
  set +e

  if [[ -n "$WATCHDOG_PID" ]]; then
    kill "$WATCHDOG_PID" 2>/dev/null || true
  fi
  if [[ -n "$TAB_WATCH_PID" ]]; then
    kill "$TAB_WATCH_PID" 2>/dev/null || true
  fi
  if [[ -n "$BROWSER_WATCH_PID" ]]; then
    kill "$BROWSER_WATCH_PID" 2>/dev/null || true
  fi
  if [[ -n "$STDIN_WATCH_PID" ]]; then
    kill "$STDIN_WATCH_PID" 2>/dev/null || true
  fi
  if [[ -n "$MCP_TEE_PID" ]]; then
    kill "$MCP_TEE_PID" 2>/dev/null || true
  fi
  terminate_mcp_runtime "cleanup"
  if [[ "$MODE" != "shared" ]]; then
    # Isolated mode still owns auxiliary children such as tab/browser watchers.
    terminate_descendants "$SCRIPT_PID" TERM
    sleep 0.2
    terminate_descendants "$SCRIPT_PID" KILL
  fi
  cleanup_runtime_files

  if [[ "$STOP_ON_EXIT" == "1" ]] && [[ -n "$BROWSER_PORT" ]]; then
    CHROME_AGENT_DEBUG_PORT="$BROWSER_PORT" bash "${ROOT}/scripts/stop-chrome-agent.sh" >/dev/null 2>&1 || true
  fi
}

reap_other_shared_wrapper_groups() {
  local browser_url="$1"
  local wrapper_pid
  local wrapper_pgid

  while IFS= read -r wrapper_pid; do
    if [[ -z "$wrapper_pid" || "$wrapper_pid" == "$SCRIPT_PID" ]]; then
      continue
    fi
    wrapper_pgid="$(pgid_for_pid "$wrapper_pid")"
    if [[ -z "$wrapper_pgid" || "$wrapper_pgid" == "$SCRIPT_PGID" ]]; then
      continue
    fi
    if ps -axo pgid=,command= | awk -v pgid="$wrapper_pgid" -v browser_url="$browser_url" '
      $1 == pgid && index($0, browser_url) { found = 1 }
      END { exit(found ? 0 : 1) }
    '; then
      chrome_mcp_log "Stopping older shared Chrome MCP process group ${wrapper_pgid} bound to ${browser_url}."
      kill_process_group "$wrapper_pgid" TERM
      sleep 0.5
      kill_process_group "$wrapper_pgid" KILL
    fi
  done < <(
    ps -axo pid=,pgid=,command= | awk -v script="${ROOT}/scripts/codex-chrome-devtools-mcp.sh" '
      $1 == $2 && index($0, script) { print $1 }
    '
  )
}

wrapper_pid_for_mcp_process() {
  local pid="$1"
  local stderr_target=""
  local wrapper_pid=""

  stderr_target="$(
    lsof -nP -a -p "$pid" -d2 2>/dev/null | awk '
      /npm-exec-[0-9]+\.stderr\.fifo$/ {
        print $NF
        exit
      }
    '
  )"
  if [[ -z "$stderr_target" ]]; then
    return 1
  fi

  wrapper_pid="$(printf '%s\n' "$stderr_target" | sed -n 's/.*npm-exec-\([0-9][0-9]*\)\.stderr\.fifo$/\1/p')"
  if [[ -z "$wrapper_pid" ]]; then
    return 1
  fi

  printf '%s\n' "$wrapper_pid"
}

reap_orphaned_mcp_for_port() {
  local port="$1"
  local pattern="chrome-devtools-mcp.*browserUrl.*127\\.0\\.0\\.1:${port}"
  local pid
  local wrapper_pid
  local -a stale_pids=()
  local -a stale_watchdogs=()
  local watchdog_pid
  local watchdog_parent

  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    wrapper_pid="$(wrapper_pid_for_mcp_process "$pid" || true)"
    if [[ -z "$wrapper_pid" || "$wrapper_pid" == "$SCRIPT_PID" ]]; then
      continue
    fi
    if ! kill -0 "$wrapper_pid" >/dev/null 2>&1; then
      stale_pids+=("$pid")
    fi
  done < <(pgrep -f "$pattern" 2>/dev/null || true)

  while IFS= read -r watchdog_pid; do
    [[ -n "$watchdog_pid" ]] || continue
    watchdog_parent="$(ps -o command= -p "$watchdog_pid" 2>/dev/null | sed -n 's/.*--parent-pid=\([0-9][0-9]*\).*/\1/p' || true)"
    if [[ -n "$watchdog_parent" ]] && ! kill -0 "$watchdog_parent" >/dev/null 2>&1; then
      stale_watchdogs+=("$watchdog_pid")
    fi
  done < <(pgrep -f "telemetry/watchdog/main\\.js" 2>/dev/null || true)

  for pid in "${stale_pids[@]}"; do
    chrome_mcp_log "Stopping orphaned chrome-devtools-mcp process pid=${pid} (wrapper already exited)."
    kill -TERM "$pid" 2>/dev/null || true
  done
  for watchdog_pid in "${stale_watchdogs[@]}"; do
    chrome_mcp_log "Stopping orphaned chrome-devtools telemetry watchdog pid=${watchdog_pid}."
    kill -TERM "$watchdog_pid" 2>/dev/null || true
  done

  if (( ${#stale_pids[@]} == 0 && ${#stale_watchdogs[@]} == 0 )); then
    return 0
  fi

  sleep 0.3
  for pid in "${stale_pids[@]}"; do
    if kill -0 "$pid" >/dev/null 2>&1; then
      kill -KILL "$pid" 2>/dev/null || true
    fi
  done
  for watchdog_pid in "${stale_watchdogs[@]}"; do
    if kill -0 "$watchdog_pid" >/dev/null 2>&1; then
      kill -KILL "$watchdog_pid" 2>/dev/null || true
    fi
  done
}

register_shared_wrapper() {
  local port="$1"
  local pidfile="${LOG_DIR}/codex-chrome-shared-wrapper-${port}.pid"
  local existing_pid=""
  local existing_pgid=""

  if command -v flock >/dev/null 2>&1; then
    exec 8>"$PORT_LOCKFILE"
    flock -x 8
    if [[ -f "$pidfile" ]]; then
      existing_pid="$(cat "$pidfile" 2>/dev/null || true)"
      if [[ -n "$existing_pid" && "$existing_pid" != "$SCRIPT_PID" ]] && kill -0 "$existing_pid" >/dev/null 2>&1; then
        existing_pgid="$(pgid_for_pid "$existing_pid")"
        if [[ -n "$existing_pgid" && "$existing_pgid" != "$SCRIPT_PGID" ]]; then
          chrome_mcp_log "Replacing older shared Chrome MCP wrapper pid=${existing_pid} pgid=${existing_pgid}."
          kill_process_group "$existing_pgid" TERM
          sleep 0.5
          kill_process_group "$existing_pgid" KILL
        fi
      fi
    fi
    echo "$SCRIPT_PID" >"$pidfile"
    flock -u 8
    exec 8>&-
  else
    echo "$SCRIPT_PID" >"$pidfile"
  fi

  SHARED_WRAPPER_PIDFILE="$pidfile"
}

write_isolated_session_file() {
  local profile_dir="$1"
  local page_count="${2:-0}"
  local working_tab_id="${3:-}"
  local identity_metadata=""

  if [[ -z "$SESSION_FILE" ]]; then
    return 0
  fi

  if declare -F codex_session_metadata >/dev/null 2>&1; then
    identity_metadata="$(codex_session_metadata "$BROWSER_PORT" | sed '/^WRAPPER_PID=/d')"
  fi

  {
    cat <<EOF
MODE=isolated
PORT=${BROWSER_PORT}
PROFILE_DIR=${profile_dir}
HEADLESS=${ISOLATED_HEADLESS}
WRAPPER_PID=${SCRIPT_PID}
TAB_TARGET=${TAB_TARGET}
TAB_CAP=${TAB_CAP}
WORKING_TAB_ID=${working_tab_id}
LAST_PAGE_COUNT=${page_count}
LAST_TRIM_AT=
EOF
    if [[ -n "$identity_metadata" ]]; then
      printf '%s\n' "$identity_metadata"
    fi
  } >"$SESSION_FILE"
}

start_isolated_tab_watch() {
  if [[ "$ENABLE_TAB_WATCH" != "1" ]]; then
    return 0
  fi
  if [[ "$MODE" != "isolated" || -z "$BROWSER_PORT" || -z "$SESSION_FILE" ]]; then
    return 0
  fi

  PAGE_ORDER_FILE="${SESSION_FILE%.env}.pages"
  : >"$PAGE_ORDER_FILE"
  CODEX_CHROME_TAB_CAP="$TAB_CAP" \
    CODEX_CHROME_TAB_TARGET="$TAB_TARGET" \
    CODEX_CHROME_TAB_WATCH_INTERVAL_SEC="$TAB_WATCH_INTERVAL" \
    bash "${ROOT}/scripts/chrome-devtools-mcp-tab-cap.sh" watch "$BROWSER_PORT" "$SESSION_FILE" "$SCRIPT_PID" >/dev/null 2>&1 &
  TAB_WATCH_PID=$!
}

start_isolated_browser_watchdog() {
  local profile_dir="$1"
  if [[ "$MODE" != "isolated" || -z "$BROWSER_PORT" ]]; then
    return 0
  fi

  (
    local miss_count=0
    while true; do
      sleep "$BROWSER_WATCH_INTERVAL_SEC"
      if ! kill -0 "$SCRIPT_PID" 2>/dev/null; then
        exit 0
      fi
      if is_browser_endpoint_ready "$BROWSER_PORT"; then
        miss_count=0
        continue
      fi
      miss_count=$((miss_count + 1))
      if (( miss_count < BROWSER_WATCH_MISS_THRESHOLD )); then
        continue
      fi
      miss_count=0
      chrome_mcp_log "Isolated Chrome endpoint on ${BROWSER_PORT} is unavailable; restarting managed Chrome."
      CHROME_AGENT_DEBUG_PORT="$BROWSER_PORT" bash "${ROOT}/scripts/stop-chrome-agent.sh" >/dev/null 2>&1 || true
      CHROME_AGENT_PROFILE_DIR="$profile_dir" CHROME_AGENT_DEBUG_PORT="$BROWSER_PORT" CHROME_AGENT_HEADLESS="$ISOLATED_HEADLESS" bash "${ROOT}/scripts/chrome-agent.sh" >/dev/null 2>&1 || true
      if wait_for_browser_endpoint "$BROWSER_PORT" "$BROWSER_READY_TIMEOUT_SEC"; then
        chrome_mcp_log "Isolated Chrome endpoint restored on ${BROWSER_PORT}."
      else
        chrome_mcp_log "Isolated Chrome restart attempt failed on ${BROWSER_PORT}; see ${LOG_DIR}/chrome-agent-${BROWSER_PORT}.log."
      fi
    done
  ) &
  BROWSER_WATCH_PID=$!
}

ensure_node_baseline_or_fail
SCRIPT_PGID="$(pgid_for_pid "$SCRIPT_PID")"
ORIGINAL_PPID="$(ps -o ppid= -p "$SCRIPT_PID" 2>/dev/null | tr -d ' ' || true)"

if [[ "$SKIP_BROWSER_BOOT" == "1" ]] || is_info_invocation "$@"; then
  run_chrome_devtools_mcp "$@"
  exit $?
fi

if [[ "$DIAGNOSTIC_ONLY" == "1" ]]; then
  if [[ "$MODE" == "isolated" ]]; then
    BROWSER_PORT="${FORCED_PORT:-0}"
  else
    BROWSER_PORT="${FORCED_PORT:-9422}"
  fi
  echo "mode=${MODE}"
  echo "port=${BROWSER_PORT}"
  if [[ "$BROWSER_PORT" != "0" ]] && is_port_listening "$BROWSER_PORT"; then
    echo "browser_state=reachable"
  else
    echo "browser_state=missing"
  fi
  exit 0
fi

trap 'cleanup' EXIT
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 129' HUP
trap 'cleanup; exit 143' TERM

case "$MODE" in
  shared)
    BROWSER_PORT="${FORCED_PORT:-9422}"
    if [[ "$BROWSER_PORT" != "9422" && "$BROWSER_PORT" != "9222" ]]; then
      fail "Shared mode supports the default automation port 9422 and the explicit visible/manual port 9222."
    fi
    cleanup_stale_state_for_port "$BROWSER_PORT"
    if ! is_port_listening "$BROWSER_PORT"; then
      if headful_mode_enabled; then
        enforce_browser_pressure_guard "shared"
      fi
      chrome_mcp_log "Shared Chrome not running on ${BROWSER_PORT}; auto-launching..."
      CHROME_AGENT_DEBUG_PORT="$BROWSER_PORT" \
        CHROME_AGENT_PROFILE_DIR="${SEED_PROFILE_DIR}" \
        CHROME_AGENT_HEADLESS="${SHARED_HEADLESS}" \
        bash "${ROOT}/scripts/chrome-agent.sh" >/dev/null
      chrome_mcp_log "Shared Chrome auto-launched on ${BROWSER_PORT}."
    fi
    if ! wait_for_browser_endpoint "$BROWSER_PORT" "$BROWSER_READY_TIMEOUT_SEC"; then
      shared_browser_remediation "$BROWSER_PORT"
      fail "Shared Chrome endpoint did not become ready on ${BROWSER_PORT}."
    fi
    if headful_mode_enabled; then
      claim_visible_browser_owner "$(port_listener_pid "$BROWSER_PORT")"
    fi
    # Shared Chrome must support concurrent MCP clients from multiple Codex
    # threads. Singleton preemption is opt-in only for manual experiments.
    reap_orphaned_mcp_for_port "$BROWSER_PORT"
    # Auto-stop non-isolated Playwright MCP processes that compete on the same
    # shared port.  Playwright with --isolated has its own Chromium and is fine.
    _stop_playwright_conflicts_on_port "$BROWSER_PORT"
    if [[ "$SHARED_SINGLETON" == "1" ]]; then
      register_shared_wrapper "$BROWSER_PORT"
      reap_other_shared_wrapper_groups "http://127.0.0.1:${BROWSER_PORT}"
    fi
    ;;
  isolated)
    BROWSER_PORT="${FORCED_PORT:-}"
    enforce_isolated_session_cap
    enforce_memory_budget_for_isolated
    if [[ -n "$FORCED_PORT" ]]; then
      if [[ "$FORCED_PORT" =~ ^[0-9]+$ ]]; then
        BROWSER_PORT="$FORCED_PORT"
      else
        fail "CODEX_CHROME_PORT must be numeric. Received: ${FORCED_PORT}"
      fi
      cleanup_stale_state_for_port "$BROWSER_PORT"
      if is_port_listening "$BROWSER_PORT"; then
        fail "Requested CODEX_CHROME_PORT ${BROWSER_PORT} is already in use."
      fi
      RESERVATION_FILE="${LOG_DIR}/codex-chrome-port-${BROWSER_PORT}.reserve"
      echo "$$" >"$RESERVATION_FILE"
    else
      BROWSER_PORT="$(reserve_port_with_lock)"
    fi

    profile_dir="${HOME}/.chrome-profiles/codex-chat-${BROWSER_PORT}"
    seed_profile_if_needed "$profile_dir"
    CHROME_AGENT_PROFILE_DIR="$profile_dir" CHROME_AGENT_DEBUG_PORT="$BROWSER_PORT" CHROME_AGENT_HEADLESS="$ISOLATED_HEADLESS" bash "${ROOT}/scripts/chrome-agent.sh" >/dev/null
    STOP_ON_EXIT=1
    ensure_isolated_browser_ready_or_fail "$BROWSER_PORT" "$profile_dir"
    if headful_mode_enabled; then
      claim_visible_browser_owner "$(port_listener_pid "$BROWSER_PORT")"
    fi
    SESSION_FILE="${LOG_DIR}/codex-chrome-session-${BROWSER_PORT}.env"
    write_isolated_session_file "$profile_dir" "0" ""
    start_isolated_tab_watch
    start_isolated_browser_watchdog "$profile_dir"
    ;;
  *)
    fail "Unsupported CODEX_CHROME_MODE: ${MODE}. Use 'isolated' or 'shared'."
    ;;
esac

chrome_mcp_log "Using Chrome DevTools endpoint http://127.0.0.1:${BROWSER_PORT} (mode=${MODE})"

# Stdin watchdog: if the MCP client (Codex) disconnects, stdin becomes
# unreadable.  The chrome-devtools-mcp node process may not notice (npm
# swallows SIGPIPE), so we monitor stdin readability in the background and
# trigger cleanup when it goes dead.  This catches the case where the parent
# exits but the wrapper's orphan watchdog hasn't fired yet.
(
  exec 2>/dev/null
  while true; do
    if ! kill -0 "$SCRIPT_PID" 2>/dev/null; then
      exit 0
    fi
    # Check if stdin of the wrapper is still open via lsof.
    if ! lsof -a -p "$SCRIPT_PID" -d0 >/dev/null 2>&1; then
      kill -TERM "$SCRIPT_PID" 2>/dev/null || true
      exit 0
    fi
    sleep 5
  done
) &
STDIN_WATCH_PID=$!

# Keep the MCP server in the foreground so Codex can complete the stdio handshake.
# Backgrounding the process causes stdin to be detached in non-interactive shells.
run_chrome_devtools_mcp --browserUrl "http://127.0.0.1:${BROWSER_PORT}" "$@"
_MCP_EXIT=$?

# Clean up stdin watchdog
kill "$STDIN_WATCH_PID" 2>/dev/null || true

exit "$_MCP_EXIT"

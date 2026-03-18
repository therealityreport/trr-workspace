#!/usr/bin/env bash
set -euo pipefail

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
SEED_PROFILE_DIR="${CODEX_CHROME_SEED_PROFILE_DIR:-${HOME}/.chrome-profiles/claude-agent}"
ISOLATED_HEADLESS="${CODEX_CHROME_ISOLATED_HEADLESS:-1}"
SKIP_BROWSER_BOOT="${CODEX_CHROME_SKIP_BROWSER_BOOT:-0}"
DIAGNOSTIC_ONLY="${CODEX_CHROME_DIAGNOSTIC_ONLY:-0}"
TAB_CAP="${CODEX_CHROME_TAB_CAP:-3}"
TAB_TARGET="${CODEX_CHROME_TAB_TARGET:-1}"
TAB_WATCH_INTERVAL="${CODEX_CHROME_TAB_WATCH_INTERVAL_SEC:-2}"
BROWSER_READY_TIMEOUT_SEC="${CODEX_CHROME_BROWSER_READY_TIMEOUT_SEC:-20}"
BROWSER_WATCH_INTERVAL_SEC="${CODEX_CHROME_BROWSER_WATCH_INTERVAL_SEC:-5}"
BROWSER_WATCH_MISS_THRESHOLD="${CODEX_CHROME_BROWSER_WATCH_MISS_THRESHOLD:-2}"

BROWSER_PORT=""
RESERVATION_FILE=""
STOP_ON_EXIT=0
CLEANUP_DONE=0
MCP_TEE_PID=""
WATCHDOG_PID=""
TAB_WATCH_PID=""
BROWSER_WATCH_PID=""
SCRIPT_PID="${BASHPID:-$$}"
SCRIPT_PGID=""
SHARED_WRAPPER_PIDFILE=""
SESSION_FILE=""
PAGE_ORDER_FILE=""

mkdir -p "$LOG_DIR" "$MCP_CACHE_DIR" "$MCP_RUN_LOG_DIR"

# Avoid colliding with macOS `/usr/bin/log` during wrapper bootstrap.
chrome_mcp_log() {
  echo "[codex-chrome-mcp] $*" >&2
}

fail() {
  chrome_mcp_log "ERROR: $*"
  exit 1
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
    wd_parent="$(ps -o command= -p "$wd_pid" 2>/dev/null | sed -n 's/.*--parent-pid=\([0-9][0-9]*\).*/\1/p')"
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
# --isolated is a problem on shared port 9222.
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
  ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' '
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

shared_browser_remediation() {
  local port="$1"
  cat >&2 <<EOF
[codex-chrome-mcp] Shared managed Chrome is not available on http://127.0.0.1:${port}.
[codex-chrome-mcp] Shared mode will not auto-launch Chrome anymore.
[codex-chrome-mcp] Remediation:
[codex-chrome-mcp]   CHROME_AGENT_DEBUG_PORT=${port} CHROME_AGENT_PROFILE_DIR=\${HOME}/.chrome-profiles/claude-agent bash "${ROOT}/scripts/chrome-agent.sh"
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

run_chrome_devtools_mcp() {
  local attempt=1
  local stderr_file="${MCP_RUN_LOG_DIR}/npm-exec-${SCRIPT_PID}.stderr"
  local status

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

      # Keep the MCP process in the foreground so the wrapper shell cannot exit
      # first and orphan npm/node children.
      if NPM_CONFIG_UPDATE_NOTIFIER=false NPM_CONFIG_FUND=false npm exec --yes --cache "$MCP_CACHE_DIR" --package "$MCP_PACKAGE" -- chrome-devtools-mcp "$@" \
        <&0 2>"$stderr_fifo"; then
        status=0
      else
        status=$?
      fi
      kill "$MCP_TEE_PID" 2>/dev/null || true
      wait "$MCP_TEE_PID" 2>/dev/null || true
      MCP_TEE_PID=""
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

  if [[ -f "$pidfile" ]]; then
    local pid
    pid="$(cat "$pidfile" 2>/dev/null || true)"
    if [[ -z "$pid" ]] || ! kill -0 "$pid" >/dev/null 2>&1; then
      rm -f "$pidfile" "$statefile"
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
    exec 9>"$PORT_LOCKFILE"
    flock -x 9
    selected="$(pick_available_port "$START_PORT" "$END_PORT" || true)"
    if [[ -n "$selected" ]]; then
      RESERVATION_FILE="${LOG_DIR}/codex-chrome-port-${selected}.reserve"
      echo "$$" >"$RESERVATION_FILE"
    fi
    flock -u 9
    exec 9>&-
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
  if [[ -n "$MCP_TEE_PID" ]]; then
    kill "$MCP_TEE_PID" 2>/dev/null || true
  fi
  # Kill the full descendant tree, not just direct children.
  terminate_descendants "$SCRIPT_PID" TERM
  sleep 0.2
  terminate_descendants "$SCRIPT_PID" KILL

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
  # Unblock any external reader (e.g. Codex's tail) stuck on the fifo by
  # opening the write end non-blocking, then remove the fifo and stderr file.
  local _cleanup_fifo="${MCP_RUN_LOG_DIR}/npm-exec-${SCRIPT_PID}.stderr.fifo"
  _unblock_fifo "$_cleanup_fifo"
  rm -f "${MCP_RUN_LOG_DIR}/npm-exec-${SCRIPT_PID}.stderr"
  rm -f "$_cleanup_fifo"

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
    watchdog_parent="$(ps -o command= -p "$watchdog_pid" 2>/dev/null | sed -n 's/.*--parent-pid=\([0-9][0-9]*\).*/\1/p')"
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
    exec 9>"$PORT_LOCKFILE"
    flock -x 9
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
    flock -u 9
    exec 9>&-
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

if [[ "$SKIP_BROWSER_BOOT" == "1" ]] || is_info_invocation "$@"; then
  run_chrome_devtools_mcp "$@"
  exit $?
fi

if [[ "$DIAGNOSTIC_ONLY" == "1" ]]; then
  if [[ "$MODE" == "isolated" ]]; then
    BROWSER_PORT="${FORCED_PORT:-0}"
  else
    BROWSER_PORT="${FORCED_PORT:-9222}"
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

# Orphan watchdog: if Claude Code exits/crashes without sending SIGTERM,
# our parent PID will change to 1 (launchd).  This background loop detects
# that and triggers cleanup so we don't leave processes running indefinitely.
#
# IMPORTANT: The watchdog traps TERM/HUP/INT so it survives its own
# kill-process-group call.  Without this, the SIGTERM it sends to the PGID
# kills the watchdog itself before it can follow up with SIGKILL, leaving
# children that survived SIGTERM (e.g. npm's graceful shutdown) permanently
# orphaned.  For the SIGKILL phase it enumerates PGID members individually
# and skips its own PID, since SIGKILL cannot be trapped.
_ORIGINAL_PPID="$(ps -o ppid= -p "$SCRIPT_PID" 2>/dev/null | tr -d ' ')"
if [[ -n "$_ORIGINAL_PPID" ]]; then
  (
    # Survive our own group-wide SIGTERM so we can follow up with SIGKILL.
    trap '' TERM HUP INT
    _wd_self="$BASHPID"
    exec </dev/null >/dev/null 2>&1
    _sweep_counter=0
    while sleep 5; do
      # Detect parent death: either wrapper is gone entirely, PPID changed
      # (reparented), or original parent PID is no longer alive.
      current_ppid="$(ps -o ppid= -p "$SCRIPT_PID" 2>/dev/null | tr -d ' ')"
      _parent_alive=1
      if [[ -z "$current_ppid" ]]; then
        _parent_alive=0
      elif [[ "$_ORIGINAL_PPID" != "1" && "$current_ppid" != "$_ORIGINAL_PPID" ]]; then
        _parent_alive=0
      elif [[ "$_ORIGINAL_PPID" != "1" ]] && ! kill -0 "$_ORIGINAL_PPID" 2>/dev/null; then
        _parent_alive=0
      fi
      # Periodically sweep stale sessions from all wrappers (every ~5 min)
      _sweep_counter=$((_sweep_counter + 1))
      if (( _sweep_counter >= 60 )); then
        _sweep_counter=0
        _sweep_stale_mcp_sessions 2>/dev/null || true
      fi
      if [[ "$_parent_alive" == "0" ]]; then
        # Phase 1: SIGTERM to the whole process group. We survive via trap.
        kill -TERM -- "-${SCRIPT_PGID}" 2>/dev/null || true
        sleep 1
        # Phase 2: SIGKILL remaining group members individually (skip self,
        # because SIGKILL cannot be trapped and we still need to clean up).
        # Note: no `local` here — we are in a subshell, not a function.
        _wd_target=""
        while IFS= read -r _wd_target; do
          _wd_target="$(printf '%s' "$_wd_target" | tr -d ' ')"
          [[ -n "$_wd_target" && "$_wd_target" != "$_wd_self" ]] || continue
          kill -KILL "$_wd_target" 2>/dev/null || true
        done < <(ps -axo pid=,pgid= | awk -v g="$SCRIPT_PGID" '$2 == g { print $1 }')
        # Phase 3: Kill any telemetry watchdog that escaped to its own PGID.
        _wd_tw=""
        _wd_tw_parent=""
        while IFS= read -r _wd_tw; do
          [[ -n "$_wd_tw" ]] || continue
          _wd_tw_parent="$(ps -o command= -p "$_wd_tw" 2>/dev/null | sed -n 's/.*--parent-pid=\([0-9][0-9]*\).*/\1/p')"
          if [[ -n "$_wd_tw_parent" ]] && ! kill -0 "$_wd_tw_parent" 2>/dev/null; then
            kill -KILL "$_wd_tw" 2>/dev/null || true
          fi
        done < <(pgrep -f "chrome-devtools-mcp.*telemetry/watchdog" 2>/dev/null || true)
        # Phase 4: Clean up files so they don't accumulate.
        _wd_fifo="${MCP_RUN_LOG_DIR}/npm-exec-${SCRIPT_PID}.stderr.fifo"
        if [[ -p "$_wd_fifo" ]]; then
          # Unblock external reader (Codex tail) via non-blocking write-end open.
          perl -e '
            use Fcntl;
            sysopen(my $fh, $ARGV[0], O_WRONLY | O_NONBLOCK) or exit 0;
            print $fh "\n";
            close $fh;
          ' "$_wd_fifo" 2>/dev/null || true
          rm -f "$_wd_fifo"
        fi
        rm -f "${MCP_RUN_LOG_DIR}/npm-exec-${SCRIPT_PID}.stderr"
        [[ -z "${RESERVATION_FILE:-}" ]] || rm -f "$RESERVATION_FILE"
        [[ -z "${SESSION_FILE:-}" ]] || rm -f "$SESSION_FILE"
        [[ -z "${PAGE_ORDER_FILE:-}" ]] || rm -f "$PAGE_ORDER_FILE"
        if [[ -n "${SHARED_WRAPPER_PIDFILE:-}" && -f "${SHARED_WRAPPER_PIDFILE:-}" ]]; then
          _wd_rec="$(cat "$SHARED_WRAPPER_PIDFILE" 2>/dev/null || true)"
          [[ "$_wd_rec" != "$SCRIPT_PID" ]] || rm -f "$SHARED_WRAPPER_PIDFILE"
        fi
        break
      fi
    done
  ) &
  WATCHDOG_PID=$!
fi

case "$MODE" in
  shared)
    BROWSER_PORT="${FORCED_PORT:-9222}"
    if [[ "$BROWSER_PORT" != "9222" ]]; then
      fail "Shared mode is pinned to port 9222. Remove CODEX_CHROME_PORT or use CODEX_CHROME_MODE=isolated."
    fi
    cleanup_stale_state_for_port "$BROWSER_PORT"
    if ! is_port_listening "$BROWSER_PORT"; then
      chrome_mcp_log "Shared Chrome not running on ${BROWSER_PORT}; auto-launching..."
      CHROME_AGENT_DEBUG_PORT="$BROWSER_PORT" \
        CHROME_AGENT_PROFILE_DIR="${SEED_PROFILE_DIR}" \
        CHROME_AGENT_HEADLESS=0 \
        bash "${ROOT}/scripts/chrome-agent.sh" >/dev/null
      if ! is_port_listening "$BROWSER_PORT"; then
        shared_browser_remediation "$BROWSER_PORT"
        exit 1
      fi
      chrome_mcp_log "Shared Chrome auto-launched on ${BROWSER_PORT}."
    fi
    if ! wait_for_browser_endpoint "$BROWSER_PORT" "$BROWSER_READY_TIMEOUT_SEC"; then
      shared_browser_remediation "$BROWSER_PORT"
      fail "Shared Chrome endpoint did not become ready on ${BROWSER_PORT}."
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
_STDIN_WATCH_PID=$!

# Keep the MCP server in the foreground so Codex can complete the stdio handshake.
# Backgrounding the process causes stdin to be detached in non-interactive shells.
run_chrome_devtools_mcp --browserUrl "http://127.0.0.1:${BROWSER_PORT}" "$@"
_MCP_EXIT=$?

# Clean up stdin watchdog
kill "$_STDIN_WATCH_PID" 2>/dev/null || true

exit "$_MCP_EXIT"

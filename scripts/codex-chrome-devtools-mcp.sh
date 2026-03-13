#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT}/scripts/lib/node-baseline.sh"

LOG_DIR="${ROOT}/.logs/workspace"
PORT_LOCKFILE="${LOG_DIR}/codex-chrome-port.lock"
MCP_CACHE_DIR="${CODEX_CHROME_MCP_CACHE_DIR:-${ROOT}/.tmp/chrome-devtools-mcp/npm-cache}"
MCP_RUN_LOG_DIR="${LOG_DIR}/chrome-devtools-mcp"
MCP_VERSION="${CHROME_DEVTOOLS_MCP_VERSION:-0.20.0}"
MCP_PACKAGE="chrome-devtools-mcp@${MCP_VERSION}"
MODE="${CODEX_CHROME_MODE:-shared}"
START_PORT="${CODEX_CHROME_PORT_RANGE_START:-9333}"
END_PORT="${CODEX_CHROME_PORT_RANGE_END:-9399}"
FORCED_PORT="${CODEX_CHROME_PORT:-}"
SEED_PROFILE_DIR="${CODEX_CHROME_SEED_PROFILE_DIR:-${HOME}/.chrome-profiles/claude-agent}"
ISOLATED_HEADLESS="${CODEX_CHROME_ISOLATED_HEADLESS:-1}"
SKIP_BROWSER_BOOT="${CODEX_CHROME_SKIP_BROWSER_BOOT:-0}"

BROWSER_PORT=""
RESERVATION_FILE=""
STOP_ON_EXIT=0
CLEANUP_DONE=0
MCP_TEE_PID=""

mkdir -p "$LOG_DIR" "$MCP_CACHE_DIR" "$MCP_RUN_LOG_DIR"

log() {
  echo "[codex-chrome-mcp] $*" >&2
}

fail() {
  log "ERROR: $*"
  exit 1
}

ensure_node_baseline_or_fail() {
  local required_major
  required_major="$(trr_node_required_major "$ROOT")"
  if trr_ensure_node_baseline "$ROOT"; then
    return 0
  fi

  log "ERROR: Node $(trr_node_version_string) does not satisfy required ${required_major}.x baseline."
  log "ERROR: Remediation: source ~/.nvm/nvm.sh && nvm use ${required_major}"
  exit 1
}

clear_mcp_exec_cache() {
  rm -rf "$MCP_CACHE_DIR"
  mkdir -p "$MCP_CACHE_DIR"
}

run_chrome_devtools_mcp() {
  local attempt=1
  local stderr_file="${MCP_RUN_LOG_DIR}/npm-exec-$$.stderr"
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

      if NPM_CONFIG_UPDATE_NOTIFIER=false NPM_CONFIG_FUND=false npm exec --yes --cache "$MCP_CACHE_DIR" --package "$MCP_PACKAGE" -- chrome-devtools-mcp "$@" \
        2>"$stderr_fifo"; then
        kill "$MCP_TEE_PID" 2>/dev/null; wait "$MCP_TEE_PID" 2>/dev/null || true
        MCP_TEE_PID=""
        rm -f "$stderr_file" "$stderr_fifo"
        return 0
      else
        status=$?
      fi
      kill "$MCP_TEE_PID" 2>/dev/null; wait "$MCP_TEE_PID" 2>/dev/null || true
      MCP_TEE_PID=""
      rm -f "$stderr_fifo"
    fi

    if (( attempt >= 2 )) || ! grep -q 'ENOTEMPTY' "$stderr_file"; then
      rm -f "$stderr_file"
      return "$status"
    fi

    log "Detected corrupt workspace npm exec cache at ${MCP_CACHE_DIR}; clearing and retrying once."
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
  log "Seeding profile ${profile_dir} from ${SEED_PROFILE_DIR}"
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

  # Kill all child processes spawned by this script (npm, node, tee, watchdog).
  # Without this, children become orphans re-parented to PID 1 and accumulate
  # across Claude Code sessions, eventually consuming all CPU.
  if [[ -n "$MCP_TEE_PID" ]]; then
    kill "$MCP_TEE_PID" 2>/dev/null || true
  fi
  # Kill entire process group rooted at this script.
  local child
  for child in $(pgrep -P $$ 2>/dev/null || true); do
    kill "$child" 2>/dev/null || true
  done

  if [[ -n "$RESERVATION_FILE" ]]; then
    rm -f "$RESERVATION_FILE"
  fi
  # Clean up stderr fifo if it exists.
  rm -f "${MCP_RUN_LOG_DIR}/npm-exec-$$.stderr.fifo"

  if [[ "$STOP_ON_EXIT" == "1" ]] && [[ -n "$BROWSER_PORT" ]]; then
    CHROME_AGENT_DEBUG_PORT="$BROWSER_PORT" bash "${ROOT}/scripts/stop-chrome-agent.sh" >/dev/null 2>&1 || true
  fi
}

trap 'cleanup' EXIT
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 129' HUP
trap 'cleanup; exit 143' TERM

ensure_node_baseline_or_fail

# Orphan watchdog: if Claude Code exits/crashes without sending SIGTERM,
# our parent PID will change to 1 (launchd).  This background loop detects
# that and triggers cleanup so we don't leave processes running indefinitely.
_ORIGINAL_PPID="$(ps -o ppid= -p $$ 2>/dev/null | tr -d ' ')"
if [[ -n "$_ORIGINAL_PPID" && "$_ORIGINAL_PPID" != "1" ]]; then
  (
    while sleep 10; do
      current_ppid="$(ps -o ppid= -p $$ 2>/dev/null | tr -d ' ')"
      if [[ -z "$current_ppid" || "$current_ppid" == "1" ]]; then
        # Parent is gone — we're orphaned.  Trigger cleanup.
        kill -TERM $$ 2>/dev/null || true
        break
      fi
    done
  ) &
  disown $! 2>/dev/null || true
fi

if [[ "$SKIP_BROWSER_BOOT" == "1" ]] || is_info_invocation "$@"; then
  run_chrome_devtools_mcp "$@"
  exit $?
fi

case "$MODE" in
  shared)
    BROWSER_PORT="${FORCED_PORT:-9222}"
    CHROME_AGENT_DEBUG_PORT="$BROWSER_PORT" bash "${ROOT}/scripts/chrome-agent.sh" >/dev/null
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
    ;;
  *)
    fail "Unsupported CODEX_CHROME_MODE: ${MODE}. Use 'isolated' or 'shared'."
    ;;
esac

log "Using Chrome DevTools endpoint http://127.0.0.1:${BROWSER_PORT} (mode=${MODE})"
# Keep the MCP server in the foreground so Codex can complete the stdio handshake.
# Backgrounding the process causes stdin to be detached in non-interactive shells.
run_chrome_devtools_mcp --browserUrl "http://127.0.0.1:${BROWSER_PORT}" "$@"

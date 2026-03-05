#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${ROOT}/.logs/workspace"
PORT_LOCKFILE="${LOG_DIR}/codex-chrome-port.lock"
MODE="${CODEX_CHROME_MODE:-isolated}"
START_PORT="${CODEX_CHROME_PORT_RANGE_START:-9333}"
END_PORT="${CODEX_CHROME_PORT_RANGE_END:-9399}"
FORCED_PORT="${CODEX_CHROME_PORT:-}"
SEED_PROFILE_DIR="${CODEX_CHROME_SEED_PROFILE_DIR:-${HOME}/.chrome-profiles/claude-agent}"
ISOLATED_HEADLESS="${CODEX_CHROME_ISOLATED_HEADLESS:-1}"

BROWSER_PORT=""
RESERVATION_FILE=""
STOP_ON_EXIT=0
MCP_PID=""

mkdir -p "$LOG_DIR"

log() {
  echo "[codex-chrome-mcp] $*" >&2
}

fail() {
  log "ERROR: $*"
  exit 1
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

      sleep 0.05
      spin=$((spin + 1))
      if (( spin > 200 )); then
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
  local rc=$?
  if [[ -n "$MCP_PID" ]] && kill -0 "$MCP_PID" >/dev/null 2>&1; then
    kill -TERM "$MCP_PID" >/dev/null 2>&1 || true
  fi
  if [[ -n "$RESERVATION_FILE" ]]; then
    rm -f "$RESERVATION_FILE"
  fi
  if [[ "$STOP_ON_EXIT" == "1" ]] && [[ -n "$BROWSER_PORT" ]]; then
    CHROME_AGENT_DEBUG_PORT="$BROWSER_PORT" bash "${ROOT}/scripts/stop-chrome-agent.sh" >/dev/null 2>&1 || true
  fi
  return $rc
}

trap cleanup EXIT

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
npx -y chrome-devtools-mcp --browserUrl "http://127.0.0.1:${BROWSER_PORT}" "$@" &
MCP_PID=$!
wait "$MCP_PID"

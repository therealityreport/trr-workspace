#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${ROOT}/.logs/workspace"
CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
HEADFUL_OWNER_DIR="${CODEX_CHROME_OWNER_DIR:-${CODEX_HOME_DIR}/tmp/browser-control}"
HEADFUL_OWNER_FILE="${HEADFUL_OWNER_DIR}/headful-chrome-owner.env"

PROFILE_DIR="${CHROME_AGENT_PROFILE_DIR:-${HOME}/.chrome-profiles/codex-agent}"
DEBUG_PORT="${CHROME_AGENT_DEBUG_PORT:-9422}"

default_headless_for_port() {
  case "$1" in
    9222)
      echo "0"
      ;;
    *)
      echo "1"
      ;;
  esac
}

# ── Chrome Profile Identity Guard ──────────────────────────────────
# This guard applies only to TRR Workspace / Codex agent launches.
# Claude in Chrome (desktop app browser automation) is permitted to use
# the admin@thereality.report profile and should NOT trigger this warning.
#
# Default agent work must use codex@thereality.report (codex-agent profile).
# The claude-agent profile contains admin@thereality.report and is reserved
# for user-authorized tasks only (e.g., paywalled sites like NYTimes).
# CHROME_AGENT_ADMIN_OVERRIDE=1 signals explicit user permission was granted.
# CHROME_AGENT_SKIP_PROFILE_GUARD=1 bypasses this guard (set by non-Codex callers).
ADMIN_PROFILE_PATTERN="${CHROME_AGENT_ADMIN_PROFILE_PATTERN:-claude-agent}"
if [[ -z "${CHROME_AGENT_ADMIN_OVERRIDE:-}" ]] \
   && [[ -z "${CHROME_AGENT_SKIP_PROFILE_GUARD:-}" ]] \
   && [[ "$PROFILE_DIR" == *"${ADMIN_PROFILE_PATTERN}"* ]]; then
  echo "[chrome-agent] WARNING: Launching with admin-capable profile (${PROFILE_DIR})." >&2
  echo "[chrome-agent] Policy: TRR Workspace agents should use codex-agent profile for routine work." >&2
  echo "[chrome-agent] Set CHROME_AGENT_ADMIN_OVERRIDE=1 if user granted permission." >&2
  echo "[chrome-agent] Set CHROME_AGENT_SKIP_PROFILE_GUARD=1 for non-Codex callers (e.g., Claude in Chrome)." >&2
fi
HEADLESS="${CHROME_AGENT_HEADLESS:-$(default_headless_for_port "$DEBUG_PORT")}"
DISABLE_GPU="${CHROME_AGENT_DISABLE_GPU:-0}"

PIDFILE="${LOG_DIR}/chrome-agent-${DEBUG_PORT}.pid"
LOGFILE="${LOG_DIR}/chrome-agent-${DEBUG_PORT}.log"
STATEFILE="${LOG_DIR}/chrome-agent-${DEBUG_PORT}.env"
LEGACY_PIDFILE="${LOG_DIR}/chrome-agent.pid"
LOCKFILE="${LOG_DIR}/chrome-agent-${DEBUG_PORT}.lock"

mkdir -p "$LOG_DIR"

clear_stale_headful_owner() {
  [[ -f "$HEADFUL_OWNER_FILE" ]] || return 0
  local owner_pid=""
  owner_pid="$(sed -n 's/^PID=//p' "$HEADFUL_OWNER_FILE" | head -n 1)"
  if [[ -n "$owner_pid" ]] && kill -0 "$owner_pid" >/dev/null 2>&1; then
    return 0
  fi
  rm -f "$HEADFUL_OWNER_FILE"
}

claim_headful_owner() {
  local browser_pid="$1"
  mkdir -p "$HEADFUL_OWNER_DIR"
  clear_stale_headful_owner
  if [[ -f "$HEADFUL_OWNER_FILE" ]]; then
    local owner_pid=""
    local owner_port=""
    local owner_profile=""
    owner_pid="$(sed -n 's/^PID=//p' "$HEADFUL_OWNER_FILE" | head -n 1)"
    owner_port="$(sed -n 's/^PORT=//p' "$HEADFUL_OWNER_FILE" | head -n 1)"
    owner_profile="$(sed -n 's/^PROFILE_DIR=//p' "$HEADFUL_OWNER_FILE" | head -n 1)"
    if [[ -n "$owner_pid" ]] && kill -0 "$owner_pid" >/dev/null 2>&1; then
      echo "[chrome-agent] ERROR: headful Chrome ownership is already held by pid=${owner_pid} port=${owner_port:-unknown} profile=${owner_profile:-unknown}." >&2
      echo "[chrome-agent] ERROR: Stop the existing headful browser before launching another visible managed Chrome." >&2
      exit 1
    fi
    rm -f "$HEADFUL_OWNER_FILE"
  fi
  cat >"$HEADFUL_OWNER_FILE" <<EOF
PID=${browser_pid}
PORT=${DEBUG_PORT}
PROFILE_DIR=${PROFILE_DIR}
HEADLESS=${HEADLESS}
EOF
}

port_pid() {
  local target_port="${1:-$DEBUG_PORT}"
  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:"${target_port}" -sTCP:LISTEN -t 2>/dev/null | head -n 1 || true
  fi
}

endpoint_ready() {
  local target_port="${1:-$DEBUG_PORT}"
  curl -sf "http://localhost:${target_port}/json/version" >/dev/null 2>&1
}

health_check() {
  local target_port="${1:-$DEBUG_PORT}"
  local lsof_pid=""
  local pidfile_path="${LOG_DIR}/chrome-agent-${target_port}.pid"
  local statefile_path="${LOG_DIR}/chrome-agent-${target_port}.env"
  local file_pid=""
  local endpoint_state="missing"
  local pid_match="unknown"

  lsof_pid="$(port_pid "$target_port")"
  file_pid="$(cat "$pidfile_path" 2>/dev/null || true)"
  if endpoint_ready "$target_port"; then
    endpoint_state="ready"
  fi
  if [[ -n "$lsof_pid" && -n "$file_pid" && "$lsof_pid" == "$file_pid" ]]; then
    pid_match="match"
  elif [[ -n "$lsof_pid" && -n "$file_pid" ]]; then
    pid_match="mismatch"
  fi

  cat <<EOF
port=${target_port}
listener_pid=${lsof_pid:-missing}
pidfile=${pidfile_path}
pidfile_pid=${file_pid:-missing}
statefile=${statefile_path}
endpoint=${endpoint_state}
pid_match=${pid_match}
health=$([[ -n "$lsof_pid" && "$endpoint_state" == "ready" ]] && echo healthy || echo unhealthy)
EOF
}

if [[ "${1:-}" == "health" ]]; then
  shift
  health_check "${1:-$DEBUG_PORT}"
  exit 0
fi

# --- Resolve Chrome binary (macOS / Linux) ---
find_chrome() {
  if [[ "$(uname)" == "Darwin" ]]; then
    local app="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    if [[ -x "$app" ]]; then
      echo "$app"
      return 0
    fi
  fi
  local cmd
  for cmd in google-chrome-stable google-chrome chromium-browser chromium; do
    if command -v "$cmd" >/dev/null 2>&1; then
      echo "$cmd"
      return 0
    fi
  done
  return 1
}

CHROME_BIN="$(find_chrome || true)"
if [[ -z "$CHROME_BIN" ]]; then
  echo "[chrome-agent] ERROR: Could not find Google Chrome. Install it or set PATH."
  exit 1
fi

LOCK_FD_OPEN=0
release_lock() {
  if [[ "$LOCK_FD_OPEN" == "1" ]]; then
    flock -u 9 2>/dev/null || true
    exec 9>&- 2>/dev/null || true
    LOCK_FD_OPEN=0
  fi
}

if command -v flock >/dev/null 2>&1; then
  exec 9>"$LOCKFILE"
  flock -x 9
  LOCK_FD_OPEN=1
  trap 'release_lock' EXIT
fi

launch_chrome() {
  if [[ "$(uname)" == "Darwin" ]] && [[ "$HEADLESS" != "1" ]] && command -v open >/dev/null 2>&1; then
    nohup open -na "/Applications/Google Chrome.app" --args "${CHROME_FLAGS[@]}" >/dev/null 2>&1 &
  else
    # Use nohup so the browser survives non-interactive shell exit in make/script launches.
    nohup "$CHROME_BIN" "${CHROME_FLAGS[@]}" >"${LOGFILE}" 2>&1 &
  fi
  CHROME_PID=$!
}

# --- Check if already running on the debugging port ---
existing_pid="$(port_pid)"
if [[ -n "$existing_pid" ]]; then
  echo "[chrome-agent] Chrome agent already running on port ${DEBUG_PORT} (pid=${existing_pid})."
  echo "[chrome-agent] DevTools endpoint: http://localhost:${DEBUG_PORT}"
  if [[ "$HEADLESS" != "1" ]]; then
    claim_headful_owner "$existing_pid"
  fi
  exit 0
fi

# --- First-run setup ---
FIRST_RUN=0
if [[ ! -d "$PROFILE_DIR" ]]; then
  FIRST_RUN=1
  mkdir -p "$PROFILE_DIR"
  echo "[chrome-agent] Created new profile directory: ${PROFILE_DIR}"
fi

# --- Build Chrome flags ---
CHROME_FLAGS=(
  "--user-data-dir=${PROFILE_DIR}"
  "--remote-debugging-port=${DEBUG_PORT}"
  "--no-first-run"
  "--no-default-browser-check"
  "--disable-background-networking"
  "--disable-sync"
  "--disable-extensions"
  "--disable-crash-reporter"
  "--disable-background-timer-throttling"
  "--disable-backgrounding-occluded-windows"
  "--disable-renderer-backgrounding"
)

if [[ "$HEADLESS" == "1" ]]; then
  CHROME_FLAGS+=("--headless=new")
fi

if [[ "$DISABLE_GPU" == "1" ]]; then
  CHROME_FLAGS+=("--disable-gpu")
fi

# --- Launch ---
echo "[chrome-agent] Launching Chrome with agent profile..."
echo "[chrome-agent]   Binary:  ${CHROME_BIN}"
echo "[chrome-agent]   Profile: ${PROFILE_DIR}"
echo "[chrome-agent]   Port:    ${DEBUG_PORT}"

launch_chrome

# Wait briefly for Chrome to start listening
for _ in 1 2 3 4 5 6 7 8 9 10; do
  if endpoint_ready "${DEBUG_PORT}"; then
    break
  fi
  sleep 0.5
done

# Verify it's actually listening
if ! endpoint_ready "${DEBUG_PORT}"; then
  echo "[chrome-agent] WARNING: Chrome started (pid=${CHROME_PID}) but port ${DEBUG_PORT} not responding yet."
  echo "[chrome-agent] Check ${LOGFILE} for errors."
else
  listening_pid="$(port_pid)"
  if [[ -n "$listening_pid" ]]; then
    CHROME_PID="$listening_pid"
  fi
  echo "[chrome-agent] Chrome agent ready."
fi

if [[ "$HEADLESS" != "1" ]]; then
  # PPID=1 is expected after nohup detaches Chrome; ownership tracks the browser PID.
  claim_headful_owner "$CHROME_PID"
fi

# Write pidfile
echo "$CHROME_PID" >"$PIDFILE"
cat >"$STATEFILE" <<EOF
DEBUG_PORT=${DEBUG_PORT}
PROFILE_DIR=${PROFILE_DIR}
HEADLESS=${HEADLESS}
PID=${CHROME_PID}
EOF
if [[ "$DEBUG_PORT" == "9222" ]]; then
  echo "$CHROME_PID" >"$LEGACY_PIDFILE"
fi
echo "[chrome-agent]   PID:     ${CHROME_PID}"
echo "[chrome-agent]   Logs:    ${LOGFILE}"
echo "[chrome-agent]   DevTools: http://localhost:${DEBUG_PORT}"

if [[ "$FIRST_RUN" == "1" ]]; then
  echo ""
  echo "[chrome-agent] ============================================"
  if [[ "$HEADLESS" == "1" ]]; then
    echo "[chrome-agent]  FIRST RUN — headless profile seeded"
  else
    echo "[chrome-agent]  FIRST RUN — manual login required"
  fi
  echo "[chrome-agent] ============================================"
  if [[ "$HEADLESS" == "1" ]]; then
    echo "[chrome-agent]  Headless shared automation is now using this profile."
    echo "[chrome-agent]  To perform a first-time manual login, re-run with:"
    echo "[chrome-agent]  CHROME_AGENT_DEBUG_PORT=9222 CHROME_AGENT_HEADLESS=0 bash ${ROOT}/scripts/chrome-agent.sh"
  else
    echo "[chrome-agent]  A new Chrome window has opened. Please:"
    echo "[chrome-agent]  1. Log into the agent Gmail account"
    echo "[chrome-agent]  2. Log into any other sites the agent needs"
    echo "[chrome-agent]  3. Sessions will persist across restarts"
  fi
  echo "[chrome-agent] ============================================"
fi

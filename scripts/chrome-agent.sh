#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${ROOT}/.logs/workspace"

PROFILE_DIR="${CHROME_AGENT_PROFILE_DIR:-${HOME}/.chrome-profiles/claude-agent}"
DEBUG_PORT="${CHROME_AGENT_DEBUG_PORT:-9222}"
HEADLESS="${CHROME_AGENT_HEADLESS:-0}"

PIDFILE="${LOG_DIR}/chrome-agent-${DEBUG_PORT}.pid"
LOGFILE="${LOG_DIR}/chrome-agent-${DEBUG_PORT}.log"
STATEFILE="${LOG_DIR}/chrome-agent-${DEBUG_PORT}.env"
LEGACY_PIDFILE="${LOG_DIR}/chrome-agent.pid"

mkdir -p "$LOG_DIR"

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

# --- Check if already running on the debugging port ---
port_pid() {
  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:"${DEBUG_PORT}" -sTCP:LISTEN -t 2>/dev/null | head -n 1 || true
  fi
}

existing_pid="$(port_pid)"
if [[ -n "$existing_pid" ]]; then
  echo "[chrome-agent] Chrome agent already running on port ${DEBUG_PORT} (pid=${existing_pid})."
  echo "[chrome-agent] DevTools endpoint: http://localhost:${DEBUG_PORT}"
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
  "--disable-background-timer-throttling"
  "--disable-backgrounding-occluded-windows"
  "--disable-renderer-backgrounding"
)

if [[ "$HEADLESS" == "1" ]]; then
  CHROME_FLAGS+=("--headless=new")
fi

# --- Launch ---
echo "[chrome-agent] Launching Chrome with agent profile..."
echo "[chrome-agent]   Binary:  ${CHROME_BIN}"
echo "[chrome-agent]   Profile: ${PROFILE_DIR}"
echo "[chrome-agent]   Port:    ${DEBUG_PORT}"

"$CHROME_BIN" "${CHROME_FLAGS[@]}" >"${LOGFILE}" 2>&1 &
CHROME_PID=$!

# Wait briefly for Chrome to start listening
for _ in 1 2 3 4 5 6 7 8 9 10; do
  if curl -sf "http://localhost:${DEBUG_PORT}/json/version" >/dev/null 2>&1; then
    break
  fi
  sleep 0.5
done

# Verify it's actually listening
if ! curl -sf "http://localhost:${DEBUG_PORT}/json/version" >/dev/null 2>&1; then
  echo "[chrome-agent] WARNING: Chrome started (pid=${CHROME_PID}) but port ${DEBUG_PORT} not responding yet."
  echo "[chrome-agent] Check ${LOGFILE} for errors."
else
  echo "[chrome-agent] Chrome agent ready."
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
  echo "[chrome-agent]  FIRST RUN — manual login required"
  echo "[chrome-agent] ============================================"
  echo "[chrome-agent]  A new Chrome window has opened. Please:"
  echo "[chrome-agent]  1. Log into the agent Gmail account"
  echo "[chrome-agent]  2. Log into any other sites the agent needs"
  echo "[chrome-agent]  3. Sessions will persist across restarts"
  echo "[chrome-agent] ============================================"
fi

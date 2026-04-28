#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${ROOT}/.logs/workspace"
PIDFILE="${LOG_DIR}/pids.env"
WATCHDOG_EVENTS="${LOG_DIR}/backend-watchdog-events.jsonl"
WATCHDOG_STATE="${LOG_DIR}/backend-watchdog.env"
BACKEND_LOG="${LOG_DIR}/trr-backend.log"
SEGMENT_DIR="${LOG_DIR}/backend-restart-segments"

source "${ROOT}/scripts/lib/backend-restart-diagnostics.sh"
source "${ROOT}/scripts/lib/workspace-health.sh"

TRR_BACKEND_PORT="${TRR_BACKEND_PORT:-8000}"
WORKSPACE_MANAGER_PID=""
TRR_BACKEND_PID=""
TRR_BACKEND_PGID=""
TRR_BACKEND_STARTED_AT=""
TRR_BACKEND_LOG_START_LINE=""

if [[ -f "$PIDFILE" ]]; then
  # shellcheck disable=SC1090
  source "$PIDFILE"
fi

pid_state() {
  local pid="$1"
  if [[ -z "$pid" ]]; then
    printf 'not recorded\n'
    return 0
  fi
  if kill -0 "$pid" >/dev/null 2>&1; then
    printf 'running\n'
    return 0
  fi
  printf 'not running\n'
}

pid_pgid() {
  local pid="$1"
  ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ' || true
}

pid_cmd() {
  local pid="$1"
  ps -o command= -p "$pid" 2>/dev/null | sed 's/^ *//' || true
}

port_listeners() {
  local port="$1"
  if ! command -v lsof >/dev/null 2>&1; then
    return 0
  fi
  lsof -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null || true
}

echo "[backend-restart-diagnose] Root: ${ROOT}"
echo "[backend-restart-diagnose] Pidfile: ${PIDFILE}"
echo

echo "[backend-restart-diagnose] Manager"
echo "  pid: ${WORKSPACE_MANAGER_PID:-n/a}"
echo "  state: $(pid_state "${WORKSPACE_MANAGER_PID:-}")"
if [[ -n "${WORKSPACE_MANAGER_PID:-}" ]]; then
  echo "  pgid: $(pid_pgid "$WORKSPACE_MANAGER_PID")"
  echo "  cmd: $(pid_cmd "$WORKSPACE_MANAGER_PID")"
fi
echo

echo "[backend-restart-diagnose] Backend"
echo "  pid: ${TRR_BACKEND_PID:-n/a}"
echo "  state: $(pid_state "${TRR_BACKEND_PID:-}")"
echo "  recorded_pgid: ${TRR_BACKEND_PGID:-n/a}"
echo "  started_at: ${TRR_BACKEND_STARTED_AT:-n/a}"
echo "  log_start_line: ${TRR_BACKEND_LOG_START_LINE:-n/a}"
if [[ -n "${TRR_BACKEND_PID:-}" ]]; then
  echo "  current_pgid: $(pid_pgid "$TRR_BACKEND_PID")"
  echo "  cmd: $(pid_cmd "$TRR_BACKEND_PID")"
fi
echo "  readiness_url: $(workspace_backend_readiness_url "$TRR_BACKEND_PORT")"
echo "  liveness_url: $(workspace_backend_liveness_url "$TRR_BACKEND_PORT")"
echo

echo "[backend-restart-diagnose] Port listeners (:${TRR_BACKEND_PORT})"
port_listeners "$TRR_BACKEND_PORT" | sed 's/^/  /'
echo

echo "[backend-restart-diagnose] Watchdog state"
if [[ -f "$WATCHDOG_STATE" ]]; then
  sed 's/^/  /' "$WATCHDOG_STATE"
else
  echo "  missing: ${WATCHDOG_STATE}"
fi
echo

echo "[backend-restart-diagnose] Recent watchdog events"
if [[ -f "$WATCHDOG_EVENTS" ]]; then
  tail -n 20 "$WATCHDOG_EVENTS" | sed 's/^/  /'
else
  echo "  missing: ${WATCHDOG_EVENTS}"
fi
echo

echo "[backend-restart-diagnose] Recent backend shutdown lines"
if [[ -f "$BACKEND_LOG" ]]; then
  rg -n "Shutting down|Application shutdown|Finished server process|Started server process|signal|PoolError|statement_timeout|GET /health/live|GET /health HTTP" "$BACKEND_LOG" | tail -n 40 | sed 's/^/  /' || true
else
  echo "  missing: ${BACKEND_LOG}"
fi
echo

echo "[backend-restart-diagnose] Archived backend restart segments"
if [[ -d "$SEGMENT_DIR" ]]; then
  find "$SEGMENT_DIR" -type f -name '*.log' -print | sort | tail -n 10 | sed 's/^/  /'
else
  echo "  none"
fi

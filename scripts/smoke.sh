#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/.logs/workspace"
PIDFILE="$LOG_DIR/pids.env"
SMOKE_HTTP_MAX_TIME="${SMOKE_HTTP_MAX_TIME:-5}"
SMOKE_HTTP_RETRIES="${SMOKE_HTTP_RETRIES:-3}"

check_pid_running() {
  local name="$1"
  local pid="$2"
  local required="$3"

  if [[ -z "${pid}" ]]; then
    if [[ "$required" == "1" ]]; then
      echo "[smoke] ERROR: missing pid for required service ${name}." >&2
      return 1
    fi
    echo "[smoke] ${name}: pid not recorded (optional)"
    return 0
  fi

  if kill -0 "$pid" >/dev/null 2>&1; then
    echo "[smoke] ${name}: running (pid=${pid})"
    return 0
  fi

  if [[ "$required" == "1" ]]; then
    echo "[smoke] ERROR: required service ${name} is not running (pid=${pid})." >&2
    return 1
  fi

  echo "[smoke] ${name}: not running (optional)"
  return 0
}

check_http() {
  local name="$1"
  local url="$2"
  local required="$3"
  local attempts=1

  if [[ "$required" == "1" && "$SMOKE_HTTP_RETRIES" =~ ^[1-9][0-9]*$ ]]; then
    attempts="$SMOKE_HTTP_RETRIES"
  fi

  for attempt in $(seq 1 "$attempts"); do
    if curl -fsS --max-time "$SMOKE_HTTP_MAX_TIME" "$url" >/dev/null 2>&1; then
      echo "[smoke] ${name}: ok (${url})"
      return 0
    fi
    if (( attempt < attempts )); then
      sleep 1
    fi
  done

  if [[ "$required" == "1" ]]; then
    echo "[smoke] ERROR: ${name} check failed (${url})." >&2
    return 1
  fi

  echo "[smoke] ${name}: unavailable (optional) (${url})"
  return 0
}

check_port_listener() {
  local name="$1"
  local port="$2"
  local required="$3"

  if command -v lsof >/dev/null 2>&1; then
    if lsof -nP -iTCP:"$port" -sTCP:LISTEN -t >/dev/null 2>&1; then
      echo "[smoke] ${name}: listener present on :${port}"
      return 0
    fi
  else
    if curl -fsS --max-time 2 "http://127.0.0.1:${port}" >/dev/null 2>&1; then
      echo "[smoke] ${name}: endpoint responded on :${port}"
      return 0
    fi
  fi

  if [[ "$required" == "1" ]]; then
    echo "[smoke] ERROR: ${name} has no listener on :${port}." >&2
    return 1
  fi

  echo "[smoke] ${name}: listener missing (optional) on :${port}"
  return 0
}

echo "[smoke] Status snapshot:"
bash "$ROOT/scripts/status-workspace.sh"

if [[ ! -f "$PIDFILE" ]]; then
  echo "[smoke] ERROR: pidfile not found (${PIDFILE}). Start workspace first with 'make dev' variants." >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$PIDFILE"

TRR_BACKEND_PORT="${TRR_BACKEND_PORT:-8000}"
TRR_APP_PORT="${TRR_APP_PORT:-3000}"
TRR_APP_HOST="${TRR_APP_HOST:-127.0.0.1}"
SCREENALYTICS_API_PORT="${SCREENALYTICS_API_PORT:-8001}"
WORKSPACE_SCREENALYTICS="${WORKSPACE_SCREENALYTICS:-1}"

failures=0

check_pid_running "TRR_BACKEND" "${TRR_BACKEND_PID:-}" 1 || failures=$((failures + 1))
check_pid_running "TRR_APP" "${TRR_APP_PID:-}" 1 || failures=$((failures + 1))
check_pid_running "TRR_SOCIAL_WORKER" "${TRR_SOCIAL_WORKER_PID:-}" 0 || true
check_pid_running "TRR_REMOTE_WORKERS" "${TRR_REMOTE_WORKERS_PID:-}" 0 || true

check_http "TRR-Backend health" "http://127.0.0.1:${TRR_BACKEND_PORT}/health" 1 || failures=$((failures + 1))
check_http "TRR-APP" "http://${TRR_APP_HOST}:${TRR_APP_PORT}/" 1 || failures=$((failures + 1))

check_port_listener "TRR-Backend" "$TRR_BACKEND_PORT" 1 || failures=$((failures + 1))
check_port_listener "TRR-APP" "$TRR_APP_PORT" 1 || failures=$((failures + 1))

if [[ "$WORKSPACE_SCREENALYTICS" == "1" ]]; then
  check_pid_running "SCREENALYTICS" "${SCREENALYTICS_PID:-}" 0 || true
  check_http "screenalytics API" "http://127.0.0.1:${SCREENALYTICS_API_PORT}/healthz" 0 || true
  check_port_listener "screenalytics API" "$SCREENALYTICS_API_PORT" 0 || true
fi

if [[ "$failures" -gt 0 ]]; then
  echo "[smoke] FAILED with ${failures} required check(s) failing." >&2
  exit 1
fi

echo "[smoke] OK"

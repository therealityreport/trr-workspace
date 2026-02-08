#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${ROOT}/.logs/workspace"
PIDFILE="${LOG_DIR}/pids.env"

if [[ ! -f "$PIDFILE" ]]; then
  echo "[workspace] No pidfile found (${PIDFILE}). Nothing to stop."
  exit 0
fi

# shellcheck disable=SC1090
source "$PIDFILE"

stop_one() {
  local name="$1"
  local pid="$2"

  if [[ -z "${pid}" ]]; then
    return 0
  fi
  if ! kill -0 "$pid" >/dev/null 2>&1; then
    echo "[workspace] ${name} not running (pid=${pid})."
    return 0
  fi

  echo "[workspace] Stopping ${name} (pid=${pid})"
  kill -TERM -- "-${pid}" >/dev/null 2>&1 || kill -TERM "${pid}" >/dev/null 2>&1 || true

  for _ in 1 2 3 4 5 6 7 8 9 10; do
    if ! kill -0 "$pid" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.2
  done

  kill -KILL -- "-${pid}" >/dev/null 2>&1 || kill -KILL "${pid}" >/dev/null 2>&1 || true
}

# Stop in reverse dependency order.
stop_one "TRR_APP" "${TRR_APP_PID:-}"
stop_one "TRR_BACKEND" "${TRR_BACKEND_PID:-}"
stop_one "SCREENALYTICS" "${SCREENALYTICS_PID:-}"

rm -f "$PIDFILE" >/dev/null 2>&1 || true
echo "[workspace] Stopped."


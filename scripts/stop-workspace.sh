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

kill_tree() {
  local pid="$1"
  local sig="${2:-TERM}"

  if [[ -z "${pid}" ]]; then
    return 0
  fi
  if ! kill -0 "$pid" >/dev/null 2>&1; then
    return 0
  fi

  local child
  for child in $(pgrep -P "$pid" 2>/dev/null || true); do
    kill_tree "$child" "$sig"
  done

  kill "-${sig}" "$pid" >/dev/null 2>&1 || true
}

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
  # Prefer killing the whole process group (works when started via setsid).
  # Fall back to killing the full child tree so `make stop` works even when
  # setsid isn't installed.
  kill -TERM -- "-${pid}" >/dev/null 2>&1 || true
  kill_tree "$pid" "TERM"

  for _ in 1 2 3 4 5 6 7 8 9 10; do
    if ! kill -0 "$pid" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.2
  done

  kill -KILL -- "-${pid}" >/dev/null 2>&1 || true
  kill_tree "$pid" "KILL"
}

# Stop in reverse dependency order.
stop_one "TRR_APP" "${TRR_APP_PID:-}"
stop_one "TRR_BACKEND" "${TRR_BACKEND_PID:-}"
stop_one "SCREENALYTICS" "${SCREENALYTICS_PID:-}"

rm -f "$PIDFILE" >/dev/null 2>&1 || true
echo "[workspace] Stopped."

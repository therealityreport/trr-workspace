#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

LOG_DIR="${ROOT}/.logs/workspace"
PIDFILE="${LOG_DIR}/pids.env"
mkdir -p "$LOG_DIR"

# If an old pidfile exists, stop those services first (safe: only kills recorded PIDs).
if [[ -f "$PIDFILE" ]]; then
  echo "[workspace] Existing pidfile found. Stopping previous workspace services..."
  bash "${ROOT}/scripts/stop-workspace.sh" || true
fi

TRR_BACKEND_PORT="${TRR_BACKEND_PORT:-8000}"
TRR_APP_PORT="${TRR_APP_PORT:-3000}"
TRR_APP_HOST="${TRR_APP_HOST:-127.0.0.1}"

# Default to :8001 to avoid clashing with TRR-Backend (:8000).
SCREENALYTICS_API_PORT="${SCREENALYTICS_API_PORT:-8001}"
SCREENALYTICS_STREAMLIT_PORT="${SCREENALYTICS_STREAMLIT_PORT:-8501}"
SCREENALYTICS_WEB_PORT="${SCREENALYTICS_WEB_PORT:-8080}"

TRR_API_URL="http://127.0.0.1:${TRR_BACKEND_PORT}"
SCREENALYTICS_API_URL="http://127.0.0.1:${SCREENALYTICS_API_PORT}"

TRR_BACKEND_LOG="${LOG_DIR}/trr-backend.log"
TRR_APP_LOG="${LOG_DIR}/trr-app.log"
SCREENALYTICS_LOG="${LOG_DIR}/screenalytics.log"

: > "$TRR_BACKEND_LOG"
: > "$TRR_APP_LOG"
: > "$SCREENALYTICS_LOG"

USE_SETSID=0
if command -v setsid >/dev/null 2>&1; then
  USE_SETSID=1
fi

declare -a PIDS=()
declare -a NAMES=()

start_bg() {
  local name="$1"
  local log="$2"
  shift 2

  if [[ "$USE_SETSID" -eq 1 ]]; then
    # Start in its own process group so we can kill the whole tree reliably.
    setsid "$@" >>"$log" 2>&1 &
  else
    "$@" >>"$log" 2>&1 &
  fi

  local pid=$!
  PIDS+=("$pid")
  NAMES+=("$name")
  echo "${name}_PID=${pid}" >>"$PIDFILE"
  echo "[workspace] ${name} started (pid=${pid})"
}

stop_bg() {
  local name="$1"
  local pid="$2"

  if [[ -z "${pid}" ]]; then
    return 0
  fi
  if ! kill -0 "$pid" >/dev/null 2>&1; then
    return 0
  fi

  echo "[workspace] Stopping ${name} (pid=${pid})"

  # Prefer killing the process group (works when started via setsid).
  kill -TERM -- "-${pid}" >/dev/null 2>&1 || kill -TERM "${pid}" >/dev/null 2>&1 || true

  # Grace period.
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    if ! kill -0 "$pid" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.2
  done

  kill -KILL -- "-${pid}" >/dev/null 2>&1 || kill -KILL "${pid}" >/dev/null 2>&1 || true
}

cleanup() {
  echo ""
  echo "[workspace] Shutting down..."

  # Stop in reverse start order.
  local i
  for ((i=${#PIDS[@]}-1; i>=0; i--)); do
    stop_bg "${NAMES[$i]}" "${PIDS[$i]}"
  done

  rm -f "$PIDFILE" >/dev/null 2>&1 || true
  echo "[workspace] Done."
}
trap cleanup EXIT INT TERM

echo "[workspace] Starting services..."

start_bg "SCREENALYTICS" "$SCREENALYTICS_LOG" bash -lc "cd \"$ROOT/screenalytics\" && exec env \
  PYTHONUNBUFFERED=1 \
  SCREENALYTICS_ENV=dev \
  SCREENALYTICS_API_URL=\"$SCREENALYTICS_API_URL\" \
  API_BASE_URL=\"$SCREENALYTICS_API_URL\" \
  API_PORT=\"$SCREENALYTICS_API_PORT\" \
  STREAMLIT_PORT=\"$SCREENALYTICS_STREAMLIT_PORT\" \
  WEB_PORT=\"$SCREENALYTICS_WEB_PORT\" \
  DEV_AUTO_YES=1 \
  ./scripts/dev_auto.sh"

start_bg "TRR_BACKEND" "$TRR_BACKEND_LOG" bash -lc "cd \"$ROOT/TRR-Backend\" && exec env \
  PYTHONUNBUFFERED=1 \
  TRR_BACKEND_PORT=\"$TRR_BACKEND_PORT\" \
  TRR_API_URL=\"$TRR_API_URL\" \
  SCREENALYTICS_API_URL=\"$SCREENALYTICS_API_URL\" \
  CORS_ALLOW_ORIGINS=\"http://127.0.0.1:${TRR_APP_PORT},http://localhost:${TRR_APP_PORT}\" \
  ./start-api.sh"

start_bg "TRR_APP" "$TRR_APP_LOG" bash -lc "cd \"$ROOT/TRR-APP/apps/web\" && exec env \
  TRR_API_URL=\"$TRR_API_URL\" \
  SCREENALYTICS_API_URL=\"$SCREENALYTICS_API_URL\" \
  pnpm exec next dev --webpack -p \"$TRR_APP_PORT\" --hostname \"$TRR_APP_HOST\""

echo ""
echo "[workspace] URLs:"
echo "  TRR-APP:               http://${TRR_APP_HOST}:${TRR_APP_PORT}"
echo "  TRR-Backend:           ${TRR_API_URL}"
echo "  screenalytics API:     ${SCREENALYTICS_API_URL}"
echo "  screenalytics Streamlit: http://127.0.0.1:${SCREENALYTICS_STREAMLIT_PORT}"
echo "  screenalytics Web:     http://127.0.0.1:${SCREENALYTICS_WEB_PORT}"
echo ""
echo "[workspace] Logs:"
echo "  ${TRR_APP_LOG}"
echo "  ${TRR_BACKEND_LOG}"
echo "  ${SCREENALYTICS_LOG}"
echo ""
echo "[workspace] Ctrl+C to stop all."

# Keep running until one of the processes exits.
while true; do
  local_dead=""
  local_dead_name=""
  for idx in "${!PIDS[@]}"; do
    pid="${PIDS[$idx]}"
    name="${NAMES[$idx]}"
    if ! kill -0 "$pid" >/dev/null 2>&1; then
      local_dead="$pid"
      local_dead_name="$name"
      break
    fi
  done
  if [[ -n "$local_dead" ]]; then
    echo ""
    echo "[workspace] WARNING: ${local_dead_name} exited (pid=${local_dead}). Check logs under ${LOG_DIR}."
    exit 1
  fi
  sleep 1
done

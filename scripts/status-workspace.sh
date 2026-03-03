#!/usr/bin/env bash
set -u -o pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${ROOT}/.logs/workspace"
PIDFILE="${LOG_DIR}/pids.env"

# Defaults (overridden by pidfile values when present)
TRR_BACKEND_PORT="${TRR_BACKEND_PORT:-8000}"
TRR_APP_PORT="${TRR_APP_PORT:-3000}"
TRR_APP_HOST="${TRR_APP_HOST:-127.0.0.1}"
SCREENALYTICS_API_PORT="${SCREENALYTICS_API_PORT:-8001}"
SCREENALYTICS_STREAMLIT_PORT="${SCREENALYTICS_STREAMLIT_PORT:-8501}"
SCREENALYTICS_WEB_PORT="${SCREENALYTICS_WEB_PORT:-8080}"
WORKSPACE_HEALTH_CURL_MAX_TIME="${WORKSPACE_HEALTH_CURL_MAX_TIME:-2}"
WORKSPACE_BACKEND_AUTO_RESTART="${WORKSPACE_BACKEND_AUTO_RESTART:-1}"
WORKSPACE_BACKEND_HEALTH_INTERVAL_SECONDS="${WORKSPACE_BACKEND_HEALTH_INTERVAL_SECONDS:-5}"
WORKSPACE_BACKEND_HEALTH_FAILURE_THRESHOLD="${WORKSPACE_BACKEND_HEALTH_FAILURE_THRESHOLD:-6}"
WORKSPACE_BACKEND_HEALTH_CURL_MAX_TIME="${WORKSPACE_BACKEND_HEALTH_CURL_MAX_TIME:-30}"
WORKSPACE_STATUS_BACKEND_HEALTH_CURL_MAX_TIME="${WORKSPACE_STATUS_BACKEND_HEALTH_CURL_MAX_TIME:-5}"
TRR_BACKEND_RELOAD="${TRR_BACKEND_RELOAD:-0}"

if ! [[ "$WORKSPACE_STATUS_BACKEND_HEALTH_CURL_MAX_TIME" =~ ^[1-9][0-9]*$ ]]; then
  WORKSPACE_STATUS_BACKEND_HEALTH_CURL_MAX_TIME="5"
fi

HAVE_PIDFILE=0
if [[ -f "$PIDFILE" ]]; then
  # shellcheck disable=SC1090
  source "$PIDFILE" || true
  HAVE_PIDFILE=1
fi

value_or_na() {
  local value="${1:-}"
  if [[ -z "$value" ]]; then
    echo "n/a"
    return 0
  fi
  echo "$value"
}

pid_state() {
  local pid="${1:-}"
  if [[ -z "$pid" ]]; then
    echo "not recorded"
    return 0
  fi
  if kill -0 "$pid" >/dev/null 2>&1; then
    echo "running (pid=${pid})"
    return 0
  fi
  echo "not running (pid=${pid})"
}

pid_is_running() {
  local pid="${1:-}"
  if [[ -z "$pid" ]]; then
    return 1
  fi
  kill -0 "$pid" >/dev/null 2>&1
}

port_listeners() {
  local port="$1"

  if command -v lsof >/dev/null 2>&1; then
    local listeners
    listeners="$(lsof -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null | awk 'NR>1 {print $1 ":" $2}' | sort -u | paste -sd, -)"
    if [[ -z "$listeners" ]]; then
      echo "none"
    else
      echo "$listeners"
    fi
    return 0
  fi

  if command -v ss >/dev/null 2>&1; then
    if ss -ltn "sport = :$port" 2>/dev/null | tail -n +2 | grep -q .; then
      echo "listening (details unavailable without lsof)"
    else
      echo "none"
    fi
    return 0
  fi

  if command -v netstat >/dev/null 2>&1; then
    if netstat -an 2>/dev/null | grep -E "[\.:]${port}[[:space:]].*LISTEN" >/dev/null; then
      echo "listening (details unavailable without lsof)"
    else
      echo "none"
    fi
    return 0
  fi

  echo "unknown (no lsof/ss/netstat)"
}

health_status() {
  local url="$1"
  local pid="${2:-}"
  if ! command -v curl >/dev/null 2>&1; then
    echo "unknown (curl missing)"
    return 0
  fi

  if curl -fsS --max-time "$WORKSPACE_STATUS_BACKEND_HEALTH_CURL_MAX_TIME" "$url" >/dev/null 2>&1; then
    echo "ok"
  else
    if pid_is_running "$pid"; then
      echo "starting/unhealthy"
    else
      echo "down"
    fi
  fi
}

backend_health_status() {
  local url="$1"
  local pid="${2:-}"
  if ! command -v curl >/dev/null 2>&1; then
    echo "unknown (curl missing)"
    return 0
  fi

  if curl -fsS --max-time "$WORKSPACE_HEALTH_CURL_MAX_TIME" "$url" >/dev/null 2>&1; then
    echo "ok"
    return 0
  fi

  if ! pid_is_running "$pid"; then
    echo "down"
    return 0
  fi

  local attempts="${WORKSPACE_BACKEND_HEALTH_FAILURE_THRESHOLD:-3}"
  if ! [[ "$attempts" =~ ^[1-9][0-9]*$ ]]; then
    attempts=3
  fi
  if (( attempts < 2 )); then
    attempts=2
  fi
  if (( attempts > 3 )); then
    attempts=3
  fi

  for _ in $(seq 2 "$attempts"); do
    sleep 1
    if curl -fsS --max-time "$WORKSPACE_STATUS_BACKEND_HEALTH_CURL_MAX_TIME" "$url" >/dev/null 2>&1; then
      echo "starting/unhealthy"
      return 0
    fi
  done

  echo "hung/unresponsive"
}

screenalytics_enabled() {
  if [[ "${WORKSPACE_SCREENALYTICS:-}" == "0" ]]; then
    return 1
  fi
  return 0
}

backend_reload_mode() {
  if [[ "${TRR_BACKEND_RELOAD:-0}" == "1" ]]; then
    echo "reload"
    return 0
  fi
  echo "non-reload"
}

count_backend_reload_events() {
  local log_path="${LOG_DIR}/trr-backend.log"
  if [[ ! -f "$log_path" ]]; then
    echo "0"
    return 0
  fi
  # Approximate churn signal from recent log entries.
  local count
  count="$(tail -n 800 "$log_path" | grep -E "WatchFiles detected changes|Started reloader process|StatReload" | wc -l | tr -d ' ')"
  if [[ -z "$count" ]]; then
    count="0"
  fi
  echo "$count"
}

echo "[status] Workspace status snapshot"
echo "[status] Root: ${ROOT}"
if [[ "$HAVE_PIDFILE" -eq 1 ]]; then
  echo "[status] Pidfile: ${PIDFILE} (loaded)"
else
  echo "[status] Pidfile: ${PIDFILE} (not found)"
fi
echo ""

echo "[status] Workspace modes:"
echo "  WORKSPACE_SCREENALYTICS: $(value_or_na "${WORKSPACE_SCREENALYTICS:-}")"
echo "  WORKSPACE_SCREENALYTICS_SKIP_DOCKER: $(value_or_na "${WORKSPACE_SCREENALYTICS_SKIP_DOCKER:-}")"
echo "  WORKSPACE_OPEN_BROWSER: $(value_or_na "${WORKSPACE_OPEN_BROWSER:-}")"
echo "  WORKSPACE_OPEN_SCREENALYTICS_TABS: $(value_or_na "${WORKSPACE_OPEN_SCREENALYTICS_TABS:-}")"
echo "  WORKSPACE_STRICT: $(value_or_na "${WORKSPACE_STRICT:-}")"
echo "  WORKSPACE_BACKEND_AUTO_RESTART: $(value_or_na "${WORKSPACE_BACKEND_AUTO_RESTART:-}")"
echo "  WORKSPACE_BACKEND_HEALTH_INTERVAL_SECONDS: $(value_or_na "${WORKSPACE_BACKEND_HEALTH_INTERVAL_SECONDS:-}")"
echo "  WORKSPACE_BACKEND_HEALTH_FAILURE_THRESHOLD: $(value_or_na "${WORKSPACE_BACKEND_HEALTH_FAILURE_THRESHOLD:-}")"
echo "  WORKSPACE_BACKEND_HEALTH_CURL_MAX_TIME: $(value_or_na "${WORKSPACE_BACKEND_HEALTH_CURL_MAX_TIME:-}")"
echo "  WORKSPACE_STATUS_BACKEND_HEALTH_CURL_MAX_TIME: $(value_or_na "${WORKSPACE_STATUS_BACKEND_HEALTH_CURL_MAX_TIME:-}")"
echo "  TRR_BACKEND_RELOAD: $(value_or_na "${TRR_BACKEND_RELOAD:-}") ($(backend_reload_mode))"
echo ""

echo "[status] Process states:"
echo "  TRR_APP: $(pid_state "${TRR_APP_PID:-}")"
echo "  TRR_BACKEND: $(pid_state "${TRR_BACKEND_PID:-}")"
if screenalytics_enabled; then
  echo "  SCREENALYTICS: $(pid_state "${SCREENALYTICS_PID:-}")"
else
  echo "  SCREENALYTICS: disabled (WORKSPACE_SCREENALYTICS=0)"
fi
echo ""

echo "[status] Port listeners:"
echo "  TRR-APP (:${TRR_APP_PORT}): $(port_listeners "${TRR_APP_PORT}")"
echo "  TRR-Backend (:${TRR_BACKEND_PORT}): $(port_listeners "${TRR_BACKEND_PORT}")"
echo "  screenalytics API (:${SCREENALYTICS_API_PORT}): $(port_listeners "${SCREENALYTICS_API_PORT}")"
echo "  screenalytics Streamlit (:${SCREENALYTICS_STREAMLIT_PORT}): $(port_listeners "${SCREENALYTICS_STREAMLIT_PORT}")"
echo "  screenalytics Web (:${SCREENALYTICS_WEB_PORT}): $(port_listeners "${SCREENALYTICS_WEB_PORT}")"
echo ""

echo "[status] Health checks (best effort):"
BACKEND_HEALTH_URL="http://127.0.0.1:${TRR_BACKEND_PORT}/health"
APP_HEALTH_URL="http://${TRR_APP_HOST}:${TRR_APP_PORT}/"
SCREENALYTICS_HEALTH_URL="http://127.0.0.1:${SCREENALYTICS_API_PORT}/healthz"
BACKEND_HEALTH_STATUS="$(backend_health_status "${BACKEND_HEALTH_URL}" "${TRR_BACKEND_PID:-}")"
APP_HEALTH_STATUS="$(health_status "${APP_HEALTH_URL}" "${TRR_APP_PID:-}")"
echo "  TRR-Backend (${BACKEND_HEALTH_URL}): ${BACKEND_HEALTH_STATUS}"
echo "  TRR-APP (${APP_HEALTH_URL}): ${APP_HEALTH_STATUS}"
if screenalytics_enabled; then
  SCREENALYTICS_HEALTH_STATUS="$(health_status "${SCREENALYTICS_HEALTH_URL}" "${SCREENALYTICS_PID:-}")"
  echo "  screenalytics API (${SCREENALYTICS_HEALTH_URL}): ${SCREENALYTICS_HEALTH_STATUS}"
else
  echo "  screenalytics API (${SCREENALYTICS_HEALTH_URL}): disabled"
fi

if [[ "${BACKEND_HEALTH_STATUS}" == "hung/unresponsive" ]]; then
  echo ""
  if [[ "${WORKSPACE_BACKEND_AUTO_RESTART:-1}" == "1" ]]; then
    echo "[status] Recommendation: backend appears hung; watchdog is enabled. Check '${LOG_DIR}/trr-backend.log' for restart attempts."
  else
    echo "[status] Recommendation: backend appears hung; run 'make stop && make dev-lite' or set WORKSPACE_BACKEND_AUTO_RESTART=1."
  fi
fi

if [[ "${TRR_BACKEND_RELOAD:-0}" == "1" ]]; then
  backend_reload_events="$(count_backend_reload_events)"
  if [[ "$backend_reload_events" =~ ^[0-9]+$ ]] && (( backend_reload_events > 3 )); then
    echo "[status] Warning: recent backend reload churn detected (${backend_reload_events} reload markers). Consider TRR_BACKEND_RELOAD=0 for stream stability."
  fi
fi

exit 0

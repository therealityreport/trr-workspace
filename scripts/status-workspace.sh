#!/usr/bin/env bash
set -u -o pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${ROOT}/.logs/workspace"
PIDFILE="${LOG_DIR}/pids.env"
BACKEND_WATCHDOG_STATE_FILE="${LOG_DIR}/backend-watchdog.env"

OUTPUT_FORMAT="text"
if [[ "${1:-}" == "--json" ]]; then
  OUTPUT_FORMAT="json"
elif [[ -n "${1:-}" ]]; then
  echo "Usage: $0 [--json]" >&2
  exit 1
fi

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
WORKSPACE_SOCIAL_WORKER_ENABLED="${WORKSPACE_SOCIAL_WORKER_ENABLED:-1}"
WORKSPACE_SOCIAL_WORKER_POSTS="${WORKSPACE_SOCIAL_WORKER_POSTS:-6}"
WORKSPACE_SOCIAL_WORKER_COMMENTS="${WORKSPACE_SOCIAL_WORKER_COMMENTS:-6}"
WORKSPACE_SOCIAL_WORKER_MEDIA_MIRROR="${WORKSPACE_SOCIAL_WORKER_MEDIA_MIRROR:-6}"
WORKSPACE_SOCIAL_WORKER_COMMENT_MEDIA_MIRROR="${WORKSPACE_SOCIAL_WORKER_COMMENT_MEDIA_MIRROR:-6}"
WORKSPACE_SOCIAL_WORKER_INTERVAL_SEC="${WORKSPACE_SOCIAL_WORKER_INTERVAL_SEC:-2}"
WORKSPACE_TRR_JOB_PLANE_MODE="${WORKSPACE_TRR_JOB_PLANE_MODE:-remote}"
WORKSPACE_TRR_LONG_JOB_ENFORCE_REMOTE="${WORKSPACE_TRR_LONG_JOB_ENFORCE_REMOTE:-1}"
WORKSPACE_TRR_REMOTE_WORKERS_ENABLED="${WORKSPACE_TRR_REMOTE_WORKERS_ENABLED:-1}"
WORKSPACE_TRR_REMOTE_ADMIN_WORKERS="${WORKSPACE_TRR_REMOTE_ADMIN_WORKERS:-1}"
WORKSPACE_TRR_REMOTE_REDDIT_WORKERS="${WORKSPACE_TRR_REMOTE_REDDIT_WORKERS:-1}"
WORKSPACE_TRR_REMOTE_GOOGLE_NEWS_WORKERS="${WORKSPACE_TRR_REMOTE_GOOGLE_NEWS_WORKERS:-1}"
WORKSPACE_TRR_REMOTE_WORKER_POLL_SECONDS="${WORKSPACE_TRR_REMOTE_WORKER_POLL_SECONDS:-2}"
WORKSPACE_TRR_REMOTE_GOOGLE_NEWS_LEASE_SECONDS="${WORKSPACE_TRR_REMOTE_GOOGLE_NEWS_LEASE_SECONDS:-300}"
TRR_BACKEND_RELOAD="${TRR_BACKEND_RELOAD:-0}"
PROFILE="${PROFILE:-}"
WORKSPACE_BACKEND_RESTART_COUNT="${WORKSPACE_BACKEND_RESTART_COUNT:-0}"
WORKSPACE_BACKEND_LAST_RESTART_REASON="${WORKSPACE_BACKEND_LAST_RESTART_REASON:-}"
WORKSPACE_BACKEND_LAST_RESTART_AT="${WORKSPACE_BACKEND_LAST_RESTART_AT:-}"
WORKSPACE_BACKEND_LAST_RESTART_PROBE_RC="${WORKSPACE_BACKEND_LAST_RESTART_PROBE_RC:-}"

if ! [[ "$WORKSPACE_STATUS_BACKEND_HEALTH_CURL_MAX_TIME" =~ ^[1-9][0-9]*$ ]]; then
  WORKSPACE_STATUS_BACKEND_HEALTH_CURL_MAX_TIME="5"
fi

HAVE_PIDFILE=0
if [[ -f "$PIDFILE" ]]; then
  # shellcheck disable=SC1090
  source "$PIDFILE" || true
  HAVE_PIDFILE=1
fi

if [[ -f "$BACKEND_WATCHDOG_STATE_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$BACKEND_WATCHDOG_STATE_FILE" || true
fi

if ! [[ "${BACKEND_RESTART_COUNT:-0}" =~ ^[0-9]+$ ]]; then
  BACKEND_RESTART_COUNT=0
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

pid_running_json() {
  local pid="${1:-}"
  if pid_is_running "$pid"; then
    echo "true"
  else
    echo "false"
  fi
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

  local count
  count="$(tail -n 800 "$log_path" | grep -E "WatchFiles detected changes|Started reloader process|StatReload" | wc -l | tr -d ' ')"
  if [[ -z "$count" ]]; then
    count="0"
  fi
  echo "$count"
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\r/\\r/g; s/\n/\\n/g'
}

BACKEND_HEALTH_URL="http://127.0.0.1:${TRR_BACKEND_PORT}/health"
APP_HEALTH_URL="http://${TRR_APP_HOST}:${TRR_APP_PORT}/"
SCREENALYTICS_HEALTH_URL="http://127.0.0.1:${SCREENALYTICS_API_PORT}/healthz"
BACKEND_HEALTH_STATUS="$(backend_health_status "${BACKEND_HEALTH_URL}" "${TRR_BACKEND_PID:-}")"
APP_HEALTH_STATUS="$(health_status "${APP_HEALTH_URL}" "${TRR_APP_PID:-}")"
if screenalytics_enabled; then
  SCREENALYTICS_HEALTH_STATUS="$(health_status "${SCREENALYTICS_HEALTH_URL}" "${SCREENALYTICS_PID:-}")"
else
  SCREENALYTICS_HEALTH_STATUS="disabled"
fi

TRR_APP_LISTENERS="$(port_listeners "${TRR_APP_PORT}")"
TRR_BACKEND_LISTENERS="$(port_listeners "${TRR_BACKEND_PORT}")"
SCREENALYTICS_API_LISTENERS="$(port_listeners "${SCREENALYTICS_API_PORT}")"
SCREENALYTICS_STREAMLIT_LISTENERS="$(port_listeners "${SCREENALYTICS_STREAMLIT_PORT}")"
SCREENALYTICS_WEB_LISTENERS="$(port_listeners "${SCREENALYTICS_WEB_PORT}")"

if [[ "$OUTPUT_FORMAT" == "json" ]]; then
  cat <<JSON
{
  "root": "$(json_escape "$ROOT")",
  "pidfile": {
    "path": "$(json_escape "$PIDFILE")",
    "loaded": $([[ "$HAVE_PIDFILE" -eq 1 ]] && echo true || echo false)
  },
  "modes": {
    "workspace_screenalytics": "$(json_escape "${WORKSPACE_SCREENALYTICS:-}")",
    "workspace_screenalytics_skip_docker": "$(json_escape "${WORKSPACE_SCREENALYTICS_SKIP_DOCKER:-}")",
    "workspace_open_browser": "$(json_escape "${WORKSPACE_OPEN_BROWSER:-}")",
    "workspace_browser_tab_sync_mode": "$(json_escape "${WORKSPACE_BROWSER_TAB_SYNC_MODE:-}")",
    "workspace_open_screenalytics_tabs": "$(json_escape "${WORKSPACE_OPEN_SCREENALYTICS_TABS:-}")",
    "workspace_strict": "$(json_escape "${WORKSPACE_STRICT:-}")",
    "workspace_backend_auto_restart": "$(json_escape "${WORKSPACE_BACKEND_AUTO_RESTART:-}")",
    "workspace_backend_health_interval_seconds": "$(json_escape "${WORKSPACE_BACKEND_HEALTH_INTERVAL_SECONDS:-}")",
    "workspace_backend_health_failure_threshold": "$(json_escape "${WORKSPACE_BACKEND_HEALTH_FAILURE_THRESHOLD:-}")",
    "workspace_backend_health_curl_max_time": "$(json_escape "${WORKSPACE_BACKEND_HEALTH_CURL_MAX_TIME:-}")",
    "workspace_status_backend_health_curl_max_time": "$(json_escape "${WORKSPACE_STATUS_BACKEND_HEALTH_CURL_MAX_TIME:-}")",
    "workspace_social_worker_enabled": "$(json_escape "${WORKSPACE_SOCIAL_WORKER_ENABLED:-}")",
    "workspace_social_worker_posts": "$(json_escape "${WORKSPACE_SOCIAL_WORKER_POSTS:-}")",
    "workspace_social_worker_comments": "$(json_escape "${WORKSPACE_SOCIAL_WORKER_COMMENTS:-}")",
    "workspace_social_worker_media_mirror": "$(json_escape "${WORKSPACE_SOCIAL_WORKER_MEDIA_MIRROR:-}")",
    "workspace_social_worker_comment_media_mirror": "$(json_escape "${WORKSPACE_SOCIAL_WORKER_COMMENT_MEDIA_MIRROR:-}")",
    "workspace_social_worker_interval_sec": "$(json_escape "${WORKSPACE_SOCIAL_WORKER_INTERVAL_SEC:-}")",
    "workspace_trr_job_plane_mode": "$(json_escape "${WORKSPACE_TRR_JOB_PLANE_MODE:-}")",
    "workspace_trr_long_job_enforce_remote": "$(json_escape "${WORKSPACE_TRR_LONG_JOB_ENFORCE_REMOTE:-}")",
    "workspace_trr_remote_workers_enabled": "$(json_escape "${WORKSPACE_TRR_REMOTE_WORKERS_ENABLED:-}")",
    "workspace_trr_remote_admin_workers": "$(json_escape "${WORKSPACE_TRR_REMOTE_ADMIN_WORKERS:-}")",
    "workspace_trr_remote_reddit_workers": "$(json_escape "${WORKSPACE_TRR_REMOTE_REDDIT_WORKERS:-}")",
    "workspace_trr_remote_google_news_workers": "$(json_escape "${WORKSPACE_TRR_REMOTE_GOOGLE_NEWS_WORKERS:-}")",
    "workspace_trr_remote_worker_poll_seconds": "$(json_escape "${WORKSPACE_TRR_REMOTE_WORKER_POLL_SECONDS:-}")",
    "workspace_trr_remote_google_news_lease_seconds": "$(json_escape "${WORKSPACE_TRR_REMOTE_GOOGLE_NEWS_LEASE_SECONDS:-}")",
    "trr_backend_reload": "$(json_escape "${TRR_BACKEND_RELOAD:-}")",
    "profile": "$(json_escape "${PROFILE:-}")"
  },
  "processes": {
    "trr_app": {"pid": "$(json_escape "${TRR_APP_PID:-}")", "running": $(pid_running_json "${TRR_APP_PID:-}")},
    "trr_social_worker": {"pid": "$(json_escape "${TRR_SOCIAL_WORKER_PID:-}")", "running": $(pid_running_json "${TRR_SOCIAL_WORKER_PID:-}")},
    "trr_remote_workers": {"pid": "$(json_escape "${TRR_REMOTE_WORKERS_PID:-}")", "running": $(pid_running_json "${TRR_REMOTE_WORKERS_PID:-}")},
    "trr_backend": {"pid": "$(json_escape "${TRR_BACKEND_PID:-}")", "running": $(pid_running_json "${TRR_BACKEND_PID:-}")},
    "screenalytics": {"pid": "$(json_escape "${SCREENALYTICS_PID:-}")", "running": $(pid_running_json "${SCREENALYTICS_PID:-}")}
  },
  "ports": {
    "trr_app": {"port": "${TRR_APP_PORT}", "listeners": "$(json_escape "$TRR_APP_LISTENERS")"},
    "trr_backend": {"port": "${TRR_BACKEND_PORT}", "listeners": "$(json_escape "$TRR_BACKEND_LISTENERS")"},
    "screenalytics_api": {"port": "${SCREENALYTICS_API_PORT}", "listeners": "$(json_escape "$SCREENALYTICS_API_LISTENERS")"},
    "screenalytics_streamlit": {"port": "${SCREENALYTICS_STREAMLIT_PORT}", "listeners": "$(json_escape "$SCREENALYTICS_STREAMLIT_LISTENERS")"},
    "screenalytics_web": {"port": "${SCREENALYTICS_WEB_PORT}", "listeners": "$(json_escape "$SCREENALYTICS_WEB_LISTENERS")"}
  },
  "health": {
    "trr_backend_url": "$(json_escape "$BACKEND_HEALTH_URL")",
    "trr_backend_status": "$(json_escape "$BACKEND_HEALTH_STATUS")",
    "trr_app_url": "$(json_escape "$APP_HEALTH_URL")",
    "trr_app_status": "$(json_escape "$APP_HEALTH_STATUS")",
    "screenalytics_api_url": "$(json_escape "$SCREENALYTICS_HEALTH_URL")",
    "screenalytics_api_status": "$(json_escape "$SCREENALYTICS_HEALTH_STATUS")"
  },
  "backend_watchdog": {
    "restart_count": ${BACKEND_RESTART_COUNT:-0},
    "last_restart_reason": "$(json_escape "${BACKEND_LAST_RESTART_REASON:-}")",
    "last_restart_at": "$(json_escape "${BACKEND_LAST_RESTART_AT:-}")",
    "last_restart_probe_rc": "$(json_escape "${BACKEND_LAST_RESTART_PROBE_RC:-}")"
  },
  "timestamp_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
JSON
  exit 0
fi

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
echo "  WORKSPACE_BROWSER_TAB_SYNC_MODE: $(value_or_na "${WORKSPACE_BROWSER_TAB_SYNC_MODE:-}")"
echo "  WORKSPACE_OPEN_SCREENALYTICS_TABS: $(value_or_na "${WORKSPACE_OPEN_SCREENALYTICS_TABS:-}")"
echo "  WORKSPACE_STRICT: $(value_or_na "${WORKSPACE_STRICT:-}")"
echo "  WORKSPACE_BACKEND_AUTO_RESTART: $(value_or_na "${WORKSPACE_BACKEND_AUTO_RESTART:-}")"
echo "  WORKSPACE_BACKEND_HEALTH_INTERVAL_SECONDS: $(value_or_na "${WORKSPACE_BACKEND_HEALTH_INTERVAL_SECONDS:-}")"
echo "  WORKSPACE_BACKEND_HEALTH_FAILURE_THRESHOLD: $(value_or_na "${WORKSPACE_BACKEND_HEALTH_FAILURE_THRESHOLD:-}")"
echo "  WORKSPACE_BACKEND_HEALTH_CURL_MAX_TIME: $(value_or_na "${WORKSPACE_BACKEND_HEALTH_CURL_MAX_TIME:-}")"
echo "  WORKSPACE_STATUS_BACKEND_HEALTH_CURL_MAX_TIME: $(value_or_na "${WORKSPACE_STATUS_BACKEND_HEALTH_CURL_MAX_TIME:-}")"
echo "  WORKSPACE_SOCIAL_WORKER_ENABLED: $(value_or_na "${WORKSPACE_SOCIAL_WORKER_ENABLED:-}")"
echo "  WORKSPACE_SOCIAL_WORKER_POSTS: $(value_or_na "${WORKSPACE_SOCIAL_WORKER_POSTS:-}")"
echo "  WORKSPACE_SOCIAL_WORKER_COMMENTS: $(value_or_na "${WORKSPACE_SOCIAL_WORKER_COMMENTS:-}")"
echo "  WORKSPACE_SOCIAL_WORKER_MEDIA_MIRROR: $(value_or_na "${WORKSPACE_SOCIAL_WORKER_MEDIA_MIRROR:-}")"
echo "  WORKSPACE_SOCIAL_WORKER_COMMENT_MEDIA_MIRROR: $(value_or_na "${WORKSPACE_SOCIAL_WORKER_COMMENT_MEDIA_MIRROR:-}")"
echo "  WORKSPACE_SOCIAL_WORKER_INTERVAL_SEC: $(value_or_na "${WORKSPACE_SOCIAL_WORKER_INTERVAL_SEC:-}")"
echo "  WORKSPACE_TRR_JOB_PLANE_MODE: $(value_or_na "${WORKSPACE_TRR_JOB_PLANE_MODE:-}")"
echo "  WORKSPACE_TRR_LONG_JOB_ENFORCE_REMOTE: $(value_or_na "${WORKSPACE_TRR_LONG_JOB_ENFORCE_REMOTE:-}")"
echo "  WORKSPACE_TRR_REMOTE_WORKERS_ENABLED: $(value_or_na "${WORKSPACE_TRR_REMOTE_WORKERS_ENABLED:-}")"
echo "  WORKSPACE_TRR_REMOTE_ADMIN_WORKERS: $(value_or_na "${WORKSPACE_TRR_REMOTE_ADMIN_WORKERS:-}")"
echo "  WORKSPACE_TRR_REMOTE_REDDIT_WORKERS: $(value_or_na "${WORKSPACE_TRR_REMOTE_REDDIT_WORKERS:-}")"
echo "  WORKSPACE_TRR_REMOTE_GOOGLE_NEWS_WORKERS: $(value_or_na "${WORKSPACE_TRR_REMOTE_GOOGLE_NEWS_WORKERS:-}")"
echo "  WORKSPACE_TRR_REMOTE_WORKER_POLL_SECONDS: $(value_or_na "${WORKSPACE_TRR_REMOTE_WORKER_POLL_SECONDS:-}")"
echo "  WORKSPACE_TRR_REMOTE_GOOGLE_NEWS_LEASE_SECONDS: $(value_or_na "${WORKSPACE_TRR_REMOTE_GOOGLE_NEWS_LEASE_SECONDS:-}")"
echo "  TRR_BACKEND_RELOAD: $(value_or_na "${TRR_BACKEND_RELOAD:-}") ($(backend_reload_mode))"
echo "  PROFILE: $(value_or_na "${PROFILE:-}")"
echo ""

echo "[status] Process states:"
echo "  TRR_APP: $(pid_state "${TRR_APP_PID:-}")"
echo "  TRR_SOCIAL_WORKER: $(pid_state "${TRR_SOCIAL_WORKER_PID:-}")"
echo "  TRR_REMOTE_WORKERS: $(pid_state "${TRR_REMOTE_WORKERS_PID:-}")"
echo "  TRR_BACKEND: $(pid_state "${TRR_BACKEND_PID:-}")"
if screenalytics_enabled; then
  echo "  SCREENALYTICS: $(pid_state "${SCREENALYTICS_PID:-}")"
else
  echo "  SCREENALYTICS: disabled (WORKSPACE_SCREENALYTICS=0)"
fi
echo ""

echo "[status] Port listeners:"
echo "  TRR-APP (:${TRR_APP_PORT}): ${TRR_APP_LISTENERS}"
echo "  TRR-Backend (:${TRR_BACKEND_PORT}): ${TRR_BACKEND_LISTENERS}"
echo "  screenalytics API (:${SCREENALYTICS_API_PORT}): ${SCREENALYTICS_API_LISTENERS}"
echo "  screenalytics Streamlit (:${SCREENALYTICS_STREAMLIT_PORT}): ${SCREENALYTICS_STREAMLIT_LISTENERS}"
echo "  screenalytics Web (:${SCREENALYTICS_WEB_PORT}): ${SCREENALYTICS_WEB_LISTENERS}"
echo ""

echo "[status] Health checks (best effort):"
echo "  TRR-Backend (${BACKEND_HEALTH_URL}): ${BACKEND_HEALTH_STATUS}"
echo "  TRR-APP (${APP_HEALTH_URL}): ${APP_HEALTH_STATUS}"
if screenalytics_enabled; then
  echo "  screenalytics API (${SCREENALYTICS_HEALTH_URL}): ${SCREENALYTICS_HEALTH_STATUS}"
else
  echo "  screenalytics API (${SCREENALYTICS_HEALTH_URL}): disabled"
fi
echo ""

echo "[status] Backend watchdog:"
echo "  restart_count: ${BACKEND_RESTART_COUNT}"
echo "  last_restart_reason: $(value_or_na "${BACKEND_LAST_RESTART_REASON:-}")"
echo "  last_restart_at: $(value_or_na "${BACKEND_LAST_RESTART_AT:-}")"
echo "  last_restart_probe_rc: $(value_or_na "${BACKEND_LAST_RESTART_PROBE_RC:-}")"

if [[ "${BACKEND_HEALTH_STATUS}" == "hung/unresponsive" ]]; then
  echo ""
  if [[ "${WORKSPACE_BACKEND_AUTO_RESTART:-1}" == "1" ]]; then
    echo "[status] Recommendation: backend appears hung; watchdog is enabled. Check '${LOG_DIR}/trr-backend.log' and '${LOG_DIR}/backend-watchdog-events.jsonl'."
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

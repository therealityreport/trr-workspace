#!/usr/bin/env bash
set -u -o pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${ROOT}/.logs/workspace"
PIDFILE="${LOG_DIR}/pids.env"
BACKEND_WATCHDOG_STATE_FILE="${LOG_DIR}/backend-watchdog.env"
RUNTIME_RECONCILE_FILE="${LOG_DIR}/runtime-reconcile.json"
source "${ROOT}/scripts/lib/mcp-runtime.sh"
source "${ROOT}/scripts/lib/workspace-runtime-reconcile-contract.sh"
source "${ROOT}/scripts/lib/workspace-health.sh"

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
WORKSPACE_HEALTH_CURL_MAX_TIME="${WORKSPACE_HEALTH_CURL_MAX_TIME:-8}"
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
WORKSPACE_TRR_REMOTE_EXECUTOR="${WORKSPACE_TRR_REMOTE_EXECUTOR:-modal}"
WORKSPACE_TRR_MODAL_ENABLED="${WORKSPACE_TRR_MODAL_ENABLED:-1}"
WORKSPACE_TRR_REMOTE_WORKERS_ENABLED="${WORKSPACE_TRR_REMOTE_WORKERS_ENABLED:-1}"
WORKSPACE_TRR_REMOTE_ADMIN_WORKERS="${WORKSPACE_TRR_REMOTE_ADMIN_WORKERS:-1}"
WORKSPACE_TRR_REMOTE_REDDIT_WORKERS="${WORKSPACE_TRR_REMOTE_REDDIT_WORKERS:-1}"
WORKSPACE_TRR_REMOTE_GOOGLE_NEWS_WORKERS="${WORKSPACE_TRR_REMOTE_GOOGLE_NEWS_WORKERS:-1}"
WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS="${WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS:-0}"
WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT="${WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT:-6}"
WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT="${WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT:-12}"
WORKSPACE_TRR_REMOTE_SOCIAL_POSTS="${WORKSPACE_TRR_REMOTE_SOCIAL_POSTS:-1}"
WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS="${WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS:-1}"
WORKSPACE_TRR_REMOTE_SOCIAL_MEDIA_MIRROR="${WORKSPACE_TRR_REMOTE_SOCIAL_MEDIA_MIRROR:-1}"
WORKSPACE_TRR_REMOTE_SOCIAL_COMMENT_MEDIA_MIRROR="${WORKSPACE_TRR_REMOTE_SOCIAL_COMMENT_MEDIA_MIRROR:-1}"
WORKSPACE_TRR_REMOTE_WORKER_POLL_SECONDS="${WORKSPACE_TRR_REMOTE_WORKER_POLL_SECONDS:-2}"
WORKSPACE_TRR_REMOTE_GOOGLE_NEWS_LEASE_SECONDS="${WORKSPACE_TRR_REMOTE_GOOGLE_NEWS_LEASE_SECONDS:-300}"
TRR_BACKEND_RELOAD="${TRR_BACKEND_RELOAD:-0}"
TRR_ADMIN_ROUTE_CACHE_DISABLED="${TRR_ADMIN_ROUTE_CACHE_DISABLED:-0}"
PROFILE="${PROFILE:-}"
WORKSPACE_DEV_MODE="${WORKSPACE_DEV_MODE:-cloud}"
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

HAVE_WATCHDOG_STATE=0
if [[ -f "$BACKEND_WATCHDOG_STATE_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$BACKEND_WATCHDOG_STATE_FILE" || true
  HAVE_WATCHDOG_STATE=1
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

runtime_value_or_na() {
  local value="${1:-}"
  if [[ "$HAVE_PIDFILE" -ne 1 ]]; then
    echo "n/a"
    return 0
  fi
  value_or_na "$value"
}

workspace_dev_mode_value() {
  if [[ "$HAVE_PIDFILE" -eq 1 && -n "${WORKSPACE_DEV_MODE:-}" ]]; then
    echo "${WORKSPACE_DEV_MODE}"
    return 0
  fi
  echo "cloud"
}

workspace_dev_mode_label() {
  echo "cloud (preferred no-Docker path)"
}

watchdog_value_or_na() {
  local value="${1:-}"
  if [[ "$HAVE_PIDFILE" -ne 1 && "$HAVE_WATCHDOG_STATE" -ne 1 ]]; then
    echo "n/a"
    return 0
  fi
  value_or_na "$value"
}

watchdog_restart_count_display() {
  if [[ "$HAVE_PIDFILE" -ne 1 && "$HAVE_WATCHDOG_STATE" -ne 1 ]]; then
    echo "n/a"
    return 0
  fi
  echo "${BACKEND_RESTART_COUNT:-0}"
}

watchdog_restart_count_json() {
  if [[ "$HAVE_PIDFILE" -ne 1 && "$HAVE_WATCHDOG_STATE" -ne 1 ]]; then
    echo "null"
    return 0
  fi
  echo "${BACKEND_RESTART_COUNT:-0}"
}

remote_execution_summary() {
  if [[ "$HAVE_PIDFILE" -ne 1 ]]; then
    echo "n/a"
    return 0
  fi
  if [[ "${WORKSPACE_TRR_REMOTE_WORKERS_ENABLED:-0}" != "1" ]]; then
    echo "disabled"
    return 0
  fi
  if status_modal_remote_active; then
    echo "modal_dispatch_active ($(modal_social_runtime_summary); local claim loops skipped)"
    return 0
  fi
  echo "local_claim_loops"
}

status_modal_remote_active() {
  [[ "$HAVE_PIDFILE" -eq 1 && "${WORKSPACE_TRR_REMOTE_WORKERS_ENABLED:-0}" == "1" && "${WORKSPACE_TRR_REMOTE_EXECUTOR:-}" == "modal" && "${WORKSPACE_TRR_MODAL_ENABLED:-}" == "1" ]]
}

status_modal_social_lane_label() {
  if [[ "$HAVE_PIDFILE" -ne 1 ]]; then
    echo "n/a"
    return 0
  fi
  if status_modal_remote_active && [[ "${WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS:-0}" == "1" ]]; then
    echo "enabled"
    return 0
  fi
  echo "disabled"
}

status_modal_social_stage_caps() {
  if [[ "$HAVE_PIDFILE" -ne 1 ]]; then
    echo "n/a"
    return 0
  fi
  echo "posts=${WORKSPACE_TRR_REMOTE_SOCIAL_POSTS:-n/a}, comments=${WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS:-n/a}, media_mirror=${WORKSPACE_TRR_REMOTE_SOCIAL_MEDIA_MIRROR:-n/a}, comment_media_mirror=${WORKSPACE_TRR_REMOTE_SOCIAL_COMMENT_MEDIA_MIRROR:-n/a}"
}

modal_social_runtime_summary() {
  if ! status_modal_remote_active; then
    echo "n/a"
    return 0
  fi
  echo "social_lane=$(status_modal_social_lane_label), dispatch_limit=${WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT:-n/a}, max_concurrency=${WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT:-n/a}, stage_caps=$(status_modal_social_stage_caps)"
}

remote_workers_process_state() {
  if [[ "$HAVE_PIDFILE" -ne 1 ]]; then
    echo "n/a"
    return 0
  fi
  if [[ "${WORKSPACE_TRR_REMOTE_WORKERS_ENABLED:-0}" != "1" ]]; then
    echo "disabled"
    return 0
  fi
  if [[ "${WORKSPACE_TRR_REMOTE_EXECUTOR:-}" == "modal" && "${WORKSPACE_TRR_MODAL_ENABLED:-}" == "1" ]]; then
    echo "not started locally (Modal dispatch active)"
    return 0
  fi
  pid_state "${TRR_REMOTE_WORKERS_PID:-}"
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
  local liveness_url="${2:-}"
  local pid="${3:-}"
  if ! command -v curl >/dev/null 2>&1; then
    echo "unknown (curl missing)"
    return 0
  fi

  if curl -fsS --max-time "$WORKSPACE_STATUS_BACKEND_HEALTH_CURL_MAX_TIME" "$url" >/dev/null 2>&1; then
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

  local liveness_ok="0"
  if [[ -n "$liveness_url" ]] && curl -fsS --max-time "$WORKSPACE_STATUS_BACKEND_HEALTH_CURL_MAX_TIME" "$liveness_url" >/dev/null 2>&1; then
    liveness_ok="1"
  fi

  workspace_backend_readiness_label 0 "$liveness_ok"
}

backend_reload_mode() {
  if [[ "$HAVE_PIDFILE" -ne 1 ]]; then
    echo "n/a"
    return 0
  fi
  if [[ "${TRR_BACKEND_RELOAD:-1}" == "1" ]]; then
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

runtime_reconcile_json() {
  python3 - "$RUNTIME_RECONCILE_FILE" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
if not path.is_file():
    print("null")
    raise SystemExit(0)
try:
    payload = json.loads(path.read_text(encoding="utf-8"))
except Exception:
    print("null")
    raise SystemExit(0)
print(json.dumps(payload, sort_keys=True))
PY
}

runtime_reconcile_text() {
  python3 - "$RUNTIME_RECONCILE_FILE" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
print("[status] Runtime reconcile:")
if not path.is_file():
    print("  overall_state: n/a")
    raise SystemExit(0)
try:
    payload = json.loads(path.read_text(encoding="utf-8"))
except Exception:
    print("  overall_state: unavailable")
    raise SystemExit(0)

print(f"  overall_state: {payload.get('overall_state') or 'unknown'}")
print(f"  summary: {payload.get('summary') or 'n/a'}")
for name in ("db", "modal", "render", "decodo"):
    component = payload.get(name) or {}
    print(f"  {name}: {component.get('state') or 'n/a'}")
    if component.get("reason"):
        print(f"    reason: {component['reason']}")
    if component.get("remediation"):
        print(f"    remediation: {component['remediation']}")
    if name == "modal":
        readiness = component.get("readiness") or {}
        if isinstance(readiness, dict) and readiness:
            if readiness.get("core_ok") is not None:
                print(f"    core_ready: {bool(readiness.get('core_ok'))}")
            probe = readiness.get("getty_remote_probe") or {}
            if isinstance(probe, dict) and probe:
                probe_ready = probe.get("ready") is True
                probe_reason = probe.get("reason")
                probe_state = "healthy" if probe_ready else "blocked"
                if probe_reason == "proxy_unconfigured":
                    probe_state = "disabled"
                print(f"    getty_remote_probe: {probe_state}")
                if probe_reason:
                    print(f"      reason: {probe_reason}")
                if probe.get("transport_mode"):
                    print(f"      transport_mode: {probe['transport_mode']}")
                if probe.get("proxy_fingerprint"):
                    print(f"      proxy_fingerprint: {probe['proxy_fingerprint']}")
PY
}

codex_owner_label() {
  local owner="$1"
  case "$owner" in
    desktop)
      echo "Desktop Codex app-server"
      ;;
    vscode)
      echo "VS Code Codex app-server"
      ;;
    *)
      echo "Unknown Codex app-server"
      ;;
  esac
}

app_server_mcp_children() {
  local pid="$1"
  local has_chrome=0
  local child
  local command
  local children=()

  while IFS= read -r child; do
    [[ -n "$child" ]] || continue
    command="$(process_command "$child")"
    case "$command" in
      *"scripts/codex-chrome-devtools-mcp.sh"*|*"codex-chrome-devtools-mcp-global.sh"*|*"chrome-devtools-mcp --browserUrl http://127.0.0.1:9422"*|*"chrome-devtools-mcp --browserUrl http://127.0.0.1:9222"*)
        has_chrome=1
        ;;
    esac
  done < <(collect_descendants "$pid" | awk '!seen[$0]++')

  if [[ "$has_chrome" == "1" ]]; then
    children+=("chrome-mcp")
  fi

  if [[ "${#children[@]}" -eq 0 ]]; then
    echo "none"
    return 0
  fi

  printf '%s\n' "${children[@]}" | paste -sd, -
}

build_codex_runtime_json() {
  local first=1
  local owner
  local pid
  local ppid
  local command
  local children

  printf '['
  while IFS=$'\t' read -r owner pid ppid command; do
    [[ -n "$pid" ]] || continue
    children="$(app_server_mcp_children "$pid")"
    if [[ "$first" -eq 0 ]]; then
      printf ','
    fi
    first=0
    printf '{"owner":"%s","label":"%s","pid":"%s","ppid":"%s","mcp_children":"%s","command":"%s"}' \
      "$(json_escape "$owner")" \
      "$(json_escape "$(codex_owner_label "$owner")")" \
      "$(json_escape "$pid")" \
      "$(json_escape "$ppid")" \
      "$(json_escape "$children")" \
      "$(json_escape "$command")"
  done <<<"${CODEX_APP_SERVER_ROWS:-}"
  printf ']'
}

BACKEND_READINESS_URL="$(workspace_backend_status_readiness_url "${TRR_BACKEND_PORT}")"
BACKEND_LIVENESS_URL="$(workspace_backend_status_liveness_url "${TRR_BACKEND_PORT}")"
APP_HEALTH_URL="http://${TRR_APP_HOST}:${TRR_APP_PORT}/"
BACKEND_READINESS_STATUS="$(backend_health_status "${BACKEND_READINESS_URL}" "${BACKEND_LIVENESS_URL}" "${TRR_BACKEND_PID:-}")"
BACKEND_LIVENESS_STATUS="$(health_status "${BACKEND_LIVENESS_URL}" "${TRR_BACKEND_PID:-}")"
APP_HEALTH_STATUS="$(health_status "${APP_HEALTH_URL}" "${TRR_APP_PID:-}")"

TRR_APP_LISTENERS="$(port_listeners "${TRR_APP_PORT}")"
TRR_BACKEND_LISTENERS="$(port_listeners "${TRR_BACKEND_PORT}")"
RUN_STATE="$([[ "$HAVE_PIDFILE" -eq 1 ]] && echo active || echo inactive)"
BACKEND_WATCHDOG_STATE_LABEL="active"
CODEX_APP_SERVER_ROWS="$(list_codex_app_servers)"
CODEX_APP_SERVER_COUNT="$(printf '%s\n' "$CODEX_APP_SERVER_ROWS" | sed '/^$/d' | wc -l | tr -d ' ')"
if [[ "$HAVE_PIDFILE" -ne 1 ]]; then
  if [[ "$HAVE_WATCHDOG_STATE" -eq 1 ]]; then
    BACKEND_WATCHDOG_STATE_LABEL="last_run_telemetry"
  else
    BACKEND_WATCHDOG_STATE_LABEL="inactive"
  fi
fi

if [[ "$OUTPUT_FORMAT" == "json" ]]; then
  cat <<JSON
{
  "root": "$(json_escape "$ROOT")",
  "run_state": "$(json_escape "$RUN_STATE")",
  "pidfile": {
    "path": "$(json_escape "$PIDFILE")",
    "loaded": $([[ "$HAVE_PIDFILE" -eq 1 ]] && echo true || echo false),
    "active": $([[ "$HAVE_PIDFILE" -eq 1 ]] && echo true || echo false)
  },
  "modes": {
    "workspace_dev_mode": "$(json_escape "$(workspace_dev_mode_value)")",
    "workspace_open_browser": "$(json_escape "$(runtime_value_or_na "${WORKSPACE_OPEN_BROWSER:-}")")",
    "workspace_browser_tab_sync_mode": "$(json_escape "$(runtime_value_or_na "${WORKSPACE_BROWSER_TAB_SYNC_MODE:-}")")",
    "workspace_strict": "$(json_escape "$(runtime_value_or_na "${WORKSPACE_STRICT:-}")")",
    "workspace_backend_auto_restart": "$(json_escape "$(runtime_value_or_na "${WORKSPACE_BACKEND_AUTO_RESTART:-}")")",
    "workspace_backend_health_interval_seconds": "$(json_escape "$(runtime_value_or_na "${WORKSPACE_BACKEND_HEALTH_INTERVAL_SECONDS:-}")")",
    "workspace_backend_health_failure_threshold": "$(json_escape "$(runtime_value_or_na "${WORKSPACE_BACKEND_HEALTH_FAILURE_THRESHOLD:-}")")",
    "workspace_backend_health_curl_max_time": "$(json_escape "$(runtime_value_or_na "${WORKSPACE_BACKEND_HEALTH_CURL_MAX_TIME:-}")")",
    "workspace_status_backend_health_curl_max_time": "$(json_escape "$(runtime_value_or_na "${WORKSPACE_STATUS_BACKEND_HEALTH_CURL_MAX_TIME:-}")")",
    "workspace_social_worker_enabled": "$(json_escape "$(runtime_value_or_na "${WORKSPACE_SOCIAL_WORKER_ENABLED:-}")")",
    "workspace_social_worker_posts": "$(json_escape "$(runtime_value_or_na "${WORKSPACE_SOCIAL_WORKER_POSTS:-}")")",
    "workspace_social_worker_comments": "$(json_escape "$(runtime_value_or_na "${WORKSPACE_SOCIAL_WORKER_COMMENTS:-}")")",
    "workspace_social_worker_media_mirror": "$(json_escape "$(runtime_value_or_na "${WORKSPACE_SOCIAL_WORKER_MEDIA_MIRROR:-}")")",
    "workspace_social_worker_comment_media_mirror": "$(json_escape "$(runtime_value_or_na "${WORKSPACE_SOCIAL_WORKER_COMMENT_MEDIA_MIRROR:-}")")",
    "workspace_social_worker_interval_sec": "$(json_escape "$(runtime_value_or_na "${WORKSPACE_SOCIAL_WORKER_INTERVAL_SEC:-}")")",
    "workspace_trr_job_plane_mode": "$(json_escape "$(runtime_value_or_na "${WORKSPACE_TRR_JOB_PLANE_MODE:-}")")",
    "workspace_trr_long_job_enforce_remote": "$(json_escape "$(runtime_value_or_na "${WORKSPACE_TRR_LONG_JOB_ENFORCE_REMOTE:-}")")",
    "trr_allow_local_admin_operation_override": "$(json_escape "$(runtime_value_or_na "${TRR_ALLOW_LOCAL_ADMIN_OPERATION_OVERRIDE:-}")")",
    "workspace_trr_remote_executor": "$(json_escape "$(runtime_value_or_na "${WORKSPACE_TRR_REMOTE_EXECUTOR:-}")")",
    "workspace_trr_modal_enabled": "$(json_escape "$(runtime_value_or_na "${WORKSPACE_TRR_MODAL_ENABLED:-}")")",
    "workspace_trr_remote_workers_enabled": "$(json_escape "$(runtime_value_or_na "${WORKSPACE_TRR_REMOTE_WORKERS_ENABLED:-}")")",
    "workspace_trr_remote_admin_workers": "$(json_escape "$(runtime_value_or_na "${WORKSPACE_TRR_REMOTE_ADMIN_WORKERS:-}")")",
    "workspace_trr_remote_reddit_workers": "$(json_escape "$(runtime_value_or_na "${WORKSPACE_TRR_REMOTE_REDDIT_WORKERS:-}")")",
    "workspace_trr_remote_google_news_workers": "$(json_escape "$(runtime_value_or_na "${WORKSPACE_TRR_REMOTE_GOOGLE_NEWS_WORKERS:-}")")",
    "workspace_trr_remote_social_workers": "$(json_escape "$(runtime_value_or_na "${WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS:-}")")",
    "workspace_trr_remote_social_dispatch_limit": "$(json_escape "$(runtime_value_or_na "${WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT:-}")")",
    "workspace_trr_modal_social_job_concurrency_limit": "$(json_escape "$(runtime_value_or_na "${WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT:-}")")",
    "workspace_trr_remote_social_posts": "$(json_escape "$(runtime_value_or_na "${WORKSPACE_TRR_REMOTE_SOCIAL_POSTS:-}")")",
    "workspace_trr_remote_social_comments": "$(json_escape "$(runtime_value_or_na "${WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS:-}")")",
    "workspace_trr_remote_social_media_mirror": "$(json_escape "$(runtime_value_or_na "${WORKSPACE_TRR_REMOTE_SOCIAL_MEDIA_MIRROR:-}")")",
    "workspace_trr_remote_social_comment_media_mirror": "$(json_escape "$(runtime_value_or_na "${WORKSPACE_TRR_REMOTE_SOCIAL_COMMENT_MEDIA_MIRROR:-}")")",
    "workspace_trr_remote_worker_poll_seconds": "$(json_escape "$(runtime_value_or_na "${WORKSPACE_TRR_REMOTE_WORKER_POLL_SECONDS:-}")")",
    "workspace_trr_remote_google_news_lease_seconds": "$(json_escape "$(runtime_value_or_na "${WORKSPACE_TRR_REMOTE_GOOGLE_NEWS_LEASE_SECONDS:-}")")",
    "trr_backend_reload": "$(json_escape "$(runtime_value_or_na "${TRR_BACKEND_RELOAD:-}")")",
    "trr_admin_route_cache_disabled": "$(json_escape "$(runtime_value_or_na "${TRR_ADMIN_ROUTE_CACHE_DISABLED:-}")")",
    "profile": "$(json_escape "$(runtime_value_or_na "${PROFILE:-}")")"
  },
  "processes": {
    "trr_app": {"pid": "$(json_escape "${TRR_APP_PID:-}")", "running": $(pid_running_json "${TRR_APP_PID:-}")},
    "trr_social_worker": {"pid": "$(json_escape "${TRR_SOCIAL_WORKER_PID:-}")", "running": $(pid_running_json "${TRR_SOCIAL_WORKER_PID:-}")},
    "trr_remote_workers": {"pid": "$(json_escape "${TRR_REMOTE_WORKERS_PID:-}")", "running": $(pid_running_json "${TRR_REMOTE_WORKERS_PID:-}")},
    "trr_backend": {"pid": "$(json_escape "${TRR_BACKEND_PID:-}")", "running": $(pid_running_json "${TRR_BACKEND_PID:-}")}
  },
  "ports": {
    "trr_app": {"port": "${TRR_APP_PORT}", "listeners": "$(json_escape "$TRR_APP_LISTENERS")"},
    "trr_backend": {"port": "${TRR_BACKEND_PORT}", "listeners": "$(json_escape "$TRR_BACKEND_LISTENERS")"}
  },
  "health": {
    "trr_backend_url": "$(json_escape "$BACKEND_READINESS_URL")",
    "trr_backend_status": "$(json_escape "$BACKEND_READINESS_STATUS")",
    "trr_backend_readiness_url": "$(json_escape "$BACKEND_READINESS_URL")",
    "trr_backend_readiness_status": "$(json_escape "$BACKEND_READINESS_STATUS")",
    "trr_backend_liveness_url": "$(json_escape "$BACKEND_LIVENESS_URL")",
    "trr_backend_liveness_status": "$(json_escape "$BACKEND_LIVENESS_STATUS")",
    "trr_app_url": "$(json_escape "$APP_HEALTH_URL")",
    "trr_app_status": "$(json_escape "$APP_HEALTH_STATUS")"
  },
  "backend_watchdog": {
    "state": "$(json_escape "$BACKEND_WATCHDOG_STATE_LABEL")",
    "restart_count": $(watchdog_restart_count_json),
    "last_restart_reason": "$(json_escape "$(watchdog_value_or_na "${BACKEND_LAST_RESTART_REASON:-}")")",
    "last_restart_at": "$(json_escape "$(watchdog_value_or_na "${BACKEND_LAST_RESTART_AT:-}")")",
    "last_restart_probe_rc": "$(json_escape "$(watchdog_value_or_na "${BACKEND_LAST_RESTART_PROBE_RC:-}")")"
  },
  "remote_execution": {
    "summary": "$(json_escape "$(remote_execution_summary)")",
    "local_claim_loop_pid": "$(json_escape "${TRR_REMOTE_WORKERS_PID:-}")",
    "local_claim_loops_running": $(pid_running_json "${TRR_REMOTE_WORKERS_PID:-}"),
    "modal_social_lane": "$(json_escape "$(status_modal_social_lane_label)")",
    "modal_social_dispatch_limit": "$(json_escape "$(runtime_value_or_na "${WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT:-}")")",
    "modal_social_max_concurrency": "$(json_escape "$(runtime_value_or_na "${WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT:-}")")",
    "modal_social_stage_caps": "$(json_escape "$(status_modal_social_stage_caps)")"
  },
  "runtime_reconcile": $(runtime_reconcile_json),
  "codex_runtime": {
    "app_servers": $(build_codex_runtime_json)
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
  echo "[status] Workspace run: active"
else
  echo "[status] Pidfile: ${PIDFILE} (not found)"
  echo "[status] Workspace run: inactive"
fi
echo ""

echo "[status] Workspace modes:"
echo "  WORKSPACE_DEV_MODE: $(workspace_dev_mode_label)"
echo "  WORKSPACE_OPEN_BROWSER: $(runtime_value_or_na "${WORKSPACE_OPEN_BROWSER:-}")"
echo "  WORKSPACE_BROWSER_TAB_SYNC_MODE: $(runtime_value_or_na "${WORKSPACE_BROWSER_TAB_SYNC_MODE:-}")"
echo "  WORKSPACE_STRICT: $(runtime_value_or_na "${WORKSPACE_STRICT:-}")"
echo "  WORKSPACE_BACKEND_AUTO_RESTART: $(runtime_value_or_na "${WORKSPACE_BACKEND_AUTO_RESTART:-}")"
echo "  WORKSPACE_BACKEND_HEALTH_INTERVAL_SECONDS: $(runtime_value_or_na "${WORKSPACE_BACKEND_HEALTH_INTERVAL_SECONDS:-}")"
echo "  WORKSPACE_BACKEND_HEALTH_FAILURE_THRESHOLD: $(runtime_value_or_na "${WORKSPACE_BACKEND_HEALTH_FAILURE_THRESHOLD:-}")"
echo "  WORKSPACE_BACKEND_HEALTH_CURL_MAX_TIME: $(runtime_value_or_na "${WORKSPACE_BACKEND_HEALTH_CURL_MAX_TIME:-}")"
echo "  WORKSPACE_STATUS_BACKEND_HEALTH_CURL_MAX_TIME: $(runtime_value_or_na "${WORKSPACE_STATUS_BACKEND_HEALTH_CURL_MAX_TIME:-}")"
echo "  WORKSPACE_SOCIAL_WORKER_ENABLED: $(runtime_value_or_na "${WORKSPACE_SOCIAL_WORKER_ENABLED:-}")"
echo "  WORKSPACE_SOCIAL_WORKER_POSTS: $(runtime_value_or_na "${WORKSPACE_SOCIAL_WORKER_POSTS:-}")"
echo "  WORKSPACE_SOCIAL_WORKER_COMMENTS: $(runtime_value_or_na "${WORKSPACE_SOCIAL_WORKER_COMMENTS:-}")"
echo "  WORKSPACE_SOCIAL_WORKER_MEDIA_MIRROR: $(runtime_value_or_na "${WORKSPACE_SOCIAL_WORKER_MEDIA_MIRROR:-}")"
echo "  WORKSPACE_SOCIAL_WORKER_COMMENT_MEDIA_MIRROR: $(runtime_value_or_na "${WORKSPACE_SOCIAL_WORKER_COMMENT_MEDIA_MIRROR:-}")"
echo "  WORKSPACE_SOCIAL_WORKER_INTERVAL_SEC: $(runtime_value_or_na "${WORKSPACE_SOCIAL_WORKER_INTERVAL_SEC:-}")"
echo "  WORKSPACE_TRR_JOB_PLANE_MODE: $(runtime_value_or_na "${WORKSPACE_TRR_JOB_PLANE_MODE:-}")"
echo "  WORKSPACE_TRR_LONG_JOB_ENFORCE_REMOTE: $(runtime_value_or_na "${WORKSPACE_TRR_LONG_JOB_ENFORCE_REMOTE:-}")"
echo "  TRR_ALLOW_LOCAL_ADMIN_OPERATION_OVERRIDE: $(runtime_value_or_na "${TRR_ALLOW_LOCAL_ADMIN_OPERATION_OVERRIDE:-}")"
echo "  WORKSPACE_TRR_REMOTE_EXECUTOR: $(runtime_value_or_na "${WORKSPACE_TRR_REMOTE_EXECUTOR:-}")"
echo "  WORKSPACE_TRR_MODAL_ENABLED: $(runtime_value_or_na "${WORKSPACE_TRR_MODAL_ENABLED:-}")"
echo "  WORKSPACE_TRR_REMOTE_WORKERS_ENABLED: $(runtime_value_or_na "${WORKSPACE_TRR_REMOTE_WORKERS_ENABLED:-}")"
echo "  WORKSPACE_TRR_REMOTE_ADMIN_WORKERS: $(runtime_value_or_na "${WORKSPACE_TRR_REMOTE_ADMIN_WORKERS:-}")"
echo "  WORKSPACE_TRR_REMOTE_REDDIT_WORKERS: $(runtime_value_or_na "${WORKSPACE_TRR_REMOTE_REDDIT_WORKERS:-}")"
echo "  WORKSPACE_TRR_REMOTE_GOOGLE_NEWS_WORKERS: $(runtime_value_or_na "${WORKSPACE_TRR_REMOTE_GOOGLE_NEWS_WORKERS:-}")"
echo "  WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS: $(runtime_value_or_na "${WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS:-}")"
echo "  WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT: $(runtime_value_or_na "${WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT:-}")"
echo "  WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT: $(runtime_value_or_na "${WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT:-}")"
echo "  WORKSPACE_TRR_REMOTE_SOCIAL_POSTS: $(runtime_value_or_na "${WORKSPACE_TRR_REMOTE_SOCIAL_POSTS:-}")"
echo "  WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS: $(runtime_value_or_na "${WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS:-}")"
echo "  WORKSPACE_TRR_REMOTE_SOCIAL_MEDIA_MIRROR: $(runtime_value_or_na "${WORKSPACE_TRR_REMOTE_SOCIAL_MEDIA_MIRROR:-}")"
echo "  WORKSPACE_TRR_REMOTE_SOCIAL_COMMENT_MEDIA_MIRROR: $(runtime_value_or_na "${WORKSPACE_TRR_REMOTE_SOCIAL_COMMENT_MEDIA_MIRROR:-}")"
echo "  WORKSPACE_TRR_REMOTE_WORKER_POLL_SECONDS: $(runtime_value_or_na "${WORKSPACE_TRR_REMOTE_WORKER_POLL_SECONDS:-}")"
echo "  WORKSPACE_TRR_REMOTE_GOOGLE_NEWS_LEASE_SECONDS: $(runtime_value_or_na "${WORKSPACE_TRR_REMOTE_GOOGLE_NEWS_LEASE_SECONDS:-}")"
echo "  TRR_BACKEND_RELOAD: $(runtime_value_or_na "${TRR_BACKEND_RELOAD:-}") ($(backend_reload_mode))"
echo "  TRR_ADMIN_ROUTE_CACHE_DISABLED: $(runtime_value_or_na "${TRR_ADMIN_ROUTE_CACHE_DISABLED:-}")"
echo "  PROFILE: $(runtime_value_or_na "${PROFILE:-}")"
echo ""

echo "[status] Process states:"
echo "  TRR_APP: $(pid_state "${TRR_APP_PID:-}")"
echo "  TRR_SOCIAL_WORKER: $(pid_state "${TRR_SOCIAL_WORKER_PID:-}")"
echo "  TRR_REMOTE_WORKERS: $(remote_workers_process_state)"
echo "  TRR_BACKEND: $(pid_state "${TRR_BACKEND_PID:-}")"
echo ""

echo "[status] Port listeners:"
echo "  TRR-APP (:${TRR_APP_PORT}): ${TRR_APP_LISTENERS}"
echo "  TRR-Backend (:${TRR_BACKEND_PORT}): ${TRR_BACKEND_LISTENERS}"
echo ""

echo "[status] Health checks (best effort):"
echo "  TRR-Backend readiness (${BACKEND_READINESS_URL}): ${BACKEND_READINESS_STATUS}"
echo "  TRR-Backend liveness (${BACKEND_LIVENESS_URL}): ${BACKEND_LIVENESS_STATUS}"
echo "  TRR-APP (${APP_HEALTH_URL}): ${APP_HEALTH_STATUS}"
echo ""

echo "[status] Backend watchdog:"
echo "  state: ${BACKEND_WATCHDOG_STATE_LABEL}"
echo "  restart_count: $(watchdog_restart_count_display)"
echo "  last_restart_reason: $(watchdog_value_or_na "${BACKEND_LAST_RESTART_REASON:-}")"
echo "  last_restart_at: $(watchdog_value_or_na "${BACKEND_LAST_RESTART_AT:-}")"
echo "  last_restart_probe_rc: $(watchdog_value_or_na "${BACKEND_LAST_RESTART_PROBE_RC:-}")"
echo ""
echo "[status] Remote execution:"
echo "  summary: $(remote_execution_summary)"
if status_modal_remote_active; then
  echo "  modal_social: $(modal_social_runtime_summary)"
fi
echo ""
runtime_reconcile_text
echo ""
echo "[status] Codex shared-state runtime:"
if [[ "$CODEX_APP_SERVER_COUNT" == "0" ]]; then
  echo "  app_servers: none detected"
else
  while IFS=$'\t' read -r owner pid ppid command; do
    [[ -n "$pid" ]] || continue
    echo "  $(codex_owner_label "$owner"): pid=${pid} ppid=${ppid} mcp_children=$(app_server_mcp_children "$pid")"
  done <<<"$CODEX_APP_SERVER_ROWS"
fi

if [[ "${BACKEND_READINESS_STATUS}" == "hung/unresponsive" ]]; then
  echo ""
  if [[ "${WORKSPACE_BACKEND_AUTO_RESTART:-1}" == "1" ]]; then
    echo "[status] Recommendation: backend appears hung; watchdog is enabled. Check '${LOG_DIR}/trr-backend.log' and '${LOG_DIR}/backend-watchdog-events.jsonl'."
  else
    echo "[status] Recommendation: backend appears hung; run 'make stop && make dev' or set WORKSPACE_BACKEND_AUTO_RESTART=1."
  fi
fi

if [[ "${TRR_BACKEND_RELOAD:-1}" == "1" ]]; then
  backend_reload_events="$(count_backend_reload_events)"
  if [[ "$backend_reload_events" =~ ^[0-9]+$ ]] && (( backend_reload_events > 3 )); then
    echo "[status] Warning: recent backend reload churn detected (${backend_reload_events} reload markers). Consider TRR_BACKEND_RELOAD=0 for stream stability."
  fi
fi

if [[ "$CODEX_APP_SERVER_COUNT" =~ ^[0-9]+$ ]] && (( CODEX_APP_SERVER_COUNT > 1 )); then
  echo "[status] Warning: multiple Codex app-server owners are sharing the same runtime. Prefer one active Desktop/VS Code owner at a time."
fi

exit 0

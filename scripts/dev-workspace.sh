#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Optional profile defaults.
# Usage: PROFILE=default make dev
PROFILE="${PROFILE:-}"
if [[ -n "$PROFILE" ]]; then
  PROFILE_FILE="$ROOT/profiles/${PROFILE}.env"
  if [[ ! -f "$PROFILE_FILE" ]]; then
    echo "[workspace] ERROR: profile file not found: ${PROFILE_FILE}" >&2
    exit 1
  fi

  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    line="${raw_line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue

    if [[ ! "$line" =~ ^[A-Z][A-Z0-9_]*= ]]; then
      echo "[workspace] ERROR: invalid profile entry in ${PROFILE_FILE}: ${raw_line}" >&2
      exit 1
    fi

    key="${line%%=*}"
    value="${line#*=}"
    if [[ -z "${!key+x}" ]]; then
      # Trusted local profile file; preserve explicitly provided environment values.
      eval "export ${key}=${value}"
    fi
  done < "$PROFILE_FILE"

  echo "[workspace] Loaded profile defaults from ${PROFILE_FILE} (explicit env vars preserved)."
  case "$PROFILE" in
    local-cloud)
      echo "[workspace] NOTE: PROFILE=local-cloud is deprecated; use make dev (or PROFILE=default make dev)." >&2
      ;;
    local-full)
      echo "[workspace] NOTE: PROFILE=local-full is deprecated; use make dev-local (or PROFILE=local-docker make dev-local)." >&2
      ;;
  esac
fi

LOG_DIR="${ROOT}/.logs/workspace"
PIDFILE="${LOG_DIR}/pids.env"
WORKSPACE_MANAGER_PID="$$"
mkdir -p "$LOG_DIR"

# Clean stale Chrome/MCP processes from prior sessions.
if [[ -x "$ROOT/scripts/codex-mcp-session-reaper.sh" ]]; then
  bash "$ROOT/scripts/codex-mcp-session-reaper.sh" reap 2>/dev/null || true
fi

# Workspace toggles
WORKSPACE_SCREENALYTICS="${WORKSPACE_SCREENALYTICS:-1}"
WORKSPACE_SCREENALYTICS_SKIP_DOCKER="${WORKSPACE_SCREENALYTICS_SKIP_DOCKER:-1}"
WORKSPACE_DEV_MODE="${WORKSPACE_DEV_MODE:-}"
WORKSPACE_STRICT="${WORKSPACE_STRICT:-0}"
WORKSPACE_FORCE_KILL_PORT_CONFLICTS="${WORKSPACE_FORCE_KILL_PORT_CONFLICTS:-0}"
WORKSPACE_CLEAN_NEXT_CACHE="${WORKSPACE_CLEAN_NEXT_CACHE:-0}"
WORKSPACE_TRR_APP_DEV_BUNDLER="${WORKSPACE_TRR_APP_DEV_BUNDLER:-turbopack}"
WORKSPACE_OPEN_BROWSER="${WORKSPACE_OPEN_BROWSER:-0}"
WORKSPACE_BROWSER_TAB_SYNC_MODE="${WORKSPACE_BROWSER_TAB_SYNC_MODE:-reuse_no_reload}"
WORKSPACE_OPEN_SCREENALYTICS_TABS="${WORKSPACE_OPEN_SCREENALYTICS_TABS:-0}"
WORKSPACE_HEALTH_CURL_MAX_TIME="${WORKSPACE_HEALTH_CURL_MAX_TIME:-2}"
WORKSPACE_HEALTH_TIMEOUT_BACKEND="${WORKSPACE_HEALTH_TIMEOUT_BACKEND:-30}"
WORKSPACE_HEALTH_TIMEOUT_APP="${WORKSPACE_HEALTH_TIMEOUT_APP:-60}"
WORKSPACE_HEALTH_TIMEOUT_SCREENALYTICS_API="${WORKSPACE_HEALTH_TIMEOUT_SCREENALYTICS_API:-30}"
WORKSPACE_HEALTH_TIMEOUT_SCREENALYTICS_STREAMLIT="${WORKSPACE_HEALTH_TIMEOUT_SCREENALYTICS_STREAMLIT:-90}"
WORKSPACE_HEALTH_TIMEOUT_SCREENALYTICS_WEB="${WORKSPACE_HEALTH_TIMEOUT_SCREENALYTICS_WEB:-90}"
WORKSPACE_BACKEND_AUTO_RESTART="${WORKSPACE_BACKEND_AUTO_RESTART:-0}"
WORKSPACE_BACKEND_HEALTH_INTERVAL_SECONDS="${WORKSPACE_BACKEND_HEALTH_INTERVAL_SECONDS:-5}"
WORKSPACE_BACKEND_HEALTH_FAILURE_THRESHOLD="${WORKSPACE_BACKEND_HEALTH_FAILURE_THRESHOLD:-6}"
WORKSPACE_BACKEND_HEALTH_CURL_MAX_TIME="${WORKSPACE_BACKEND_HEALTH_CURL_MAX_TIME:-5}"
WORKSPACE_BACKEND_HEALTH_GRACE_SECONDS="${WORKSPACE_BACKEND_HEALTH_GRACE_SECONDS:-90}"
WORKSPACE_BACKEND_HEALTH_BUSY_TIMEOUT_IGNORE="${WORKSPACE_BACKEND_HEALTH_BUSY_TIMEOUT_IGNORE:-1}"
WORKSPACE_BACKEND_HEALTH_BUSY_TIMEOUT_STREAK="${WORKSPACE_BACKEND_HEALTH_BUSY_TIMEOUT_STREAK:-6}"
WORKSPACE_SOCIAL_WORKER_ENABLED="${WORKSPACE_SOCIAL_WORKER_ENABLED:-0}"
WORKSPACE_SOCIAL_WORKER_FORCE_LOCAL="${WORKSPACE_SOCIAL_WORKER_FORCE_LOCAL:-0}"
WORKSPACE_SOCIAL_WORKER_POSTS="${WORKSPACE_SOCIAL_WORKER_POSTS:-1}"
WORKSPACE_SOCIAL_WORKER_COMMENTS="${WORKSPACE_SOCIAL_WORKER_COMMENTS:-1}"
WORKSPACE_SOCIAL_WORKER_MEDIA_MIRROR="${WORKSPACE_SOCIAL_WORKER_MEDIA_MIRROR:-0}"
WORKSPACE_SOCIAL_WORKER_COMMENT_MEDIA_MIRROR="${WORKSPACE_SOCIAL_WORKER_COMMENT_MEDIA_MIRROR:-0}"
WORKSPACE_SOCIAL_WORKER_INTERVAL_SEC="${WORKSPACE_SOCIAL_WORKER_INTERVAL_SEC:-3}"
WORKSPACE_TRR_JOB_PLANE_MODE="${WORKSPACE_TRR_JOB_PLANE_MODE:-remote}"
WORKSPACE_TRR_LONG_JOB_ENFORCE_REMOTE="${WORKSPACE_TRR_LONG_JOB_ENFORCE_REMOTE:-1}"
WORKSPACE_TRR_REMOTE_EXECUTOR="${WORKSPACE_TRR_REMOTE_EXECUTOR:-modal}"
WORKSPACE_TRR_MODAL_ENABLED="${WORKSPACE_TRR_MODAL_ENABLED:-1}"
WORKSPACE_TRR_MODAL_APP_NAME="${WORKSPACE_TRR_MODAL_APP_NAME:-trr-backend-jobs}"
WORKSPACE_TRR_MODAL_ADMIN_OPERATION_FUNCTION="${WORKSPACE_TRR_MODAL_ADMIN_OPERATION_FUNCTION:-run_admin_operation_v2}"
WORKSPACE_TRR_MODAL_GOOGLE_NEWS_FUNCTION="${WORKSPACE_TRR_MODAL_GOOGLE_NEWS_FUNCTION:-run_google_news_sync}"
WORKSPACE_TRR_MODAL_REDDIT_REFRESH_FUNCTION="${WORKSPACE_TRR_MODAL_REDDIT_REFRESH_FUNCTION:-run_reddit_refresh}"
WORKSPACE_TRR_MODAL_SOCIAL_JOB_FUNCTION="${WORKSPACE_TRR_MODAL_SOCIAL_JOB_FUNCTION:-run_social_job}"
WORKSPACE_TRR_MODAL_SOCIAL_RECOVERY_FUNCTION="${WORKSPACE_TRR_MODAL_SOCIAL_RECOVERY_FUNCTION:-sweep_social_dispatch_queue}"
WORKSPACE_TRR_MODAL_RUNTIME_SECRET_NAME="${WORKSPACE_TRR_MODAL_RUNTIME_SECRET_NAME:-trr-backend-runtime}"
WORKSPACE_TRR_MODAL_SOCIAL_SECRET_NAME="${WORKSPACE_TRR_MODAL_SOCIAL_SECRET_NAME:-trr-social-auth}"
WORKSPACE_TRR_REMOTE_WORKERS_ENABLED="${WORKSPACE_TRR_REMOTE_WORKERS_ENABLED:-0}"
WORKSPACE_TRR_REMOTE_ADMIN_WORKERS="${WORKSPACE_TRR_REMOTE_ADMIN_WORKERS:-1}"
WORKSPACE_TRR_REMOTE_REDDIT_WORKERS="${WORKSPACE_TRR_REMOTE_REDDIT_WORKERS:-1}"
WORKSPACE_TRR_REMOTE_GOOGLE_NEWS_WORKERS="${WORKSPACE_TRR_REMOTE_GOOGLE_NEWS_WORKERS:-1}"
WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS="${WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS:-0}"
WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT="${WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT:-25}"
WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT="${WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT:-64}"
WORKSPACE_TRR_REMOTE_SOCIAL_POSTS="${WORKSPACE_TRR_REMOTE_SOCIAL_POSTS:-2}"
WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS="${WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS:-2}"
WORKSPACE_TRR_REMOTE_SOCIAL_MEDIA_MIRROR="${WORKSPACE_TRR_REMOTE_SOCIAL_MEDIA_MIRROR:-1}"
WORKSPACE_TRR_REMOTE_SOCIAL_COMMENT_MEDIA_MIRROR="${WORKSPACE_TRR_REMOTE_SOCIAL_COMMENT_MEDIA_MIRROR:-1}"
WORKSPACE_TRR_REMOTE_WORKER_POLL_SECONDS="${WORKSPACE_TRR_REMOTE_WORKER_POLL_SECONDS:-2}"
WORKSPACE_TRR_REMOTE_GOOGLE_NEWS_LEASE_SECONDS="${WORKSPACE_TRR_REMOTE_GOOGLE_NEWS_LEASE_SECONDS:-300}"
TRR_BACKEND_RELOAD="${TRR_BACKEND_RELOAD:-1}"
TRR_BACKEND_WORKERS="${TRR_BACKEND_WORKERS:-1}"
TRR_BACKEND_REQUIRE_REDIS_FOR_MULTI_WORKER="${TRR_BACKEND_REQUIRE_REDIS_FOR_MULTI_WORKER:-0}"
TRR_SOCIAL_PROXY_SHORT_TIMEOUT_MS="${TRR_SOCIAL_PROXY_SHORT_TIMEOUT_MS:-25000}"
TRR_SOCIAL_PROXY_DEFAULT_TIMEOUT_MS="${TRR_SOCIAL_PROXY_DEFAULT_TIMEOUT_MS:-45000}"
TRR_REDDIT_CACHE_LOOKUP_TIMEOUT_MS="${TRR_REDDIT_CACHE_LOOKUP_TIMEOUT_MS:-20000}"
TRR_REDDIT_CACHE_LOOKUP_RETRIES="${TRR_REDDIT_CACHE_LOOKUP_RETRIES:-1}"

if [[ -z "$WORKSPACE_DEV_MODE" ]]; then
  if [[ "$WORKSPACE_SCREENALYTICS_SKIP_DOCKER" == "1" ]]; then
    WORKSPACE_DEV_MODE="cloud"
  else
    WORKSPACE_DEV_MODE="local_docker"
  fi
fi

if [[ "$WORKSPACE_DEV_MODE" != "cloud" && "$WORKSPACE_DEV_MODE" != "local_docker" ]]; then
  echo "[workspace] ERROR: invalid WORKSPACE_DEV_MODE='${WORKSPACE_DEV_MODE}' (expected cloud or local_docker)." >&2
  exit 1
fi

if [[ "$WORKSPACE_DEV_MODE" == "cloud" ]]; then
  WORKSPACE_SCREENALYTICS_SKIP_DOCKER="1"
elif [[ "$WORKSPACE_DEV_MODE" == "local_docker" ]]; then
  WORKSPACE_SCREENALYTICS_SKIP_DOCKER="0"
fi

workspace_screenalytics_mode_label() {
  if [[ "$WORKSPACE_SCREENALYTICS" != "1" ]]; then
    echo "disabled"
    return 0
  fi
  if [[ "$WORKSPACE_DEV_MODE" == "local_docker" ]]; then
    echo "local Docker (Redis + MinIO)"
    return 0
  fi
  echo "cloud-backed (no Docker)"
}

if ! [[ "$WORKSPACE_BACKEND_AUTO_RESTART" =~ ^[01]$ ]]; then
  echo "[workspace] WARNING: invalid WORKSPACE_BACKEND_AUTO_RESTART='${WORKSPACE_BACKEND_AUTO_RESTART}', using 1." >&2
  WORKSPACE_BACKEND_AUTO_RESTART="1"
fi
if ! [[ "$WORKSPACE_BACKEND_HEALTH_INTERVAL_SECONDS" =~ ^[1-9][0-9]*$ ]]; then
  echo "[workspace] WARNING: invalid WORKSPACE_BACKEND_HEALTH_INTERVAL_SECONDS='${WORKSPACE_BACKEND_HEALTH_INTERVAL_SECONDS}', using 5." >&2
  WORKSPACE_BACKEND_HEALTH_INTERVAL_SECONDS="5"
fi
if ! [[ "$WORKSPACE_BACKEND_HEALTH_FAILURE_THRESHOLD" =~ ^[1-9][0-9]*$ ]]; then
  echo "[workspace] WARNING: invalid WORKSPACE_BACKEND_HEALTH_FAILURE_THRESHOLD='${WORKSPACE_BACKEND_HEALTH_FAILURE_THRESHOLD}', using 6." >&2
  WORKSPACE_BACKEND_HEALTH_FAILURE_THRESHOLD="6"
fi
if ! [[ "$WORKSPACE_BACKEND_HEALTH_CURL_MAX_TIME" =~ ^[1-9][0-9]*$ ]]; then
  echo "[workspace] WARNING: invalid WORKSPACE_BACKEND_HEALTH_CURL_MAX_TIME='${WORKSPACE_BACKEND_HEALTH_CURL_MAX_TIME}', using 30." >&2
  WORKSPACE_BACKEND_HEALTH_CURL_MAX_TIME="30"
fi
if ! [[ "$WORKSPACE_BACKEND_HEALTH_BUSY_TIMEOUT_IGNORE" =~ ^[01]$ ]]; then
  echo "[workspace] WARNING: invalid WORKSPACE_BACKEND_HEALTH_BUSY_TIMEOUT_IGNORE='${WORKSPACE_BACKEND_HEALTH_BUSY_TIMEOUT_IGNORE}', using 1." >&2
  WORKSPACE_BACKEND_HEALTH_BUSY_TIMEOUT_IGNORE="1"
fi
if ! [[ "$WORKSPACE_BACKEND_HEALTH_BUSY_TIMEOUT_STREAK" =~ ^[1-9][0-9]*$ ]]; then
  echo "[workspace] WARNING: invalid WORKSPACE_BACKEND_HEALTH_BUSY_TIMEOUT_STREAK='${WORKSPACE_BACKEND_HEALTH_BUSY_TIMEOUT_STREAK}', using 6." >&2
  WORKSPACE_BACKEND_HEALTH_BUSY_TIMEOUT_STREAK="6"
fi
if ! [[ "$WORKSPACE_SOCIAL_WORKER_ENABLED" =~ ^[01]$ ]]; then
  echo "[workspace] WARNING: invalid WORKSPACE_SOCIAL_WORKER_ENABLED='${WORKSPACE_SOCIAL_WORKER_ENABLED}', using 0." >&2
  WORKSPACE_SOCIAL_WORKER_ENABLED="0"
fi
if ! [[ "$WORKSPACE_SOCIAL_WORKER_FORCE_LOCAL" =~ ^[01]$ ]]; then
  echo "[workspace] WARNING: invalid WORKSPACE_SOCIAL_WORKER_FORCE_LOCAL='${WORKSPACE_SOCIAL_WORKER_FORCE_LOCAL}', using 0." >&2
  WORKSPACE_SOCIAL_WORKER_FORCE_LOCAL="0"
fi
if ! [[ "$WORKSPACE_SOCIAL_WORKER_POSTS" =~ ^[0-9]+$ ]]; then
  echo "[workspace] WARNING: invalid WORKSPACE_SOCIAL_WORKER_POSTS='${WORKSPACE_SOCIAL_WORKER_POSTS}', using 1." >&2
  WORKSPACE_SOCIAL_WORKER_POSTS="1"
fi
if ! [[ "$WORKSPACE_SOCIAL_WORKER_COMMENTS" =~ ^[0-9]+$ ]]; then
  echo "[workspace] WARNING: invalid WORKSPACE_SOCIAL_WORKER_COMMENTS='${WORKSPACE_SOCIAL_WORKER_COMMENTS}', using 1." >&2
  WORKSPACE_SOCIAL_WORKER_COMMENTS="1"
fi
if ! [[ "$WORKSPACE_SOCIAL_WORKER_MEDIA_MIRROR" =~ ^[0-9]+$ ]]; then
  echo "[workspace] WARNING: invalid WORKSPACE_SOCIAL_WORKER_MEDIA_MIRROR='${WORKSPACE_SOCIAL_WORKER_MEDIA_MIRROR}', using 0." >&2
  WORKSPACE_SOCIAL_WORKER_MEDIA_MIRROR="0"
fi
if ! [[ "$WORKSPACE_SOCIAL_WORKER_COMMENT_MEDIA_MIRROR" =~ ^[0-9]+$ ]]; then
  echo "[workspace] WARNING: invalid WORKSPACE_SOCIAL_WORKER_COMMENT_MEDIA_MIRROR='${WORKSPACE_SOCIAL_WORKER_COMMENT_MEDIA_MIRROR}', using 0." >&2
  WORKSPACE_SOCIAL_WORKER_COMMENT_MEDIA_MIRROR="0"
fi
if ! [[ "$WORKSPACE_SOCIAL_WORKER_INTERVAL_SEC" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "[workspace] WARNING: invalid WORKSPACE_SOCIAL_WORKER_INTERVAL_SEC='${WORKSPACE_SOCIAL_WORKER_INTERVAL_SEC}', using 3." >&2
  WORKSPACE_SOCIAL_WORKER_INTERVAL_SEC="3"
fi
if [[ "$WORKSPACE_TRR_APP_DEV_BUNDLER" != "turbopack" && "$WORKSPACE_TRR_APP_DEV_BUNDLER" != "webpack" ]]; then
  echo "[workspace] WARNING: invalid WORKSPACE_TRR_APP_DEV_BUNDLER='${WORKSPACE_TRR_APP_DEV_BUNDLER}', using turbopack." >&2
  WORKSPACE_TRR_APP_DEV_BUNDLER="turbopack"
fi
if [[ "$WORKSPACE_TRR_JOB_PLANE_MODE" != "local" && "$WORKSPACE_TRR_JOB_PLANE_MODE" != "remote" ]]; then
  echo "[workspace] WARNING: invalid WORKSPACE_TRR_JOB_PLANE_MODE='${WORKSPACE_TRR_JOB_PLANE_MODE}', using remote." >&2
  WORKSPACE_TRR_JOB_PLANE_MODE="remote"
fi
if [[ "$WORKSPACE_TRR_REMOTE_EXECUTOR" != "modal" && "$WORKSPACE_TRR_REMOTE_EXECUTOR" != "legacy_worker" ]]; then
  echo "[workspace] WARNING: invalid WORKSPACE_TRR_REMOTE_EXECUTOR='${WORKSPACE_TRR_REMOTE_EXECUTOR}', using modal." >&2
  WORKSPACE_TRR_REMOTE_EXECUTOR="modal"
fi
if ! [[ "$WORKSPACE_TRR_LONG_JOB_ENFORCE_REMOTE" =~ ^[01]$ ]]; then
  echo "[workspace] WARNING: invalid WORKSPACE_TRR_LONG_JOB_ENFORCE_REMOTE='${WORKSPACE_TRR_LONG_JOB_ENFORCE_REMOTE}', using 1." >&2
  WORKSPACE_TRR_LONG_JOB_ENFORCE_REMOTE="1"
fi
if ! [[ "$WORKSPACE_TRR_MODAL_ENABLED" =~ ^[01]$ ]]; then
  echo "[workspace] WARNING: invalid WORKSPACE_TRR_MODAL_ENABLED='${WORKSPACE_TRR_MODAL_ENABLED}', using 1." >&2
  WORKSPACE_TRR_MODAL_ENABLED="1"
fi
if ! [[ "$WORKSPACE_TRR_REMOTE_WORKERS_ENABLED" =~ ^[01]$ ]]; then
  echo "[workspace] WARNING: invalid WORKSPACE_TRR_REMOTE_WORKERS_ENABLED='${WORKSPACE_TRR_REMOTE_WORKERS_ENABLED}', using 0." >&2
  WORKSPACE_TRR_REMOTE_WORKERS_ENABLED="0"
fi
if ! [[ "$WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS" =~ ^[01]$ ]]; then
  echo "[workspace] WARNING: invalid WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS='${WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS}', using 0." >&2
  WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS="0"
fi
if ! [[ "$WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT" =~ ^[1-9][0-9]*$ ]]; then
  echo "[workspace] WARNING: invalid WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT='${WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT}', using 25." >&2
  WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT="25"
fi
if ! [[ "$WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT" =~ ^[1-9][0-9]*$ ]]; then
  echo "[workspace] WARNING: invalid WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT='${WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT}', using 64." >&2
  WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT="64"
fi
if [[ "$WORKSPACE_TRR_JOB_PLANE_MODE" == "remote" && "$WORKSPACE_SOCIAL_WORKER_ENABLED" == "1" && "$WORKSPACE_SOCIAL_WORKER_FORCE_LOCAL" != "1" ]]; then
  echo "[workspace] Remote job plane selected; disabling local social worker pool. Set WORKSPACE_SOCIAL_WORKER_FORCE_LOCAL=1 to override." >&2
  WORKSPACE_SOCIAL_WORKER_ENABLED="0"
fi
if ! [[ "$WORKSPACE_TRR_REMOTE_ADMIN_WORKERS" =~ ^[1-9][0-9]*$ ]]; then
  echo "[workspace] WARNING: invalid WORKSPACE_TRR_REMOTE_ADMIN_WORKERS='${WORKSPACE_TRR_REMOTE_ADMIN_WORKERS}', using 1." >&2
  WORKSPACE_TRR_REMOTE_ADMIN_WORKERS="1"
fi
if ! [[ "$WORKSPACE_TRR_REMOTE_REDDIT_WORKERS" =~ ^[1-9][0-9]*$ ]]; then
  echo "[workspace] WARNING: invalid WORKSPACE_TRR_REMOTE_REDDIT_WORKERS='${WORKSPACE_TRR_REMOTE_REDDIT_WORKERS}', using 1." >&2
  WORKSPACE_TRR_REMOTE_REDDIT_WORKERS="1"
fi
if ! [[ "$WORKSPACE_TRR_REMOTE_GOOGLE_NEWS_WORKERS" =~ ^[1-9][0-9]*$ ]]; then
  echo "[workspace] WARNING: invalid WORKSPACE_TRR_REMOTE_GOOGLE_NEWS_WORKERS='${WORKSPACE_TRR_REMOTE_GOOGLE_NEWS_WORKERS}', using 1." >&2
  WORKSPACE_TRR_REMOTE_GOOGLE_NEWS_WORKERS="1"
fi
if ! [[ "$WORKSPACE_TRR_REMOTE_SOCIAL_POSTS" =~ ^[0-9]+$ ]]; then
  echo "[workspace] WARNING: invalid WORKSPACE_TRR_REMOTE_SOCIAL_POSTS='${WORKSPACE_TRR_REMOTE_SOCIAL_POSTS}', using 2." >&2
  WORKSPACE_TRR_REMOTE_SOCIAL_POSTS="2"
fi
if ! [[ "$WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS" =~ ^[0-9]+$ ]]; then
  echo "[workspace] WARNING: invalid WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS='${WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS}', using 2." >&2
  WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS="2"
fi
if ! [[ "$WORKSPACE_TRR_REMOTE_SOCIAL_MEDIA_MIRROR" =~ ^[0-9]+$ ]]; then
  echo "[workspace] WARNING: invalid WORKSPACE_TRR_REMOTE_SOCIAL_MEDIA_MIRROR='${WORKSPACE_TRR_REMOTE_SOCIAL_MEDIA_MIRROR}', using 1." >&2
  WORKSPACE_TRR_REMOTE_SOCIAL_MEDIA_MIRROR="1"
fi
if ! [[ "$WORKSPACE_TRR_REMOTE_SOCIAL_COMMENT_MEDIA_MIRROR" =~ ^[0-9]+$ ]]; then
  echo "[workspace] WARNING: invalid WORKSPACE_TRR_REMOTE_SOCIAL_COMMENT_MEDIA_MIRROR='${WORKSPACE_TRR_REMOTE_SOCIAL_COMMENT_MEDIA_MIRROR}', using 1." >&2
  WORKSPACE_TRR_REMOTE_SOCIAL_COMMENT_MEDIA_MIRROR="1"
fi
if ! [[ "$WORKSPACE_TRR_REMOTE_WORKER_POLL_SECONDS" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "[workspace] WARNING: invalid WORKSPACE_TRR_REMOTE_WORKER_POLL_SECONDS='${WORKSPACE_TRR_REMOTE_WORKER_POLL_SECONDS}', using 2." >&2
  WORKSPACE_TRR_REMOTE_WORKER_POLL_SECONDS="2"
fi
if ! [[ "$WORKSPACE_TRR_REMOTE_GOOGLE_NEWS_LEASE_SECONDS" =~ ^[1-9][0-9]*$ ]]; then
  echo "[workspace] WARNING: invalid WORKSPACE_TRR_REMOTE_GOOGLE_NEWS_LEASE_SECONDS='${WORKSPACE_TRR_REMOTE_GOOGLE_NEWS_LEASE_SECONDS}', using 300." >&2
  WORKSPACE_TRR_REMOTE_GOOGLE_NEWS_LEASE_SECONDS="300"
fi
if ! [[ "$WORKSPACE_BACKEND_HEALTH_GRACE_SECONDS" =~ ^[0-9]+$ ]]; then
  echo "[workspace] WARNING: invalid WORKSPACE_BACKEND_HEALTH_GRACE_SECONDS='${WORKSPACE_BACKEND_HEALTH_GRACE_SECONDS}', using 90." >&2
  WORKSPACE_BACKEND_HEALTH_GRACE_SECONDS="90"
fi
if ! [[ "$TRR_BACKEND_WORKERS" =~ ^[1-9][0-9]*$ ]]; then
  echo "[workspace] WARNING: invalid TRR_BACKEND_WORKERS='${TRR_BACKEND_WORKERS}', using 1." >&2
  TRR_BACKEND_WORKERS="1"
fi
if ! [[ "$TRR_BACKEND_REQUIRE_REDIS_FOR_MULTI_WORKER" =~ ^[01]$ ]]; then
  echo "[workspace] WARNING: invalid TRR_BACKEND_REQUIRE_REDIS_FOR_MULTI_WORKER='${TRR_BACKEND_REQUIRE_REDIS_FOR_MULTI_WORKER}', using 0." >&2
  TRR_BACKEND_REQUIRE_REDIS_FOR_MULTI_WORKER="0"
fi
if ! [[ "$TRR_BACKEND_RELOAD" =~ ^[01]$ ]]; then
  echo "[workspace] WARNING: invalid TRR_BACKEND_RELOAD='${TRR_BACKEND_RELOAD}', using 1." >&2
  TRR_BACKEND_RELOAD="1"
fi
if ! [[ "$TRR_SOCIAL_PROXY_SHORT_TIMEOUT_MS" =~ ^[1-9][0-9]*$ ]]; then
  echo "[workspace] WARNING: invalid TRR_SOCIAL_PROXY_SHORT_TIMEOUT_MS='${TRR_SOCIAL_PROXY_SHORT_TIMEOUT_MS}', using 25000." >&2
  TRR_SOCIAL_PROXY_SHORT_TIMEOUT_MS="25000"
fi
if ! [[ "$TRR_SOCIAL_PROXY_DEFAULT_TIMEOUT_MS" =~ ^[1-9][0-9]*$ ]]; then
  echo "[workspace] WARNING: invalid TRR_SOCIAL_PROXY_DEFAULT_TIMEOUT_MS='${TRR_SOCIAL_PROXY_DEFAULT_TIMEOUT_MS}', using 45000." >&2
  TRR_SOCIAL_PROXY_DEFAULT_TIMEOUT_MS="45000"
fi
if ! [[ "$TRR_REDDIT_CACHE_LOOKUP_TIMEOUT_MS" =~ ^[1-9][0-9]*$ ]]; then
  echo "[workspace] WARNING: invalid TRR_REDDIT_CACHE_LOOKUP_TIMEOUT_MS='${TRR_REDDIT_CACHE_LOOKUP_TIMEOUT_MS}', using 20000." >&2
  TRR_REDDIT_CACHE_LOOKUP_TIMEOUT_MS="20000"
fi
if ! [[ "$TRR_REDDIT_CACHE_LOOKUP_RETRIES" =~ ^[0-9]+$ ]]; then
  echo "[workspace] WARNING: invalid TRR_REDDIT_CACHE_LOOKUP_RETRIES='${TRR_REDDIT_CACHE_LOOKUP_RETRIES}', using 1." >&2
  TRR_REDDIT_CACHE_LOOKUP_RETRIES="1"
fi

# screenalytics dev_auto defaults (may be overridden via env when invoking this script).
SCREENALYTICS_DEV_AUTO_ALLOW_DB_ERROR_DEFAULT="0"
if [[ "$WORKSPACE_STRICT" != "1" ]]; then
  SCREENALYTICS_DEV_AUTO_ALLOW_DB_ERROR_DEFAULT="1"
fi
SCREENALYTICS_DEV_AUTO_ALLOW_DB_ERROR="${DEV_AUTO_ALLOW_DB_ERROR:-$SCREENALYTICS_DEV_AUTO_ALLOW_DB_ERROR_DEFAULT}"

# Avoid relying on `#!/usr/bin/env bash` (or the `env` command) in sub-scripts.
# If PATH contains a slow/unavailable entry, `/usr/bin/env` can hang while
# searching for `bash`, leaving services "started" but with no listeners.
BASH_BIN="/bin/bash"

# If an old pidfile exists, stop those services first (safe: only kills recorded PIDs).
if [[ -f "$PIDFILE" ]]; then
  echo "[workspace] Previous workspace session found. Stopping it first..."
  bash "${ROOT}/scripts/stop-workspace.sh" || true
fi

TRR_BACKEND_PORT="${TRR_BACKEND_PORT:-8000}"
TRR_APP_PORT="${TRR_APP_PORT:-3000}"
TRR_APP_HOST="${TRR_APP_HOST:-127.0.0.1}"
ADMIN_APP_ORIGIN="${ADMIN_APP_ORIGIN:-http://admin.localhost:3000}"
ADMIN_APP_HOSTS="${ADMIN_APP_HOSTS:-admin.localhost,localhost,127.0.0.1,[::1]}"
ADMIN_ENFORCE_HOST="${ADMIN_ENFORCE_HOST:-true}"
ADMIN_STRICT_HOST_ROUTING="${ADMIN_STRICT_HOST_ROUTING:-false}"

# Default to :8001 to avoid clashing with TRR-Backend (:8000).
SCREENALYTICS_API_PORT="${SCREENALYTICS_API_PORT:-8001}"
SCREENALYTICS_STREAMLIT_PORT="${SCREENALYTICS_STREAMLIT_PORT:-8501}"
SCREENALYTICS_WEB_PORT="${SCREENALYTICS_WEB_PORT:-8080}"

TRR_API_URL="${TRR_API_URL:-http://127.0.0.1:${TRR_BACKEND_PORT}}"
BACKEND_HEALTH_URL="${BACKEND_HEALTH_URL:-${TRR_API_URL}/health}"
SCREENALYTICS_LOCAL_API_URL="http://127.0.0.1:${SCREENALYTICS_API_PORT}"
SCREENALYTICS_API_URL="${SCREENALYTICS_API_URL:-$SCREENALYTICS_LOCAL_API_URL}"
SCREENALYTICS_LOCAL_HEALTH_URL="${SCREENALYTICS_LOCAL_API_URL}/healthz"

TRR_BACKEND_LOG="${LOG_DIR}/trr-backend.log"
TRR_APP_LOG="${LOG_DIR}/trr-app.log"
SCREENALYTICS_LOG="${LOG_DIR}/screenalytics.log"
SOCIAL_WORKER_LOG="${LOG_DIR}/social-worker.log"
REMOTE_WORKER_LOG="${LOG_DIR}/remote-workers.log"
BACKEND_WATCHDOG_STATE_FILE="${LOG_DIR}/backend-watchdog.env"
BACKEND_WATCHDOG_EVENTS_FILE="${LOG_DIR}/backend-watchdog-events.jsonl"

# Preserve prior run logs for troubleshooting.
RUN_TS="$(date +%Y%m%d-%H%M%S)"
ARCHIVE_DIR="${LOG_DIR}/archive/${RUN_TS}"
rotated_any=0
for log in "$TRR_BACKEND_LOG" "$TRR_APP_LOG" "$SCREENALYTICS_LOG" "$SOCIAL_WORKER_LOG" "$REMOTE_WORKER_LOG"; do
  if [[ -f "$log" && -s "$log" ]]; then
    rotated_any=1
    break
  fi
done
if [[ "$rotated_any" -eq 1 ]]; then
  mkdir -p "$ARCHIVE_DIR"
  for log in "$TRR_BACKEND_LOG" "$TRR_APP_LOG" "$SCREENALYTICS_LOG" "$SOCIAL_WORKER_LOG" "$REMOTE_WORKER_LOG"; do
    if [[ -f "$log" ]]; then
      mv "$log" "$ARCHIVE_DIR/$(basename "$log")"
    fi
  done
  echo "[workspace] Archived previous logs to ${ARCHIVE_DIR}"
fi

: > "$TRR_BACKEND_LOG"
: > "$TRR_APP_LOG"
: > "$SCREENALYTICS_LOG"
: > "$SOCIAL_WORKER_LOG"
: > "$REMOTE_WORKER_LOG"

HAVE_LSOF=0
if command -v lsof >/dev/null 2>&1; then
  HAVE_LSOF=1
fi

USE_SETSID=0
if command -v setsid >/dev/null 2>&1; then
  USE_SETSID=1
fi

PY_SETSID=""
if [[ "$USE_SETSID" -eq 0 ]]; then
  if command -v python3.11 >/dev/null 2>&1; then
    PY_SETSID="$(command -v python3.11)"
  elif command -v python3 >/dev/null 2>&1; then
    PY_SETSID="$(command -v python3)"
  elif command -v python >/dev/null 2>&1; then
    PY_SETSID="$(command -v python)"
  fi
fi

port_listeners() {
  local port="$1"
  if [[ "$HAVE_LSOF" -ne 1 ]]; then
    echo ""
    return 0
  fi
  (lsof -nP -iTCP:"$port" -sTCP:LISTEN -t 2>/dev/null || true) | sort -u | tr '\n' ' '
}

backend_has_active_connections() {
  if [[ "$HAVE_LSOF" -ne 1 ]]; then
    return 1
  fi
  lsof -nP -iTCP:"$TRR_BACKEND_PORT" -sTCP:ESTABLISHED -t 2>/dev/null | grep -q .
}

backend_health_probe() {
  local timeout="$1"
  curl -fsS --max-time "$timeout" "$BACKEND_HEALTH_URL" >/dev/null 2>&1
}

backend_busy_confirm_timeout() {
  local base_timeout="${WORKSPACE_BACKEND_HEALTH_CURL_MAX_TIME:-5}"
  local derived_timeout=$(( base_timeout * 3 ))
  if (( derived_timeout < 15 )); then
    derived_timeout=15
  fi
  echo "$derived_timeout"
}

pid_ppid() {
  local pid="$1"
  ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ' || true
}

pid_cmd() {
  local pid="$1"
  ps -o command= -p "$pid" 2>/dev/null | sed 's/^ *//' || true
}

pid_cwd() {
  local pid="$1"
  if [[ "$HAVE_LSOF" -ne 1 ]]; then
    echo ""
    return 0
  fi
  lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | head -n 1 || true
}

is_safe_stale() {
  local pid="$1"
  local port="$2"

  local ppid cwd cmd
  ppid="$(pid_ppid "$pid")"
  if [[ "$ppid" == "1" ]]; then
    return 0
  fi

  cwd="$(pid_cwd "$pid")"
  if [[ -n "$cwd" && "$cwd" == "$ROOT"* ]]; then
    return 0
  fi

  cmd="$(pid_cmd "$pid")"
  if [[ -n "$cmd" && "$cmd" == *"$ROOT"* ]]; then
    return 0
  fi

  # Port-specific allowlist (kept narrow; do not auto-kill generic :3000 "next dev" processes).
  if [[ "$port" == "$TRR_BACKEND_PORT" ]]; then
    [[ "$cmd" == *"uvicorn"* && "$cmd" == *"api.main:app"* ]] && return 0
  fi
  if [[ "$port" == "$SCREENALYTICS_API_PORT" ]]; then
    [[ "$cmd" == *"uvicorn"* && "$cmd" == *"apps.api.main:app"* ]] && return 0
  fi

  return 1
}

kill_pids() {
  local pids="$1"
  if [[ -z "$pids" ]]; then
    return 0
  fi

  # shellcheck disable=SC2086
  kill -TERM $pids >/dev/null 2>&1 || true
  sleep 0.5

  # shellcheck disable=SC2086
  kill -KILL $pids >/dev/null 2>&1 || true
  sleep 0.2
}

ensure_port_free() {
  local port="$1"
  local label="$2"
  local required="$3" # 1 required, 0 optional

  local pids
  pids="$(port_listeners "$port")"
  if [[ -z "$pids" ]]; then
    return 0
  fi

  echo "[workspace] Port ${port} is already in use (service=${label})."

  if [[ "$WORKSPACE_FORCE_KILL_PORT_CONFLICTS" == "1" ]]; then
    echo "[workspace] WORKSPACE_FORCE_KILL_PORT_CONFLICTS=1; killing listeners: ${pids}"
    kill_pids "$pids"
    return 0
  fi

  local unsafe=0
  local pid cmd cwd
  for pid in $pids; do
    if ! is_safe_stale "$pid" "$port"; then
      unsafe=1
      cmd="$(pid_cmd "$pid")"
      cwd="$(pid_cwd "$pid")"
      echo "[workspace] Refusing to kill pid=${pid} (not safe-stale)."
      echo "[workspace]   cmd: ${cmd}"
      if [[ -n "$cwd" ]]; then
        echo "[workspace]   cwd: ${cwd}"
      fi
    fi
  done

  if [[ "$unsafe" -eq 1 ]]; then
    if [[ "$required" -eq 1 ]]; then
      echo "[workspace] ERROR: required port ${port} is in use by non-stale process(es)." >&2
      echo "[workspace]   Stop it manually, or set WORKSPACE_FORCE_KILL_PORT_CONFLICTS=1 to override." >&2
      return 1
    fi
    echo "[workspace] WARNING: optional port ${port} is in use by non-stale process(es)." >&2
    return 2
  fi

  echo "[workspace] Killing safe-stale listeners on port ${port}: ${pids}"
  kill_pids "$pids"

  if [[ -n "$(port_listeners "$port")" ]]; then
    echo "[workspace] ERROR: port ${port} still appears to be in use after kill attempt." >&2
    return 1
  fi

  return 0
}

# Port preflight (required services)
if [[ "$HAVE_LSOF" -eq 1 ]]; then
  ensure_port_free "$TRR_BACKEND_PORT" "TRR-Backend" 1
  ensure_port_free "$TRR_APP_PORT" "TRR-APP" 1
else
  echo "[workspace] WARNING: lsof not available; skipping port preflight." >&2
fi

# ---------------------------------------------------------------------------
# Optional screenalytics gating (Docker is only required in local_docker mode)
# ---------------------------------------------------------------------------
if [[ "$WORKSPACE_SCREENALYTICS" == "1" ]]; then
  if [[ "$WORKSPACE_SCREENALYTICS_SKIP_DOCKER" != "1" ]]; then
    if ! command -v docker >/dev/null 2>&1; then
      if [[ "$WORKSPACE_STRICT" == "1" ]]; then
        echo "[workspace] ERROR: docker not found (required for make dev-local / local Redis + MinIO)." >&2
        exit 1
      fi
      echo "[workspace] WARNING: docker not found; disabling screenalytics for this session." >&2
      WORKSPACE_SCREENALYTICS=0
    elif ! docker info >/dev/null 2>&1; then
      echo "[workspace] Docker daemon is not running. Starting Docker..."
      if [[ "$(uname)" == "Darwin" ]]; then
        if [[ -d "/Applications/Docker.app" ]]; then
          open -a Docker
          echo "[workspace] Waiting for Docker daemon..."
          for i in $(seq 1 60); do
            if docker info >/dev/null 2>&1; then
              echo "[workspace] Docker daemon is ready."
              break
            fi
            sleep 1
            if (( i % 10 == 0 )); then
              echo "[workspace]   Still waiting... (${i}s elapsed)"
            fi
          done
        fi
      fi

      if ! docker info >/dev/null 2>&1; then
        if [[ "$WORKSPACE_STRICT" == "1" ]]; then
          echo "[workspace] ERROR: Docker daemon is not running (required for make dev-local / local Redis + MinIO)." >&2
          exit 1
        fi
        echo "[workspace] WARNING: Docker daemon not available; disabling screenalytics for this session." >&2
        WORKSPACE_SCREENALYTICS=0
      else
        echo "[workspace] Docker daemon is running."
      fi
    else
      echo "[workspace] Docker daemon is running."
    fi
  else
    echo "[workspace] screenalytics mode is cloud-backed; skipping local Docker preflight and compose startup."
  fi

  if [[ "$WORKSPACE_SCREENALYTICS" == "1" && "$HAVE_LSOF" -eq 1 ]]; then
    # Screenalytics ports are optional for workspace success. If they conflict with unknown listeners,
    # disable screenalytics unless in strict mode.
    rc=0
    ensure_port_free "$SCREENALYTICS_API_PORT" "screenalytics API" 0 || rc=$?
    if [[ "$rc" -ne 0 ]]; then
      if [[ "$WORKSPACE_STRICT" == "1" ]]; then
        echo "[workspace] ERROR: screenalytics API port conflict in strict mode." >&2
        exit 1
      fi
      echo "[workspace] WARNING: screenalytics API port not available; disabling screenalytics for this session." >&2
      WORKSPACE_SCREENALYTICS=0
    fi

    if [[ "$WORKSPACE_SCREENALYTICS" == "1" ]]; then
      rc=0
      ensure_port_free "$SCREENALYTICS_STREAMLIT_PORT" "screenalytics Streamlit" 0 || rc=$?
      if [[ "$rc" -ne 0 ]]; then
        if [[ "$WORKSPACE_STRICT" == "1" ]]; then
          echo "[workspace] ERROR: screenalytics Streamlit port conflict in strict mode." >&2
          exit 1
        fi
        echo "[workspace] WARNING: screenalytics Streamlit port not available; disabling screenalytics for this session." >&2
        WORKSPACE_SCREENALYTICS=0
      fi
    fi

    if [[ "$WORKSPACE_SCREENALYTICS" == "1" ]]; then
      rc=0
      ensure_port_free "$SCREENALYTICS_WEB_PORT" "screenalytics Web" 0 || rc=$?
      if [[ "$rc" -ne 0 ]]; then
        if [[ "$WORKSPACE_STRICT" == "1" ]]; then
          echo "[workspace] ERROR: screenalytics Web port conflict in strict mode." >&2
          exit 1
        fi
        echo "[workspace] WARNING: screenalytics Web port not available; disabling screenalytics for this session." >&2
        WORKSPACE_SCREENALYTICS=0
      fi
    fi
  fi

  if [[ "$WORKSPACE_SCREENALYTICS" == "1" && "$WORKSPACE_SCREENALYTICS_SKIP_DOCKER" != "1" ]]; then
    # Start local screenalytics infrastructure (Redis + MinIO) before services.
    echo "[workspace] Starting local Docker infrastructure (Redis + MinIO)..."
    docker compose -f "${ROOT}/screenalytics/infra/docker/compose.yaml" up -d
  fi
fi

declare -a PIDS=()
declare -a NAMES=()
LAST_STARTED_PID=""
WORKSPACE_SHUTTING_DOWN=0
BACKEND_HEALTH_FAILURES=0
BACKEND_HEALTH_BUSY_TIMEOUT_STREAK_COUNT=0
BACKEND_LAST_HEALTH_CHECK_AT=0
TRR_BACKEND_PID=""
TRR_APP_PID=""
BACKEND_RESTART_COUNT=0
BACKEND_LAST_RESTART_REASON=""
BACKEND_LAST_RESTART_AT=""
BACKEND_LAST_RESTART_PROBE_RC=""
TRR_APP_DIR="${ROOT}/TRR-APP/apps/web"
TRR_APP_NEXT_DIR="${TRR_APP_DIR}/.next"
TRR_APP_NEXT_DEV_DIR="${TRR_APP_NEXT_DIR}/dev"
TRR_APP_NEXT_DEV_LOG="${TRR_APP_NEXT_DEV_DIR}/logs/next-development.log"
TRR_APP_CACHE_RECOVERY_ATTEMPTED=0

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

process_or_group_alive() {
  local pid="$1"
  if [[ -z "${pid}" ]]; then
    return 1
  fi
  kill -0 "$pid" >/dev/null 2>&1
}

start_bg() {
  local name="$1"
  local log="$2"
  shift 2

  if [[ "$USE_SETSID" -eq 1 ]]; then
    # Start in its own process group so we can kill the whole tree reliably.
    setsid "$@" >>"$log" 2>&1 &
  elif [[ -n "$PY_SETSID" ]]; then
    # macOS default: create a new session/process group without requiring external `setsid`.
    "$PY_SETSID" -c 'import os, sys; os.setsid(); os.execvp(sys.argv[1], sys.argv[1:])' "$@" >>"$log" 2>&1 &
  else
    echo "[workspace] WARNING: cannot create new process group (no setsid/python). Stop may leave orphans." >&2
    "$@" >>"$log" 2>&1 &
  fi

  local pid=$!
  PIDS+=("$pid")
  NAMES+=("$name")
  LAST_STARTED_PID="$pid"
  echo "${name}_PID=${pid}" >>"$PIDFILE"
  echo "[workspace] ${name} started (pid=${pid})"
}

start_bg_no_setsid() {
  local name="$1"
  local log="$2"
  shift 2

  "$@" >>"$log" 2>&1 &

  local pid=$!
  PIDS+=("$pid")
  NAMES+=("$name")
  LAST_STARTED_PID="$pid"
  echo "${name}_PID=${pid}" >>"$PIDFILE"
  echo "[workspace] ${name} started (pid=${pid})"
}

write_pidfile_runtime_value() {
  local key="$1"
  local value="$2"
  echo "${key}=${value}" >>"$PIDFILE"
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

write_backend_watchdog_state() {
  cat > "$BACKEND_WATCHDOG_STATE_FILE" <<EOF
BACKEND_RESTART_COUNT=${BACKEND_RESTART_COUNT}
BACKEND_LAST_RESTART_REASON="${BACKEND_LAST_RESTART_REASON}"
BACKEND_LAST_RESTART_AT="${BACKEND_LAST_RESTART_AT}"
BACKEND_LAST_RESTART_PROBE_RC="${BACKEND_LAST_RESTART_PROBE_RC}"
EOF
}

record_backend_restart() {
  local reason="$1"
  local probe_rc="$2"
  local details="${3:-}"

  BACKEND_RESTART_COUNT=$((BACKEND_RESTART_COUNT + 1))
  BACKEND_LAST_RESTART_REASON="$reason"
  BACKEND_LAST_RESTART_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  BACKEND_LAST_RESTART_PROBE_RC="$probe_rc"

  write_backend_watchdog_state
  write_pidfile_runtime_value "WORKSPACE_BACKEND_RESTART_COUNT" "$BACKEND_RESTART_COUNT"
  write_pidfile_runtime_value "WORKSPACE_BACKEND_LAST_RESTART_REASON" "\"$BACKEND_LAST_RESTART_REASON\""
  write_pidfile_runtime_value "WORKSPACE_BACKEND_LAST_RESTART_AT" "\"$BACKEND_LAST_RESTART_AT\""
  write_pidfile_runtime_value "WORKSPACE_BACKEND_LAST_RESTART_PROBE_RC" "\"$BACKEND_LAST_RESTART_PROBE_RC\""

  printf '{"ts":"%s","reason":"%s","probe_rc":"%s","count":%s,"details":"%s"}\n' \
    "$(json_escape "$BACKEND_LAST_RESTART_AT")" \
    "$(json_escape "$BACKEND_LAST_RESTART_REASON")" \
    "$(json_escape "$BACKEND_LAST_RESTART_PROBE_RC")" \
    "$BACKEND_RESTART_COUNT" \
    "$(json_escape "$details")" \
    >> "$BACKEND_WATCHDOG_EVENTS_FILE"
}

find_service_index() {
  local target_name="$1"
  local indices=("${!NAMES[@]}")
  local i idx
  for ((i=${#indices[@]}-1; i>=0; i--)); do
    idx="${indices[$i]}"
    if [[ "${NAMES[$idx]-}" == "$target_name" ]]; then
      echo "$idx"
      return 0
    fi
  done
  return 1
}

workspace_modal_remote_active() {
  [[ "$WORKSPACE_TRR_REMOTE_WORKERS_ENABLED" == "1" && "$WORKSPACE_TRR_REMOTE_EXECUTOR" == "modal" && "$WORKSPACE_TRR_MODAL_ENABLED" == "1" ]]
}

workspace_modal_social_lane_label() {
  if workspace_modal_remote_active && [[ "$WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS" == "1" ]]; then
    echo "enabled"
    return 0
  fi
  echo "disabled"
}

workspace_modal_social_stage_caps() {
  echo "posts=${WORKSPACE_TRR_REMOTE_SOCIAL_POSTS}, comments=${WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS}, media_mirror=${WORKSPACE_TRR_REMOTE_SOCIAL_MEDIA_MIRROR}, comment_media_mirror=${WORKSPACE_TRR_REMOTE_SOCIAL_COMMENT_MEDIA_MIRROR}"
}

workspace_modal_social_tuning_summary() {
  echo "lane=$(workspace_modal_social_lane_label), dispatch_limit=${WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT}, max_concurrency=${WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT}, stage_caps=$(workspace_modal_social_stage_caps)"
}

start_trr_backend() {
  local social_dispatch_limit="$WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT"
  local social_job_concurrency_limit="$WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT"
  local social_stage_posts="$WORKSPACE_SOCIAL_WORKER_POSTS"
  local social_stage_comments="$WORKSPACE_SOCIAL_WORKER_COMMENTS"
  local social_stage_media_mirror="$WORKSPACE_SOCIAL_WORKER_MEDIA_MIRROR"
  local social_stage_comment_media_mirror="$WORKSPACE_SOCIAL_WORKER_COMMENT_MEDIA_MIRROR"

  if [[ "$WORKSPACE_TRR_REMOTE_EXECUTOR" == "modal" && "$WORKSPACE_TRR_MODAL_ENABLED" == "1" ]]; then
    social_stage_posts="$WORKSPACE_TRR_REMOTE_SOCIAL_POSTS"
    social_stage_comments="$WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS"
    social_stage_media_mirror="$WORKSPACE_TRR_REMOTE_SOCIAL_MEDIA_MIRROR"
    social_stage_comment_media_mirror="$WORKSPACE_TRR_REMOTE_SOCIAL_COMMENT_MEDIA_MIRROR"
  fi

  start_bg "TRR_BACKEND" "$TRR_BACKEND_LOG" "$BASH_BIN" -lc "cd \"$ROOT/TRR-Backend\" && \
    PYTHONUNBUFFERED=1 \
    TRR_BACKEND_PORT=\"$TRR_BACKEND_PORT\" \
    TRR_BACKEND_RELOAD=\"$TRR_BACKEND_RELOAD\" \
    TRR_BACKEND_WORKERS=\"$TRR_BACKEND_WORKERS\" \
    TRR_BACKEND_REQUIRE_REDIS_FOR_MULTI_WORKER=\"$TRR_BACKEND_REQUIRE_REDIS_FOR_MULTI_WORKER\" \
    TRR_JOB_PLANE_MODE=\"$WORKSPACE_TRR_JOB_PLANE_MODE\" \
    TRR_LONG_JOB_ENFORCE_REMOTE=\"$WORKSPACE_TRR_LONG_JOB_ENFORCE_REMOTE\" \
    TRR_REMOTE_EXECUTOR=\"$WORKSPACE_TRR_REMOTE_EXECUTOR\" \
    TRR_MODAL_ENABLED=\"$WORKSPACE_TRR_MODAL_ENABLED\" \
    TRR_MODAL_APP_NAME=\"$WORKSPACE_TRR_MODAL_APP_NAME\" \
    TRR_MODAL_ADMIN_OPERATION_FUNCTION=\"$WORKSPACE_TRR_MODAL_ADMIN_OPERATION_FUNCTION\" \
    TRR_MODAL_GOOGLE_NEWS_FUNCTION=\"$WORKSPACE_TRR_MODAL_GOOGLE_NEWS_FUNCTION\" \
    TRR_MODAL_REDDIT_REFRESH_FUNCTION=\"$WORKSPACE_TRR_MODAL_REDDIT_REFRESH_FUNCTION\" \
    TRR_MODAL_SOCIAL_JOB_FUNCTION=\"$WORKSPACE_TRR_MODAL_SOCIAL_JOB_FUNCTION\" \
    TRR_MODAL_SOCIAL_RECOVERY_FUNCTION=\"$WORKSPACE_TRR_MODAL_SOCIAL_RECOVERY_FUNCTION\" \
    TRR_MODAL_RUNTIME_SECRET_NAME=\"$WORKSPACE_TRR_MODAL_RUNTIME_SECRET_NAME\" \
    TRR_MODAL_SOCIAL_SECRET_NAME=\"$WORKSPACE_TRR_MODAL_SOCIAL_SECRET_NAME\" \
    TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT=\"$social_job_concurrency_limit\" \
    SOCIAL_QUEUE_ENABLED=true \
    SOCIAL_MODAL_DISPATCH_LIMIT=\"$social_dispatch_limit\" \
    SOCIAL_WORKER_POOL_POSTS=\"$social_stage_posts\" \
    SOCIAL_WORKER_POOL_COMMENTS=\"$social_stage_comments\" \
    SOCIAL_WORKER_POOL_MEDIA_MIRROR=\"$social_stage_media_mirror\" \
    SOCIAL_WORKER_POOL_COMMENT_MEDIA_MIRROR=\"$social_stage_comment_media_mirror\" \
    TRR_API_URL=\"$TRR_API_URL\" \
    SCREENALYTICS_API_URL=\"$SCREENALYTICS_API_URL\" \
    CORS_ALLOW_ORIGINS=\"http://127.0.0.1:${TRR_APP_PORT},http://localhost:${TRR_APP_PORT}\" \
    exec \"$BASH_BIN\" ./start-api.sh"

  TRR_BACKEND_PID="$LAST_STARTED_PID"
  BACKEND_HEALTH_FAILURES=0
  BACKEND_HEALTH_BUSY_TIMEOUT_STREAK_COUNT=0
  BACKEND_LAST_HEALTH_CHECK_AT=0
  write_pidfile_runtime_value "TRR_BACKEND_PID" "$TRR_BACKEND_PID"
}

trr_app_next_cache_has_recoverable_errors() {
  if [[ ! -f "$TRR_APP_NEXT_DEV_LOG" ]]; then
    return 1
  fi

  rg -q \
    -e "Cannot find module './vendor-chunks/" \
    -e "ENOENT: no such file or directory, open '.*/\\.next/dev/routes-manifest\\.json'" \
    -e "ENOENT: no such file or directory, open '.*/\\.next/dev/server/app-paths-manifest\\.json'" \
    "$TRR_APP_NEXT_DEV_LOG"
}

trr_app_next_cache_looks_corrupt() {
  if [[ ! -d "$TRR_APP_NEXT_DEV_DIR" ]]; then
    return 1
  fi

  if [[ ! -f "$TRR_APP_NEXT_DEV_DIR/routes-manifest.json" ]]; then
    return 0
  fi
  if [[ ! -f "$TRR_APP_NEXT_DEV_DIR/server/app-paths-manifest.json" ]]; then
    return 0
  fi

  trr_app_next_cache_has_recoverable_errors
}

clean_trr_app_next_cache() {
  local reason="$1"
  echo "[workspace] ${reason}; clearing ${TRR_APP_NEXT_DIR}."
  rm -rf "$TRR_APP_NEXT_DIR"
}

prepare_trr_app_next_cache() {
  if [[ "$WORKSPACE_CLEAN_NEXT_CACHE" == "1" ]]; then
    clean_trr_app_next_cache "WORKSPACE_CLEAN_NEXT_CACHE=1"
    return 0
  fi

  if trr_app_next_cache_looks_corrupt; then
    clean_trr_app_next_cache "Detected stale Next.js dev cache"
  fi
}

start_trr_app() {
  prepare_trr_app_next_cache

  local trr_app_dev_flag="--turbopack"
  local trr_app_fallback_command="pnpm -C TRR-APP/apps/web run dev:stable"
  if [[ "$WORKSPACE_TRR_APP_DEV_BUNDLER" == "webpack" ]]; then
    trr_app_dev_flag="--webpack"
  fi

  echo "[workspace] TRR-APP dev bundler: ${WORKSPACE_TRR_APP_DEV_BUNDLER}. If you hit Turbopack issues: ${trr_app_fallback_command}"

  # Keep TRR_APP attached to its parent shell process; with setsid wrappers,
  # Next.js can re-parent and make PID tracking flaky.
  start_bg_no_setsid "TRR_APP" "$TRR_APP_LOG" "$BASH_BIN" -c "cd \"$ROOT/TRR-APP\" && \
    if [[ -s \"${HOME}/.nvm/nvm.sh\" ]]; then \
      source \"${HOME}/.nvm/nvm.sh\"; \
      nvm use --silent >/dev/null 2>&1 || echo \"[workspace] WARNING: nvm use failed; continuing with current node.\" >&2; \
    fi && \
    cd \"$TRR_APP_DIR\" && \
    TRR_API_URL=\"$TRR_API_URL\" \
    SCREENALYTICS_API_URL=\"$SCREENALYTICS_API_URL\" \
    TRR_SOCIAL_PROXY_SHORT_TIMEOUT_MS=\"$TRR_SOCIAL_PROXY_SHORT_TIMEOUT_MS\" \
    TRR_SOCIAL_PROXY_DEFAULT_TIMEOUT_MS=\"$TRR_SOCIAL_PROXY_DEFAULT_TIMEOUT_MS\" \
    TRR_REDDIT_CACHE_LOOKUP_TIMEOUT_MS=\"$TRR_REDDIT_CACHE_LOOKUP_TIMEOUT_MS\" \
    TRR_REDDIT_CACHE_LOOKUP_RETRIES=\"$TRR_REDDIT_CACHE_LOOKUP_RETRIES\" \
    ADMIN_APP_ORIGIN=\"$ADMIN_APP_ORIGIN\" \
    ADMIN_APP_HOSTS=\"$ADMIN_APP_HOSTS\" \
    ADMIN_ENFORCE_HOST=\"$ADMIN_ENFORCE_HOST\" \
    ADMIN_STRICT_HOST_ROUTING=\"$ADMIN_STRICT_HOST_ROUTING\" \
    exec ./node_modules/.bin/next dev ${trr_app_dev_flag} -p \"$TRR_APP_PORT\" --hostname \"$TRR_APP_HOST\""

  TRR_APP_PID="$LAST_STARTED_PID"
  write_pidfile_runtime_value "TRR_APP_PID" "$TRR_APP_PID"
}

start_trr_social_worker() {
  if [[ "$WORKSPACE_SOCIAL_WORKER_ENABLED" != "1" ]]; then
    echo "[workspace] Social ingest worker disabled (WORKSPACE_SOCIAL_WORKER_ENABLED=0)."
    return 0
  fi

  if [[ "$WORKSPACE_SOCIAL_WORKER_POSTS" -eq 0 && "$WORKSPACE_SOCIAL_WORKER_COMMENTS" -eq 0 && "$WORKSPACE_SOCIAL_WORKER_MEDIA_MIRROR" -eq 0 && "$WORKSPACE_SOCIAL_WORKER_COMMENT_MEDIA_MIRROR" -eq 0 ]]; then
    echo "[workspace] Social ingest worker disabled (all worker pools are 0)."
    return 0
  fi

  start_bg "TRR_SOCIAL_WORKER" "$SOCIAL_WORKER_LOG" "$BASH_BIN" -lc "cd \"$ROOT/TRR-Backend\" && \
    if [[ ! -f .venv/bin/activate ]]; then \
      echo \"[workspace] ERROR: missing TRR-Backend .venv for social worker.\" >&2; \
      exit 1; \
    fi && \
    source .venv/bin/activate && \
    PYTHONUNBUFFERED=1 \
    SOCIAL_QUEUE_ENABLED=true \
    SOCIAL_WORKER_POOL_POSTS=\"$WORKSPACE_SOCIAL_WORKER_POSTS\" \
    SOCIAL_WORKER_POOL_COMMENTS=\"$WORKSPACE_SOCIAL_WORKER_COMMENTS\" \
    SOCIAL_WORKER_POOL_MEDIA_MIRROR=\"$WORKSPACE_SOCIAL_WORKER_MEDIA_MIRROR\" \
    SOCIAL_WORKER_POOL_COMMENT_MEDIA_MIRROR=\"$WORKSPACE_SOCIAL_WORKER_COMMENT_MEDIA_MIRROR\" \
    SOCIAL_WORKER_POOL_INTERVAL_SEC=\"$WORKSPACE_SOCIAL_WORKER_INTERVAL_SEC\" \
    exec \"$BASH_BIN\" ./scripts/socials/start_worker_pool.sh"
}

start_trr_remote_workers() {
  if [[ "$WORKSPACE_TRR_REMOTE_WORKERS_ENABLED" != "1" ]]; then
    return 0
  fi

  if [[ "$WORKSPACE_TRR_REMOTE_EXECUTOR" == "modal" && "$WORKSPACE_TRR_MODAL_ENABLED" == "1" ]]; then
    echo "[workspace] Remote job execution is Modal-owned; skipping local claim-loop workers."
    echo "[workspace] Modal dispatch covers admin=${WORKSPACE_TRR_REMOTE_ADMIN_WORKERS}, reddit=${WORKSPACE_TRR_REMOTE_REDDIT_WORKERS}, google-news=${WORKSPACE_TRR_REMOTE_GOOGLE_NEWS_WORKERS}, social_lane=$(workspace_modal_social_lane_label)."
    echo "[workspace] Modal social tuning: $(workspace_modal_social_tuning_summary)."
    return 0
  fi

  start_bg "TRR_REMOTE_WORKERS" "$REMOTE_WORKER_LOG" "$BASH_BIN" -lc "cd \"$ROOT/TRR-Backend\" && \
    if [[ ! -f .venv/bin/activate ]]; then \
      echo \"[workspace] ERROR: missing TRR-Backend .venv for remote workers.\" >&2; \
      exit 1; \
    fi && \
    source .venv/bin/activate && \
    PYTHONUNBUFFERED=1 \
    TRR_JOB_PLANE_MODE=\"$WORKSPACE_TRR_JOB_PLANE_MODE\" \
    TRR_LONG_JOB_ENFORCE_REMOTE=\"$WORKSPACE_TRR_LONG_JOB_ENFORCE_REMOTE\" \
    TRR_REMOTE_WORKER_POLL_SECONDS=\"$WORKSPACE_TRR_REMOTE_WORKER_POLL_SECONDS\" \
    TRR_ADMIN_OPERATION_WORKER_COUNT=\"$WORKSPACE_TRR_REMOTE_ADMIN_WORKERS\" \
    TRR_REDDIT_REFRESH_WORKER_COUNT=\"$WORKSPACE_TRR_REMOTE_REDDIT_WORKERS\" \
    TRR_GOOGLE_NEWS_WORKER_COUNT=\"$WORKSPACE_TRR_REMOTE_GOOGLE_NEWS_WORKERS\" \
    TRR_SOCIAL_INGEST_WORKER_ENABLED=\"$WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS\" \
    TRR_SOCIAL_INGEST_WORKER_POSTS=\"$WORKSPACE_TRR_REMOTE_SOCIAL_POSTS\" \
    TRR_SOCIAL_INGEST_WORKER_COMMENTS=\"$WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS\" \
    TRR_SOCIAL_INGEST_WORKER_MEDIA_MIRROR=\"$WORKSPACE_TRR_REMOTE_SOCIAL_MEDIA_MIRROR\" \
    TRR_SOCIAL_INGEST_WORKER_COMMENT_MEDIA_MIRROR=\"$WORKSPACE_TRR_REMOTE_SOCIAL_COMMENT_MEDIA_MIRROR\" \
    TRR_SOCIAL_INGEST_WORKER_POLL_SECONDS=\"$WORKSPACE_TRR_REMOTE_WORKER_POLL_SECONDS\" \
    TRR_GOOGLE_NEWS_WORKER_LEASE_SECONDS=\"$WORKSPACE_TRR_REMOTE_GOOGLE_NEWS_LEASE_SECONDS\" \
    exec \"$BASH_BIN\" ./scripts/start_remote_job_workers.sh"
}

stop_bg() {
  local name="$1"
  local pid="$2"

  if [[ -z "${pid}" ]]; then
    return 0
  fi
  if ! process_or_group_alive "$pid"; then
    return 0
  fi

  echo "[workspace] Stopping ${name} (pid=${pid})"

  # Prefer killing the process group (works when started via setsid).
  kill -TERM -- "-${pid}" >/dev/null 2>&1 || true
  kill_tree "$pid" "TERM"

  # Grace period.
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    if ! kill -0 "$pid" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.2
  done

  kill -KILL -- "-${pid}" >/dev/null 2>&1 || true
  kill_tree "$pid" "KILL"
}

cleanup() {
  if [[ "${CLEANUP_RAN:-0}" == "1" ]]; then
    return 0
  fi
  CLEANUP_RAN=1
  WORKSPACE_SHUTTING_DOWN=1

  echo ""
  echo "[workspace] Shutting down..."

  # Stop in reverse start order.  Use actual indices since arrays may be sparse
  # after unsetting crashed-service entries at runtime.
  local indices=("${!PIDS[@]}")
  local i
  for ((i=${#indices[@]}-1; i>=0; i--)); do
    local idx="${indices[$i]}"
    stop_bg "${NAMES[$idx]-SERVICE_$idx}" "${PIDS[$idx]-}"
  done

  rm -f "$PIDFILE" >/dev/null 2>&1 || true
  echo "[workspace] Done."
}
trap cleanup EXIT
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

touch "$BACKEND_WATCHDOG_EVENTS_FILE"
write_backend_watchdog_state

# Initialize pidfile (used by `make stop`) with config for this run.
: >"$PIDFILE"
{
  echo "WORKSPACE_MANAGER_PID=${WORKSPACE_MANAGER_PID}"
  echo "TRR_BACKEND_PORT=${TRR_BACKEND_PORT}"
  echo "TRR_APP_PORT=${TRR_APP_PORT}"
  echo "TRR_APP_HOST=${TRR_APP_HOST}"
  echo "ADMIN_APP_ORIGIN=\"${ADMIN_APP_ORIGIN}\""
  echo "ADMIN_APP_HOSTS=\"${ADMIN_APP_HOSTS}\""
  echo "ADMIN_ENFORCE_HOST=${ADMIN_ENFORCE_HOST}"
  echo "ADMIN_STRICT_HOST_ROUTING=${ADMIN_STRICT_HOST_ROUTING}"
  echo "SCREENALYTICS_API_PORT=${SCREENALYTICS_API_PORT}"
  echo "SCREENALYTICS_STREAMLIT_PORT=${SCREENALYTICS_STREAMLIT_PORT}"
  echo "SCREENALYTICS_WEB_PORT=${SCREENALYTICS_WEB_PORT}"
  echo "TRR_API_URL=\"${TRR_API_URL}\""
  echo "SCREENALYTICS_API_URL=\"${SCREENALYTICS_API_URL}\""
  echo "SCREENALYTICS_LOCAL_API_URL=\"${SCREENALYTICS_LOCAL_API_URL}\""
  echo "WORKSPACE_DEV_MODE=${WORKSPACE_DEV_MODE}"
  echo "WORKSPACE_SCREENALYTICS=${WORKSPACE_SCREENALYTICS}"
  echo "WORKSPACE_SCREENALYTICS_SKIP_DOCKER=${WORKSPACE_SCREENALYTICS_SKIP_DOCKER}"
  echo "WORKSPACE_STRICT=${WORKSPACE_STRICT}"
  echo "WORKSPACE_TRR_APP_DEV_BUNDLER=${WORKSPACE_TRR_APP_DEV_BUNDLER}"
  echo "WORKSPACE_OPEN_BROWSER=${WORKSPACE_OPEN_BROWSER}"
  echo "WORKSPACE_BROWSER_TAB_SYNC_MODE=${WORKSPACE_BROWSER_TAB_SYNC_MODE}"
  echo "WORKSPACE_OPEN_SCREENALYTICS_TABS=${WORKSPACE_OPEN_SCREENALYTICS_TABS}"
  echo "WORKSPACE_HEALTH_CURL_MAX_TIME=${WORKSPACE_HEALTH_CURL_MAX_TIME}"
  echo "WORKSPACE_HEALTH_TIMEOUT_BACKEND=${WORKSPACE_HEALTH_TIMEOUT_BACKEND}"
  echo "WORKSPACE_HEALTH_TIMEOUT_APP=${WORKSPACE_HEALTH_TIMEOUT_APP}"
  echo "WORKSPACE_HEALTH_TIMEOUT_SCREENALYTICS_API=${WORKSPACE_HEALTH_TIMEOUT_SCREENALYTICS_API}"
  echo "WORKSPACE_HEALTH_TIMEOUT_SCREENALYTICS_STREAMLIT=${WORKSPACE_HEALTH_TIMEOUT_SCREENALYTICS_STREAMLIT}"
  echo "WORKSPACE_HEALTH_TIMEOUT_SCREENALYTICS_WEB=${WORKSPACE_HEALTH_TIMEOUT_SCREENALYTICS_WEB}"
  echo "WORKSPACE_BACKEND_AUTO_RESTART=${WORKSPACE_BACKEND_AUTO_RESTART}"
  echo "WORKSPACE_BACKEND_HEALTH_INTERVAL_SECONDS=${WORKSPACE_BACKEND_HEALTH_INTERVAL_SECONDS}"
  echo "WORKSPACE_BACKEND_HEALTH_FAILURE_THRESHOLD=${WORKSPACE_BACKEND_HEALTH_FAILURE_THRESHOLD}"
  echo "WORKSPACE_BACKEND_HEALTH_CURL_MAX_TIME=${WORKSPACE_BACKEND_HEALTH_CURL_MAX_TIME}"
  echo "WORKSPACE_BACKEND_HEALTH_GRACE_SECONDS=${WORKSPACE_BACKEND_HEALTH_GRACE_SECONDS}"
  echo "WORKSPACE_BACKEND_HEALTH_BUSY_TIMEOUT_IGNORE=${WORKSPACE_BACKEND_HEALTH_BUSY_TIMEOUT_IGNORE}"
  echo "WORKSPACE_BACKEND_HEALTH_BUSY_TIMEOUT_STREAK=${WORKSPACE_BACKEND_HEALTH_BUSY_TIMEOUT_STREAK}"
  echo "WORKSPACE_SOCIAL_WORKER_ENABLED=${WORKSPACE_SOCIAL_WORKER_ENABLED}"
  echo "WORKSPACE_SOCIAL_WORKER_POSTS=${WORKSPACE_SOCIAL_WORKER_POSTS}"
  echo "WORKSPACE_SOCIAL_WORKER_COMMENTS=${WORKSPACE_SOCIAL_WORKER_COMMENTS}"
  echo "WORKSPACE_SOCIAL_WORKER_MEDIA_MIRROR=${WORKSPACE_SOCIAL_WORKER_MEDIA_MIRROR}"
  echo "WORKSPACE_SOCIAL_WORKER_COMMENT_MEDIA_MIRROR=${WORKSPACE_SOCIAL_WORKER_COMMENT_MEDIA_MIRROR}"
  echo "WORKSPACE_SOCIAL_WORKER_INTERVAL_SEC=${WORKSPACE_SOCIAL_WORKER_INTERVAL_SEC}"
  echo "WORKSPACE_TRR_JOB_PLANE_MODE=${WORKSPACE_TRR_JOB_PLANE_MODE}"
  echo "WORKSPACE_TRR_LONG_JOB_ENFORCE_REMOTE=${WORKSPACE_TRR_LONG_JOB_ENFORCE_REMOTE}"
  echo "WORKSPACE_TRR_REMOTE_EXECUTOR=${WORKSPACE_TRR_REMOTE_EXECUTOR}"
  echo "WORKSPACE_TRR_MODAL_ENABLED=${WORKSPACE_TRR_MODAL_ENABLED}"
  echo "WORKSPACE_TRR_MODAL_APP_NAME=${WORKSPACE_TRR_MODAL_APP_NAME}"
  echo "WORKSPACE_TRR_MODAL_ADMIN_OPERATION_FUNCTION=${WORKSPACE_TRR_MODAL_ADMIN_OPERATION_FUNCTION}"
  echo "WORKSPACE_TRR_MODAL_GOOGLE_NEWS_FUNCTION=${WORKSPACE_TRR_MODAL_GOOGLE_NEWS_FUNCTION}"
  echo "WORKSPACE_TRR_MODAL_REDDIT_REFRESH_FUNCTION=${WORKSPACE_TRR_MODAL_REDDIT_REFRESH_FUNCTION}"
  echo "WORKSPACE_TRR_MODAL_SOCIAL_JOB_FUNCTION=${WORKSPACE_TRR_MODAL_SOCIAL_JOB_FUNCTION}"
  echo "WORKSPACE_TRR_MODAL_SOCIAL_RECOVERY_FUNCTION=${WORKSPACE_TRR_MODAL_SOCIAL_RECOVERY_FUNCTION}"
  echo "WORKSPACE_TRR_MODAL_RUNTIME_SECRET_NAME=${WORKSPACE_TRR_MODAL_RUNTIME_SECRET_NAME}"
  echo "WORKSPACE_TRR_MODAL_SOCIAL_SECRET_NAME=${WORKSPACE_TRR_MODAL_SOCIAL_SECRET_NAME}"
  echo "WORKSPACE_TRR_REMOTE_WORKERS_ENABLED=${WORKSPACE_TRR_REMOTE_WORKERS_ENABLED}"
  echo "WORKSPACE_TRR_REMOTE_ADMIN_WORKERS=${WORKSPACE_TRR_REMOTE_ADMIN_WORKERS}"
  echo "WORKSPACE_TRR_REMOTE_REDDIT_WORKERS=${WORKSPACE_TRR_REMOTE_REDDIT_WORKERS}"
  echo "WORKSPACE_TRR_REMOTE_GOOGLE_NEWS_WORKERS=${WORKSPACE_TRR_REMOTE_GOOGLE_NEWS_WORKERS}"
  echo "WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS=${WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS}"
  echo "WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT=${WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT}"
  echo "WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT=${WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT}"
  echo "WORKSPACE_TRR_REMOTE_SOCIAL_POSTS=${WORKSPACE_TRR_REMOTE_SOCIAL_POSTS}"
  echo "WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS=${WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS}"
  echo "WORKSPACE_TRR_REMOTE_SOCIAL_MEDIA_MIRROR=${WORKSPACE_TRR_REMOTE_SOCIAL_MEDIA_MIRROR}"
  echo "WORKSPACE_TRR_REMOTE_SOCIAL_COMMENT_MEDIA_MIRROR=${WORKSPACE_TRR_REMOTE_SOCIAL_COMMENT_MEDIA_MIRROR}"
  echo "WORKSPACE_TRR_REMOTE_WORKER_POLL_SECONDS=${WORKSPACE_TRR_REMOTE_WORKER_POLL_SECONDS}"
  echo "WORKSPACE_TRR_REMOTE_GOOGLE_NEWS_LEASE_SECONDS=${WORKSPACE_TRR_REMOTE_GOOGLE_NEWS_LEASE_SECONDS}"
  echo "PROFILE=\"${PROFILE}\""
  echo "TRR_BACKEND_WORKERS=${TRR_BACKEND_WORKERS}"
  echo "TRR_BACKEND_REQUIRE_REDIS_FOR_MULTI_WORKER=${TRR_BACKEND_REQUIRE_REDIS_FOR_MULTI_WORKER}"
  echo "TRR_BACKEND_RELOAD=${TRR_BACKEND_RELOAD}"
  echo "TRR_SOCIAL_PROXY_SHORT_TIMEOUT_MS=${TRR_SOCIAL_PROXY_SHORT_TIMEOUT_MS}"
  echo "TRR_SOCIAL_PROXY_DEFAULT_TIMEOUT_MS=${TRR_SOCIAL_PROXY_DEFAULT_TIMEOUT_MS}"
  echo "TRR_REDDIT_CACHE_LOOKUP_TIMEOUT_MS=${TRR_REDDIT_CACHE_LOOKUP_TIMEOUT_MS}"
  echo "TRR_REDDIT_CACHE_LOOKUP_RETRIES=${TRR_REDDIT_CACHE_LOOKUP_RETRIES}"
  echo "WORKSPACE_BACKEND_RESTART_COUNT=${BACKEND_RESTART_COUNT}"
  echo "WORKSPACE_BACKEND_LAST_RESTART_REASON=\"${BACKEND_LAST_RESTART_REASON}\""
  echo "WORKSPACE_BACKEND_LAST_RESTART_AT=\"${BACKEND_LAST_RESTART_AT}\""
  echo "WORKSPACE_BACKEND_LAST_RESTART_PROBE_RC=\"${BACKEND_LAST_RESTART_PROBE_RC}\""
} >>"$PIDFILE"

echo "[workspace] Starting services..."

if [[ "$WORKSPACE_SCREENALYTICS" == "1" ]]; then
  start_bg "SCREENALYTICS" "$SCREENALYTICS_LOG" "$BASH_BIN" -lc "cd \"$ROOT/screenalytics\" && \
    PYTHONUNBUFFERED=1 \
    SCREENALYTICS_ENV=dev \
    TRR_API_URL=\"$TRR_API_URL\" \
    SCREENALYTICS_API_URL=\"$SCREENALYTICS_LOCAL_API_URL\" \
    API_BASE_URL=\"$SCREENALYTICS_LOCAL_API_URL\" \
    API_PORT=\"$SCREENALYTICS_API_PORT\" \
    STREAMLIT_PORT=\"$SCREENALYTICS_STREAMLIT_PORT\" \
    WEB_PORT=\"$SCREENALYTICS_WEB_PORT\" \
    SCREENALYTICS_SKIP_DOCKER=\"$WORKSPACE_SCREENALYTICS_SKIP_DOCKER\" \
    DEV_AUTO_ALLOW_DB_ERROR=\"$SCREENALYTICS_DEV_AUTO_ALLOW_DB_ERROR\" \
    DEV_AUTO_OPEN_BROWSER=0 \
    DEV_AUTO_YES=1 \
    exec \"$BASH_BIN\" ./scripts/dev_auto.sh"
else
  echo "[workspace] screenalytics disabled for this session (WORKSPACE_SCREENALYTICS=0)."
fi

start_trr_backend
start_trr_social_worker
start_trr_remote_workers
start_trr_app

echo ""
echo "[workspace] URLs:"
echo "  TRR-APP:               http://${TRR_APP_HOST}:${TRR_APP_PORT}"
echo "  TRR-APP Admin:         ${ADMIN_APP_ORIGIN}"
echo "  TRR-Backend:           ${TRR_API_URL}"
echo "  Local services:        TRR-APP, TRR-Backend"
if [[ -n "$PROFILE" ]]; then
  echo "  Workspace profile:     ${PROFILE}"
fi
echo "  TRR-Backend mode:      $([[ \"$TRR_BACKEND_RELOAD\" == \"1\" ]] && echo \"reload\" || echo \"non-reload\")"
echo "  Job plane mode:        ${WORKSPACE_TRR_JOB_PLANE_MODE} (enforce_remote=${WORKSPACE_TRR_LONG_JOB_ENFORCE_REMOTE}, executor=${WORKSPACE_TRR_REMOTE_EXECUTOR}, modal_enabled=${WORKSPACE_TRR_MODAL_ENABLED})"
echo "  Workspace dev mode:    ${WORKSPACE_DEV_MODE}"
echo "  TRR-APP dev bundler:   ${WORKSPACE_TRR_APP_DEV_BUNDLER} (fallback: pnpm -C TRR-APP/apps/web run dev:stable)"
if [[ "$WORKSPACE_OPEN_BROWSER" == "1" ]]; then
  echo "  Browser sync:          enabled (mode=${WORKSPACE_BROWSER_TAB_SYNC_MODE})"
else
  echo "  Browser sync:          disabled"
fi
if [[ "$WORKSPACE_BACKEND_AUTO_RESTART" == "1" ]]; then
  echo "  Backend watchdog:      enabled (interval=${WORKSPACE_BACKEND_HEALTH_INTERVAL_SECONDS}s, threshold=${WORKSPACE_BACKEND_HEALTH_FAILURE_THRESHOLD})"
else
  echo "  Backend watchdog:      disabled"
fi
if [[ "$WORKSPACE_SOCIAL_WORKER_ENABLED" == "1" ]]; then
  echo "  Social worker pool:    posts=${WORKSPACE_SOCIAL_WORKER_POSTS}, comments=${WORKSPACE_SOCIAL_WORKER_COMMENTS}, media_mirror=${WORKSPACE_SOCIAL_WORKER_MEDIA_MIRROR}, comment_media_mirror=${WORKSPACE_SOCIAL_WORKER_COMMENT_MEDIA_MIRROR}"
elif [[ "$WORKSPACE_TRR_REMOTE_EXECUTOR" == "modal" && "$WORKSPACE_TRR_MODAL_ENABLED" == "1" ]]; then
  echo "  Social worker pool:    disabled (Modal-owned background execution)"
else
  echo "  Social worker pool:    disabled"
fi
if [[ "$WORKSPACE_TRR_REMOTE_WORKERS_ENABLED" == "1" ]]; then
  if [[ "$WORKSPACE_TRR_REMOTE_EXECUTOR" == "modal" && "$WORKSPACE_TRR_MODAL_ENABLED" == "1" ]]; then
    echo "  Remote execution:      Modal dispatch active (admin=${WORKSPACE_TRR_REMOTE_ADMIN_WORKERS}, reddit=${WORKSPACE_TRR_REMOTE_REDDIT_WORKERS}, google-news=${WORKSPACE_TRR_REMOTE_GOOGLE_NEWS_WORKERS}; local claim loops skipped)"
    echo "  Modal social tuning:  $(workspace_modal_social_tuning_summary)"
  else
    echo "  Remote job workers:    enabled (admin=${WORKSPACE_TRR_REMOTE_ADMIN_WORKERS}, reddit=${WORKSPACE_TRR_REMOTE_REDDIT_WORKERS}, google-news=${WORKSPACE_TRR_REMOTE_GOOGLE_NEWS_WORKERS}, social=${WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS}, poll=${WORKSPACE_TRR_REMOTE_WORKER_POLL_SECONDS}s)"
  fi
else
  echo "  Remote execution:      disabled"
fi
if [[ "$WORKSPACE_SCREENALYTICS" == "1" ]]; then
  echo "  screenalytics mode:    $(workspace_screenalytics_mode_label)"
  echo "  screenalytics API target: ${SCREENALYTICS_API_URL}"
  if [[ "$SCREENALYTICS_API_URL" != "$SCREENALYTICS_LOCAL_API_URL" ]]; then
    echo "  screenalytics API local:  ${SCREENALYTICS_LOCAL_API_URL}"
  fi
  echo "  screenalytics Streamlit: http://127.0.0.1:${SCREENALYTICS_STREAMLIT_PORT}"
  echo "  screenalytics Web:     http://127.0.0.1:${SCREENALYTICS_WEB_PORT}"
  if [[ "$WORKSPACE_SCREENALYTICS_SKIP_DOCKER" == "1" ]]; then
    echo "  screenalytics infra:   local Docker bypass enabled"
  else
    echo "  screenalytics infra:   local Redis + MinIO via Docker"
  fi
else
  echo "  screenalytics:         (disabled)"
fi
echo ""
echo "[workspace] Logs:"
echo "  ${TRR_APP_LOG}"
echo "  ${TRR_BACKEND_LOG}"
echo "  ${SOCIAL_WORKER_LOG}"
echo "  ${REMOTE_WORKER_LOG}"
echo "  ${SCREENALYTICS_LOG}"
echo ""
echo "[workspace] Ctrl+C to stop all."

# ---------------------------------------------------------------------------
# Startup health checks (so printed URLs reflect actual readiness)
# ---------------------------------------------------------------------------
wait_http_ok() {
  local name="$1"
  local url="$2"
  local seconds="$3"

  for _ in $(seq 1 "$seconds"); do
    if curl -fsS --max-time "$WORKSPACE_HEALTH_CURL_MAX_TIME" "$url" >/dev/null 2>&1; then
      echo "[workspace] ${name} is up: ${url}"
      return 0
    fi
    sleep 1
  done

  return 1
}

echo "[workspace] Checking service health..."
if ! wait_http_ok "TRR-Backend" "$BACKEND_HEALTH_URL" "$WORKSPACE_HEALTH_TIMEOUT_BACKEND"; then
  echo "[workspace] ERROR: TRR-Backend did not become healthy within ${WORKSPACE_HEALTH_TIMEOUT_BACKEND}s." >&2
  tail -n 80 "$TRR_BACKEND_LOG" >&2 || true
  exit 1
fi

if ! wait_http_ok "TRR-APP" "http://${TRR_APP_HOST}:${TRR_APP_PORT}/" "$WORKSPACE_HEALTH_TIMEOUT_APP"; then
  if [[ "$TRR_APP_CACHE_RECOVERY_ATTEMPTED" != "1" ]] && trr_app_next_cache_looks_corrupt; then
    echo "[workspace] WARNING: TRR-APP failed its first health check with a corrupted Next.js cache. Retrying once with a clean .next directory."
    TRR_APP_CACHE_RECOVERY_ATTEMPTED=1

    app_idx="$(find_service_index "TRR_APP" || true)"
    app_pid="${TRR_APP_PID:-}"
    if [[ -n "$app_idx" ]]; then
      app_pid="${PIDS[$app_idx]-$app_pid}"
    fi

    stop_bg "TRR_APP" "$app_pid"
    if [[ -n "$app_idx" ]]; then
      unset "PIDS[$app_idx]"
      unset "NAMES[$app_idx]"
    fi

    clean_trr_app_next_cache "TRR-APP health check detected cache corruption"
    start_trr_app

    if wait_http_ok "TRR-APP" "http://${TRR_APP_HOST}:${TRR_APP_PORT}/" "$WORKSPACE_HEALTH_TIMEOUT_APP"; then
      :
    else
      echo "[workspace] ERROR: TRR-APP remained unhealthy after automatic Next.js cache recovery." >&2
      tail -n 120 "$TRR_APP_LOG" >&2 || true
      tail -n 120 "$TRR_APP_NEXT_DEV_LOG" >&2 || true
      exit 1
    fi
  else
  echo "[workspace] ERROR: TRR-APP did not become reachable within ${WORKSPACE_HEALTH_TIMEOUT_APP}s." >&2
  tail -n 120 "$TRR_APP_LOG" >&2 || true
  tail -n 120 "$TRR_APP_NEXT_DEV_LOG" >&2 || true
  exit 1
  fi
fi

if [[ "$WORKSPACE_SCREENALYTICS" == "1" ]]; then
  if ! wait_http_ok "screenalytics API" "$SCREENALYTICS_LOCAL_HEALTH_URL" "$WORKSPACE_HEALTH_TIMEOUT_SCREENALYTICS_API"; then
    echo "[workspace] WARNING: screenalytics API did not become healthy within ${WORKSPACE_HEALTH_TIMEOUT_SCREENALYTICS_API}s (continuing)." >&2
    tail -n 120 "$SCREENALYTICS_LOG" >&2 || true
  fi

  # UI servers can take longer (model warmup, Next dev, etc). Don't fail the workspace if they're slow.
  SCREENALYTICS_STREAMLIT_OK=0
  if wait_http_ok "screenalytics Streamlit" "http://127.0.0.1:${SCREENALYTICS_STREAMLIT_PORT}/" "$WORKSPACE_HEALTH_TIMEOUT_SCREENALYTICS_STREAMLIT"; then
    SCREENALYTICS_STREAMLIT_OK=1
  else
    echo "[workspace] WARNING: screenalytics Streamlit did not become reachable within ${WORKSPACE_HEALTH_TIMEOUT_SCREENALYTICS_STREAMLIT}s (continuing)." >&2
    tail -n 120 "$SCREENALYTICS_LOG" >&2 || true
  fi

  SCREENALYTICS_WEB_OK=0
  if wait_http_ok "screenalytics Web" "http://127.0.0.1:${SCREENALYTICS_WEB_PORT}/" "$WORKSPACE_HEALTH_TIMEOUT_SCREENALYTICS_WEB"; then
    SCREENALYTICS_WEB_OK=1
  else
    echo "[workspace] WARNING: screenalytics Web did not become reachable within ${WORKSPACE_HEALTH_TIMEOUT_SCREENALYTICS_WEB}s (continuing)." >&2
    tail -n 120 "$SCREENALYTICS_LOG" >&2 || true
  fi

fi

# Keep running until one of the processes exits.
APP_DEV_URL="http://${TRR_APP_HOST}:${TRR_APP_PORT}"
SCREENALYTICS_STREAMLIT_DEV_URL=""
SCREENALYTICS_WEB_DEV_URL=""
if [[ "$WORKSPACE_SCREENALYTICS" == "1" ]]; then
  if [[ "${SCREENALYTICS_STREAMLIT_OK:-0}" -eq 1 ]]; then
    SCREENALYTICS_STREAMLIT_DEV_URL="http://127.0.0.1:${SCREENALYTICS_STREAMLIT_PORT}"
  fi
  if [[ "${SCREENALYTICS_WEB_OK:-0}" -eq 1 ]]; then
    SCREENALYTICS_WEB_DEV_URL="http://127.0.0.1:${SCREENALYTICS_WEB_PORT}"
  fi
fi
if [[ "$WORKSPACE_OPEN_BROWSER" == "1" ]]; then
  BROWSER_SCREENALYTICS_STREAMLIT_URL="$SCREENALYTICS_STREAMLIT_DEV_URL"
  BROWSER_SCREENALYTICS_WEB_URL="$SCREENALYTICS_WEB_DEV_URL"
  if [[ "$WORKSPACE_OPEN_SCREENALYTICS_TABS" != "1" ]]; then
    BROWSER_SCREENALYTICS_STREAMLIT_URL=""
    BROWSER_SCREENALYTICS_WEB_URL=""
    echo "[workspace] Screenalytics tab sync disabled (WORKSPACE_OPEN_SCREENALYTICS_TABS=0)."
  fi
  echo "[workspace] Syncing workspace browser tabs..."
  echo "[workspace] Browser tab sync mode: ${WORKSPACE_BROWSER_TAB_SYNC_MODE}"
  bash "$ROOT/scripts/open-workspace-dev-window.sh" "$APP_DEV_URL" "$BROWSER_SCREENALYTICS_STREAMLIT_URL" "$BROWSER_SCREENALYTICS_WEB_URL"
else
  echo "[workspace] Skipping browser sync (WORKSPACE_OPEN_BROWSER=0)."
fi

# Delay the runtime health watchdog to avoid false-positive warnings during
# the initial burst of browser requests that can saturate backend workers.
if (( WORKSPACE_BACKEND_HEALTH_GRACE_SECONDS > 0 )); then
  BACKEND_LAST_HEALTH_CHECK_AT=$(( $(date +%s) + WORKSPACE_BACKEND_HEALTH_GRACE_SECONDS ))
fi

while true; do
  if [[ "$WORKSPACE_BACKEND_AUTO_RESTART" == "1" && "$WORKSPACE_SHUTTING_DOWN" != "1" ]]; then
    now_ts="$(date +%s)"
    if (( now_ts - BACKEND_LAST_HEALTH_CHECK_AT >= WORKSPACE_BACKEND_HEALTH_INTERVAL_SECONDS )); then
      BACKEND_LAST_HEALTH_CHECK_AT="$now_ts"

      if backend_health_probe "$WORKSPACE_BACKEND_HEALTH_CURL_MAX_TIME"; then
        if (( BACKEND_HEALTH_FAILURES > 0 )); then
          echo "[workspace] TRR-Backend health recovered after ${BACKEND_HEALTH_FAILURES} failed probe(s)."
        fi
        BACKEND_HEALTH_FAILURES=0
        BACKEND_HEALTH_BUSY_TIMEOUT_STREAK_COUNT=0
      else
        probe_rc="$?"
        failure_threshold="$WORKSPACE_BACKEND_HEALTH_FAILURE_THRESHOLD"
        is_busy_timeout=0
        if [[ "$probe_rc" -eq 28 ]] && backend_has_active_connections; then
          is_busy_timeout=1
          busy_confirm_timeout="$(backend_busy_confirm_timeout)"
          if backend_health_probe "$busy_confirm_timeout"; then
            if (( BACKEND_HEALTH_FAILURES > 0 || BACKEND_HEALTH_BUSY_TIMEOUT_STREAK_COUNT > 0 )); then
              echo "[workspace] TRR-Backend health recovered on a slower follow-up probe during active traffic."
            fi
            BACKEND_HEALTH_FAILURES=0
            BACKEND_HEALTH_BUSY_TIMEOUT_STREAK_COUNT=0
            continue
          fi
        fi
        should_restart=0
        if [[ "$is_busy_timeout" -eq 1 && "$WORKSPACE_BACKEND_HEALTH_BUSY_TIMEOUT_IGNORE" == "1" ]]; then
          BACKEND_HEALTH_BUSY_TIMEOUT_STREAK_COUNT=$((BACKEND_HEALTH_BUSY_TIMEOUT_STREAK_COUNT + 1))
          BACKEND_HEALTH_FAILURES=0
          echo "[workspace] WARNING: TRR-Backend health probe timed out with active connections (busy streak ${BACKEND_HEALTH_BUSY_TIMEOUT_STREAK_COUNT}/${WORKSPACE_BACKEND_HEALTH_BUSY_TIMEOUT_STREAK}, rc=${probe_rc}); suppressing auto-restart because WORKSPACE_BACKEND_HEALTH_BUSY_TIMEOUT_IGNORE=1."
        else
          BACKEND_HEALTH_BUSY_TIMEOUT_STREAK_COUNT=0
          BACKEND_HEALTH_FAILURES=$((BACKEND_HEALTH_FAILURES + 1))
          if [[ "$is_busy_timeout" -eq 1 ]]; then
            echo "[workspace] WARNING: TRR-Backend health probe timed out with active connections (${BACKEND_HEALTH_FAILURES}/${failure_threshold}, rc=${probe_rc})."
          else
            echo "[workspace] WARNING: TRR-Backend health probe failed (${BACKEND_HEALTH_FAILURES}/${failure_threshold}, rc=${probe_rc})."
          fi
          if (( BACKEND_HEALTH_FAILURES >= failure_threshold )); then
            should_restart=1
          fi
        fi

        if [[ "$should_restart" -eq 1 && "$WORKSPACE_SHUTTING_DOWN" != "1" ]]; then
          backend_idx="$(find_service_index "TRR_BACKEND" || true)"
          backend_pid="${TRR_BACKEND_PID:-}"
          if [[ -n "$backend_idx" ]]; then
            backend_pid="${PIDS[$backend_idx]-$backend_pid}"
          fi

          record_backend_restart \
            "health_probe_failure" \
            "${probe_rc}" \
            "failures=${BACKEND_HEALTH_FAILURES};busy_timeout_streak=${BACKEND_HEALTH_BUSY_TIMEOUT_STREAK_COUNT}"
          echo "[workspace] Restarting TRR-Backend after repeated health failures..."
          stop_bg "TRR_BACKEND" "$backend_pid"
          if [[ -n "$backend_idx" ]]; then
            unset "PIDS[$backend_idx]"
            unset "NAMES[$backend_idx]"
          fi
          start_trr_backend
          if ! wait_http_ok "TRR-Backend" "$BACKEND_HEALTH_URL" "$WORKSPACE_HEALTH_TIMEOUT_BACKEND"; then
            echo "[workspace] ERROR: TRR-Backend did not recover after auto-restart." >&2
            tail -n 120 "$TRR_BACKEND_LOG" >&2 || true
            exit 1
          fi
        fi
        continue
      fi
    fi
  fi

  local_dead=""
  local_dead_name=""
  local_dead_idx=""
  for idx in "${!PIDS[@]}"; do
    pid="${PIDS[$idx]-}"
    name="${NAMES[$idx]-SERVICE_$idx}"
    if [[ -z "$pid" ]]; then
      continue
    fi
    if ! process_or_group_alive "$pid"; then
      local_dead="$pid"
      local_dead_name="$name"
      local_dead_idx="$idx"
      break
    fi
  done
  if [[ -n "$local_dead" ]]; then
    if [[ "$local_dead_name" == "TRR_BACKEND" && "$WORKSPACE_BACKEND_AUTO_RESTART" == "1" && "$WORKSPACE_SHUTTING_DOWN" != "1" ]]; then
      echo ""
      record_backend_restart "process_exit" "0" "exited_pid=${local_dead}"
      echo "[workspace] WARNING: TRR_BACKEND exited (pid=${local_dead}); restarting automatically."
      unset "PIDS[$local_dead_idx]"
      unset "NAMES[$local_dead_idx]"
      start_trr_backend
      if ! wait_http_ok "TRR-Backend" "$BACKEND_HEALTH_URL" "$WORKSPACE_HEALTH_TIMEOUT_BACKEND"; then
        echo "[workspace] ERROR: TRR-Backend did not recover after process exit restart." >&2
        tail -n 120 "$TRR_BACKEND_LOG" >&2 || true
        exit 1
      fi
      continue
    elif [[ "$local_dead_name" == "SCREENALYTICS" && "$WORKSPACE_STRICT" != "1" ]]; then
      echo ""
      echo "[workspace] WARNING: screenalytics exited (pid=${local_dead}). Continuing (WORKSPACE_STRICT=0)."
      tail -n 120 "$SCREENALYTICS_LOG" >&2 || true
      unset "PIDS[$local_dead_idx]"
      unset "NAMES[$local_dead_idx]"
    else
      echo ""
      echo "[workspace] WARNING: ${local_dead_name} exited (pid=${local_dead}). Check logs under ${LOG_DIR}."
      exit 1
    fi
  fi
  sleep 5
done

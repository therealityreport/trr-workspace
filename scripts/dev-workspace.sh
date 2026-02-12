#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

LOG_DIR="${ROOT}/.logs/workspace"
PIDFILE="${LOG_DIR}/pids.env"
mkdir -p "$LOG_DIR"

# Workspace toggles
WORKSPACE_SCREENALYTICS="${WORKSPACE_SCREENALYTICS:-1}"
WORKSPACE_STRICT="${WORKSPACE_STRICT:-0}"
WORKSPACE_FORCE_KILL_PORT_CONFLICTS="${WORKSPACE_FORCE_KILL_PORT_CONFLICTS:-0}"
WORKSPACE_CLEAN_NEXT_CACHE="${WORKSPACE_CLEAN_NEXT_CACHE:-1}"

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
# Optional screenalytics gating (docker is required only when screenalytics is enabled)
# ---------------------------------------------------------------------------
if [[ "$WORKSPACE_SCREENALYTICS" == "1" ]]; then
  if ! command -v docker >/dev/null 2>&1; then
    if [[ "$WORKSPACE_STRICT" == "1" ]]; then
      echo "[workspace] ERROR: docker not found (required for screenalytics)." >&2
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
        echo "[workspace] ERROR: Docker daemon is not running (required for screenalytics)." >&2
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

  if [[ "$WORKSPACE_SCREENALYTICS" == "1" ]]; then
    # Start screenalytics infrastructure (Redis + MinIO) before services.
    echo "[workspace] Starting Docker infrastructure (Redis + MinIO)..."
    docker compose -f "${ROOT}/screenalytics/infra/docker/compose.yaml" up -d
  fi
fi

declare -a PIDS=()
declare -a NAMES=()

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
trap cleanup EXIT INT TERM

# Initialize pidfile (used by `make stop`) with config for this run.
: >"$PIDFILE"
{
  echo "TRR_BACKEND_PORT=${TRR_BACKEND_PORT}"
  echo "TRR_APP_PORT=${TRR_APP_PORT}"
  echo "TRR_APP_HOST=${TRR_APP_HOST}"
  echo "SCREENALYTICS_API_PORT=${SCREENALYTICS_API_PORT}"
  echo "SCREENALYTICS_STREAMLIT_PORT=${SCREENALYTICS_STREAMLIT_PORT}"
  echo "SCREENALYTICS_WEB_PORT=${SCREENALYTICS_WEB_PORT}"
  echo "TRR_API_URL=\"${TRR_API_URL}\""
  echo "SCREENALYTICS_API_URL=\"${SCREENALYTICS_API_URL}\""
  echo "WORKSPACE_SCREENALYTICS=${WORKSPACE_SCREENALYTICS}"
  echo "WORKSPACE_STRICT=${WORKSPACE_STRICT}"
} >>"$PIDFILE"

echo "[workspace] Starting services..."

if [[ "$WORKSPACE_SCREENALYTICS" == "1" ]]; then
  start_bg "SCREENALYTICS" "$SCREENALYTICS_LOG" "$BASH_BIN" -lc "cd \"$ROOT/screenalytics\" && \
    PYTHONUNBUFFERED=1 \
    SCREENALYTICS_ENV=dev \
    SCREENALYTICS_API_URL=\"$SCREENALYTICS_API_URL\" \
    API_BASE_URL=\"$SCREENALYTICS_API_URL\" \
    API_PORT=\"$SCREENALYTICS_API_PORT\" \
    STREAMLIT_PORT=\"$SCREENALYTICS_STREAMLIT_PORT\" \
    WEB_PORT=\"$SCREENALYTICS_WEB_PORT\" \
    DEV_AUTO_ALLOW_DB_ERROR=\"$SCREENALYTICS_DEV_AUTO_ALLOW_DB_ERROR\" \
    DEV_AUTO_YES=1 \
    exec \"$BASH_BIN\" ./scripts/dev_auto.sh"
else
  echo "[workspace] screenalytics disabled for this session (WORKSPACE_SCREENALYTICS=0)."
fi

start_bg "TRR_BACKEND" "$TRR_BACKEND_LOG" "$BASH_BIN" -lc "cd \"$ROOT/TRR-Backend\" && \
  PYTHONUNBUFFERED=1 \
  TRR_BACKEND_PORT=\"$TRR_BACKEND_PORT\" \
  TRR_API_URL=\"$TRR_API_URL\" \
  SCREENALYTICS_API_URL=\"$SCREENALYTICS_API_URL\" \
  CORS_ALLOW_ORIGINS=\"http://127.0.0.1:${TRR_APP_PORT},http://localhost:${TRR_APP_PORT}\" \
  exec \"$BASH_BIN\" ./start-api.sh"

start_bg "TRR_APP" "$TRR_APP_LOG" "$BASH_BIN" -lc "cd \"$ROOT/TRR-APP\" && \
  if [[ -s \"${HOME}/.nvm/nvm.sh\" ]]; then \
    source \"${HOME}/.nvm/nvm.sh\"; \
    nvm use --silent >/dev/null 2>&1 || echo \"[workspace] WARNING: nvm use failed; continuing with current node.\" >&2; \
  fi && \
  cd \"$ROOT/TRR-APP/apps/web\" && \
  if [[ \"$WORKSPACE_CLEAN_NEXT_CACHE\" == \"1\" ]]; then rm -rf .next; fi && \
  TRR_API_URL=\"$TRR_API_URL\" \
  SCREENALYTICS_API_URL=\"$SCREENALYTICS_API_URL\" \
  exec pnpm exec next dev --webpack -p \"$TRR_APP_PORT\" --hostname \"$TRR_APP_HOST\""

echo ""
echo "[workspace] URLs:"
echo "  TRR-APP:               http://${TRR_APP_HOST}:${TRR_APP_PORT}"
echo "  TRR-Backend:           ${TRR_API_URL}"
if [[ "$WORKSPACE_SCREENALYTICS" == "1" ]]; then
  echo "  screenalytics API:     ${SCREENALYTICS_API_URL}"
  echo "  screenalytics Streamlit: http://127.0.0.1:${SCREENALYTICS_STREAMLIT_PORT}"
  echo "  screenalytics Web:     http://127.0.0.1:${SCREENALYTICS_WEB_PORT}"
else
  echo "  screenalytics:         (disabled)"
fi
echo ""
echo "[workspace] Logs:"
echo "  ${TRR_APP_LOG}"
echo "  ${TRR_BACKEND_LOG}"
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
    if curl -fsS --max-time 2 "$url" >/dev/null 2>&1; then
      echo "[workspace] ${name} is up: ${url}"
      return 0
    fi
    sleep 1
  done

  return 1
}

echo "[workspace] Checking service health..."
if ! wait_http_ok "TRR-Backend" "${TRR_API_URL}/health" 30; then
  echo "[workspace] ERROR: TRR-Backend did not become healthy within 30s." >&2
  tail -n 80 "$TRR_BACKEND_LOG" >&2 || true
  exit 1
fi

if ! wait_http_ok "TRR-APP" "http://${TRR_APP_HOST}:${TRR_APP_PORT}/" 60; then
  echo "[workspace] ERROR: TRR-APP did not become reachable within 60s." >&2
  tail -n 120 "$TRR_APP_LOG" >&2 || true
  exit 1
fi

if [[ "$WORKSPACE_SCREENALYTICS" == "1" ]]; then
  if ! wait_http_ok "screenalytics API" "${SCREENALYTICS_API_URL}/healthz" 30; then
    echo "[workspace] WARNING: screenalytics API did not become healthy within 30s (continuing)." >&2
    tail -n 120 "$SCREENALYTICS_LOG" >&2 || true
  fi

  # UI servers can take longer (model warmup, Next dev, etc). Don't fail the workspace if they're slow.
  if ! wait_http_ok "screenalytics Streamlit" "http://127.0.0.1:${SCREENALYTICS_STREAMLIT_PORT}/" 90; then
    echo "[workspace] WARNING: screenalytics Streamlit did not become reachable within 90s (continuing)." >&2
    tail -n 120 "$SCREENALYTICS_LOG" >&2 || true
  fi

  if ! wait_http_ok "screenalytics Web" "http://127.0.0.1:${SCREENALYTICS_WEB_PORT}/" 90; then
    echo "[workspace] WARNING: screenalytics Web did not become reachable within 90s (continuing)." >&2
    tail -n 120 "$SCREENALYTICS_LOG" >&2 || true
  fi
fi

# Keep running until one of the processes exits.
while true; do
  local_dead=""
  local_dead_name=""
  for idx in "${!PIDS[@]}"; do
    pid="${PIDS[$idx]-}"
    name="${NAMES[$idx]-SERVICE_$idx}"
    if [[ -z "$pid" ]]; then
      continue
    fi
    if ! kill -0 "$pid" >/dev/null 2>&1; then
      local_dead="$pid"
      local_dead_name="$name"
      break
    fi
  done
  if [[ -n "$local_dead" ]]; then
    if [[ "$local_dead_name" == "SCREENALYTICS" && "$WORKSPACE_STRICT" != "1" ]]; then
      echo ""
      echo "[workspace] WARNING: screenalytics exited (pid=${local_dead}). Continuing (WORKSPACE_STRICT=0)."
      tail -n 120 "$SCREENALYTICS_LOG" >&2 || true
      unset 'PIDS[idx]'
      unset 'NAMES[idx]'
    else
      echo ""
      echo "[workspace] WARNING: ${local_dead_name} exited (pid=${local_dead}). Check logs under ${LOG_DIR}."
      exit 1
    fi
  fi
  sleep 1
done

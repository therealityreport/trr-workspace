#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${ROOT}/.logs/workspace"
PIDFILE="${LOG_DIR}/pids.env"
source "${ROOT}/scripts/lib/workspace-port-cleanup.sh"

# Defaults (may be overridden by pidfile)
TRR_BACKEND_PORT="${TRR_BACKEND_PORT:-8000}"
TRR_APP_PORT="${TRR_APP_PORT:-3000}"
WORKSPACE_FORCE_KILL_PORT_CONFLICTS="${WORKSPACE_FORCE_KILL_PORT_CONFLICTS:-0}"

HAVE_LSOF=0
if command -v lsof >/dev/null 2>&1; then
  HAVE_LSOF=1
fi

if [[ -f "$PIDFILE" ]]; then
  # shellcheck disable=SC1090
  source "$PIDFILE"
else
  echo "[workspace] No pidfile found (${PIDFILE}). Attempting safe cleanup by port..."
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
  workspace_pid_ppid "$1"
}

pid_cmd() {
  workspace_pid_cmd "$1"
}

pid_cwd() {
  workspace_pid_cwd "$1"
}

is_safe_stale() {
  workspace_is_safe_stale "$1" "$2"
}

kill_pids() {
  workspace_kill_targets "$1"
}

descendants_of() {
  workspace_descendants_of "$1"
}

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

stop_manager() {
  local pid="$1"

  if [[ -z "${pid}" ]]; then
    return 1
  fi
  if [[ "$pid" == "$$" ]]; then
    return 1
  fi
  if ! kill -0 "$pid" >/dev/null 2>&1; then
    echo "[workspace] Workspace manager not running (pid=${pid})."
    return 1
  fi

  echo "[workspace] Stopping workspace manager (pid=${pid})"
  kill -TERM "$pid" >/dev/null 2>&1 || true

  for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50; do
    if [[ ! -f "$PIDFILE" ]]; then
      return 0
    fi
    sleep 0.2
  done

  echo "[workspace] Workspace manager did not shut down cleanly; forcing termination."
  kill -KILL "$pid" >/dev/null 2>&1 || true
  return 1
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
  local kids
  kids="$(descendants_of "$pid")"

  # Prefer killing the process group (works when started in its own group).
  kill -TERM -- "-${pid}" >/dev/null 2>&1 || true
  kill -TERM "${pid}" >/dev/null 2>&1 || true
  if [[ -n "$kids" ]]; then
    # shellcheck disable=SC2086
    kill -TERM $kids >/dev/null 2>&1 || true
  fi

  for _ in 1 2 3 4 5 6 7 8 9 10; do
    if ! kill -0 "$pid" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.2
  done

  kill -KILL -- "-${pid}" >/dev/null 2>&1 || true
  kill -KILL "${pid}" >/dev/null 2>&1 || true
  if [[ -n "$kids" ]]; then
    # shellcheck disable=SC2086
    kill -KILL $kids >/dev/null 2>&1 || true
  fi
}

cleanup_port() {
  local port="$1"
  local label="$2"

  if [[ "$HAVE_LSOF" -ne 1 ]]; then
    return 0
  fi

  local pids
  pids="$(port_listeners "$port")"
  if [[ -z "$pids" ]]; then
    return 0
  fi

  local to_kill=""
  local pid cmd cwd
  for pid in $pids; do
    if [[ "$WORKSPACE_FORCE_KILL_PORT_CONFLICTS" == "1" ]] || is_safe_stale "$pid" "$port"; then
      to_kill="${to_kill} ${pid}"
    else
      cmd="$(pid_cmd "$pid")"
      cwd="$(pid_cwd "$pid")"
      echo "[workspace] Leaving non-stale listener on port ${port} (pid=${pid})."
      echo "[workspace]   cmd: ${cmd}"
      if [[ -n "$cwd" ]]; then
        echo "[workspace]   cwd: ${cwd}"
      fi
    fi
  done

  to_kill="$(echo "$to_kill" | xargs 2>/dev/null || true)"
  if [[ -n "$to_kill" ]]; then
    local cleanup_targets
    cleanup_targets="$(workspace_expand_cleanup_targets "$to_kill" "$port")"
    echo "[workspace] Stopping ${label} listeners on port ${port}: ${cleanup_targets}"
    kill_pids "$cleanup_targets"
  fi
}

MANAGER_STOP_SUCCEEDED=0
if [[ -f "$PIDFILE" ]]; then
  if stop_manager "${WORKSPACE_MANAGER_PID:-}"; then
    MANAGER_STOP_SUCCEEDED=1
  fi
fi

if [[ -f "$PIDFILE" && "$MANAGER_STOP_SUCCEEDED" -ne 1 ]]; then
  # Fallback: stop individual services in reverse dependency order.
  stop_one "TRR_APP" "${TRR_APP_PID:-}"
  stop_one "TRR_REMOTE_WORKERS" "${TRR_REMOTE_WORKERS_PID:-}"
  stop_one "TRR_SOCIAL_WORKER" "${TRR_SOCIAL_WORKER_PID:-}"
  stop_one "TRR_BACKEND" "${TRR_BACKEND_PID:-}"
fi

# Best-effort cleanup by port (handles stale/orphan listeners even if pidfile is missing).
cleanup_port "$TRR_APP_PORT" "TRR-APP"
cleanup_port "$TRR_BACKEND_PORT" "TRR-Backend"

rm -f "$PIDFILE" >/dev/null 2>&1 || true
echo "[workspace] Stopped."

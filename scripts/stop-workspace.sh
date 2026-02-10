#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${ROOT}/.logs/workspace"
PIDFILE="${LOG_DIR}/pids.env"

# Defaults (may be overridden by pidfile)
TRR_BACKEND_PORT="${TRR_BACKEND_PORT:-8000}"
TRR_APP_PORT="${TRR_APP_PORT:-3000}"
SCREENALYTICS_API_PORT="${SCREENALYTICS_API_PORT:-8001}"
SCREENALYTICS_STREAMLIT_PORT="${SCREENALYTICS_STREAMLIT_PORT:-8501}"
SCREENALYTICS_WEB_PORT="${SCREENALYTICS_WEB_PORT:-8080}"
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

  # Port-specific allowlist for known backends.
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

descendants_of() {
  local root_pid="$1"
  local -a queue=()
  local -a all=()

  queue+=("$root_pid")

  while [[ "${#queue[@]}" -gt 0 ]]; do
    local pid="${queue[0]}"
    queue=("${queue[@]:1}")

    local children
    children="$(pgrep -P "$pid" 2>/dev/null || true)"
    if [[ -z "$children" ]]; then
      continue
    fi

    local child
    for child in $children; do
      all+=("$child")
      queue+=("$child")
    done
  done

  if [[ "${#all[@]}" -eq 0 ]]; then
    echo ""
    return 0
  fi
  printf '%s\n' "${all[@]}" | sort -u | tr '\n' ' '
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
    echo "[workspace] Stopping ${label} listeners on port ${port}: ${to_kill}"
    kill_pids "$to_kill"
  fi
}

if [[ -f "$PIDFILE" ]]; then
  # Stop in reverse dependency order.
  stop_one "TRR_APP" "${TRR_APP_PID:-}"
  stop_one "TRR_BACKEND" "${TRR_BACKEND_PID:-}"
  stop_one "SCREENALYTICS" "${SCREENALYTICS_PID:-}"
fi

# Best-effort cleanup by port (handles stale/orphan listeners even if pidfile is missing).
cleanup_port "$TRR_APP_PORT" "TRR-APP"
cleanup_port "$TRR_BACKEND_PORT" "TRR-Backend"
cleanup_port "$SCREENALYTICS_API_PORT" "screenalytics API"
cleanup_port "$SCREENALYTICS_STREAMLIT_PORT" "screenalytics Streamlit"
cleanup_port "$SCREENALYTICS_WEB_PORT" "screenalytics Web"

rm -f "$PIDFILE" >/dev/null 2>&1 || true
echo "[workspace] Stopped."

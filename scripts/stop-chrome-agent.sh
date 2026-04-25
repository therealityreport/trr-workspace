#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${ROOT}/.logs/workspace"
CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
HEADFUL_OWNER_FILE="${CODEX_CHROME_OWNER_DIR:-${CODEX_HOME_DIR}/tmp/browser-control}/headful-chrome-owner.env"
DEBUG_PORT="${CHROME_AGENT_DEBUG_PORT:-9422}"
LEGACY_PIDFILE="${LOG_DIR}/chrome-agent.pid"
STOP_ALL="${CHROME_AGENT_STOP_ALL:-0}"

cleanup_chrome_dock_recents_if_requested() {
  [[ "${CHROME_AGENT_CLEAN_DOCK_RECENTS:-0}" == "1" ]] || return 0
  [[ "$(uname)" == "Darwin" ]] || return 0
  bash "${ROOT}/scripts/cleanup-chrome-dock-recents.sh" >&2 || true
}

clear_headful_owner_if_matches() {
  local chrome_pid="$1"
  [[ -f "$HEADFUL_OWNER_FILE" ]] || return 0
  local owner_pid=""
  owner_pid="$(sed -n 's/^PID=//p' "$HEADFUL_OWNER_FILE" | head -n 1)"
  if [[ -z "$owner_pid" || "$owner_pid" == "$chrome_pid" ]]; then
    rm -f "$HEADFUL_OWNER_FILE"
  fi
}

stop_by_port() {
  local port="$1"
  local pidfile="${LOG_DIR}/chrome-agent-${port}.pid"
  local statefile="${LOG_DIR}/chrome-agent-${port}.env"
  local legacy_pidfile="${LOG_DIR}/chrome-agent.pid"
  local reservefile="${LOG_DIR}/codex-chrome-port-${port}.reserve"

  if [[ ! -f "$pidfile" ]]; then
    # Backward compatibility for old 9222 pidfile naming.
    if [[ "$port" == "9222" && -f "$legacy_pidfile" ]]; then
      pidfile="$legacy_pidfile"
    else
      echo "[chrome-agent] No pidfile found for port ${port}. Checking listeners..."
      if command -v lsof >/dev/null 2>&1; then
        pids="$(lsof -nP -iTCP:"${port}" -sTCP:LISTEN -t 2>/dev/null || true)"
        if [[ -n "$pids" ]]; then
          echo "[chrome-agent] Stopping listeners on port ${port}: ${pids}"
          # shellcheck disable=SC2086
          kill -TERM $pids >/dev/null 2>&1 || true
          sleep 0.5
          # shellcheck disable=SC2086
          kill -KILL $pids >/dev/null 2>&1 || true
          echo "[chrome-agent] Stopped listeners on ${port}."
          rm -f "$reservefile"
        else
          echo "[chrome-agent] Nothing running on port ${port}."
        fi
      else
        echo "[chrome-agent] No lsof available; cannot detect processes."
      fi
      return 0
    fi
  fi

  CHROME_PID="$(cat "$pidfile")"
  rm -f "$pidfile"
  rm -f "$statefile"
  clear_headful_owner_if_matches "$CHROME_PID"
  if [[ "$port" == "9222" ]]; then
    rm -f "$legacy_pidfile"
  fi
  rm -f "$reservefile"

  if [[ -z "$CHROME_PID" ]] || ! kill -0 "$CHROME_PID" >/dev/null 2>&1; then
    echo "[chrome-agent] Not running for port ${port} (pid=${CHROME_PID:-?})."
    return 0
  fi

  echo "[chrome-agent] Stopping Chrome agent on port ${port} (pid=${CHROME_PID})..."
  kill -TERM "$CHROME_PID" >/dev/null 2>&1 || true

  for _ in 1 2 3 4 5 6 7 8 9 10; do
    if ! kill -0 "$CHROME_PID" >/dev/null 2>&1; then
      echo "[chrome-agent] Stopped port ${port}."
      return 0
    fi
    sleep 0.3
  done

  kill -KILL "$CHROME_PID" >/dev/null 2>&1 || true
  echo "[chrome-agent] Force-killed port ${port}."
}

if [[ "$STOP_ALL" == "1" ]]; then
  shopt -s nullglob
  pidfiles=("${LOG_DIR}"/chrome-agent-*.pid)
  shopt -u nullglob

  if [[ "${#pidfiles[@]}" -eq 0 ]]; then
    echo "[chrome-agent] No managed chrome-agent pidfiles found."
    if [[ -f "$LEGACY_PIDFILE" ]]; then
      stop_by_port "9222"
    fi
    cleanup_chrome_dock_recents_if_requested
    exit 0
  fi

  echo "[chrome-agent] Stopping all managed Chrome agent instances..."
  for pidfile in "${pidfiles[@]}"; do
    port="${pidfile##*/chrome-agent-}"
    port="${port%.pid}"
    stop_by_port "$port"
  done
  if [[ -f "$LEGACY_PIDFILE" ]]; then
    stop_by_port "9222"
  fi
  cleanup_chrome_dock_recents_if_requested
  exit 0
fi

stop_by_port "$DEBUG_PORT"
cleanup_chrome_dock_recents_if_requested

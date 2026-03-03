#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${ROOT}/.logs/workspace"
PIDFILE="${LOG_DIR}/chrome-agent.pid"
DEBUG_PORT="${CHROME_AGENT_DEBUG_PORT:-9222}"

if [[ ! -f "$PIDFILE" ]]; then
  echo "[chrome-agent] No pidfile found. Checking port ${DEBUG_PORT}..."
  if command -v lsof >/dev/null 2>&1; then
    pids="$(lsof -nP -iTCP:"${DEBUG_PORT}" -sTCP:LISTEN -t 2>/dev/null || true)"
    if [[ -n "$pids" ]]; then
      echo "[chrome-agent] Stopping listeners on port ${DEBUG_PORT}: ${pids}"
      # shellcheck disable=SC2086
      kill -TERM $pids >/dev/null 2>&1 || true
      sleep 0.5
      # shellcheck disable=SC2086
      kill -KILL $pids >/dev/null 2>&1 || true
      echo "[chrome-agent] Stopped."
    else
      echo "[chrome-agent] Nothing running on port ${DEBUG_PORT}."
    fi
  else
    echo "[chrome-agent] No lsof available; cannot detect processes."
  fi
  exit 0
fi

CHROME_PID="$(cat "$PIDFILE")"
rm -f "$PIDFILE"

if [[ -z "$CHROME_PID" ]] || ! kill -0 "$CHROME_PID" >/dev/null 2>&1; then
  echo "[chrome-agent] Not running (pid=${CHROME_PID:-?})."
  exit 0
fi

echo "[chrome-agent] Stopping Chrome agent (pid=${CHROME_PID})..."
kill -TERM "$CHROME_PID" >/dev/null 2>&1 || true

for _ in 1 2 3 4 5 6 7 8 9 10; do
  if ! kill -0 "$CHROME_PID" >/dev/null 2>&1; then
    echo "[chrome-agent] Stopped."
    exit 0
  fi
  sleep 0.3
done

kill -KILL "$CHROME_PID" >/dev/null 2>&1 || true
echo "[chrome-agent] Force-killed."

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${ROOT}/.logs/workspace"

print_instance() {
  local port="$1"
  local pidfile="${LOG_DIR}/chrome-agent-${port}.pid"
  local statefile="${LOG_DIR}/chrome-agent-${port}.env"

  local pid
  pid="$(cat "$pidfile" 2>/dev/null || true)"
  local status="stopped"
  if [[ -n "$pid" ]] && kill -0 "$pid" >/dev/null 2>&1; then
    status="running"
  fi

  local profile="unknown"
  if [[ -f "$statefile" ]]; then
    profile="$(sed -n 's/^PROFILE_DIR=//p' "$statefile" | head -n 1)"
  fi

  printf "%-6s %-10s %-8s %s\n" "$port" "$status" "${pid:-?}" "$profile"
}

shopt -s nullglob
pidfiles=("${LOG_DIR}"/chrome-agent-*.pid)
shopt -u nullglob

if [[ "${#pidfiles[@]}" -eq 0 ]]; then
  echo "[chrome-agent] No managed Chrome instances found."
  if [[ -f "${LOG_DIR}/chrome-agent.pid" ]]; then
    legacy_pid="$(cat "${LOG_DIR}/chrome-agent.pid" 2>/dev/null || true)"
    if [[ -n "${legacy_pid}" ]] && kill -0 "${legacy_pid}" >/dev/null 2>&1; then
      echo "[chrome-agent] Legacy 9222 instance appears to be running (pid=${legacy_pid})."
    fi
  fi
  exit 0
fi

printf "%-6s %-10s %-8s %s\n" "PORT" "STATUS" "PID" "PROFILE"
for pidfile in "${pidfiles[@]}"; do
  port="${pidfile##*/chrome-agent-}"
  port="${port%.pid}"
  print_instance "$port"
done

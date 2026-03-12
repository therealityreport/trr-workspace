#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${ROOT}/.logs/workspace"

endpoint_reachable() {
  local port="$1"
  curl -sf "http://127.0.0.1:${port}/json/version" >/dev/null 2>&1
}

add_port() {
  local candidate="$1"
  local existing

  for existing in "${PORTS[@]:-}"; do
    if [[ "$existing" == "$candidate" ]]; then
      return 0
    fi
  done

  PORTS+=("$candidate")
}

print_instance() {
  local port="$1"
  local pidfile="${LOG_DIR}/chrome-agent-${port}.pid"
  local statefile="${LOG_DIR}/chrome-agent-${port}.env"

  local pid
  if [[ "$port" == "9222" && ! -f "$pidfile" && -f "${LOG_DIR}/chrome-agent.pid" ]]; then
    pidfile="${LOG_DIR}/chrome-agent.pid"
  fi
  pid="$(cat "$pidfile" 2>/dev/null || true)"
  local reachable="no"
  if endpoint_reachable "$port"; then
    reachable="yes"
  fi

  local profile="unknown"
  local headless="unknown"
  if [[ -f "$statefile" ]]; then
    profile="$(sed -n 's/^PROFILE_DIR=//p' "$statefile" | head -n 1)"
    headless="$(sed -n 's/^HEADLESS=//p' "$statefile" | head -n 1)"
  elif [[ "$port" == "9222" ]]; then
    profile="${HOME}/.chrome-profiles/claude-agent"
    headless="0"
  fi

  local status="stopped"
  if [[ -n "$pid" ]] && kill -0 "$pid" >/dev/null 2>&1; then
    if [[ "$reachable" == "yes" ]]; then
      status="running"
    else
      status="degraded"
    fi
  elif [[ "$reachable" == "yes" ]]; then
    status="listener-only"
  fi

  printf "%-6s %-13s %-8s %-9s %-8s %s\n" "$port" "$status" "${pid:-?}" "$reachable" "${headless:-?}" "$profile"
}

pidfiles=()
shopt -s nullglob
pidfiles=("${LOG_DIR}"/chrome-agent-*.pid)
shopt -u nullglob

PORTS=()
for pidfile in "${pidfiles[@]:-}"; do
  [[ -n "$pidfile" ]] || continue
  port="${pidfile##*/chrome-agent-}"
  port="${port%.pid}"
  add_port "$port"
done

if [[ -f "${LOG_DIR}/chrome-agent.pid" ]] || endpoint_reachable "9222"; then
  add_port "9222"
fi

if [[ "${#PORTS[@]}" -eq 0 ]]; then
  echo "[chrome-agent] No managed Chrome instances found."
  exit 0
fi

printf "%-6s %-13s %-8s %-9s %-8s %s\n" "PORT" "STATUS" "PID" "REACHABLE" "HEADLESS" "PROFILE"
for port in "${PORTS[@]:-}"; do
  [[ -n "$port" ]] || continue
  print_instance "$port"
done

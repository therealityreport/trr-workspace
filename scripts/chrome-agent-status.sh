#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${ROOT}/.logs/workspace"
source "${ROOT}/scripts/lib/chrome-runtime.sh"

endpoint_reachable() {
  chrome_endpoint_reachable "$1"
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
  local healed_state=""

  local reachable="no"
  if endpoint_reachable "$port"; then
    reachable="yes"
    if [[ "$port" == "9222" || "$port" == "9422" ]]; then
      healed_state="$(heal_shared_chrome_runtime_state "$LOG_DIR" "$port" 2>/dev/null || true)"
    fi
  fi

  local pid
  if [[ "$port" == "9222" && ! -f "$pidfile" && -f "${LOG_DIR}/chrome-agent.pid" ]]; then
    pidfile="${LOG_DIR}/chrome-agent.pid"
  fi
  pid="$(cat "$pidfile" 2>/dev/null || true)"
  if [[ -n "$healed_state" ]]; then
    pid="${healed_state%%:*}"
  elif [[ "$reachable" == "yes" ]]; then
    pid="$(chrome_listener_pid "$port")"
  fi

  local profile="unknown"
  local headless="unknown"
  if [[ -f "$statefile" ]]; then
    profile="$(sed -n 's/^PROFILE_DIR=//p' "$statefile" | head -n 1)"
    headless="$(sed -n 's/^HEADLESS=//p' "$statefile" | head -n 1)"
  else
    profile="$(default_chrome_profile_for_port "$port")"
    headless="0"
  fi

  local status="stopped"
  if [[ "$reachable" == "yes" ]]; then
    status="running"
  elif [[ -n "$pid" ]] && kill -0 "$pid" >/dev/null 2>&1; then
    status="degraded"
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

if endpoint_reachable "9222"; then
  add_port "9222"
elif [[ -f "${LOG_DIR}/chrome-agent.pid" ]]; then
  legacy_pid="$(cat "${LOG_DIR}/chrome-agent.pid" 2>/dev/null || true)"
  if [[ -n "$legacy_pid" ]] && kill -0 "$legacy_pid" >/dev/null 2>&1; then
    add_port "9222"
  fi
fi

if [[ -f "${LOG_DIR}/chrome-agent-9422.pid" ]] || endpoint_reachable "9422"; then
  add_port "9422"
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

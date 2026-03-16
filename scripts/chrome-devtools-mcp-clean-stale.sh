#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${ROOT}/.logs/workspace"

cleaned=0

clean_if_dead() {
  local file="$1"
  local pid="$2"
  shift 2
  if [[ -z "$pid" ]] || ! kill -0 "$pid" >/dev/null 2>&1; then
    rm -f "$file" "$@"
    cleaned=$((cleaned + 1))
  fi
}

shopt -s nullglob
for reserve in "${LOG_DIR}"/codex-chrome-port-*.reserve; do
  owner_pid="$(cat "$reserve" 2>/dev/null || true)"
  clean_if_dead "$reserve" "$owner_pid"
done

for pidfile in "${LOG_DIR}"/chrome-agent-*.pid; do
  browser_pid="$(cat "$pidfile" 2>/dev/null || true)"
  statefile="${pidfile%.pid}.env"
  clean_if_dead "$pidfile" "$browser_pid" "$statefile"
done

for statefile in "${LOG_DIR}"/chrome-agent-*.env; do
  pidfile="${statefile%.env}.pid"
  if [[ ! -f "$pidfile" ]]; then
    rm -f "$statefile"
    cleaned=$((cleaned + 1))
  fi
done
shopt -u nullglob

echo "[chrome-devtools-mcp] Stale managed runtime artifacts cleaned: ${cleaned}"

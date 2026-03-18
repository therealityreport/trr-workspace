#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${ROOT}/.logs/workspace"
source "${ROOT}/scripts/lib/chrome-runtime.sh"

cleaned=0
broken_live_sessions=0

log() {
  echo "[chrome-devtools-mcp] $*" >&2
}

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

for sessionfile in "${LOG_DIR}"/codex-chrome-session-*.env; do
  wrapper_pid="$(sed -n 's/^WRAPPER_PID=//p' "$sessionfile" | head -n 1)"
  pagesfile="${sessionfile%.env}.pages"
  reservefile="${LOG_DIR}/codex-chrome-port-$(basename "${sessionfile%.env}" | sed 's/^codex-chrome-session-//').reserve"
  clean_if_dead "$sessionfile" "$wrapper_pid" "$pagesfile" "$reservefile"
done

for pagesfile in "${LOG_DIR}"/codex-chrome-session-*.pages; do
  sessionfile="${pagesfile%.pages}.env"
  if [[ ! -f "$sessionfile" ]]; then
    rm -f "$pagesfile"
    cleaned=$((cleaned + 1))
  fi
done

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

for sessionfile in "${LOG_DIR}"/codex-chrome-session-*.env; do
  port="$(sed -n 's/^PORT=//p' "$sessionfile" | head -n 1)"
  wrapper_pid="$(sed -n 's/^WRAPPER_PID=//p' "$sessionfile" | head -n 1)"
  pidfile="${LOG_DIR}/chrome-agent-${port}.pid"
  statefile="${LOG_DIR}/chrome-agent-${port}.env"
  pagesfile="${sessionfile%.env}.pages"
  reservefile="${LOG_DIR}/codex-chrome-port-${port}.reserve"
  browser_pid="$(cat "$pidfile" 2>/dev/null || true)"

  if [[ -z "$port" || -z "$wrapper_pid" ]]; then
    continue
  fi
  if ! kill -0 "$wrapper_pid" >/dev/null 2>&1; then
    continue
  fi
  if chrome_endpoint_reachable "$port"; then
    continue
  fi
  if [[ -n "$browser_pid" ]] && kill -0 "$browser_pid" >/dev/null 2>&1; then
    continue
  fi

  log "Stopping broken live isolated session on port ${port} (wrapper=${wrapper_pid}, endpoint=missing)"
  kill -TERM "$wrapper_pid" >/dev/null 2>&1 || true
  sleep 0.5
  if kill -0 "$wrapper_pid" >/dev/null 2>&1; then
    kill -KILL "$wrapper_pid" >/dev/null 2>&1 || true
  fi
  rm -f "$sessionfile" "$pagesfile" "$reservefile" "$pidfile" "$statefile"
  cleaned=$((cleaned + 1))
  broken_live_sessions=$((broken_live_sessions + 1))
done
shopt -u nullglob

echo "[chrome-devtools-mcp] Stale managed runtime artifacts cleaned: ${cleaned} (broken_live_sessions=${broken_live_sessions})"

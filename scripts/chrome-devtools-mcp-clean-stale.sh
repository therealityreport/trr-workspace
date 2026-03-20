#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${ROOT}/.logs/workspace"
MCP_RUN_LOG_DIR="${LOG_DIR}/chrome-devtools-mcp"
source "${ROOT}/scripts/lib/chrome-runtime.sh"

cleaned=0
broken_live_sessions=0
retained_logs=0

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

visible_owner_field() {
  local key="$1"
  [[ -f "$visible_browser_owner_file" ]] || return 0
  sed -n "s/^${key}=//p" "$visible_browser_owner_file" | head -n 1
}

visible_owner_browser_pid() {
  local pid
  pid="$(visible_owner_field BROWSER_PID)"
  if [[ -n "$pid" ]]; then
    printf '%s\n' "$pid"
    return 0
  fi
  visible_owner_field OWNER_PID
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
  port="$(printf '%s\n' "$(basename "$pidfile")" | sed -n 's/^chrome-agent-\([0-9][0-9]*\)\.pid$/\1/p')"
  if [[ -z "$port" ]] || { ! chrome_endpoint_reachable "$port" && [[ -z "$(chrome_listener_pid "$port")" ]]; }; then
    rm -f "$pidfile" "$statefile"
    cleaned=$((cleaned + 1))
  fi
done

for statefile in "${LOG_DIR}"/chrome-agent-*.env; do
  pidfile="${statefile%.env}.pid"
  if [[ ! -f "$pidfile" ]]; then
    rm -f "$statefile"
    cleaned=$((cleaned + 1))
  fi
done

for singleton_pidfile in "${LOG_DIR}"/mcp-singleton-*.pid; do
  owner_pid="$(cat "$singleton_pidfile" 2>/dev/null || true)"
  clean_if_dead "$singleton_pidfile" "$owner_pid"
done

visible_browser_owner_file="${LOG_DIR}/chrome-devtools-visible-browser-owner.env"
if [[ -f "$visible_browser_owner_file" ]]; then
  owner_pid="$(visible_owner_browser_pid)"
  owner_wrapper_pid="$(visible_owner_field WRAPPER_PID)"
  owner_port="$(visible_owner_field PORT)"
  listener_pid=""
  if [[ -n "$owner_port" ]]; then
    listener_pid="$(chrome_listener_pid "$owner_port")"
  fi
  if [[ -n "$owner_pid" ]] && kill -0 "$owner_pid" >/dev/null 2>&1; then
    :
  elif [[ -n "$listener_pid" ]]; then
    :
  elif [[ -n "$owner_wrapper_pid" ]] && kill -0 "$owner_wrapper_pid" >/dev/null 2>&1; then
    :
  else
    rm -f "$visible_browser_owner_file"
    cleaned=$((cleaned + 1))
  fi
fi

for metadata in "${LOG_DIR}"/chrome-tab-metadata.*; do
  port="$(printf '%s\n' "$(basename "$metadata")" | sed -n 's/^chrome-tab-metadata\.\([0-9][0-9]*\)\..*/\1/p')"
  if [[ -z "$port" ]] || ! chrome_endpoint_reachable "$port"; then
    rm -f "$metadata"
    cleaned=$((cleaned + 1))
  fi
done

for log_file in "${LOG_DIR}"/chrome-agent-*.log; do
  port="$(printf '%s\n' "$(basename "$log_file")" | sed -n 's/^chrome-agent-\([0-9][0-9]*\)\.log$/\1/p')"
  pidfile="${LOG_DIR}/chrome-agent-${port}.pid"
  listener_pid="$(chrome_listener_pid "$port")"
  if [[ -z "$port" ]]; then
    continue
  fi
  if [[ -z "$listener_pid" && ! -f "$pidfile" ]]; then
    rm -f "$log_file"
    cleaned=$((cleaned + 1))
    continue
  fi
  if find "$log_file" -mtime +7 >/dev/null 2>&1; then
    rm -f "$log_file"
    retained_logs=$((retained_logs + 1))
  fi
done

if [[ -d "$MCP_RUN_LOG_DIR" ]]; then
  find "$MCP_RUN_LOG_DIR" -name 'npm-exec-*.stderr' -mtime +1 -delete 2>/dev/null || true
  find "$MCP_RUN_LOG_DIR" -name 'npm-exec-*.stderr.fifo' -mtime +1 -delete 2>/dev/null || true
fi

if [[ -d "${ROOT}/.tmp/chrome-devtools-mcp/npm-cache/_logs" ]]; then
  find "${ROOT}/.tmp/chrome-devtools-mcp/npm-cache/_logs" -type f -mtime +1 -delete 2>/dev/null || true
fi

for sessionfile in "${LOG_DIR}"/codex-chrome-session-*.env; do
  port="$(sed -n 's/^PORT=//p' "$sessionfile" | head -n 1)"
  wrapper_pid="$(sed -n 's/^WRAPPER_PID=//p' "$sessionfile" | head -n 1)"
  pidfile="${LOG_DIR}/chrome-agent-${port}.pid"
  statefile="${LOG_DIR}/chrome-agent-${port}.env"
  pagesfile="${sessionfile%.env}.pages"
  reservefile="${LOG_DIR}/codex-chrome-port-${port}.reserve"
  browser_pid="$(cat "$pidfile" 2>/dev/null || true)"
  listener_pid="$(chrome_listener_pid "$port")"

  if [[ -z "$port" || -z "$wrapper_pid" ]]; then
    continue
  fi
  if ! kill -0 "$wrapper_pid" >/dev/null 2>&1; then
    continue
  fi
  if chrome_endpoint_reachable "$port"; then
    continue
  fi
  if [[ -n "$listener_pid" || -n "$browser_pid" ]] && [[ -n "$(chrome_listener_pid "$port")" ]]; then
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
echo "[chrome-devtools-mcp] Old retained logs pruned: ${retained_logs}"

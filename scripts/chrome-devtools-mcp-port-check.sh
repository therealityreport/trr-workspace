#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${ROOT}/.logs/workspace"
source "${ROOT}/scripts/lib/chrome-runtime.sh"

usage() {
  cat <<'EOF'
Usage:
  scripts/chrome-devtools-mcp-port-check.sh [port ...]

Checks each Chrome DevTools port by comparing:
  - listener PID
  - /json/version webSocketDebuggerUrl
  - /json/list page targets

This is the investigation gate for reported port mismatches.
EOF
}

collect_default_ports() {
  local pidfile
  shopt -s nullglob
  for pidfile in "${LOG_DIR}"/chrome-agent-*.pid; do
    printf '%s\n' "${pidfile##*/chrome-agent-}" | sed 's/\.pid$//'
  done
  shopt -u nullglob
}

version_payload() {
  local port="$1"
  curl -sf "http://127.0.0.1:${port}/json/version" 2>/dev/null || true
}

list_payload() {
  local port="$1"
  curl -sf "http://127.0.0.1:${port}/json/list" 2>/dev/null || true
}

ports=("$@")
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if (( ${#ports[@]} == 0 )); then
  mapfile -t ports < <(collect_default_ports | sort -n | awk '!seen[$0]++')
fi

if (( ${#ports[@]} == 0 )); then
  echo "[chrome-devtools-mcp-port-check] No managed Chrome ports found."
  exit 0
fi

for port in "${ports[@]}"; do
  listener_pid="$(chrome_listener_pid "$port")"
  version="$(version_payload "$port")"
  targets="$(list_payload "$port")"
  python3 - "$port" "$listener_pid" "$version" "$targets" <<'PY'
import json
import sys

port = sys.argv[1]
listener_pid = sys.argv[2] or "missing"
version_payload = sys.argv[3]
targets_payload = sys.argv[4]

endpoint = "missing"
ws_url = ""
ws_port = ""
pages = 0
match = "unknown"

if version_payload.strip():
    endpoint = "reachable"
    try:
        version_data = json.loads(version_payload)
    except json.JSONDecodeError:
        version_data = {}
    ws_url = str(version_data.get("webSocketDebuggerUrl") or "").strip()
    if ws_url.startswith("ws://") and ":" in ws_url:
        try:
            ws_port = ws_url.split("://", 1)[1].split("/", 1)[0].rsplit(":", 1)[1]
        except Exception:
            ws_port = ""

if targets_payload.strip():
    try:
        targets = json.loads(targets_payload)
    except json.JSONDecodeError:
        targets = []
    pages = sum(1 for item in targets if str(item.get("type") or "") == "page")

if ws_port:
    match = "match" if ws_port == port else "mismatch"

print(f"[chrome-devtools-mcp-port-check] port={port} endpoint={endpoint} listener_pid={listener_pid} ws_port={ws_port or 'missing'} ws_match={match} pages={pages}")
if ws_url:
    print(f"[chrome-devtools-mcp-port-check]   websocket={ws_url}")
PY
done

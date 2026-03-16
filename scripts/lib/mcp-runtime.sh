#!/usr/bin/env bash

ROOT="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
CODEX_CONFIG_FILE="${CODEX_CONFIG_FILE:-${CODEX_HOME_DIR}/config.toml}"

config_server_enabled() {
  local server="$1"
  python3 - "$CODEX_CONFIG_FILE" "$server" <<'PY'
import pathlib
import sys
import tomllib

config_path = pathlib.Path(sys.argv[1])
server_name = sys.argv[2]

if not config_path.exists():
    raise SystemExit(4)

with config_path.open("rb") as handle:
    data = tomllib.load(handle)

servers = data.get("mcp_servers") or {}
server = servers.get(server_name)
if not isinstance(server, dict):
    raise SystemExit(3)

value = server.get("enabled", True)
print("true" if value else "false")
PY
}

find_matching_pids() {
  local regex="$1"
  ps -axo pid=,command= | awk -v self="$$" -v regex="$regex" '
    $1 == self { next }
    $0 ~ /(^|[[:space:]])(\/bin\/)?(bash|zsh|sh)[[:space:]]+-c[[:space:]]/ { next }
    $0 ~ regex { print $1 }
  '
}

collect_descendants() {
  local pid="$1"
  local child

  while IFS= read -r child; do
    [[ -n "$child" ]] || continue
    collect_descendants "$child"
    printf '%s\n' "$child"
  done < <(pgrep -P "$pid" 2>/dev/null || true)
}

kill_pid_tree() {
  local root_pid="$1"
  local label="${2:-$1}"
  local descendant

  if [[ -z "$root_pid" ]] || ! kill -0 "$root_pid" >/dev/null 2>&1; then
    return 0
  fi

  while IFS= read -r descendant; do
    [[ -n "$descendant" ]] || continue
    kill -TERM "$descendant" >/dev/null 2>&1 || true
  done < <(collect_descendants "$root_pid" | awk '!seen[$0]++')
  kill -TERM "$root_pid" >/dev/null 2>&1 || true
  sleep 0.5

  while IFS= read -r descendant; do
    [[ -n "$descendant" ]] || continue
    if kill -0 "$descendant" >/dev/null 2>&1; then
      kill -KILL "$descendant" >/dev/null 2>&1 || true
    fi
  done < <(collect_descendants "$root_pid" | awk '!seen[$0]++')
  if kill -0 "$root_pid" >/dev/null 2>&1; then
    kill -KILL "$root_pid" >/dev/null 2>&1 || true
  fi

  if kill -0 "$root_pid" >/dev/null 2>&1; then
    echo "[mcp-runtime] WARNING: process tree still alive after kill attempt: ${label} (pid=${root_pid})" >&2
    return 1
  fi
  return 0
}

process_command() {
  local pid="$1"
  ps -o command= -p "$pid" 2>/dev/null || true
}

process_parent_pid() {
  local pid="$1"
  ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ' || true
}

pid_is_descendant_of() {
  local ancestor="$1"
  local pid="$2"
  local current="$pid"
  local depth=0

  while [[ -n "$current" && "$current" =~ ^[0-9]+$ && "$current" != "0" && "$depth" -lt 32 ]]; do
    if [[ "$current" == "$ancestor" ]]; then
      return 0
    fi
    current="$(process_parent_pid "$current")"
    depth=$((depth + 1))
  done

  return 1
}

classify_codex_app_server_pid() {
  local pid="$1"
  local current="$pid"
  local depth=0
  local command=""

  while [[ -n "$current" && "$current" =~ ^[0-9]+$ && "$current" != "0" && "$depth" -lt 8 ]]; do
    command="$(process_command "$current")"
    case "$command" in
      *"/Applications/Codex.app/"*)
        echo "desktop"
        return 0
        ;;
      *"/Applications/Visual Studio Code.app/"*|*"/.vscode/extensions/"*|*"/Library/Application Support/Code"*)
        echo "vscode"
        return 0
        ;;
    esac
    current="$(process_parent_pid "$current")"
    depth=$((depth + 1))
  done

  echo "unknown"
}

list_codex_app_servers() {
  local pid
  local ppid
  local command

  while read -r pid ppid command; do
    [[ -n "$pid" ]] || continue
    [[ "$pid" == "$$" ]] && continue
    case "$command" in
      *" -c "*)
        continue
        ;;
    esac
    case "$command" in
      *"codex app-server"*)
        printf '%s\t%s\t%s\t%s\n' "$(classify_codex_app_server_pid "$pid")" "$pid" "$ppid" "$command"
        ;;
    esac
  done < <(ps -axo pid=,ppid=,command=)
}

chrome_wrapper_pids() {
  find_matching_pids "scripts/codex-chrome-devtools-mcp\\.sh"
}

shared_chrome_client_pids() {
  find_matching_pids "chrome-devtools-mcp --browserUrl http://127\\.0\\.0\\.1:9222"
}

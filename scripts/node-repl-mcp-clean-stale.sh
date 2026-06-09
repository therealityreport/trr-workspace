#!/usr/bin/env bash
set -euo pipefail

ACTIVE_EXECS_DIR="${NODE_REPL_ACTIVE_EXECS_DIR:-${CODEX_HOME:-${HOME}/.codex}/node_repl/active_execs}"
STALE_STAMP="${NODE_REPL_STALE_STAMP:-$(date -u +%Y%m%d%H%M%S)}"
PROJECT_ROOT="${NODE_REPL_PROJECT_ROOT:-}"
CLEAN_PROJECT_OWNED="${NODE_REPL_CLEAN_PROJECT_OWNED:-0}"

cleaned=0
retained_live=0
unreadable=0
retired_project_owned=0

pid_alive() {
  local pid="${1:-}"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  kill -0 "$pid" >/dev/null 2>&1
}

canonical_path() {
  python3 - "$1" <<'PY'
import sys
from pathlib import Path

try:
    print(Path(sys.argv[1]).resolve())
except Exception:
    raise SystemExit(1)
PY
}

pid_cwd() {
  local pid="${1:-}"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | head -n 1
}

pid_command() {
  local pid="${1:-}"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  ps -p "$pid" -o command= 2>/dev/null | head -n 1
}

path_is_under_project_root() {
  local path="${1:-}"
  local resolved_path resolved_root

  [[ -n "$PROJECT_ROOT" && -n "$path" ]] || return 1
  resolved_path="$(canonical_path "$path" 2>/dev/null)" || return 1
  resolved_root="$(canonical_path "$PROJECT_ROOT" 2>/dev/null)" || return 1

  [[ "$resolved_path" == "$resolved_root" || "$resolved_path" == "$resolved_root"/* ]]
}

pid_is_project_owned_node_repl() {
  local pid="${1:-}"
  local cwd command

  [[ "$CLEAN_PROJECT_OWNED" == "1" ]] || return 1
  pid_alive "$pid" || return 1

  cwd="$(pid_cwd "$pid" 2>/dev/null || true)"
  command="$(pid_command "$pid" 2>/dev/null || true)"
  [[ "$command" == *node_repl* ]] || return 1
  path_is_under_project_root "$cwd"
}

marker_pids() {
  local marker="$1"
  python3 - "$marker" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
try:
    payload = json.loads(path.read_text(encoding="utf-8"))
except Exception:
    raise SystemExit(1)

for key in ("nodeReplPid", "kernelPid"):
    value = payload.get(key)
    print(f"{key}={value if value is not None else ''}")
PY
}

move_stale_marker() {
  local marker="$1"
  local target="${marker}.stale-${STALE_STAMP}"
  local suffix=1

  while [[ -e "$target" ]]; do
    target="${marker}.stale-${STALE_STAMP}.${suffix}"
    suffix=$((suffix + 1))
  done

  mv "$marker" "$target"
  cleaned=$((cleaned + 1))
}

retire_project_owned_marker() {
  local marker="$1"
  local node_repl_pid="$2"

  pid_is_project_owned_node_repl "$node_repl_pid" || return 1
  kill "$node_repl_pid" >/dev/null 2>&1 || true
  retired_project_owned=$((retired_project_owned + 1))
  move_stale_marker "$marker"
}

if [[ -d "$ACTIVE_EXECS_DIR" ]]; then
  shopt -s nullglob
  for marker in "${ACTIVE_EXECS_DIR}"/*.json; do
    pids_output=""
    if ! pids_output="$(marker_pids "$marker" 2>/dev/null)"; then
      unreadable=$((unreadable + 1))
      move_stale_marker "$marker"
      continue
    fi

    node_repl_pid="$(printf '%s\n' "$pids_output" | sed -n 's/^nodeReplPid=//p' | head -n 1)"
    kernel_pid="$(printf '%s\n' "$pids_output" | sed -n 's/^kernelPid=//p' | head -n 1)"

    if pid_alive "$node_repl_pid" || pid_alive "$kernel_pid"; then
      if retire_project_owned_marker "$marker" "$node_repl_pid"; then
        continue
      fi
      retained_live=$((retained_live + 1))
      continue
    fi

    move_stale_marker "$marker"
  done
  shopt -u nullglob
fi

echo "[node-repl-mcp] Stale in-app Browser exec markers cleaned: ${cleaned} (retained_live=${retained_live}, unreadable=${unreadable}, retired_project_owned=${retired_project_owned})"

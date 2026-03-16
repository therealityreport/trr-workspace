#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT}/scripts/lib/mcp-runtime.sh"

LOG_DIR="${ROOT}/.logs/workspace"
SHARED_WRAPPER_PIDFILE="${LOG_DIR}/codex-chrome-shared-wrapper-9222.pid"

shared_wrapper_killed=0
shared_client_killed=0

choose_keeper_wrapper() {
  local keep=""
  local wrappers=""

  if [[ -f "$SHARED_WRAPPER_PIDFILE" ]]; then
    keep="$(cat "$SHARED_WRAPPER_PIDFILE" 2>/dev/null || true)"
    if [[ -n "$keep" ]] && ! kill -0 "$keep" >/dev/null 2>&1; then
      keep=""
    fi
  fi

  if [[ -n "$keep" ]]; then
    echo "$keep"
    return 0
  fi

  wrappers="$(chrome_wrapper_pids | awk '!seen[$0]++' | sort -n)"
  if [[ -n "$wrappers" ]]; then
    echo "$wrappers" | tail -n 1
  fi
}

kill_stale_shared_chrome_processes() {
  local keeper_wrapper
  local wrapper_pid
  local client_pid
  local has_shared_client
  local covered_by_live_wrapper

  keeper_wrapper="$(choose_keeper_wrapper)"

  while IFS= read -r wrapper_pid; do
    [[ -n "$wrapper_pid" ]] || continue
    if [[ -n "$keeper_wrapper" && "$wrapper_pid" == "$keeper_wrapper" ]]; then
      continue
    fi

    has_shared_client=0
    while IFS= read -r client_pid; do
      [[ -n "$client_pid" ]] || continue
      if pid_is_descendant_of "$wrapper_pid" "$client_pid"; then
        has_shared_client=1
        break
      fi
    done < <(shared_chrome_client_pids | awk '!seen[$0]++')

    if [[ "$has_shared_client" == "1" ]]; then
      if kill_pid_tree "$wrapper_pid" "chrome-shared-wrapper"; then
        shared_wrapper_killed=$((shared_wrapper_killed + 1))
      fi
    fi
  done < <(chrome_wrapper_pids | awk '!seen[$0]++')

  while IFS= read -r client_pid; do
    [[ -n "$client_pid" ]] || continue
    covered_by_live_wrapper=0
    while IFS= read -r wrapper_pid; do
      [[ -n "$wrapper_pid" ]] || continue
      if pid_is_descendant_of "$wrapper_pid" "$client_pid"; then
        covered_by_live_wrapper=1
        break
      fi
    done < <(chrome_wrapper_pids | awk '!seen[$0]++')

    if [[ "$covered_by_live_wrapper" == "0" ]]; then
      if kill_pid_tree "$client_pid" "chrome-shared-client"; then
        shared_client_killed=$((shared_client_killed + 1))
      fi
    fi
  done < <(shared_chrome_client_pids | awk '!seen[$0]++')
}

kill_stale_shared_chrome_processes
chrome_clean_output="$(bash "${ROOT}/scripts/chrome-devtools-mcp-clean-stale.sh")"

echo "[mcp-clean] Stale shared wrapper trees killed: ${shared_wrapper_killed}"
echo "[mcp-clean] Orphan shared clients killed: ${shared_client_killed}"
echo "${chrome_clean_output}"

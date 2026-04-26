#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT}/scripts/lib/mcp-runtime.sh"

LOG_DIR="${ROOT}/.logs/workspace"
SHARED_WRAPPER_PIDFILE="${LOG_DIR}/codex-chrome-shared-wrapper-9422.pid"
SOAK_MODE=0
SOAK_ITERATIONS="${MCP_CLEAN_SOAK_ITERATIONS:-3}"
SOAK_SLEEP_SEC="${MCP_CLEAN_SOAK_SLEEP_SEC:-1}"

shared_wrapper_killed=0
shared_client_killed=0
reaper_output=""
chrome_clean_output=""

cleanup_chrome_dock_recents_if_requested() {
  [[ "${CHROME_AGENT_CLEAN_DOCK_RECENTS:-0}" == "1" ]] || return 0
  [[ "$(uname)" == "Darwin" ]] || return 0
  bash "${ROOT}/scripts/cleanup-chrome-dock-recents.sh" 2>&1 || true
}

usage() {
  cat <<'EOF'
Usage:
  mcp-clean.sh
  mcp-clean.sh --soak

Options:
  --soak   Run repeated cleanup cycles with pre/post validation snapshots.
EOF
}

run_status_summary() {
  CHROME_DEVTOOLS_MCP_STATUS_MODE=summary bash "${ROOT}/scripts/chrome-devtools-mcp-status.sh" 2>&1 || true
}

run_reaper_diagnose() {
  bash "${ROOT}/scripts/codex-mcp-session-reaper.sh" diagnose 2>&1 || true
}

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

run_cleanup_once() {
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

emit_cleanup_results() {
  local dock_clean_output=""

  echo "[mcp-clean] Stale shared wrapper trees killed: ${shared_wrapper_killed}"
  echo "[mcp-clean] Orphan shared clients killed: ${shared_client_killed}"
  echo "${reaper_output}"
  echo "${chrome_clean_output}"

  dock_clean_output="$(cleanup_chrome_dock_recents_if_requested)"
  if [[ -n "$dock_clean_output" ]]; then
    echo "${dock_clean_output}"
  fi
}

run_cleanup_cycle() {
  run_cleanup_once
  reaper_output="$(bash "${ROOT}/scripts/codex-mcp-session-reaper.sh" reap)"
  chrome_clean_output="$(bash "${ROOT}/scripts/chrome-devtools-mcp-clean-stale.sh")"
  emit_cleanup_results
}

run_soak_validation() {
  local iteration

  if ! [[ "$SOAK_ITERATIONS" =~ ^[0-9]+$ ]] || (( SOAK_ITERATIONS < 1 )); then
    SOAK_ITERATIONS=3
  fi
  if ! [[ "$SOAK_SLEEP_SEC" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    SOAK_SLEEP_SEC=1
  fi

  echo "[mcp-clean] Soak validation: iterations=${SOAK_ITERATIONS} sleep=${SOAK_SLEEP_SEC}s"
  echo "[mcp-clean] Pre-clean pressure snapshot:"
  run_status_summary
  echo "[mcp-clean] Pre-clean orphan snapshot:"
  run_reaper_diagnose

  for ((iteration = 1; iteration <= SOAK_ITERATIONS; iteration++)); do
    echo "[mcp-clean] Cleanup cycle ${iteration}/${SOAK_ITERATIONS}"
    run_cleanup_cycle
    if (( iteration < SOAK_ITERATIONS )); then
      sleep "$SOAK_SLEEP_SEC"
    fi
  done

  echo "[mcp-clean] Post-clean pressure snapshot:"
  run_status_summary
  echo "[mcp-clean] Post-clean orphan snapshot:"
  run_reaper_diagnose
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --soak)
      SOAK_MODE=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[mcp-clean] ERROR: unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

if [[ "$SOAK_MODE" == "1" ]]; then
  run_soak_validation
  exit 0
fi

run_cleanup_cycle

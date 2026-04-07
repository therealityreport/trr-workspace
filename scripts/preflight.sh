#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

source "$ROOT/scripts/lib/node-baseline.sh"
source "$ROOT/scripts/lib/preflight-diagnostics.sh"
source "$ROOT/scripts/lib/runtime-db-env.sh"
source "$ROOT/scripts/lib/workspace-terminal.sh"

preflight_diag_init "preflight.sh" "$ROOT" "preflight"

ATTENTION_FILE="$(workspace_attention_file "$ROOT")"
workspace_attention_reset "$ATTENTION_FILE"

record_browser_attention() {
  local output="$1"
  local pressure=""
  local port=""

  pressure="$(printf '%s\n' "$output" | sed -n 's/.*local browser pressure is \([^ .][^.]*\)\(.|\)*$/\1/p' | head -n 1)"
  if [[ -n "$pressure" ]]; then
    workspace_attention_add \
      "$ATTENTION_FILE" \
      "Browser automation pressure is ${pressure}." \
      "Impact: chrome-devtools is available, but local browser pressure is elevated." \
      "Remediation: run 'make mcp-clean' if stale Chrome runtime artifacts or external MCP leftovers are not expected."
    return 0
  fi

  if printf '%s\n' "$output" | grep -q "shared Chrome is not responding on port"; then
    port="$(printf '%s\n' "$output" | sed -n 's/.*shared Chrome is not responding on port \([0-9][0-9]*\).*/\1/p' | head -n 1)"
    workspace_attention_add \
      "$ATTENTION_FILE" \
      "Browser automation shared Chrome is not responding${port:+ on port ${port}}." \
      "Impact: chrome-devtools registration is present, but the shared browser runtime is unavailable." \
      "Remediation: run 'make mcp-clean' and retry the workspace startup."
  fi
}

emit_preflight_phase_output() {
  local phase="$1"
  local rc="$2"
  local output="$3"

  [[ -n "$output" ]] || return 0

  if [[ "$rc" != "0" ]]; then
    printf '%s\n' "$output"
    return 0
  fi

  case "$phase" in
    doctor)
      printf '%s\n' "$output"
      ;;
    env-contract)
      echo "[preflight] Env contract OK"
      ;;
    env-contract-generate)
      echo "[preflight] Env contract regenerated"
      ;;
    env-contract-verify)
      echo "[preflight] Env contract re-validated"
      ;;
    env-contract-report)
      echo "[preflight] Env contract reports OK"
      ;;
    env-contract-report-write)
      echo "[preflight] Env contract reports regenerated"
      ;;
    env-contract-report-verify)
      echo "[preflight] Env contract reports re-validated"
      ;;
    handoff-sync)
      echo "[preflight] Handoffs synced"
      ;;
    check-policy)
      echo "[preflight] Policy checks OK"
      ;;
    chrome-devtools-mcp-status)
      record_browser_attention "$output"
      if [[ -s "$ATTENTION_FILE" ]]; then
        echo "[preflight] Browser automation checked (startup attention recorded)"
      else
        echo "[preflight] Browser automation checked"
      fi
      ;;
    *)
      printf '%s\n' "$output"
      ;;
  esac
}

run_preflight_phase() {
  local phase="$1"
  local message="$2"
  shift 2

  local command_display start_ms end_ms elapsed_ms child_pid rc child_script="" phase_output=""

  echo "$message"
  command_display="$(preflight_diag_render_command "$@")"
  preflight_diag_set_phase "$phase"

  if ! preflight_diag_is_enabled; then
    set +e
    phase_output="$("$@" 2>&1)"
    rc="$?"
    set -e
    emit_preflight_phase_output "$phase" "$rc" "$phase_output"
    preflight_diag_set_phase "idle"
    return "$rc"
  fi

  start_ms="$(preflight_diag_now_ms)"
  perl -e '
    $SIG{INT} = "DEFAULT";
    $SIG{TERM} = "DEFAULT";
    $SIG{HUP} = "DEFAULT";
    exec @ARGV or die "exec failed: $!";
  ' "$@" &
  child_pid="$!"
  if [[ "${1:-}" == "bash" && "${2:-}" == *.sh ]]; then
    child_script="${2##*/}"
  fi
  export WORKSPACE_PREFLIGHT_DIAGNOSTICS_ACTIVE_CHILD_PID="$child_pid"
  export WORKSPACE_PREFLIGHT_DIAGNOSTICS_ACTIVE_CHILD_COMMAND="$command_display"
  export WORKSPACE_PREFLIGHT_DIAGNOSTICS_ACTIVE_CHILD_SCRIPT="$child_script"
  preflight_diag_log_event phase_start child_pid "$child_pid" command "$command_display"

  set +e
  wait "$child_pid"
  rc="$?"
  set -e

  end_ms="$(preflight_diag_now_ms)"
  elapsed_ms="$((end_ms - start_ms))"
  preflight_diag_log_event phase_end child_pid "$child_pid" exit_code "$rc" elapsed_ms "$elapsed_ms" command "$command_display"
  unset WORKSPACE_PREFLIGHT_DIAGNOSTICS_ACTIVE_CHILD_PID
  unset WORKSPACE_PREFLIGHT_DIAGNOSTICS_ACTIVE_CHILD_COMMAND
  unset WORKSPACE_PREFLIGHT_DIAGNOSTICS_ACTIVE_CHILD_SCRIPT
  preflight_diag_set_phase "idle"
  return "$rc"
}

preflight_on_signal() {
  local signal_name="$1"
  local active_child="${WORKSPACE_PREFLIGHT_DIAGNOSTICS_ACTIVE_CHILD_PID:-}"
  local active_child_script="${WORKSPACE_PREFLIGHT_DIAGNOSTICS_ACTIVE_CHILD_SCRIPT:-}"
  local child_signal_logged="0"
  export WORKSPACE_PREFLIGHT_DIAGNOSTICS_EXIT_CODE="$(preflight_diag_signal_exit_code "$signal_name")"
  preflight_diag_log_event signal_received signal "$signal_name"
  if [[ -n "$active_child" ]] && kill -0 "$active_child" >/dev/null 2>&1; then
    if [[ -n "$active_child_script" && -n "${WORKSPACE_PREFLIGHT_DIAGNOSTICS_LOGFILE:-}" ]]; then
      local _attempt
      for _attempt in 1 2 3 4 5; do
        if rg -Fq "event=signal_received script=${active_child_script}" "${WORKSPACE_PREFLIGHT_DIAGNOSTICS_LOGFILE}"; then
          child_signal_logged="1"
          break
        fi
        if ! kill -0 "$active_child" >/dev/null 2>&1; then
          break
        fi
        sleep 0.05
      done
      if [[ "$child_signal_logged" != "1" ]] && kill -0 "$active_child" >/dev/null 2>&1; then
        kill -s "$signal_name" "$active_child" >/dev/null 2>&1 || true
      fi
      for _attempt in 1 2 3 4 5 6 7 8 9 10; do
        if rg -Fq "event=signal_received script=${active_child_script}" "${WORKSPACE_PREFLIGHT_DIAGNOSTICS_LOGFILE}"; then
          break
        fi
        if ! kill -0 "$active_child" >/dev/null 2>&1; then
          break
        fi
        sleep 0.1
      done
    else
      kill -s "$signal_name" "$active_child" >/dev/null 2>&1 || true
      sleep 0.2
    fi
  fi
  preflight_diag_log_snapshot "signal_${signal_name}"
  trap - "$signal_name"
  kill -s "$signal_name" "$$"
}

preflight_on_exit() {
  local rc="$?"
  if [[ -n "${WORKSPACE_PREFLIGHT_DIAGNOSTICS_EXIT_CODE:-}" ]]; then
    rc="$WORKSPACE_PREFLIGHT_DIAGNOSTICS_EXIT_CODE"
  fi
  preflight_diag_log_event exit exit_code "$rc"
}

if preflight_diag_is_enabled; then
  echo "[preflight] Diagnostics log: ${WORKSPACE_PREFLIGHT_DIAGNOSTICS_LOGFILE}"
  preflight_diag_log_event session_start log_file "${WORKSPACE_PREFLIGHT_DIAGNOSTICS_LOGFILE}"
  trap preflight_on_exit EXIT
  trap 'preflight_on_signal INT' INT
  trap 'preflight_on_signal TERM' TERM
  trap 'preflight_on_signal HUP' HUP
fi

REQUIRED_NODE_MAJOR="$(trr_node_required_major "$ROOT")"
if ! trr_ensure_node_baseline "$ROOT"; then
  echo "[preflight] ERROR: Node $(trr_node_version_string) does not satisfy required ${REQUIRED_NODE_MAJOR}.x baseline." >&2
  echo "[preflight] Remediation:" >&2
  echo "[preflight]   source ~/.nvm/nvm.sh && nvm use ${REQUIRED_NODE_MAJOR}" >&2
  echo "[preflight]   source ~/.nvm/nvm.sh && nvm install ${REQUIRED_NODE_MAJOR}" >&2
  exit 1
fi

WORKSPACE_DEV_MODE="${WORKSPACE_DEV_MODE:-cloud}"
case "$WORKSPACE_DEV_MODE" in
  cloud|local_docker) ;;
  *)
    echo "[preflight] ERROR: invalid WORKSPACE_DEV_MODE='${WORKSPACE_DEV_MODE}' (expected cloud for the preferred no-Docker path or local_docker for the explicit Docker fallback)." >&2
    exit 1
    ;;
esac

WORKSPACE_PREFLIGHT_STRICT="${WORKSPACE_PREFLIGHT_STRICT:-0}"

if [[ "$WORKSPACE_DEV_MODE" == "local_docker" ]]; then
  echo "[preflight] Mode: local_docker (explicit Docker fallback)"
else
  echo "[preflight] Mode: cloud (preferred no-Docker path)"
fi

if ! trr_runtime_db_require_local_app_url "$ROOT" "preflight"; then
  exit 1
fi

run_preflight_phase "doctor" "[preflight] Running workspace doctor..." env WORKSPACE_DEV_MODE="$WORKSPACE_DEV_MODE" WORKSPACE_PREFLIGHT_STRICT="$WORKSPACE_PREFLIGHT_STRICT" bash "$ROOT/scripts/doctor.sh"

env_contract_rc=0
run_preflight_phase "env-contract" "[preflight] Validating generated env contract..." bash "$ROOT/scripts/workspace-env-contract.sh" --check || env_contract_rc="$?"
if [[ "$env_contract_rc" != "0" ]]; then
  if [[ "$WORKSPACE_PREFLIGHT_STRICT" == "1" ]]; then
    exit "$env_contract_rc"
  fi
  echo "[preflight] WARNING: generated env contract is out of date; regenerating because WORKSPACE_PREFLIGHT_STRICT=0." >&2
  run_preflight_phase "env-contract-generate" "[preflight] Regenerating generated env contract..." bash "$ROOT/scripts/workspace-env-contract.sh" --generate
  env_contract_rc=0
  run_preflight_phase "env-contract-verify" "[preflight] Re-validating generated env contract..." bash "$ROOT/scripts/workspace-env-contract.sh" --check || env_contract_rc="$?"
  if [[ "$env_contract_rc" != "0" ]]; then
    echo "[preflight] ERROR: env contract is still out of date after regeneration." >&2
    exit "$env_contract_rc"
  fi
  echo "[preflight] NOTE: generated env contract was refreshed in-place; review and commit docs/workspace/env-contract.md if the new baseline is intended." >&2
fi

env_contract_report_rc=0
run_preflight_phase "env-contract-report" "[preflight] Validating env contract reports..." python3 "$ROOT/scripts/env_contract_report.py" validate || env_contract_report_rc="$?"
if [[ "$env_contract_report_rc" != "0" ]]; then
  if [[ "$WORKSPACE_PREFLIGHT_STRICT" == "1" ]]; then
    exit "$env_contract_report_rc"
  fi
  echo "[preflight] WARNING: env contract reports are out of date; regenerating because WORKSPACE_PREFLIGHT_STRICT=0." >&2
  run_preflight_phase "env-contract-report-write" "[preflight] Regenerating env contract reports..." python3 "$ROOT/scripts/env_contract_report.py" write
  env_contract_report_rc=0
  run_preflight_phase "env-contract-report-verify" "[preflight] Re-validating env contract reports..." python3 "$ROOT/scripts/env_contract_report.py" validate || env_contract_report_rc="$?"
  if [[ "$env_contract_report_rc" != "0" ]]; then
    echo "[preflight] ERROR: env contract reports are still out of date after regeneration." >&2
    exit "$env_contract_report_rc"
  fi
  echo "[preflight] NOTE: env contract reports were refreshed in-place; review and commit docs/workspace/env-contract-inventory.md, docs/workspace/env-deprecations.md, and docs/workspace/vercel-env-review.md if the new baseline is intended." >&2
fi

run_preflight_phase "handoff-sync" "[preflight] Syncing generated handoffs..." python3 "$ROOT/scripts/sync-handoffs.py" --write

run_preflight_phase "check-policy" "[preflight] Checking policy drift rules..." bash "$ROOT/scripts/check-policy.sh"

run_preflight_phase "chrome-devtools-mcp-status" "[preflight] Checking browser automation..." env CHROME_DEVTOOLS_MCP_STATUS_MODE=summary bash "$ROOT/scripts/chrome-devtools-mcp-status.sh"

if [[ -d "$ROOT/.playwright-mcp" && "${WORKSPACE_PREFLIGHT_DIAGNOSTICS:-0}" == "1" ]]; then
  echo "[preflight] NOTE: '$ROOT/.playwright-mcp' exists and is treated as legacy/local-only." >&2
  echo "[preflight] NOTE: Workspace policy is Chrome DevTools MCP only." >&2
fi

echo "[preflight] OK"

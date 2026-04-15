#!/usr/bin/env bash

preflight_handle_handoff_sync_result() {
  local strict_mode="$1"
  local handoff_rc="$2"
  local handoff_output="${3:-}"

  if [[ "$handoff_rc" == "0" ]]; then
    return 0
  fi

  if [[ "$strict_mode" == "1" ]]; then
    return "$handoff_rc"
  fi

  echo "[preflight] WARNING: handoff sync failed; continuing because WORKSPACE_PREFLIGHT_STRICT=0."
  if [[ -n "$handoff_output" ]]; then
    printf '%s\n' "$handoff_output"
  fi
  echo "[preflight] Remediation: run 'make handoff-check' or 'make preflight-strict' for the blocking validation path."
  return 0
}

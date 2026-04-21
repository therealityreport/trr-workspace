#!/usr/bin/env bash

preflight_handle_env_contract_result() {
  local strict_mode="$1"
  local env_contract_rc="$2"
  local env_contract_output="${3:-}"

  if [[ "$env_contract_rc" == "0" ]]; then
    return 0
  fi

  if [[ "$strict_mode" == "1" ]]; then
    return "$env_contract_rc"
  fi

  echo "[preflight] WARNING: generated env contract is out of date; continuing because WORKSPACE_PREFLIGHT_STRICT=0."
  if [[ -n "$env_contract_output" ]]; then
    printf '%s\n' "$env_contract_output"
  fi
  echo "[preflight] Remediation: run 'make env-contract' to refresh docs/workspace/env-contract.md."
  return 0
}

preflight_handle_env_contract_report_result() {
  local strict_mode="$1"
  local env_contract_report_rc="$2"
  local env_contract_report_output="${3:-}"

  if [[ "$env_contract_report_rc" == "0" ]]; then
    return 0
  fi

  if [[ "$strict_mode" == "1" ]]; then
    return "$env_contract_report_rc"
  fi

  echo "[preflight] WARNING: env contract reports are out of date; continuing because WORKSPACE_PREFLIGHT_STRICT=0."
  if [[ -n "$env_contract_report_output" ]]; then
    printf '%s\n' "$env_contract_report_output"
  fi
  echo "[preflight] Remediation: run 'make env-contract-report' to refresh docs/workspace/env-contract-inventory.md, docs/workspace/env-deprecations.md, and docs/workspace/vercel-env-review.md."
  return 0
}

#!/usr/bin/env bash

chrome_devtools_status_emit_field() {
  local key="$1"
  local value="$2"
  printf '%s=%s\n' "$key" "$value"
}

chrome_devtools_status_value() {
  local output="$1"
  local key="$2"
  printf '%s\n' "$output" | sed -n "s/^${key}=//p" | head -n 1
}

chrome_devtools_transport_repair_classify() {
  local output="${1:-}"
  local overall_state
  local attention_kind
  local shared_runtime_state
  local pressure_state
  local shared_port
  local repair_action="none"
  local repair_reason="ready"

  overall_state="$(chrome_devtools_status_value "$output" "overall_state")"
  attention_kind="$(chrome_devtools_status_value "$output" "attention_kind")"
  shared_runtime_state="$(chrome_devtools_status_value "$output" "shared_runtime_state")"
  pressure_state="$(chrome_devtools_status_value "$output" "pressure_state")"
  shared_port="$(chrome_devtools_status_value "$output" "shared_port")"

  if [[ "$attention_kind" == "unavailable" || "$overall_state" == "unavailable" || "$shared_runtime_state" == "unavailable" ]]; then
    repair_action="repair"
    repair_reason="shared_runtime_unavailable"
  elif [[ "$pressure_state" == "unsafe" ]]; then
    repair_action="repair"
    repair_reason="unsafe_stale_runtime"
  elif [[ "$overall_state" == "recoverable" || "$shared_runtime_state" == "recoverable" ]]; then
    repair_reason="recoverable_auto_launch"
  elif [[ "$overall_state" == "degraded" ]]; then
    repair_reason="degraded_nonblocking"
  elif [[ -n "$overall_state" ]]; then
    repair_reason="$overall_state"
  else
    repair_reason="unknown"
  fi

  chrome_devtools_status_emit_field "repair_action" "$repair_action"
  chrome_devtools_status_emit_field "repair_reason" "$repair_reason"
  chrome_devtools_status_emit_field "overall_state" "$overall_state"
  chrome_devtools_status_emit_field "attention_kind" "$attention_kind"
  chrome_devtools_status_emit_field "shared_runtime_state" "$shared_runtime_state"
  chrome_devtools_status_emit_field "pressure_state" "$pressure_state"
  chrome_devtools_status_emit_field "shared_port" "$shared_port"
}

chrome_devtools_status_classify() {
  local wrapper_mode="$1"
  local shared_endpoint_state="$2"
  local pressure_state="$3"
  local shared_auto_launch="$4"
  local wrapper_smoke_ok="$5"
  local shared_port="${6:-9422}"
  local chrome_rss_mb="${7:-}"
  local shared_clients="${8:-}"
  local managed_roots="${9:-}"
  local conflicts="${10:-}"
  local overall_state="ready"
  local attention_kind="none"
  local shared_runtime_state="n/a"

  if [[ "$wrapper_smoke_ok" != "1" ]]; then
    overall_state="unavailable"
    attention_kind="unavailable"
    shared_runtime_state="unavailable"
  elif [[ "$wrapper_mode" == "isolated" ]]; then
    if [[ "$pressure_state" != "safe" ]]; then
      overall_state="degraded"
      attention_kind="pressure"
    fi
  elif [[ "$shared_endpoint_state" == "reachable" ]]; then
    shared_runtime_state="ready"
    if [[ "$pressure_state" != "safe" ]]; then
      overall_state="degraded"
      attention_kind="pressure"
    fi
  elif [[ "$shared_auto_launch" == "1" ]]; then
    overall_state="recoverable"
    attention_kind="none"
    shared_runtime_state="recoverable"
  else
    overall_state="unavailable"
    attention_kind="unavailable"
    shared_runtime_state="unavailable"
  fi

  chrome_devtools_status_emit_field "overall_state" "$overall_state"
  chrome_devtools_status_emit_field "attention_kind" "$attention_kind"
  chrome_devtools_status_emit_field "wrapper_mode" "$wrapper_mode"
  chrome_devtools_status_emit_field "pressure_state" "$pressure_state"
  chrome_devtools_status_emit_field "shared_endpoint_state" "$shared_endpoint_state"
  chrome_devtools_status_emit_field "shared_auto_launch" "$shared_auto_launch"
  chrome_devtools_status_emit_field "shared_runtime_state" "$shared_runtime_state"
  chrome_devtools_status_emit_field "shared_port" "$shared_port"
  chrome_devtools_status_emit_field "chrome_rss_mb" "$chrome_rss_mb"
  chrome_devtools_status_emit_field "shared_clients" "$shared_clients"
  chrome_devtools_status_emit_field "managed_roots" "$managed_roots"
  chrome_devtools_status_emit_field "conflicts" "$conflicts"
}

#!/usr/bin/env bash

chrome_devtools_status_emit_field() {
  local key="$1"
  local value="$2"
  printf '%s=%s\n' "$key" "$value"
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

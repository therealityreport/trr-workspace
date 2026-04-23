#!/usr/bin/env bash

workspace_backend_readiness_url() {
  local port="$1"
  printf 'http://127.0.0.1:%s/health\n' "$port"
}

workspace_backend_liveness_url() {
  local port="$1"
  printf 'http://127.0.0.1:%s/health/live\n' "$port"
}

workspace_backend_watchdog_url() {
  workspace_backend_liveness_url "$1"
}

workspace_backend_status_readiness_url() {
  workspace_backend_readiness_url "$1"
}

workspace_backend_status_liveness_url() {
  workspace_backend_liveness_url "$1"
}

workspace_backend_readiness_label() {
  local readiness_ok="$1"
  local liveness_ok="$2"
  if [[ "$readiness_ok" == "1" ]]; then
    printf 'healthy\n'
    return 0
  fi
  if [[ "$liveness_ok" == "1" ]]; then
    printf 'degraded/slow\n'
    return 0
  fi
  printf 'hung/unresponsive\n'
}

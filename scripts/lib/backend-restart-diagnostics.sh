#!/usr/bin/env bash

backend_restart_json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

backend_restart_exit_signal() {
  local status="$1"
  if [[ "$status" =~ ^[0-9]+$ ]] && (( status >= 128 )); then
    printf '%s\n' "$((status - 128))"
    return 0
  fi
  printf '\n'
}

backend_restart_event_json() {
  local ts="$1"
  local event="$2"
  local reason="$3"
  local probe_rc="$4"
  local count="$5"
  local details="$6"
  local manager_pid="$7"
  local backend_pid="$8"
  local backend_pgid="$9"
  local listeners="${10}"
  local killer_path="${11}"
  local exit_status="${12}"
  local exit_signal="${13}"

  printf '{"ts":"%s","event":"%s","reason":"%s","probe_rc":"%s","count":%s,"details":"%s","manager_pid":"%s","backend_pid":"%s","backend_pgid":"%s","listeners":"%s","killer_path":"%s","exit_status":"%s","exit_signal":"%s"}\n' \
    "$(backend_restart_json_escape "$ts")" \
    "$(backend_restart_json_escape "$event")" \
    "$(backend_restart_json_escape "$reason")" \
    "$(backend_restart_json_escape "$probe_rc")" \
    "$count" \
    "$(backend_restart_json_escape "$details")" \
    "$(backend_restart_json_escape "$manager_pid")" \
    "$(backend_restart_json_escape "$backend_pid")" \
    "$(backend_restart_json_escape "$backend_pgid")" \
    "$(backend_restart_json_escape "$listeners")" \
    "$(backend_restart_json_escape "$killer_path")" \
    "$(backend_restart_json_escape "$exit_status")" \
    "$(backend_restart_json_escape "$exit_signal")"
}

backend_restart_archive_segment() {
  local log_path="$1"
  local segment_dir="$2"
  local backend_pid="$3"
  local reason="$4"
  local ts="$5"
  local keep="${6:-10}"
  local start_line="${7:-}"

  if [[ ! -f "$log_path" || ! -s "$log_path" ]]; then
    return 0
  fi

  mkdir -p "$segment_dir"

  local safe_reason
  safe_reason="$(printf '%s' "$reason" | tr -c 'A-Za-z0-9_.-' '_')"
  local segment_path="${segment_dir}/${ts}-pid-${backend_pid:-unknown}-${safe_reason}.log"
  if [[ "$start_line" =~ ^[1-9][0-9]*$ ]]; then
    sed -n "${start_line},\$p" "$log_path" > "$segment_path"
  else
    cp "$log_path" "$segment_path"
  fi
  printf '%s\n' "$segment_path"

  if [[ "$keep" =~ ^[1-9][0-9]*$ ]]; then
    local total remove_count
    total="$(find "$segment_dir" -type f -name '*.log' -print | wc -l | tr -d ' ')"
    if [[ "$total" =~ ^[0-9]+$ ]] && (( total > keep )); then
      remove_count=$((total - keep))
      find "$segment_dir" -type f -name '*.log' -print | sort | sed -n "1,${remove_count}p" | xargs rm -f 2>/dev/null || true
    fi
  fi
}

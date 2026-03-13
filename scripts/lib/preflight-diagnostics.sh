#!/usr/bin/env bash

preflight_diag_is_enabled() {
  [[ "${WORKSPACE_PREFLIGHT_DIAGNOSTICS:-0}" == "1" ]]
}

preflight_diag_now_utc() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

preflight_diag_now_ms() {
  perl -MTime::HiRes=time -e 'printf "%.0f\n", time() * 1000'
}

preflight_diag_signal_exit_code() {
  case "${1:-}" in
    INT)
      echo 130
      ;;
    HUP)
      echo 129
      ;;
    TERM)
      echo 143
      ;;
    *)
      echo 1
      ;;
  esac
}

preflight_diag_exit_code_signal_name() {
  case "${1:-}" in
    130)
      echo "INT"
      ;;
    129)
      echo "HUP"
      ;;
    143)
      echo "TERM"
      ;;
    *)
      echo ""
      ;;
  esac
}

preflight_diag_quote() {
  printf '%q' "${1:-}"
}

preflight_diag_ps_field() {
  local field="$1"
  local pid="${2:-$$}"
  ps -o "${field}=" -p "$pid" 2>/dev/null | awk '{$1=$1; print}'
}

preflight_diag_parent_command() {
  local parent_pid="${1:-$PPID}"
  ps -o command= -p "$parent_pid" 2>/dev/null | awk '{$1=$1; print}'
}

preflight_diag_tty() {
  local tty_name
  tty_name="$(preflight_diag_ps_field tty "$$")"
  if [[ -n "$tty_name" && "$tty_name" != "?" && "$tty_name" != "??" ]]; then
    echo "$tty_name"
    return 0
  fi
  echo "none"
}

preflight_diag_render_command() {
  local rendered=""
  local arg

  for arg in "$@"; do
    if [[ -n "$rendered" ]]; then
      rendered+=" "
    fi
    rendered+="$(preflight_diag_quote "$arg")"
  done

  printf '%s' "$rendered"
}

preflight_diag_write() {
  local line="$1"
  if ! preflight_diag_is_enabled || [[ -z "${WORKSPACE_PREFLIGHT_DIAGNOSTICS_LOGFILE:-}" ]]; then
    return 0
  fi
  printf '%s\n' "$line" >>"$WORKSPACE_PREFLIGHT_DIAGNOSTICS_LOGFILE"
}

preflight_diag_set_phase() {
  export WORKSPACE_PREFLIGHT_DIAGNOSTICS_PHASE="${1:-idle}"
}

preflight_diag_log_event() {
  local event="$1"
  shift

  if ! preflight_diag_is_enabled; then
    return 0
  fi

  local pid ppid pgid sid tty_name parent_command line key value
  pid="$$"
  ppid="$PPID"
  pgid="$(preflight_diag_ps_field pgid "$pid")"
  sid="$(preflight_diag_ps_field sess "$pid")"
  tty_name="$(preflight_diag_tty)"
  parent_command="$(preflight_diag_parent_command "$ppid")"

  line="timestamp=$(preflight_diag_quote "$(preflight_diag_now_utc)")"
  line+=" event=$(preflight_diag_quote "$event")"
  line+=" script=$(preflight_diag_quote "${WORKSPACE_PREFLIGHT_DIAGNOSTICS_SCRIPT:-unknown}")"
  line+=" phase=$(preflight_diag_quote "${WORKSPACE_PREFLIGHT_DIAGNOSTICS_PHASE:-idle}")"
  line+=" pid=$(preflight_diag_quote "$pid")"
  line+=" ppid=$(preflight_diag_quote "$ppid")"
  line+=" pgid=$(preflight_diag_quote "$pgid")"
  line+=" sid=$(preflight_diag_quote "$sid")"
  line+=" tty=$(preflight_diag_quote "$tty_name")"
  line+=" pwd=$(preflight_diag_quote "$PWD")"
  line+=" parent_command=$(preflight_diag_quote "$parent_command")"

  while (( "$#" >= 2 )); do
    key="$1"
    value="$2"
    shift 2
    line+=" ${key}=$(preflight_diag_quote "$value")"
  done

  preflight_diag_write "$line"
}

preflight_diag_log_snapshot() {
  local snapshot_scope="${1:-unspecified}"
  local pid ppid pgid ps_lines line

  if ! preflight_diag_is_enabled; then
    return 0
  fi

  pid="$$"
  ppid="$PPID"
  pgid="$(preflight_diag_ps_field pgid "$pid")"

  preflight_diag_log_event process_snapshot snapshot_scope "$snapshot_scope"
  preflight_diag_write "snapshot_begin scope=$(preflight_diag_quote "$snapshot_scope")"

  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    preflight_diag_write "snapshot_row $(preflight_diag_quote "$line")"
  done < <(
    ps -axo pid=,ppid=,pgid=,sess=,tty=,stat=,etime=,command= \
      | awk -v target_pid="$pid" -v target_ppid="$ppid" -v target_pgid="$pgid" '
          $1 == target_pid || $1 == target_ppid || $3 == target_pgid {
            sub(/^[[:space:]]+/, "", $0)
            print $0
          }
        '
  )

  preflight_diag_write "snapshot_end scope=$(preflight_diag_quote "$snapshot_scope")"
}

preflight_diag_init() {
  local script_name="$1"
  local root="$2"
  local prefix="${3:-preflight}"
  local log_dir timestamp

  export WORKSPACE_PREFLIGHT_DIAGNOSTICS_SCRIPT="$script_name"
  export WORKSPACE_PREFLIGHT_DIAGNOSTICS_ROOT="$root"

  if ! preflight_diag_is_enabled; then
    return 0
  fi

  log_dir="${root}/.logs/workspace/preflight-diagnostics"
  mkdir -p "$log_dir"
  export WORKSPACE_PREFLIGHT_DIAGNOSTICS_LOG_DIR="$log_dir"

  if [[ -z "${WORKSPACE_PREFLIGHT_DIAGNOSTICS_LOGFILE:-}" ]]; then
    timestamp="$(date -u +"%Y%m%dT%H%M%SZ")"
    export WORKSPACE_PREFLIGHT_DIAGNOSTICS_LOGFILE="${log_dir}/${timestamp}-${prefix}-$$.log"
  fi

  if [[ -z "${WORKSPACE_PREFLIGHT_DIAGNOSTICS_PHASE:-}" ]]; then
    preflight_diag_set_phase "init"
  fi
}

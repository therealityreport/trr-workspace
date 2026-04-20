#!/usr/bin/env bash

workspace_pid_ppid() {
  local pid="$1"
  ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ' || true
}

workspace_pid_cmd() {
  local pid="$1"
  ps -o command= -p "$pid" 2>/dev/null | sed 's/^ *//' || true
}

workspace_pid_cwd() {
  local pid="$1"
  if [[ "${HAVE_LSOF:-0}" -ne 1 ]]; then
    echo ""
    return 0
  fi
  lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | head -n 1 || true
}

workspace_is_safe_stale() {
  local pid="$1"
  local port="$2"

  local ppid cwd cmd
  ppid="$(workspace_pid_ppid "$pid")"
  if [[ "$ppid" == "1" ]]; then
    return 0
  fi

  cwd="$(workspace_pid_cwd "$pid")"
  if [[ -n "$cwd" && "$cwd" == "$ROOT"* ]]; then
    return 0
  fi

  cmd="$(workspace_pid_cmd "$pid")"
  if [[ -n "$cmd" && "$cmd" == *"$ROOT"* ]]; then
    return 0
  fi

  if [[ "$port" == "${TRR_BACKEND_PORT:-}" ]]; then
    [[ "$cmd" == *"uvicorn"* && "$cmd" == *"api.main:app"* ]] && return 0
  fi

  return 1
}

workspace_resolve_safe_stale_kill_target() {
  local pid="$1"
  local port="$2"
  local current="$pid"
  local parent=""
  local parent_cwd=""

  while true; do
    parent="$(workspace_pid_ppid "$current")"
    if [[ -z "$parent" || "$parent" == "1" || "$parent" == "$current" ]]; then
      break
    fi
    parent_cwd="$(workspace_pid_cwd "$parent")"
    if [[ -z "$parent_cwd" || "$parent_cwd" != "$ROOT"* ]]; then
      break
    fi
    if ! workspace_is_safe_stale "$parent" "$port"; then
      break
    fi
    current="$parent"
  done

  printf '%s\n' "$current"
}

workspace_descendants_of() {
  local root_pid="$1"
  local -a queue=()
  local -a all=()

  queue+=("$root_pid")

  while [[ "${#queue[@]}" -gt 0 ]]; do
    local pid="${queue[0]}"
    queue=("${queue[@]:1}")

    local children
    children="$(pgrep -P "$pid" 2>/dev/null || true)"
    if [[ -z "$children" ]]; then
      continue
    fi

    local child
    for child in $children; do
      all+=("$child")
      queue+=("$child")
    done
  done

  if [[ "${#all[@]}" -eq 0 ]]; then
    echo ""
    return 0
  fi

  printf '%s\n' "${all[@]}" | awk '!seen[$0]++' | tr '\n' ' ' | xargs 2>/dev/null || true
}

workspace_expand_cleanup_targets() {
  local pids="$1"
  local port="$2"

  if [[ -z "$pids" ]]; then
    echo ""
    return 0
  fi

  local pid target
  for pid in $pids; do
    target="$pid"
    if workspace_is_safe_stale "$pid" "$port"; then
      target="$(workspace_resolve_safe_stale_kill_target "$pid" "$port")"
    fi
    printf '%s\n' "$target"
  done | awk 'NF && !seen[$0]++' | tr '\n' ' ' | xargs 2>/dev/null || true
}

workspace_kill_targets() {
  local pids="$1"
  if [[ -z "$pids" ]]; then
    return 0
  fi

  local expanded=""
  local pid descendants
  for pid in $pids; do
    expanded="${expanded}${pid}"$'\n'
    descendants="$(workspace_descendants_of "$pid")"
    for child in $descendants; do
      expanded="${expanded}${child}"$'\n'
    done
  done

  expanded="$(printf '%s' "$expanded" | awk 'NF && !seen[$0]++' | tr '\n' ' ' | xargs 2>/dev/null || true)"
  if [[ -z "$expanded" ]]; then
    return 0
  fi

  # shellcheck disable=SC2086
  kill -TERM $expanded >/dev/null 2>&1 || true
  sleep 0.5
  # shellcheck disable=SC2086
  kill -KILL $expanded >/dev/null 2>&1 || true
  sleep 0.2
}

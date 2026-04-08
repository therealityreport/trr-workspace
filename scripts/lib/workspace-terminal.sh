#!/usr/bin/env bash

workspace_attention_file() {
  local root="$1"
  printf '%s\n' "${root}/.logs/workspace/startup-attention.log"
}

workspace_attention_reset() {
  local file="$1"
  mkdir -p "$(dirname "$file")"
  : > "$file"
}

workspace_attention_add() {
  local file="$1"
  local title="${2//$'\t'/ }"
  local impact="${3//$'\t'/ }"
  local remediation="${4//$'\t'/ }"

  mkdir -p "$(dirname "$file")"
  printf '%s\t%s\t%s\n' "$title" "$impact" "$remediation" >>"$file"
}

workspace_attention_render() {
  local file="$1"
  local prefix="$2"
  local title impact remediation

  [[ -s "$file" ]] || return 0

  echo "${prefix} Attention:"
  while IFS=$'\t' read -r title impact remediation; do
    [[ -n "$title" ]] || continue
    echo "  - ${title}"
    if [[ -n "$impact" ]]; then
      echo "    ${impact}"
    fi
    if [[ -n "$remediation" ]]; then
      echo "    ${remediation}"
    fi
  done <"$file"
}

workspace_reaper_render_summary() {
  local prefix="$1"
  local killed="$2"
  local rm_sessions="$3"
  local rm_pages="$4"
  local rm_reserves="$5"
  local rm_agents="$6"
  local rm_figma_sessions="$7"
  local stopped_chrome="$8"
  local stopped_shared_headful="$9"
  local broken_live_sessions="${10}"

  if [[ "$killed" == "0" && "$rm_sessions" == "0" && "$rm_pages" == "0" && "$rm_reserves" == "0" && "$rm_agents" == "0" && "$rm_figma_sessions" == "0" && "$stopped_chrome" == "0" && "$stopped_shared_headful" == "0" && "$broken_live_sessions" == "0" ]]; then
    echo "${prefix} No stale MCP/Chrome runtime artifacts found."
    return 0
  fi

  echo "=== REAP SUMMARY ==="
  echo "KILLED_PROCESSES=${killed}"
  echo "REMOVED_SESSION_FILES=${rm_sessions}"
  echo "REMOVED_PAGES_FILES=${rm_pages}"
  echo "REMOVED_RESERVE_FILES=${rm_reserves}"
  echo "REMOVED_AGENT_PIDFILES=${rm_agents}"
  echo "REMOVED_FIGMA_SESSION_FILES=${rm_figma_sessions}"
  echo "STOPPED_CHROME_AGENTS=${stopped_chrome}"
  echo "STOPPED_SHARED_HEADFUL=${stopped_shared_headful}"
  echo "BROKEN_LIVE_SESSIONS=${broken_live_sessions}"
}

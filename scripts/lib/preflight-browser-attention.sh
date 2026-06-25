#!/usr/bin/env bash

preflight_record_browser_attention() {
  local attention_file="$1"
  local output="${2:-}"
  local attention_kind=""
  local overall_state=""
  local shared_runtime_state=""
  local shared_port=""
  local orphaned_chrome_mcp_processes=""
  local orphaned_chrome_mcp_attention_threshold=""

  attention_kind="$(printf '%s\n' "$output" | sed -n 's/^attention_kind=//p' | head -n 1)"
  overall_state="$(printf '%s\n' "$output" | sed -n 's/^overall_state=//p' | head -n 1)"
  shared_runtime_state="$(printf '%s\n' "$output" | sed -n 's/^shared_runtime_state=//p' | head -n 1)"
  shared_port="$(printf '%s\n' "$output" | sed -n 's/^shared_port=//p' | head -n 1)"
  orphaned_chrome_mcp_processes="$(printf '%s\n' "$output" | sed -n 's/^orphaned_chrome_mcp_processes=//p' | head -n 1)"
  orphaned_chrome_mcp_attention_threshold="$(printf '%s\n' "$output" | sed -n 's/^orphaned_chrome_mcp_attention_threshold=//p' | head -n 1)"
  orphaned_chrome_mcp_processes="${orphaned_chrome_mcp_processes:-0}"
  orphaned_chrome_mcp_attention_threshold="${orphaned_chrome_mcp_attention_threshold:-3}"

  workspace_attention_remove_title_prefix "$attention_file" "Chrome DevTools orphaned MCP processes detected"
  if [[ "$orphaned_chrome_mcp_processes" =~ ^[0-9]+$ \
    && "$orphaned_chrome_mcp_attention_threshold" =~ ^[0-9]+$ \
    && "$orphaned_chrome_mcp_processes" -ge "$orphaned_chrome_mcp_attention_threshold" \
    && "$orphaned_chrome_mcp_processes" -gt 0 ]]; then
    workspace_attention_add \
      "$attention_file" \
      "Chrome DevTools orphaned MCP processes detected (${orphaned_chrome_mcp_processes})." \
      "Impact: stale browser-control processes can keep chrome-devtools transports closed or slow to attach." \
      "Remediation: run 'make chrome-repair' to clean stale MCP processes, restart shared Chrome, and print the reload hint."
  fi

  if [[ "$attention_kind" == "pressure" ]]; then
    return 0
  fi

  if [[ "$attention_kind" == "unavailable" || "$overall_state" == "unavailable" || "$shared_runtime_state" == "unavailable" ]]; then
    workspace_attention_add \
      "$attention_file" \
      "Browser automation shared Chrome is not responding${shared_port:+ on port ${shared_port}}." \
      "Impact: chrome-devtools registration is present, but the shared browser runtime is unavailable." \
      "Remediation: run 'make mcp-clean' and retry the workspace startup."
  fi
}

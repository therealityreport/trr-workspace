#!/usr/bin/env bash

preflight_record_browser_attention() {
  local attention_file="$1"
  local output="${2:-}"
  local attention_kind=""
  local overall_state=""
  local shared_runtime_state=""
  local shared_port=""

  attention_kind="$(printf '%s\n' "$output" | sed -n 's/^attention_kind=//p' | head -n 1)"
  overall_state="$(printf '%s\n' "$output" | sed -n 's/^overall_state=//p' | head -n 1)"
  shared_runtime_state="$(printf '%s\n' "$output" | sed -n 's/^shared_runtime_state=//p' | head -n 1)"
  shared_port="$(printf '%s\n' "$output" | sed -n 's/^shared_port=//p' | head -n 1)"

  if [[ "$attention_kind" == "pressure" ]]; then
    return 0
  fi

  if [[ "$overall_state" == "recoverable" || "$shared_runtime_state" == "recoverable" ]]; then
    workspace_attention_add \
      "$attention_file" \
      "Browser automation shared Chrome needs recovery${shared_port:+ on port ${shared_port}}." \
      "Impact: chrome-devtools is configured, but the shared browser runtime is not ready for this startup yet." \
      "Remediation: retry the browser task once; if the shared runtime does not recover, run 'make mcp-clean' and restart the workspace."
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

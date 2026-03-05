#!/usr/bin/env bash
set -euo pipefail

CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
CONFIG_FILE="${CODEX_HOME_DIR}/config.toml"

AWS_SERVERS=(
  "awslabs-core"
  "awslabs-aws-api"
  "awslabs-aws-docs"
  "awslabs-pricing"
  "awslabs-cloudwatch"
  "awsknowledge"
  "awsiac"
)

usage() {
  cat <<USAGE
Usage:
  $0 aws-on
  $0 aws-off
  $0 aws-status

Description:
  Toggles the AWS MCP profile in Codex config: ${CONFIG_FILE}
  - aws-on: enables all AWS MCP servers listed in this script
  - aws-off: disables all AWS MCP servers listed in this script
  - aws-status: prints enabled/disabled per AWS MCP server
USAGE
}

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "[mcp-profile] ERROR: config file not found: ${CONFIG_FILE}" >&2
  exit 1
fi

backup_config() {
  local ts
  ts="$(date +%Y%m%d-%H%M%S)"
  local backup="${CONFIG_FILE}.bak.aws-profile-${ts}"
  cp "$CONFIG_FILE" "$backup"
  echo "[mcp-profile] Backup: ${backup}"
}

get_server_status() {
  local server="$1"
  awk -v server="$server" '
    BEGIN { in_section=0; enabled=""; emitted=0 }
    /^\[mcp_servers\./ {
      if (in_section) {
        if (enabled == "") enabled = "true"
        print enabled
        emitted = 1
        exit 0
      }
      if ($0 == "[mcp_servers." server "]") {
        in_section = 1
        enabled = ""
      }
      next
    }
    in_section && /^enabled[[:space:]]*=/ {
      val = $0
      sub(/^enabled[[:space:]]*=[[:space:]]*/, "", val)
      gsub(/[[:space:]\"]/, "", val)
      enabled = tolower(val)
    }
    END {
      if (emitted == 1) {
        exit 0
      }
      if (in_section) {
        if (enabled == "") enabled = "true"
        print enabled
        exit 0
      }
      exit 3
    }
  ' "$CONFIG_FILE"
}

set_server_enabled() {
  local server="$1"
  local desired="$2"
  local tmp
  tmp="$(mktemp)"

  awk -v server="$server" -v desired="$desired" '
    BEGIN { in_section=0; found_section=0; replaced=0 }
    /^\[mcp_servers\./ {
      if (in_section && replaced == 0) {
        print "enabled = " desired
      }
      if ($0 == "[mcp_servers." server "]") {
        in_section = 1
        found_section = 1
        replaced = 0
      } else {
        in_section = 0
      }
      print
      next
    }
    in_section && /^enabled[[:space:]]*=/ {
      print "enabled = " desired
      replaced = 1
      next
    }
    { print }
    END {
      if (in_section && replaced == 0) {
        print "enabled = " desired
      }
      if (found_section == 0) {
        exit 2
      }
    }
  ' "$CONFIG_FILE" > "$tmp"

  local rc=$?
  if [[ $rc -ne 0 ]]; then
    rm -f "$tmp"
    if [[ $rc -eq 2 ]]; then
      echo "[mcp-profile] WARNING: server section not found: ${server}" >&2
      return 0
    fi
    echo "[mcp-profile] ERROR: failed to update ${server}" >&2
    exit 1
  fi

  mv "$tmp" "$CONFIG_FILE"
}

print_status() {
  echo "[mcp-profile] AWS MCP status (${CONFIG_FILE})"
  for server in "${AWS_SERVERS[@]}"; do
    if status="$(get_server_status "$server" 2>/dev/null)"; then
      echo "  - ${server}: ${status}"
    else
      echo "  - ${server}: missing"
    fi
  done
}

command="${1:-}"
case "$command" in
  aws-on)
    backup_config
    for server in "${AWS_SERVERS[@]}"; do
      set_server_enabled "$server" "true"
    done
    echo "[mcp-profile] Applied profile: aws-on"
    print_status
    echo "[mcp-profile] Restart Codex session to apply MCP server state changes."
    ;;
  aws-off)
    backup_config
    for server in "${AWS_SERVERS[@]}"; do
      set_server_enabled "$server" "false"
    done
    echo "[mcp-profile] Applied profile: aws-off"
    print_status
    echo "[mcp-profile] Restart Codex session to apply MCP server state changes."
    ;;
  aws-status)
    print_status
    ;;
  *)
    usage
    exit 1
    ;;
esac

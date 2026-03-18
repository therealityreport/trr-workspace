#!/usr/bin/env bash

# Provides thread/session ownership metadata for the MCP wrapper.
# Since Codex doesn't pass a thread ID, we synthesize one from observable signals.

ROOT="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# Compute a stable session identifier from available signals.
# If CODEX_THREAD_ID is in the env, use it (future-proofing).
# Otherwise, construct from: wrapper's PPID, port, and minute-truncated timestamp.
codex_session_id() {
  # Return cached value if already computed
  if [[ -n "${CODEX_SESSION_ID:-}" ]]; then
    echo "$CODEX_SESSION_ID"
    return 0
  fi

  # If Codex provides a thread ID, use it directly
  if [[ -n "${CODEX_THREAD_ID:-}" ]]; then
    CODEX_SESSION_ID="$CODEX_THREAD_ID"
    export CODEX_SESSION_ID
    echo "$CODEX_SESSION_ID"
    return 0
  fi

  # Otherwise, construct from observable signals
  local wrapper_ppid port minute_ts

  # Wrapper's parent PID (the immediate Codex app-server child)
  wrapper_ppid="$(ps -o ppid= -p "$$" 2>/dev/null | tr -d ' ')"
  if [[ -z "$wrapper_ppid" ]]; then
    wrapper_ppid="unknown"
  fi

  # Try to get port from environment or CLI context
  # Port may be passed as first arg or available in env
  port="${CODEX_CHROME_PORT:-${1:-${MCP_PORT:-unknown}}}"

  # Timestamp truncated to minute resolution
  # This ensures the same wrapper restart within a minute maps to the same ID
  minute_ts="$(date -u +%Y%m%d%H%M)"

  # Construct the session ID
  CODEX_SESSION_ID="codex-${wrapper_ppid}-${port}-${minute_ts}"
  export CODEX_SESSION_ID

  echo "$CODEX_SESSION_ID"
}

# Print key=value lines suitable for writing to a session env file.
# Provides:
# - CODEX_SESSION_ID: computed stable identifier
# - WRAPPER_PID: current wrapper process ID
# - WRAPPER_PPID: parent PID of wrapper
# - APP_SERVER_PID: the codex app-server process (or "unknown")
# - APP_SERVER_TYPE: desktop|vscode|unknown
# - STARTED_AT: ISO 8601 UTC timestamp
codex_session_metadata() {
  local requested_port="${1:-${CODEX_CHROME_PORT:-${MCP_PORT:-unknown}}}"
  local session_id wrapper_pid wrapper_ppid app_server_pid app_server_type started_at

  session_id="$(codex_session_id "$requested_port")"
  wrapper_pid="$$"
  wrapper_ppid="$(ps -o ppid= -p "$$" 2>/dev/null | tr -d ' ')"
  started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  # Walk up the parent chain to find the codex app-server process
  app_server_pid="$(
    local current="$wrapper_ppid"
    local depth=0
    local max_depth=8

    while [[ -n "$current" && "$current" =~ ^[0-9]+$ && "$current" != "0" && "$depth" -lt "$max_depth" ]]; do
      local cmd
      cmd="$(ps -o command= -p "$current" 2>/dev/null || true)"

      if [[ "$cmd" == *"codex app-server"* ]]; then
        echo "$current"
        return 0
      fi

      current="$(ps -o ppid= -p "$current" 2>/dev/null | tr -d ' ')"
      depth=$((depth + 1))
    done

    echo "unknown"
  )"

  # Classify the app server type using the helper from mcp-runtime.sh
  if [[ -f "${ROOT}/scripts/lib/mcp-runtime.sh" ]]; then
    # Source the helper function if available
    . "${ROOT}/scripts/lib/mcp-runtime.sh"
    if [[ "$app_server_pid" != "unknown" ]]; then
      app_server_type="$(classify_codex_app_server_pid "$app_server_pid")"
    else
      app_server_type="unknown"
    fi
  else
    app_server_type="unknown"
  fi

  # Output key=value pairs
  cat <<EOF
CODEX_SESSION_ID=${session_id}
WRAPPER_PID=${wrapper_pid}
WRAPPER_PPID=${wrapper_ppid}
APP_SERVER_PID=${app_server_pid}
APP_SERVER_TYPE=${app_server_type}
STARTED_AT=${started_at}
EOF
}

# Takes a file path, writes codex_session_metadata() output to it atomically.
# Write to .tmp, then move to final location to ensure atomicity.
write_session_metadata_file() {
  local target_path="$1"
  local tmpfile

  if [[ -z "$target_path" ]]; then
    echo "[codex-session-identity] ERROR: target_path required" >&2
    return 1
  fi

  # Create temporary file in same directory for atomic move
  tmpfile="${target_path}.tmp"

  # Write metadata to temporary file
  codex_session_metadata >"$tmpfile" || {
    rm -f "$tmpfile"
    echo "[codex-session-identity] ERROR: failed to write metadata" >&2
    return 1
  }

  # Move atomically to target location
  mv "$tmpfile" "$target_path" || {
    rm -f "$tmpfile"
    echo "[codex-session-identity] ERROR: failed to move metadata file to ${target_path}" >&2
    return 1
  }

  return 0
}

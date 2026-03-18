#!/usr/bin/env bash
# codex-mcp-http-bridge.sh — stdio-to-HTTP bridge for Codex MCP servers
#
# Codex CLI 0.98.x has a known bug where Streamable HTTP MCP servers fail
# during transport handshake (tools register but show "no tools available").
# This wrapper converts url-based servers to stdio using mcp-remote.
#
# Usage:
#   codex-mcp-http-bridge.sh <url> [bearer_token_env_var_name]
#
# Examples:
#   codex-mcp-http-bridge.sh https://mcp.figma.com/mcp
#   codex-mcp-http-bridge.sh https://api.githubcopilot.com/mcp GITHUB_PAT
#   codex-mcp-http-bridge.sh https://mcp.supabase.com/mcp?... SUPABASE_ACCESS_TOKEN
#
# When bearer_token_env_var_name is provided, the script reads the token from
# that environment variable and passes it to mcp-remote as an Authorization
# header.  Codex sets env vars from the [mcp_servers.<name>].env config key
# before spawning this process, so the token must be available either through
# that mechanism or the parent shell environment.
#
# Remove this bridge when Codex CLI ships a working Streamable HTTP transport.
# Track: https://github.com/openai/codex/issues/11284
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT}/scripts/lib/node-baseline.sh"

MCP_REMOTE_VERSION="${MCP_REMOTE_VERSION:-0.1.38}"
MCP_REMOTE_PACKAGE="mcp-remote@${MCP_REMOTE_VERSION}"
MCP_REMOTE_CACHE_DIR="${CODEX_MCP_REMOTE_CACHE_DIR:-${ROOT}/.tmp/mcp-remote/npm-cache}"

bridge_log() {
  echo "[codex-mcp-http-bridge] $*" >&2
}

if [[ $# -lt 1 ]]; then
  bridge_log "Usage: codex-mcp-http-bridge.sh <url> [bearer_token_env_var_name]"
  exit 1
fi

SERVER_URL="$1"
BEARER_ENV_VAR="${2:-}"

# Ensure Node baseline (24.x) is active — same as chrome-devtools wrapper.
if ! trr_ensure_node_baseline "$ROOT"; then
  required_major="$(trr_node_required_major "$ROOT")"
  bridge_log "ERROR: Node $(trr_node_version_string) does not satisfy required ${required_major}.x baseline."
  bridge_log "ERROR: Remediation: source ~/.nvm/nvm.sh && nvm use ${required_major}"
  exit 1
fi

mkdir -p "$MCP_REMOTE_CACHE_DIR"

# Build mcp-remote argument list.
ARGS=("$SERVER_URL")

if [[ -n "$BEARER_ENV_VAR" ]]; then
  # Read the bearer token from the named environment variable.
  TOKEN="${!BEARER_ENV_VAR:-}"
  if [[ -z "$TOKEN" ]]; then
    bridge_log "WARNING: Bearer token env var ${BEARER_ENV_VAR} is empty or unset. Connecting without auth."
  else
    ARGS+=("--header" "Authorization:Bearer ${TOKEN}")
  fi
fi

bridge_log "Bridging ${SERVER_URL} via mcp-remote ${MCP_REMOTE_VERSION} (stdio→HTTP)"

# Run mcp-remote in the foreground to preserve stdio attachment for the MCP
# handshake.  NPM_CONFIG_UPDATE_NOTIFIER=false suppresses npm noise.
exec env \
  NPM_CONFIG_UPDATE_NOTIFIER=false \
  NPM_CONFIG_FUND=false \
  npm exec --yes --cache "$MCP_REMOTE_CACHE_DIR" --package "$MCP_REMOTE_PACKAGE" -- \
  mcp-remote "${ARGS[@]}"

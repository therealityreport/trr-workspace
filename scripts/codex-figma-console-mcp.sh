#!/usr/bin/env bash
set -euo pipefail

exec "${CODEX_HOME:-$HOME/.codex}/bin/codex-figma-console-mcp.sh" "$@"

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=scripts/lib/node-baseline.sh
source "$ROOT/scripts/lib/node-baseline.sh"

REQUIRED_NODE_MAJOR="$(trr_node_required_major "$ROOT")"
if ! trr_ensure_node_baseline "$ROOT"; then
  echo "[browser-smoke] ERROR: Node $(trr_node_version_string) does not satisfy required ${REQUIRED_NODE_MAJOR}.x baseline." >&2
  echo "[browser-smoke] Remediation:" >&2
  echo "[browser-smoke]   source ~/.nvm/nvm.sh && nvm use ${REQUIRED_NODE_MAJOR}" >&2
  echo "[browser-smoke]   source ~/.nvm/nvm.sh && nvm install ${REQUIRED_NODE_MAJOR}" >&2
  exit 1
fi

cd "$ROOT/TRR-APP/apps/web"
trr_pnpm "$ROOT/TRR-APP" run smoke:admin-detail-routes -- "$@"

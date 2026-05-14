#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/node-baseline.sh"
source "$ROOT/scripts/lib/python-venv.sh"

echo "[test] TRR-Backend..."
trr_ensure_repo_runtime "$ROOT/TRR-Backend" "$ROOT/TRR-Backend/requirements.txt"
"$ROOT/TRR-Backend/.venv/bin/ruff" check "$ROOT/TRR-Backend"
"$ROOT/TRR-Backend/.venv/bin/ruff" format --check "$ROOT/TRR-Backend"
(cd "$ROOT/TRR-Backend" && "$ROOT/TRR-Backend/.venv/bin/pytest")

echo "[test] TRR-APP..."
REQUIRED_NODE_MAJOR="$(trr_node_required_major "$ROOT")"
if ! trr_ensure_node_baseline "$ROOT"; then
  echo "[test] ERROR: Node $(trr_node_version_string) does not satisfy required ${REQUIRED_NODE_MAJOR}.x baseline." >&2
  exit 1
fi
(cd "$ROOT/TRR-APP/apps/web" && trr_pnpm "$ROOT/TRR-APP" run lint && trr_pnpm "$ROOT/TRR-APP" exec next build --webpack && trr_pnpm "$ROOT/TRR-APP" run test:ci)

echo "[test] Done."

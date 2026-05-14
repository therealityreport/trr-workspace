#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
source "$ROOT/scripts/lib/node-baseline.sh"
source "$ROOT/scripts/lib/python-venv.sh"

PYTHON_BIN="$(trr_resolve_python_bin)"

echo "[bootstrap] TRR-APP (pnpm)..."
REQUIRED_NODE_MAJOR="$(trr_node_required_major "$ROOT")"
if ! trr_ensure_node_baseline "$ROOT"; then
  echo "[bootstrap] ERROR: Node $(trr_node_version_string) does not satisfy required ${REQUIRED_NODE_MAJOR}.x baseline." >&2
  exit 1
fi
(cd "$ROOT/TRR-APP" && trr_pnpm "$ROOT/TRR-APP" install)

echo "[bootstrap] TRR-Backend (python deps)..."
trr_ensure_repo_venv "$ROOT/TRR-Backend"
"$ROOT/TRR-Backend/.venv/bin/python" -m pip install -r "$ROOT/TRR-Backend/requirements.txt"

echo "[bootstrap] Done."

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
source "$ROOT/scripts/lib/python-venv.sh"

PYTHON_BIN="$(trr_resolve_python_bin)"

echo "[bootstrap] TRR-APP (pnpm)..."
(cd "$ROOT/TRR-APP" && pnpm install)

echo "[bootstrap] TRR-Backend (python deps)..."
trr_ensure_repo_venv "$ROOT/TRR-Backend"
"$ROOT/TRR-Backend/.venv/bin/python" -m pip install -r "$ROOT/TRR-Backend/requirements.txt"

echo "[bootstrap] Done."

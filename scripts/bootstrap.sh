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

echo "[bootstrap] screenalytics (python deps)..."
trr_ensure_repo_venv "$ROOT/screenalytics"
# Remove stale, unmanaged packages that commonly survive from older local setups
# and trigger resolver warnings against the lock-driven stack.
"$ROOT/screenalytics/.venv/bin/python" -m pip uninstall -y facenet-pytorch >/dev/null 2>&1 || true
"$ROOT/screenalytics/.venv/bin/python" -m pip install -r "$ROOT/screenalytics/requirements.txt"

SCREENALYTICS_INSTALL_ML="${SCREENALYTICS_INSTALL_ML:-1}"
if [[ "$SCREENALYTICS_INSTALL_ML" == "1" ]]; then
  "$ROOT/screenalytics/.venv/bin/python" -m pip install -r "$ROOT/screenalytics/requirements-ml.txt" || {
    echo "[bootstrap] WARNING: screenalytics ML requirements failed. Set SCREENALYTICS_INSTALL_ML=0 to skip." >&2
  }
else
  echo "[bootstrap] screenalytics: skipping ML requirements (SCREENALYTICS_INSTALL_ML=${SCREENALYTICS_INSTALL_ML})"
fi

"$ROOT/screenalytics/.venv/bin/python" -m pip install -e "$ROOT/screenalytics/packages/py-screenalytics" || {
  echo "[bootstrap] WARNING: editable install failed: screenalytics/packages/py-screenalytics" >&2
}

echo "[bootstrap] screenalytics web (npm ci)..."
(cd "$ROOT/screenalytics/web" && npm ci)

echo "[bootstrap] Done."

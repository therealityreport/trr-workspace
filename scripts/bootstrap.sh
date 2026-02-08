#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PYTHON_BIN="${PYTHON_BIN:-python3.11}"
if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  echo "[bootstrap] ERROR: ${PYTHON_BIN} not found. Install Python 3.11+ (python3.11 on PATH)." >&2
  exit 1
fi

ensure_venv() {
  local repo_dir="$1"
  if [[ -x "${repo_dir}/.venv/bin/python" ]]; then
    return 0
  fi
  echo "[bootstrap] Creating venv: ${repo_dir}/.venv (${PYTHON_BIN})"
  "$PYTHON_BIN" -m venv "${repo_dir}/.venv"
}

echo "[bootstrap] TRR-APP (pnpm)..."
(cd "$ROOT/TRR-APP" && pnpm install)

echo "[bootstrap] TRR-Backend (python deps)..."
ensure_venv "$ROOT/TRR-Backend"
"$ROOT/TRR-Backend/.venv/bin/pip" install -r "$ROOT/TRR-Backend/requirements.txt"

echo "[bootstrap] screenalytics (python deps)..."
ensure_venv "$ROOT/screenalytics"
"$ROOT/screenalytics/.venv/bin/pip" install -r "$ROOT/screenalytics/requirements.txt"

SCREENALYTICS_INSTALL_ML="${SCREENALYTICS_INSTALL_ML:-1}"
if [[ "$SCREENALYTICS_INSTALL_ML" == "1" ]]; then
  "$ROOT/screenalytics/.venv/bin/pip" install -r "$ROOT/screenalytics/requirements-ml.txt" || {
    echo "[bootstrap] WARNING: screenalytics ML requirements failed. Set SCREENALYTICS_INSTALL_ML=0 to skip." >&2
  }
else
  echo "[bootstrap] screenalytics: skipping ML requirements (SCREENALYTICS_INSTALL_ML=${SCREENALYTICS_INSTALL_ML})"
fi

"$ROOT/screenalytics/.venv/bin/pip" install -e "$ROOT/screenalytics/packages/py-screenalytics" || {
  echo "[bootstrap] WARNING: editable install failed: screenalytics/packages/py-screenalytics" >&2
}

echo "[bootstrap] screenalytics web (npm ci)..."
(cd "$ROOT/screenalytics/web" && npm ci)

echo "[bootstrap] Done."


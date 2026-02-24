#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

REQUIRED_PY_MAJOR=3
REQUIRED_PY_MINOR=11

resolve_python_bin() {
  local configured="${PYTHON_BIN:-}"
  local candidate path

  if [[ -n "$configured" ]]; then
    if [[ -x "$configured" ]]; then
      echo "$configured"
      return 0
    fi
    if command -v "$configured" >/dev/null 2>&1; then
      command -v "$configured"
      return 0
    fi
    echo "[bootstrap] WARNING: PYTHON_BIN is set but not executable/found: ${configured}" >&2
  fi

  for candidate in python3.11 python3 python; do
    if command -v "$candidate" >/dev/null 2>&1; then
      path="$(command -v "$candidate")"
      echo "$path"
      return 0
    fi
  done

  echo ""
}

python_version_ok() {
  local py="$1"
  local major minor
  local out

  out="$("$py" -c 'import sys; print(f"{sys.version_info[0]} {sys.version_info[1]}")' 2>/dev/null || true)"
  major="${out%% *}"
  minor="${out##* }"
  if [[ -z "$major" || -z "$minor" ]]; then
    return 1
  fi
  if ! [[ "$major" =~ ^[0-9]+$ && "$minor" =~ ^[0-9]+$ ]]; then
    return 1
  fi

  if (( major > REQUIRED_PY_MAJOR )); then
    return 0
  fi
  if (( major == REQUIRED_PY_MAJOR && minor >= REQUIRED_PY_MINOR )); then
    return 0
  fi
  return 1
}

python_version_str() {
  local py="$1"
  "$py" -c 'import sys; print(f"{sys.version_info[0]}.{sys.version_info[1]}")' 2>/dev/null || echo "unknown"
}

PYTHON_BIN="$(resolve_python_bin)"
if [[ -z "$PYTHON_BIN" ]]; then
  echo "[bootstrap] ERROR: Missing Python interpreter (tried: PYTHON_BIN, python3.11, python3, python)." >&2
  echo "[bootstrap] Install Python 3.11+ and ensure it is on PATH." >&2
  exit 1
fi

if ! python_version_ok "$PYTHON_BIN"; then
  echo "[bootstrap] ERROR: Python 3.11+ required, got ${PYTHON_BIN} ($(python_version_str "$PYTHON_BIN"))." >&2
  exit 1
fi

venv_path_ok() {
  local repo_dir="$1"
  local expected="${repo_dir}/.venv"
  local activate="${expected}/bin/activate"
  local actual

  if [[ ! -f "$activate" ]]; then
    return 1
  fi

  # venvs are not reliably relocatable; if activation points at a different path,
  # recreate so scripts and PATH wiring behave as expected.
  actual="$(grep '^VIRTUAL_ENV=' "$activate" | head -n 1 | cut -d= -f2-)"
  if [[ -z "$actual" ]]; then
    return 1
  fi
  if [[ "$actual" == "$expected" ]]; then
    return 0
  fi
  return 1
}

ensure_venv() {
  local repo_dir="$1"
  local venv_py="${repo_dir}/.venv/bin/python"

  if [[ -x "$venv_py" ]]; then
    if python_version_ok "$venv_py" && venv_path_ok "$repo_dir"; then
      return 0
    fi

    local found
    found="$(python_version_str "$venv_py")"
    echo "[bootstrap] Recreating venv: ${repo_dir}/.venv (found python ${found}, need >=${REQUIRED_PY_MAJOR}.${REQUIRED_PY_MINOR} and correct venv path)"
    rm -rf "${repo_dir}/.venv"
  fi
  echo "[bootstrap] Creating venv: ${repo_dir}/.venv (${PYTHON_BIN})"
  "$PYTHON_BIN" -m venv "${repo_dir}/.venv"
}

echo "[bootstrap] TRR-APP (pnpm)..."
(cd "$ROOT/TRR-APP" && pnpm install)

echo "[bootstrap] TRR-Backend (python deps)..."
ensure_venv "$ROOT/TRR-Backend"
"$ROOT/TRR-Backend/.venv/bin/python" -m pip install -r "$ROOT/TRR-Backend/requirements.txt"

echo "[bootstrap] screenalytics (python deps)..."
ensure_venv "$ROOT/screenalytics"
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

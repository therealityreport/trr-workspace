#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

need() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[doctor] Missing required command: $cmd" >&2
    exit 1
  fi
}

need git
need node
need npm
need pnpm
need curl

REQUIRED_PY_MAJOR=3
REQUIRED_PY_MINOR=11

python_version_str() {
  local py="$1"
  "$py" -c 'import sys; print(f"{sys.version_info[0]}.{sys.version_info[1]}")' 2>/dev/null || echo "unknown"
}

python_version_ok() {
  local py="$1"
  local out major minor

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
    echo "[doctor] WARNING: PYTHON_BIN is set but not executable/found: ${configured}" >&2
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

PYTHON_BIN="$(resolve_python_bin)"
if [[ -z "$PYTHON_BIN" ]]; then
  echo "[doctor] Missing required Python interpreter (tried: PYTHON_BIN, python3.11, python3, python)." >&2
  echo "[doctor] Install Python 3.11+ and ensure it is on PATH." >&2
  exit 1
fi

if ! python_version_ok "$PYTHON_BIN"; then
  echo "[doctor] Python version check failed: ${PYTHON_BIN} ($(python_version_str "$PYTHON_BIN"))" >&2
  echo "[doctor] Python 3.11+ is required." >&2
  exit 1
fi

echo "[doctor] Versions:"
echo "  node: $({ node --version; } 2>/dev/null)"
echo "  pnpm: $({ pnpm --version; } 2>/dev/null)"
echo "  python: ${PYTHON_BIN} ($({ ${PYTHON_BIN} --version; } 2>/dev/null))"

if command -v docker >/dev/null 2>&1; then
  echo "  docker: $({ docker --version; } 2>/dev/null)"
  if ! docker info >/dev/null 2>&1; then
    echo "[doctor] WARNING: docker daemon not running (needed for screenalytics full stack)." >&2
  fi
else
  echo "[doctor] WARNING: docker not found (needed for screenalytics full stack)." >&2
fi

echo ""
echo "[doctor] Local env:"

venv_py_version_str() {
  local py="$1"
  "$py" -c 'import sys; print(f"{sys.version_info[0]}.{sys.version_info[1]}")' 2>/dev/null || echo "unknown"
}

venv_py_version_ok() {
  local py="$1"
  local major minor
  local out

  out="$("$py" -c 'import sys; print(f"{sys.version_info[0]} {sys.version_info[1]}")' 2>/dev/null || true)"
  major="${out%% *}"
  minor="${out##* }"
  if [[ -z "$major" || -z "$minor" ]]; then
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

check_repo_venv() {
  local name="$1"
  local repo_dir="$2"
  local venv_py="${repo_dir}/.venv/bin/python"

  if [[ -x "$venv_py" ]]; then
    local ver
    ver="$(venv_py_version_str "$venv_py")"
    if venv_py_version_ok "$venv_py"; then
      echo "  ${name}: .venv present (python ${ver})"
    else
      echo "  ${name}: .venv present (python ${ver})" >&2
      echo "    [doctor] WARNING: ${name} venv python is <${REQUIRED_PY_MAJOR}.${REQUIRED_PY_MINOR}. Run: make bootstrap" >&2
    fi
  else
    echo "  ${name}: .venv missing (run: make bootstrap)"
  fi
}

check_repo_venv "TRR-Backend" "$ROOT/TRR-Backend"

check_repo_venv "screenalytics" "$ROOT/screenalytics"

if [[ -f "$ROOT/TRR-APP/pnpm-lock.yaml" ]]; then
  echo "  TRR-APP: pnpm-lock.yaml present"
else
  echo "  TRR-APP: pnpm-lock.yaml missing (run: make bootstrap)"
fi

echo ""
echo "[doctor] OK (warnings above may still require action)."

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

if command -v python3.11 >/dev/null 2>&1; then
  PYTHON_BIN="python3.11"
else
  echo "[doctor] Missing required command: python3.11" >&2
  echo "[doctor] Install Python 3.11+ (python3.11 must be on PATH)." >&2
  exit 1
fi

echo "[doctor] Versions:"
echo "  node: $({ node --version; } 2>/dev/null)"
echo "  pnpm: $({ pnpm --version; } 2>/dev/null)"
echo "  ${PYTHON_BIN}: $({ ${PYTHON_BIN} --version; } 2>/dev/null)"

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

if [[ -d "$ROOT/TRR-Backend/.venv" ]]; then
  echo "  TRR-Backend: .venv present"
else
  echo "  TRR-Backend: .venv missing (run: make bootstrap)"
fi

if [[ -d "$ROOT/screenalytics/.venv" ]]; then
  echo "  screenalytics: .venv present"
else
  echo "  screenalytics: .venv missing (run: make bootstrap)"
fi

if [[ -f "$ROOT/TRR-APP/pnpm-lock.yaml" ]]; then
  echo "  TRR-APP: pnpm-lock.yaml present"
else
  echo "  TRR-APP: pnpm-lock.yaml missing (run: make bootstrap)"
fi

echo ""
echo "[doctor] OK (warnings above may still require action)."


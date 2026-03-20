#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/node-baseline.sh"
RUN_BACKEND=1
RUN_APP=1
RUN_SCREENALYTICS=1

for arg in "$@"; do
  case "$arg" in
    --backend-only)
      RUN_BACKEND=1
      RUN_APP=0
      RUN_SCREENALYTICS=0
      ;;
    --app-only)
      RUN_BACKEND=0
      RUN_APP=1
      RUN_SCREENALYTICS=0
      ;;
    --screenalytics-only)
      RUN_BACKEND=0
      RUN_APP=0
      RUN_SCREENALYTICS=1
      ;;
    *)
      echo "Usage: $0 [--backend-only|--app-only|--screenalytics-only]" >&2
      exit 1
      ;;
  esac
done

if [[ "$RUN_BACKEND" == "1" ]]; then
  echo "[test-fast] TRR-Backend..."
  if [[ ! -x "$ROOT/TRR-Backend/.venv/bin/python" ]]; then
    echo "[test-fast] ERROR: TRR-Backend/.venv missing. Run: make bootstrap" >&2
    exit 1
  fi
  "$ROOT/TRR-Backend/.venv/bin/ruff" check "$ROOT/TRR-Backend"
  "$ROOT/TRR-Backend/.venv/bin/ruff" format --check "$ROOT/TRR-Backend"
  if [[ -f "$ROOT/TRR-Backend/tests/api/test_health.py" ]]; then
    (cd "$ROOT/TRR-Backend" && "$ROOT/TRR-Backend/.venv/bin/pytest" -q tests/api/test_health.py)
  else
    (cd "$ROOT/TRR-Backend" && "$ROOT/TRR-Backend/.venv/bin/pytest" -q -k health --maxfail=1)
  fi
fi

if [[ "$RUN_APP" == "1" ]]; then
  echo "[test-fast] TRR-APP..."
  REQUIRED_NODE_MAJOR="$(trr_node_required_major "$ROOT")"
  if ! trr_ensure_node_baseline "$ROOT"; then
    echo "[test-fast] ERROR: Node $(trr_node_version_string) does not satisfy required ${REQUIRED_NODE_MAJOR}.x baseline." >&2
    echo "[test-fast] Remediation:" >&2
    echo "[test-fast]   source ~/.nvm/nvm.sh && nvm use ${REQUIRED_NODE_MAJOR}" >&2
    echo "[test-fast]   source ~/.nvm/nvm.sh && nvm install ${REQUIRED_NODE_MAJOR}" >&2
    exit 1
  fi
  (cd "$ROOT/TRR-APP/apps/web" && pnpm run lint)
fi

if [[ "$RUN_SCREENALYTICS" == "1" ]]; then
  echo "[test-fast] screenalytics..."
  if [[ ! -x "$ROOT/screenalytics/.venv/bin/python" ]]; then
    echo "[test-fast] ERROR: screenalytics/.venv missing. Run: make bootstrap" >&2
    exit 1
  fi
  "$ROOT/screenalytics/.venv/bin/python" -m py_compile \
    "$ROOT/screenalytics/apps/api/main.py" \
    "$ROOT/screenalytics/apps/workspace-ui/streamlit_app.py"
  if [[ -f "$ROOT/screenalytics/tests/api/test_trr_health.py" ]]; then
    (cd "$ROOT/screenalytics" && "$ROOT/screenalytics/.venv/bin/pytest" -q tests/api/test_trr_health.py)
  fi
fi

echo "[test-fast] Done."

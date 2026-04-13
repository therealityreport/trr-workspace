#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/node-baseline.sh"
source "$ROOT/scripts/lib/python-venv.sh"
RUN_BACKEND=1
RUN_APP=1

for arg in "$@"; do
  case "$arg" in
    --backend-only)
      RUN_BACKEND=1
      RUN_APP=0
      ;;
    --app-only)
      RUN_BACKEND=0
      RUN_APP=1
      ;;
    *)
      echo "Usage: $0 [--backend-only|--app-only]" >&2
      exit 1
      ;;
  esac
done

if [[ "$RUN_BACKEND" == "1" ]]; then
  echo "[test-fast] TRR-Backend..."
  trr_ensure_repo_runtime "$ROOT/TRR-Backend" "$ROOT/TRR-Backend/requirements.txt"
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

echo "[test-fast] Done."

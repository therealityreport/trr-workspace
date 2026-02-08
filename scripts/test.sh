#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "[test] TRR-Backend..."
if [[ ! -x "$ROOT/TRR-Backend/.venv/bin/python" ]]; then
  echo "[test] ERROR: TRR-Backend/.venv missing. Run: make bootstrap" >&2
  exit 1
fi
"$ROOT/TRR-Backend/.venv/bin/ruff" check "$ROOT/TRR-Backend"
"$ROOT/TRR-Backend/.venv/bin/ruff" format --check "$ROOT/TRR-Backend"
(cd "$ROOT/TRR-Backend" && "$ROOT/TRR-Backend/.venv/bin/pytest")

echo "[test] TRR-APP..."
(cd "$ROOT/TRR-APP/apps/web" && pnpm run lint && pnpm exec next build --webpack && pnpm run test:ci)

echo "[test] screenalytics..."
if [[ ! -x "$ROOT/screenalytics/.venv/bin/python" ]]; then
  echo "[test] ERROR: screenalytics/.venv missing. Run: make bootstrap" >&2
  exit 1
fi
"$ROOT/screenalytics/.venv/bin/python" -m py_compile \
  "$ROOT/screenalytics/apps/api/main.py" \
  "$ROOT/screenalytics/apps/workspace-ui/streamlit_app.py"
(cd "$ROOT/screenalytics" && "$ROOT/screenalytics/.venv/bin/pytest" -q tests/api/test_trr_health.py)

echo "[test] Done."

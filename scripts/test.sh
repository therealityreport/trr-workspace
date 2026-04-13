#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/python-venv.sh"

echo "[test] TRR-Backend..."
trr_ensure_repo_runtime "$ROOT/TRR-Backend" "$ROOT/TRR-Backend/requirements.txt"
"$ROOT/TRR-Backend/.venv/bin/ruff" check "$ROOT/TRR-Backend"
"$ROOT/TRR-Backend/.venv/bin/ruff" format --check "$ROOT/TRR-Backend"
(cd "$ROOT/TRR-Backend" && "$ROOT/TRR-Backend/.venv/bin/pytest")

echo "[test] TRR-APP..."
(cd "$ROOT/TRR-APP/apps/web" && pnpm run lint && pnpm exec next build --webpack && pnpm run test:ci)

echo "[test] Done."

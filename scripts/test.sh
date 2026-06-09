#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/node-baseline.sh"
source "$ROOT/scripts/lib/python-venv.sh"
source "$ROOT/scripts/lib/workspace-test-contracts.sh"

echo "[test] TRR-Backend..."
trr_ensure_repo_runtime "$ROOT/TRR-Backend" "$ROOT/TRR-Backend/requirements.txt"
"$ROOT/TRR-Backend/.venv/bin/ruff" check "$ROOT/TRR-Backend"
"$ROOT/TRR-Backend/.venv/bin/ruff" format --check "$ROOT/TRR-Backend"
(cd "$ROOT/TRR-Backend" && "$ROOT/TRR-Backend/.venv/bin/pytest")

echo "[test] Workspace script contracts..."
trr_workspace_pytest_contracts "$ROOT"

echo "[test] TRR-APP..."
trr_ensure_node_baseline_or_exit "test" "$ROOT"
(cd "$ROOT/TRR-APP/apps/web" && trr_pnpm "$ROOT/TRR-APP" run lint && trr_pnpm "$ROOT/TRR-APP" exec next build --webpack && trr_pnpm "$ROOT/TRR-APP" run test:ci)

echo "[test] Done."

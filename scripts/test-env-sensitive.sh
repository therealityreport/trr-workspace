#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/node-baseline.sh"
source "$ROOT/scripts/lib/python-venv.sh"

echo "[env-sensitive] backend targeted regression..."
trr_ensure_repo_runtime "$ROOT/TRR-Backend" "$ROOT/TRR-Backend/requirements.txt"
(cd "$ROOT/TRR-Backend" && "$ROOT/TRR-Backend/.venv/bin/pytest" -q \
  tests/repositories/test_social_season_analytics.py::test_load_twikit_credentials_falls_back_to_browser_cookies)

echo "[env-sensitive] TRR-APP lint/typecheck/test..."
REQUIRED_NODE_MAJOR="$(trr_node_required_major "$ROOT")"
if ! trr_ensure_node_baseline "$ROOT"; then
  echo "[env-sensitive] ERROR: Node $(trr_node_version_string) does not satisfy required ${REQUIRED_NODE_MAJOR}.x baseline." >&2
  exit 1
fi
(cd "$ROOT/TRR-APP/apps/web" && trr_pnpm "$ROOT/TRR-APP" run lint && trr_pnpm "$ROOT/TRR-APP" run typecheck && trr_pnpm "$ROOT/TRR-APP" run test:ci)

echo "[env-sensitive] Done."

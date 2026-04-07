#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/python-venv.sh"

echo "[env-sensitive] backend targeted regression..."
trr_ensure_repo_runtime "$ROOT/TRR-Backend" "$ROOT/TRR-Backend/requirements.txt"
(cd "$ROOT/TRR-Backend" && "$ROOT/TRR-Backend/.venv/bin/pytest" -q \
  tests/repositories/test_social_season_analytics.py::test_load_twikit_credentials_falls_back_to_browser_cookies)

echo "[env-sensitive] screenalytics unit suite..."
if [[ ! -x "$ROOT/screenalytics/.venv/bin/pytest" ]]; then
  echo "[env-sensitive] ERROR: screenalytics/.venv missing. Run: make bootstrap" >&2
  exit 1
fi
(cd "$ROOT/screenalytics" && "$ROOT/screenalytics/.venv/bin/pytest" tests/unit -q --maxfail=20)

echo "[env-sensitive] TRR-APP lint/typecheck/test..."
(cd "$ROOT/TRR-APP/apps/web" && pnpm run lint && pnpm run typecheck && pnpm run test:ci)

echo "[env-sensitive] Done."

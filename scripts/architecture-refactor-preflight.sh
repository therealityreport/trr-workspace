#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOOPBACK_DB_URL="postgresql://postgres:postgres@127.0.0.1:54322/postgres"

python3 "$ROOT/scripts/runtime_capacity.py" check
python3 "$ROOT/scripts/deployment_targets.py" check
env \
  -u TRR_DB_SESSION_URL \
  -u TRR_DB_URL \
  -u TRR_DB_FALLBACK_URL \
  -u DATABASE_URL \
  -u SUPABASE_DB_URL \
  PROFILE=architecture-refactor \
  WORKSPACE_DEV_MODE=local \
  WORKSPACE_TRR_DB_LANE=direct \
  TRR_DB_DIRECT_URL="$LOOPBACK_DB_URL" \
  bash "$ROOT/scripts/dev-workspace.sh" --assert-no-side-effects

echo "[architecture-refactor] OK: loopback DB target verified; apply, reconcile, hosted deploy, and remote workers are disabled."

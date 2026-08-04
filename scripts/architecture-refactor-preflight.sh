#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOOPBACK_DB_URL="postgresql://postgres:postgres@127.0.0.1:54322/postgres"

resolve_python_311_bin() {
  local candidate path
  for candidate in python3.11 python3 python; do
    if [[ -x "$candidate" ]]; then
      path="$candidate"
    elif command -v "$candidate" >/dev/null 2>&1; then
      path="$(command -v "$candidate")"
    else
      continue
    fi

    if "$path" - <<'PY' >/dev/null 2>&1
import sys
raise SystemExit(0 if sys.version_info >= (3, 11) else 1)
PY
    then
      printf '%s\n' "$path"
      return 0
    fi
  done

  echo "[architecture-refactor] ERROR: Python 3.11+ is required." >&2
  return 1
}

PYTHON_BIN="$(resolve_python_311_bin)"
"$PYTHON_BIN" "$ROOT/scripts/runtime_capacity.py" check
"$PYTHON_BIN" "$ROOT/scripts/deployment_targets.py" check
PYTHON_SHIM_DIR="$(mktemp -d "${TMPDIR:-/tmp}/trr-python.XXXXXX")"
trap 'rm -f "$PYTHON_SHIM_DIR/python3"; rmdir "$PYTHON_SHIM_DIR" 2>/dev/null || true' EXIT
ln -s "$PYTHON_BIN" "$PYTHON_SHIM_DIR/python3"
env \
  -u TRR_DB_SESSION_URL \
  -u TRR_DB_URL \
  -u TRR_DB_FALLBACK_URL \
  -u DATABASE_URL \
  -u SUPABASE_DB_URL \
  PATH="$PYTHON_SHIM_DIR:$PATH" \
  PROFILE=architecture-refactor \
  WORKSPACE_DEV_MODE=local \
  WORKSPACE_TRR_DB_LANE=direct \
  TRR_DB_DIRECT_URL="$LOOPBACK_DB_URL" \
  bash "$ROOT/scripts/dev-workspace.sh" --assert-no-side-effects

echo "[architecture-refactor] OK: loopback DB target verified; apply, reconcile, hosted deploy, and remote workers are disabled."

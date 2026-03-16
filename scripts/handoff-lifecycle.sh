#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-}"
LOG_DIR="$ROOT/.logs/workspace/handoff-sync"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
LOGFILE="$LOG_DIR/${TIMESTAMP}-${MODE:-unknown}-$$.log"

mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOGFILE") 2>&1

echo "[handoff-lifecycle] mode=${MODE} root=${ROOT} log=${LOGFILE}"

case "$MODE" in
  pre-plan)
    set +e
    make -C "$ROOT" --no-print-directory handoff-check
    rc="$?"
    set -e
    if [[ "$rc" == "0" ]]; then
      echo "[handoff-lifecycle] pre-plan check already clean."
      exit 0
    fi
    if [[ "$rc" == "1" ]]; then
      echo "[handoff-lifecycle] pre-plan detected generated-output drift; auto-healing."
      make -C "$ROOT" --no-print-directory handoff-sync
      make -C "$ROOT" --no-print-directory handoff-check
      echo "[handoff-lifecycle] pre-plan auto-heal completed."
      exit 0
    fi
    echo "[handoff-lifecycle] pre-plan failed. Fix canonical snapshot data before planning." >&2
    exit "$rc"
    ;;
  post-phase)
    make -C "$ROOT" --no-print-directory handoff-sync
    ;;
  closeout)
    make -C "$ROOT" --no-print-directory handoff-sync
    make -C "$ROOT" --no-print-directory check-policy
    ;;
  *)
    echo "[handoff-lifecycle] ERROR: expected mode pre-plan | post-phase | closeout" >&2
    exit 2
    ;;
esac

echo "[handoff-lifecycle] mode=${MODE} complete"

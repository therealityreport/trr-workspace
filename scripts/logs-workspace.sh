#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${ROOT}/.logs/workspace"

TRR_BACKEND_LOG="${LOG_DIR}/trr-backend.log"
TRR_APP_LOG="${LOG_DIR}/trr-app.log"
SCREENALYTICS_LOG="${LOG_DIR}/screenalytics.log"

mkdir -p "$LOG_DIR"

touch "$TRR_APP_LOG" "$TRR_BACKEND_LOG" "$SCREENALYTICS_LOG"

echo "[workspace] Tailing logs (Ctrl+C to stop):"
echo "  $TRR_APP_LOG"
echo "  $TRR_BACKEND_LOG"
echo "  $SCREENALYTICS_LOG"
echo ""

tail -n 200 -f "$TRR_APP_LOG" "$TRR_BACKEND_LOG" "$SCREENALYTICS_LOG"


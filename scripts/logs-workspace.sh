#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${ROOT}/.logs/workspace"

TRR_BACKEND_LOG="${LOG_DIR}/trr-backend.log"
TRR_APP_LOG="${LOG_DIR}/trr-app.log"
SOCIAL_WORKER_LOG="${LOG_DIR}/social-worker.log"
REMOTE_WORKER_LOG="${LOG_DIR}/remote-workers.log"
BACKEND_WATCHDOG_EVENTS_LOG="${LOG_DIR}/backend-watchdog-events.jsonl"

mkdir -p "$LOG_DIR"

touch "$TRR_APP_LOG" "$TRR_BACKEND_LOG" "$SOCIAL_WORKER_LOG" "$REMOTE_WORKER_LOG" "$BACKEND_WATCHDOG_EVENTS_LOG"

echo "[workspace] Tailing logs (Ctrl+C to stop):"
echo "  $TRR_APP_LOG"
echo "  $TRR_BACKEND_LOG"
echo "  $SOCIAL_WORKER_LOG"
echo "  $REMOTE_WORKER_LOG"
echo "  $BACKEND_WATCHDOG_EVENTS_LOG"
echo ""

tail -n 200 -f "$TRR_APP_LOG" "$TRR_BACKEND_LOG" "$SOCIAL_WORKER_LOG" "$REMOTE_WORKER_LOG" "$BACKEND_WATCHDOG_EVENTS_LOG"

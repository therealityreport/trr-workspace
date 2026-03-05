#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE_DIR="$ROOT/.logs/workspace/archive"
MAX_DAYS="${WORKSPACE_LOG_MAX_DAYS:-14}"
MAX_ARCHIVE_MB="${WORKSPACE_LOG_MAX_ARCHIVE_MB:-1024}"

if [[ ! "$MAX_DAYS" =~ ^[0-9]+$ ]]; then
  echo "[logs-prune] ERROR: WORKSPACE_LOG_MAX_DAYS must be a non-negative integer." >&2
  exit 1
fi

if [[ ! "$MAX_ARCHIVE_MB" =~ ^[1-9][0-9]*$ ]]; then
  echo "[logs-prune] ERROR: WORKSPACE_LOG_MAX_ARCHIVE_MB must be a positive integer." >&2
  exit 1
fi

if [[ ! -d "$ARCHIVE_DIR" ]]; then
  echo "[logs-prune] No archive directory found at ${ARCHIVE_DIR}; nothing to prune."
  exit 0
fi

if [[ "$MAX_DAYS" -gt 0 ]]; then
  echo "[logs-prune] Removing archives older than ${MAX_DAYS} day(s)..."
  find "$ARCHIVE_DIR" -mindepth 1 -maxdepth 1 -type d -mtime +"$MAX_DAYS" -print -exec rm -rf {} +
fi

max_kb=$((MAX_ARCHIVE_MB * 1024))
current_kb="$(du -sk "$ARCHIVE_DIR" 2>/dev/null | awk '{print $1}')"
if [[ -z "$current_kb" ]]; then
  current_kb=0
fi

if (( current_kb <= max_kb )); then
  echo "[logs-prune] Archive size ${current_kb}KB within limit ${max_kb}KB."
  exit 0
fi

echo "[logs-prune] Archive size ${current_kb}KB exceeds limit ${max_kb}KB; pruning oldest snapshots..."

mapfile -t snapshots < <(find "$ARCHIVE_DIR" -mindepth 1 -maxdepth 1 -type d | sort)
for snapshot in "${snapshots[@]}"; do
  if (( current_kb <= max_kb )); then
    break
  fi
  echo "[logs-prune] Removing ${snapshot}"
  rm -rf "$snapshot"
  current_kb="$(du -sk "$ARCHIVE_DIR" 2>/dev/null | awk '{print $1}')"
  if [[ -z "$current_kb" ]]; then
    current_kb=0
  fi
done

echo "[logs-prune] Final archive size: ${current_kb}KB"

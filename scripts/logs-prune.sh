#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE_DIR="$ROOT/.logs/workspace/archive"
HANDOFF_SYNC_DIR="$ROOT/.logs/workspace/handoff-sync"
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

prune_log_dir() {
  local target_dir="$1"
  local label="$2"
  local max_kb current_kb

  if [[ ! -d "$target_dir" ]]; then
    echo "[logs-prune] No ${label} directory found at ${target_dir}; nothing to prune."
    return 0
  fi

  if [[ "$MAX_DAYS" -gt 0 ]]; then
    echo "[logs-prune] Removing ${label} entries older than ${MAX_DAYS} day(s)..."
    find "$target_dir" -mindepth 1 -maxdepth 1 -mtime +"$MAX_DAYS" -print -exec rm -rf {} +
  fi

  max_kb=$((MAX_ARCHIVE_MB * 1024))
  current_kb="$(du -sk "$target_dir" 2>/dev/null | awk '{print $1}')"
  if [[ -z "$current_kb" ]]; then
    current_kb=0
  fi

  if (( current_kb <= max_kb )); then
    echo "[logs-prune] ${label} size ${current_kb}KB within limit ${max_kb}KB."
    return 0
  fi

  echo "[logs-prune] ${label} size ${current_kb}KB exceeds limit ${max_kb}KB; pruning oldest entries..."
  mapfile -t entries < <(find "$target_dir" -mindepth 1 -maxdepth 1 -print | sort)
  for entry in "${entries[@]}"; do
    if (( current_kb <= max_kb )); then
      break
    fi
    echo "[logs-prune] Removing ${entry}"
    rm -rf "$entry"
    current_kb="$(du -sk "$target_dir" 2>/dev/null | awk '{print $1}')"
    if [[ -z "$current_kb" ]]; then
      current_kb=0
    fi
  done

  echo "[logs-prune] Final ${label} size: ${current_kb}KB"
}

prune_log_dir "$ARCHIVE_DIR" "archive"
prune_log_dir "$HANDOFF_SYNC_DIR" "handoff-sync"

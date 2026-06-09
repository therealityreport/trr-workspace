#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_ROOT="${CONTEXT7_PLUGIN_ROOT:-$HOME/.codex/plugins/context7}"
CACHE_ROOT="${CONTEXT7_CACHE_ROOT:-$HOME/.codex/plugins/cache/local-plugins/context7}"
CACHE_VERSION="${CONTEXT7_CACHE_VERSION:-0.1.2}"
CACHE_PLUGIN_ROOT="${CACHE_ROOT}/${CACHE_VERSION}"

if [[ ! -x "$PLUGIN_ROOT/scripts/repair-context7-mcp.mjs" ]]; then
  echo "[context7-repair] ERROR: missing Context7 repair script: $PLUGIN_ROOT/scripts/repair-context7-mcp.mjs" >&2
  exit 1
fi

node "$PLUGIN_ROOT/scripts/repair-context7-mcp.mjs" --repair --reload
node "$PLUGIN_ROOT/scripts/doctor-context7-mcp.mjs"
node "$PLUGIN_ROOT/scripts/validate-plugin.mjs"
node "$PLUGIN_ROOT/scripts/smoke-context7-app-compat.mjs"

if [[ -d "$CACHE_PLUGIN_ROOT" ]]; then
  if diff -qr "$PLUGIN_ROOT" "$CACHE_PLUGIN_ROOT" \
    -x .DS_Store \
    -x 'node_modules' \
    >/tmp/context7-cache-parity.diff 2>&1; then
    echo "[context7-repair] Cache parity OK: ${CACHE_PLUGIN_ROOT}"
    stale_found=0
    while IFS= read -r stale_dir; do
      [[ -n "$stale_dir" ]] || continue
      stale_found=1
      rm -rf "$stale_dir"
      echo "[context7-repair] Removed stale Context7 cache copy: ${stale_dir}"
    done < <(find "$CACHE_ROOT" -mindepth 1 -maxdepth 1 -type d ! -name "$CACHE_VERSION" -print 2>/dev/null)
    if [[ "$stale_found" == "0" ]]; then
      echo "[context7-repair] No stale Context7 cache copies found."
    fi
  else
    echo "[context7-repair] ERROR: Context7 cache copy differs from installed plugin: ${CACHE_PLUGIN_ROOT}" >&2
    cat /tmp/context7-cache-parity.diff >&2
    exit 1
  fi
else
  echo "[context7-repair] WARNING: Context7 cache copy missing: ${CACHE_PLUGIN_ROOT}" >&2
fi

echo "[context7-repair] OK: Context7 config points to the compatibility wrapper and the wrapper smoke passed."

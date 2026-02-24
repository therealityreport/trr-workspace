#!/usr/bin/env bash
set -euo pipefail

PRIMARY_URL="${1:-}"
STREAMLIT_URL="${2:-}"
WEB_URL="${3:-}"

if [[ -z "$PRIMARY_URL" ]]; then
  echo "[open-workspace-dev-window] ERROR: primary URL is required."
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPEN_OR_REFRESH_SCRIPT="${SCRIPT_DIR}/open-or-refresh-browser-tab.sh"

open_with_default() {
  local target_url="$1"
  if [[ -z "$target_url" ]]; then
    return 0
  fi
  if command -v open >/dev/null 2>&1; then
    open "$target_url" >/dev/null 2>&1 || true
    return 0
  fi
  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$target_url" >/dev/null 2>&1 || true
    return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 -m webbrowser "$target_url" >/dev/null 2>&1 || true
  fi
}

open_or_refresh() {
  local url="$1"
  local label="$2"
  if [[ -z "$url" ]]; then
    return 0
  fi

  if [[ -x "$OPEN_OR_REFRESH_SCRIPT" ]]; then
    if "$OPEN_OR_REFRESH_SCRIPT" "$url" "$label"; then
      return 0
    fi
    open_with_default "$url"
    return 0
  fi

  open_with_default "$url"
}

open_or_refresh "$PRIMARY_URL" "TRR APP/Admin"
open_or_refresh "$STREAMLIT_URL" "screenalytics Streamlit"
open_or_refresh "$WEB_URL" "screenalytics Web"

echo "[open-workspace-dev-window] Refreshed existing tabs when found; opened new tabs for missing URLs."
exit 0

#!/usr/bin/env bash
set -euo pipefail

URL="${1:-}"
LABEL="${2:-browser tab}"

if [[ -z "$URL" ]]; then
  echo "[open-or-refresh-browser-tab] ERROR: URL is required."
  exit 2
fi

URL_NO_SLASH="${URL%/}"
if [[ -z "$URL_NO_SLASH" ]]; then
  URL_NO_SLASH="$URL"
fi
URL_WITH_SLASH="${URL_NO_SLASH}/"

open_with_default() {
  local target_url="$1"
  open "$target_url" >/dev/null 2>&1 || true
}

refresh_chrome_tab() {
  local target_url="$1"
  local url_no_slash="$2"
  local url_with_slash="$3"

  osascript <<APPLESCRIPT "$target_url" "$url_no_slash" "$url_with_slash" 2>/dev/null || return 1
on run argv
  set targetURL to item 1 of argv
  set targetURLNoSlash to item 2 of argv
  set targetURLWithSlash to item 3 of argv

  tell application "Google Chrome"
    activate
    if (count of every window) is 0 then
      return "not_found"
    end if

    repeat with aWindow in every window
      repeat with tabIndex from 1 to (count of tabs of aWindow)
        set aTab to tab tabIndex of aWindow
        set tabURL to URL of aTab
        if (tabURL = targetURL) or (tabURL = targetURLNoSlash) or (tabURL = targetURLWithSlash) then
          set active tab index of aWindow to tabIndex
          tell aTab to reload
          set index of aWindow to 1
          return "found"
        end if
      end repeat
    end repeat

    return "not_found"
  end tell
end run
APPLESCRIPT
}

refresh_safari_tab() {
  local target_url="$1"
  local url_no_slash="$2"
  local url_with_slash="$3"

  osascript <<APPLESCRIPT "$target_url" "$url_no_slash" "$url_with_slash" 2>/dev/null || return 1
on run argv
  set targetURL to item 1 of argv
  set targetURLNoSlash to item 2 of argv
  set targetURLWithSlash to item 3 of argv

  tell application "Safari"
    activate
    if (count of every window) is 0 then
      return "not_found"
    end if

    repeat with aWindow in every window
      repeat with aTab in tabs of aWindow
        set tabURL to URL of aTab
        if (tabURL = targetURL) or (tabURL = targetURLNoSlash) or (tabURL = targetURLWithSlash) then
          set current tab of aWindow to aTab
          do JavaScript "window.location.reload();" in aTab
          set index of aWindow to 1
          return "found"
        end if
      end repeat
    end repeat

    return "not_found"
  end tell
end run
APPLESCRIPT
}

if [[ "$(uname)" != "Darwin" ]]; then
  echo "[open-or-refresh-browser-tab] Opening (non-macOS): ${LABEL} -> ${URL}"
  open_with_default "$URL"
  exit 0
fi

if command -v osascript >/dev/null 2>&1; then
  if refresh_chrome_tab "$URL" "$URL_NO_SLASH" "$URL_WITH_SLASH" | grep -q "found"; then
    echo "[open-or-refresh-browser-tab] Reused existing tab: ${LABEL} -> ${URL}"
    exit 0
  fi

  if refresh_safari_tab "$URL" "$URL_NO_SLASH" "$URL_WITH_SLASH" | grep -q "found"; then
    echo "[open-or-refresh-browser-tab] Reused existing tab: ${LABEL} -> ${URL}"
    exit 0
  fi
fi

echo "[open-or-refresh-browser-tab] Opening new tab: ${LABEL} -> ${URL}"
open_with_default "$URL"
exit 0

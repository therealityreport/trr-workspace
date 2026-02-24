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

ALT_URL_NO_SLASH=""
ALT_URL_WITH_SLASH=""
if [[ "$URL_NO_SLASH" =~ ^http://127\.0\.0\.1:([0-9]+)(/.*)?$ ]]; then
  ALT_URL_NO_SLASH="http://localhost:${BASH_REMATCH[1]}"
  ALT_URL_WITH_SLASH="${ALT_URL_NO_SLASH}/"
elif [[ "$URL_NO_SLASH" =~ ^http://localhost:([0-9]+)(/.*)?$ ]]; then
  ALT_URL_NO_SLASH="http://127.0.0.1:${BASH_REMATCH[1]}"
  ALT_URL_WITH_SLASH="${ALT_URL_NO_SLASH}/"
fi

open_with_default() {
  local target_url="$1"
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

refresh_chrome_tabs() {
  local target_url="$1"
  local url_no_slash="$2"
  local url_with_slash="$3"
  local alt_url_no_slash="${4:-}"
  local alt_url_with_slash="${5:-}"

  osascript - "$target_url" "$url_no_slash" "$url_with_slash" "$alt_url_no_slash" "$alt_url_with_slash" 2>/dev/null <<'APPLESCRIPT' || return 1
on run argv
  set targetURL to item 1 of argv
  set targetURLNoSlash to item 2 of argv
  set targetURLWithSlash to item 3 of argv
  set altURLNoSlash to item 4 of argv
  set altURLWithSlash to item 5 of argv

  tell application "Google Chrome"
    activate
    if (count of every window) is 0 then
      return "0"
    end if

    set refreshedCount to 0
    set firstWindowIndex to 0
    set firstTabIndex to 0
    set windowCounter to 0

    repeat with aWindow in every window
      set windowCounter to windowCounter + 1
      repeat with tabIndex from 1 to (count of tabs of aWindow)
        set aTab to tab tabIndex of aWindow
        set tabURL to URL of aTab
        if my urlMatches(tabURL, targetURL, targetURLNoSlash, targetURLWithSlash, altURLNoSlash, altURLWithSlash) then
          tell aTab to reload
          set refreshedCount to refreshedCount + 1
          if firstWindowIndex is 0 then
            set firstWindowIndex to windowCounter
            set firstTabIndex to tabIndex
          end if
        end if
      end repeat
    end repeat

    if refreshedCount > 0 then
      set focusWindow to window firstWindowIndex
      set active tab index of focusWindow to firstTabIndex
      set index of focusWindow to 1
    end if

    return refreshedCount as text
  end tell
end run

on urlMatches(tabURL, targetURL, targetURLNoSlash, targetURLWithSlash, altURLNoSlash, altURLWithSlash)
  if tabURL is missing value then
    return false
  end if
  if (tabURL = targetURL) or (tabURL = targetURLNoSlash) or (tabURL = targetURLWithSlash) then
    return true
  end if
  if (tabURL starts with targetURLWithSlash) or (tabURL starts with targetURLNoSlash) then
    return true
  end if
  if altURLNoSlash is not "" then
    if (tabURL = altURLNoSlash) or (tabURL = altURLWithSlash) then
      return true
    end if
    if (tabURL starts with altURLWithSlash) or (tabURL starts with altURLNoSlash) then
      return true
    end if
  end if
  return false
end urlMatches
APPLESCRIPT
}

refresh_safari_tabs() {
  local target_url="$1"
  local url_no_slash="$2"
  local url_with_slash="$3"
  local alt_url_no_slash="${4:-}"
  local alt_url_with_slash="${5:-}"

  osascript - "$target_url" "$url_no_slash" "$url_with_slash" "$alt_url_no_slash" "$alt_url_with_slash" 2>/dev/null <<'APPLESCRIPT' || return 1
on run argv
  set targetURL to item 1 of argv
  set targetURLNoSlash to item 2 of argv
  set targetURLWithSlash to item 3 of argv
  set altURLNoSlash to item 4 of argv
  set altURLWithSlash to item 5 of argv

  tell application "Safari"
    activate
    if (count of every window) is 0 then
      return "0"
    end if

    set refreshedCount to 0
    set firstWindowIndex to 0
    set firstTabIndex to 0
    set windowCounter to 0

    repeat with aWindow in every window
      set windowCounter to windowCounter + 1
      set tabCounter to 0
      repeat with aTab in tabs of aWindow
        set tabCounter to tabCounter + 1
        set tabURL to URL of aTab
        if my urlMatches(tabURL, targetURL, targetURLNoSlash, targetURLWithSlash, altURLNoSlash, altURLWithSlash) then
          do JavaScript "window.location.reload();" in aTab
          set refreshedCount to refreshedCount + 1
          if firstWindowIndex is 0 then
            set firstWindowIndex to windowCounter
            set firstTabIndex to tabCounter
          end if
        end if
      end repeat
    end repeat

    if refreshedCount > 0 then
      set focusWindow to window firstWindowIndex
      set current tab of focusWindow to tab firstTabIndex of focusWindow
      set index of focusWindow to 1
    end if

    return refreshedCount as text
  end tell
end run

on urlMatches(tabURL, targetURL, targetURLNoSlash, targetURLWithSlash, altURLNoSlash, altURLWithSlash)
  if tabURL is missing value then
    return false
  end if
  if (tabURL = targetURL) or (tabURL = targetURLNoSlash) or (tabURL = targetURLWithSlash) then
    return true
  end if
  if (tabURL starts with targetURLWithSlash) or (tabURL starts with targetURLNoSlash) then
    return true
  end if
  if altURLNoSlash is not "" then
    if (tabURL = altURLNoSlash) or (tabURL = altURLWithSlash) then
      return true
    end if
    if (tabURL starts with altURLWithSlash) or (tabURL starts with altURLNoSlash) then
      return true
    end if
  end if
  return false
end urlMatches
APPLESCRIPT
}

if [[ "$(uname)" != "Darwin" ]]; then
  echo "[open-or-refresh-browser-tab] Opening (non-macOS): ${LABEL} -> ${URL}"
  open_with_default "$URL"
  exit 0
fi

if command -v osascript >/dev/null 2>&1; then
  refreshed_count="$(refresh_chrome_tabs "$URL" "$URL_NO_SLASH" "$URL_WITH_SLASH" "$ALT_URL_NO_SLASH" "$ALT_URL_WITH_SLASH" || true)"
  if [[ "$refreshed_count" =~ ^[0-9]+$ ]] && (( refreshed_count > 0 )); then
    echo "[open-or-refresh-browser-tab] Refreshed ${refreshed_count} existing Chrome tab(s): ${LABEL} -> ${URL}"
    exit 0
  fi

  refreshed_count="$(refresh_safari_tabs "$URL" "$URL_NO_SLASH" "$URL_WITH_SLASH" "$ALT_URL_NO_SLASH" "$ALT_URL_WITH_SLASH" || true)"
  if [[ "$refreshed_count" =~ ^[0-9]+$ ]] && (( refreshed_count > 0 )); then
    echo "[open-or-refresh-browser-tab] Refreshed ${refreshed_count} existing Safari tab(s): ${LABEL} -> ${URL}"
    exit 0
  fi
fi

echo "[open-or-refresh-browser-tab] Opening new tab: ${LABEL} -> ${URL}"
open_with_default "$URL"
exit 0

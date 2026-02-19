#!/usr/bin/env bash
set -euo pipefail

PRIMARY_URL="${1:-}"
SECONDARY_URL="${2:-}"

if [[ -z "$PRIMARY_URL" ]]; then
  echo "[open-workspace-dev-window] ERROR: primary URL is required."
  exit 2
fi

normalize_url() {
  local url="$1"
  if [[ "$url" == */ ]]; then
    echo "${url%/}"
    return 0
  fi
  echo "$url"
}

origin_from_url() {
  local url="$1"
  if [[ "$url" =~ ^https?://[^/]+ ]]; then
    echo "${BASH_REMATCH[0]}"
    return 0
  fi
  echo "$url"
}

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
    return 0
  fi
}

open_default_urls() {
  echo "[open-workspace-dev-window] Fallback: opening URLs with default browser."
  open_with_default "$PRIMARY_URL"
  open_with_default "$SECONDARY_URL"
}

PRIMARY_URL="$(normalize_url "$PRIMARY_URL")"
SECONDARY_URL="$(normalize_url "$SECONDARY_URL")"
PRIMARY_ORIGIN="$(origin_from_url "$PRIMARY_URL")"
SECONDARY_ORIGIN=""
if [[ -n "$SECONDARY_URL" ]]; then
  SECONDARY_ORIGIN="$(origin_from_url "$SECONDARY_URL")"
fi

open_chrome_window() {
  local result
  result="$(
    osascript "$PRIMARY_URL" "$SECONDARY_URL" "$PRIMARY_ORIGIN" "$SECONDARY_ORIGIN" <<'APPLESCRIPT'
on run argv
  set primaryURL to item 1 of argv
  set secondaryURL to item 2 of argv
  set primaryOrigin to item 3 of argv
  set secondaryOrigin to item 4 of argv

  tell application "Google Chrome"
    activate
    my closeMatchingTabs(primaryOrigin, secondaryOrigin)

    set newWindow to make new window
    set URL of active tab of newWindow to primaryURL
    if secondaryURL is not "" then
      make new tab at end of tabs of newWindow with properties {URL:secondaryURL}
    end if
    set active tab index of newWindow to 1
    set index of newWindow to 1
  end tell

  return "ok"
end run

on closeMatchingTabs(primaryOrigin, secondaryOrigin)
  tell application "Google Chrome"
    set windowCount to count of windows
    repeat with winIndex from windowCount to 1 by -1
      set aWindow to window winIndex
      set tabCount to count of tabs of aWindow
      repeat with tabIndex from tabCount to 1 by -1
        set aTab to tab tabIndex of aWindow
        set tabURL to URL of aTab
        if my shouldCloseURL(tabURL, primaryOrigin, secondaryOrigin) then
          close aTab
        end if
      end repeat
      if (count of tabs of aWindow) is 0 then
        close aWindow
      end if
    end repeat
  end tell
end closeMatchingTabs

on shouldCloseURL(tabURL, primaryOrigin, secondaryOrigin)
  if tabURL is missing value then
    return false
  end if
  if (tabURL is equal to primaryOrigin) or (tabURL starts with (primaryOrigin & "/")) then
    return true
  end if
  if secondaryOrigin is not "" then
    if (tabURL is equal to secondaryOrigin) or (tabURL starts with (secondaryOrigin & "/")) then
      return true
    end if
  end if
  return false
end shouldCloseURL
APPLESCRIPT
  )" || return 1

  [[ "$result" == "ok" ]]
}

open_safari_window() {
  local result
  result="$(
    osascript "$PRIMARY_URL" "$SECONDARY_URL" "$PRIMARY_ORIGIN" "$SECONDARY_ORIGIN" <<'APPLESCRIPT'
on run argv
  set primaryURL to item 1 of argv
  set secondaryURL to item 2 of argv
  set primaryOrigin to item 3 of argv
  set secondaryOrigin to item 4 of argv

  tell application "Safari"
    activate
    my closeMatchingTabs(primaryOrigin, secondaryOrigin)

    set newWindow to make new document
    set URL of current tab of newWindow to primaryURL
    if secondaryURL is not "" then
      tell newWindow
        make new tab with properties {URL:secondaryURL}
      end tell
    end if
    set current tab of newWindow to tab 1 of newWindow
    set index of newWindow to 1
  end tell

  return "ok"
end run

on closeMatchingTabs(primaryOrigin, secondaryOrigin)
  tell application "Safari"
    set windowCount to count of windows
    repeat with winIndex from windowCount to 1 by -1
      set aWindow to window winIndex
      set tabCount to count of tabs of aWindow
      repeat with tabIndex from tabCount to 1 by -1
        set aTab to tab tabIndex of aWindow
        set tabURL to URL of aTab
        if my shouldCloseURL(tabURL, primaryOrigin, secondaryOrigin) then
          close aTab
        end if
      end repeat
      if (count of tabs of aWindow) is 0 then
        close aWindow
      end if
    end repeat
  end tell
end closeMatchingTabs

on shouldCloseURL(tabURL, primaryOrigin, secondaryOrigin)
  if tabURL is missing value then
    return false
  end if
  if (tabURL is equal to primaryOrigin) or (tabURL starts with (primaryOrigin & "/")) then
    return true
  end if
  if secondaryOrigin is not "" then
    if (tabURL is equal to secondaryOrigin) or (tabURL starts with (secondaryOrigin & "/")) then
      return true
    end if
  end if
  return false
end shouldCloseURL
APPLESCRIPT
  )" || return 1

  [[ "$result" == "ok" ]]
}

if [[ "$(uname)" != "Darwin" ]]; then
  open_default_urls
  exit 0
fi

if ! command -v osascript >/dev/null 2>&1; then
  open_default_urls
  exit 0
fi

if open_chrome_window; then
  echo "[open-workspace-dev-window] Opened fresh Chrome window for workspace URLs."
  exit 0
fi

if open_safari_window; then
  echo "[open-workspace-dev-window] Opened fresh Safari window for workspace URLs."
  exit 0
fi

echo "[open-workspace-dev-window] WARNING: browser automation unavailable; using fallback."
open_default_urls
exit 0

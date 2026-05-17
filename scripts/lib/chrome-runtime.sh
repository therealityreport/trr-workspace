#!/usr/bin/env bash

chrome_endpoint_reachable() {
  local port="$1"
  curl -sf "http://127.0.0.1:${port}/json/version" >/dev/null 2>&1
}

chrome_page_targets_tsv() {
  local port="$1"
  local payload

  payload="$(curl -sf "http://127.0.0.1:${port}/json/list" 2>/dev/null || true)"
  if [[ -z "$payload" ]]; then
    return 1
  fi

  python3 - <<'PY' "$payload"
import json
import sys

payload = sys.argv[1]
try:
    targets = json.loads(payload)
except json.JSONDecodeError:
    raise SystemExit(1)

for target in targets:
    if str(target.get("type") or "") != "page":
        continue
    print(
        "\t".join(
            [
                str(target.get("id") or "").strip(),
                str(target.get("url") or "").strip(),
                str(target.get("title") or "").replace("\t", " ").strip(),
            ]
        )
    )
PY
}

chrome_page_count() {
  local port="$1"
  local output

  output="$(chrome_page_targets_tsv "$port" 2>/dev/null || true)"
  if [[ -z "$output" ]]; then
    echo "0"
    return 0
  fi

  printf '%s\n' "$output" | sed '/^$/d' | wc -l | tr -d ' '
}

chrome_close_target() {
  local port="$1"
  local target_id="$2"
  curl -sf "http://127.0.0.1:${port}/json/close/${target_id}" >/dev/null 2>&1
}

chrome_listener_pid() {
  local port="$1"
  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:"${port}" -sTCP:LISTEN -t 2>/dev/null | head -n 1 || true
  fi
}

chrome_process_profile_directory() {
  local pid="$1"
  local command_line
  local profile_directory

  [[ -n "$pid" ]] || return 0
  command_line="$(ps -ww -o command= -p "$pid" 2>/dev/null || true)"
  [[ "$command_line" == *"--profile-directory="* ]] || return 0

  profile_directory="${command_line#*--profile-directory=}"
  profile_directory="${profile_directory%% --*}"
  printf '%s\n' "$profile_directory"
}

default_chrome_profile_for_port() {
  local port="$1"
  case "$port" in
    9222|9422)
      echo "${HOME}/.chrome-profiles/codex-agent"
      ;;
    *)
      echo "${HOME}/.chrome-profiles/codex-chat-${port}"
      ;;
  esac
}

default_chrome_profile_directory_for_profile_dir() {
  local profile_dir="$1"
  local account_email="${2:-${CHROME_AGENT_PROFILE_EMAIL:-codex@thereality.report}}"

  [[ -n "$profile_dir" && -d "$profile_dir" && -n "$account_email" ]] || return 0
  command -v python3 >/dev/null 2>&1 || return 0

  python3 - "$profile_dir" "$account_email" <<'PY' 2>/dev/null || true
import json
import sys
from pathlib import Path

root = Path(sys.argv[1]).expanduser()
email = sys.argv[2].strip().lower()
if not email:
    raise SystemExit(0)

for preferences in sorted(root.glob("*/Preferences")):
    try:
        payload = json.loads(preferences.read_text(encoding="utf-8"))
    except Exception:
        continue
    account_info = payload.get("account_info")
    if not isinstance(account_info, list):
        continue
    for account in account_info:
        if not isinstance(account, dict):
            continue
        if str(account.get("email") or "").strip().lower() == email:
            print(preferences.parent.name)
            raise SystemExit(0)
PY
}

default_chrome_profile_directory_for_port() {
  local port="$1"
  default_chrome_profile_directory_for_profile_dir "$(default_chrome_profile_for_port "$port")"
}

default_chrome_headless_for_port() {
  local port="$1"
  case "$port" in
    9422)
      echo "1"
      ;;
    9222)
      echo "0"
      ;;
    *)
      echo "1"
      ;;
  esac
}

heal_shared_chrome_runtime_state() {
  local log_dir="$1"
  local port="${2:-9422}"
  local pidfile="${log_dir}/chrome-agent-${port}.pid"
  local statefile="${log_dir}/chrome-agent-${port}.env"
  local legacy_pidfile="${log_dir}/chrome-agent.pid"
  local profile_dir
  local profile_directory
  local desired_headless
  local listener_pid
  local current_pid
  local current_profile
  local current_profile_directory
  local current_headless
  local changed=0

  if ! chrome_endpoint_reachable "$port"; then
    return 1
  fi

  listener_pid="$(chrome_listener_pid "$port")"
  if [[ -z "$listener_pid" ]]; then
    return 2
  fi

  current_pid="$(cat "$pidfile" 2>/dev/null || true)"
  if [[ "$current_pid" != "$listener_pid" ]]; then
    printf '%s\n' "$listener_pid" >"$pidfile"
    changed=1
  fi

  if [[ "$port" == "9222" ]]; then
    current_pid="$(cat "$legacy_pidfile" 2>/dev/null || true)"
    if [[ "$current_pid" != "$listener_pid" ]]; then
      printf '%s\n' "$listener_pid" >"$legacy_pidfile"
      changed=1
    fi
  fi

  profile_dir="$(default_chrome_profile_for_port "$port")"
  profile_directory="$(chrome_process_profile_directory "$listener_pid")"
  desired_headless="$(default_chrome_headless_for_port "$port")"
  current_profile="$(sed -n 's/^PROFILE_DIR=//p' "$statefile" | head -n 1)"
  current_profile_directory="$(sed -n 's/^PROFILE_DIRECTORY=//p' "$statefile" | head -n 1)"
  current_headless="$(sed -n 's/^HEADLESS=//p' "$statefile" | head -n 1)"
  if [[ "$current_profile" != "$profile_dir" || "$current_profile_directory" != "$profile_directory" || "$current_headless" != "$desired_headless" || "$(sed -n 's/^PID=//p' "$statefile" | head -n 1)" != "$listener_pid" ]]; then
    cat >"$statefile" <<EOF
DEBUG_PORT=${port}
PROFILE_DIR=${profile_dir}
PROFILE_DIRECTORY=${profile_directory}
HEADLESS=${desired_headless}
PID=${listener_pid}
EOF
    changed=1
  fi

  echo "$listener_pid:$changed"
}

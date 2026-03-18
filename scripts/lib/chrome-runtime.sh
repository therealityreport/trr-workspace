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

default_chrome_profile_for_port() {
  local port="$1"
  if [[ "$port" == "9222" ]]; then
    echo "${HOME}/.chrome-profiles/claude-agent"
  else
    echo "${HOME}/.chrome-profiles/codex-chat-${port}"
  fi
}

heal_shared_chrome_runtime_state() {
  local log_dir="$1"
  local port="${2:-9222}"
  local pidfile="${log_dir}/chrome-agent-${port}.pid"
  local statefile="${log_dir}/chrome-agent-${port}.env"
  local legacy_pidfile="${log_dir}/chrome-agent.pid"
  local profile_dir
  local listener_pid
  local current_pid
  local current_profile
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
  current_profile="$(sed -n 's/^PROFILE_DIR=//p' "$statefile" | head -n 1)"
  current_headless="$(sed -n 's/^HEADLESS=//p' "$statefile" | head -n 1)"
  if [[ "$current_profile" != "$profile_dir" || "$current_headless" != "0" || "$(sed -n 's/^PID=//p' "$statefile" | head -n 1)" != "$listener_pid" ]]; then
    cat >"$statefile" <<EOF
DEBUG_PORT=${port}
PROFILE_DIR=${profile_dir}
HEADLESS=0
PID=${listener_pid}
EOF
    changed=1
  fi

  echo "$listener_pid:$changed"
}

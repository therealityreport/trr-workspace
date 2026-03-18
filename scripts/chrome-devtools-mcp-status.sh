#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${CODEX_CONFIG_FILE:-${HOME}/.codex/config.toml}"
EXPECTED_COMMAND="${ROOT}/scripts/codex-chrome-devtools-mcp.sh"
LOG_DIR="${ROOT}/.logs/workspace"
SHARED_PORT="9222"
STATUS_MODE="${CHROME_DEVTOOLS_MCP_STATUS_MODE:-detailed}"
source "${ROOT}/scripts/lib/chrome-runtime.sh"
source "${ROOT}/scripts/lib/mcp-runtime.sh"
TAB_CAP_DEFAULT="${CODEX_CHROME_TAB_CAP:-3}"
TAB_TARGET_DEFAULT="${CODEX_CHROME_TAB_TARGET:-1}"

fail() {
  echo "[chrome-devtools-mcp] ERROR: $*" >&2
  exit 1
}

warn() {
  echo "[chrome-devtools-mcp] WARNING: $*" >&2
}

codex_cli_available() {
  command -v codex >/dev/null 2>&1
}

validate_repo_managed_codex_config() {
  if ! bash "${ROOT}/scripts/codex-config-sync.sh" validate >/dev/null; then
    fail "Codex config drift detected. Run: bash ${ROOT}/scripts/codex-config-sync.sh install"
  fi
}

codex_registry_line_for_chrome() {
  codex mcp list 2>/dev/null | awk '/^chrome-devtools[[:space:]]/ { print; exit }'
}

codex_registry_enabled() {
  local line="$1"
  [[ -n "$line" && "$line" == *" enabled "* ]]
}

is_summary_mode() {
  [[ "$STATUS_MODE" == "summary" ]]
}

isolated_profile_state() {
  local profile
  shopt -s nullglob
  for profile in "${HOME}"/.chrome-profiles/codex-chat-*; do
    if [[ -d "$profile" ]]; then
      shopt -u nullglob
      echo "present"
      return 0
    fi
  done
  shopt -u nullglob
  echo "missing"
}

endpoint_state() {
  local port="$1"
  if chrome_endpoint_reachable "$port"; then
    echo "reachable"
  else
    echo "missing"
  fi
}

shared_ws_url() {
  local payload
  payload="$(curl -sf "http://127.0.0.1:${SHARED_PORT}/json/version" 2>/dev/null || true)"
  python3 - <<'PY' "$payload"
import json
import sys

payload = sys.argv[1]
if not payload.strip():
    raise SystemExit(0)
try:
    data = json.loads(payload)
except json.JSONDecodeError:
    raise SystemExit(0)
value = str(data.get("webSocketDebuggerUrl") or "").strip()
if value:
    print(value)
PY
}

port_listener_pid() {
  chrome_listener_pid "$1"
}

shared_pidfile_value() {
  local pidfile="${LOG_DIR}/chrome-agent-${SHARED_PORT}.pid"
  if [[ -f "$pidfile" ]]; then
    cat "$pidfile" 2>/dev/null || true
    return 0
  fi
  if [[ -f "${LOG_DIR}/chrome-agent.pid" ]]; then
    cat "${LOG_DIR}/chrome-agent.pid" 2>/dev/null || true
  fi
}

shared_profile_value() {
  local statefile="${LOG_DIR}/chrome-agent-${SHARED_PORT}.env"
  if [[ -f "$statefile" ]]; then
    sed -n 's/^PROFILE_DIR=//p' "$statefile" | head -n 1
    return 0
  fi
  default_chrome_profile_for_port "$SHARED_PORT"
}

configured_mode() {
  local env_line
  env_line="$(printf '%s\n' "$chrome_section" | awk '/^env = / {print; exit}')"
  if [[ -n "$env_line" ]]; then
    printf '%s\n' "$env_line" | sed -n 's/.*CODEX_CHROME_MODE *= *"\([^"]*\)".*/\1/p'
    return 0
  fi
  printf '%s\n' "${CODEX_CHROME_MODE:-isolated}"
}

configured_env_value() {
  local key="$1"
  local default_value="$2"
  local env_line
  env_line="$(printf '%s\n' "$chrome_section" | awk '/^env = / {print; exit}')"
  if [[ -n "$env_line" ]]; then
    local value
    value="$(printf '%s\n' "$env_line" | sed -n "s/.*${key} *= *\"\\{0,1\\}\\([^\",}]*\\).*/\\1/p")"
    if [[ -n "$value" ]]; then
      printf '%s\n' "$value"
      return 0
    fi
  fi
  printf '%s\n' "$default_value"
}

configured_shared_singleton() {
  configured_env_value "CODEX_CHROME_SHARED_SINGLETON" "${CODEX_CHROME_SHARED_SINGLETON:-0}"
}

configured_isolated_headless() {
  configured_env_value "CODEX_CHROME_ISOLATED_HEADLESS" "${CODEX_CHROME_ISOLATED_HEADLESS:-1}"
}

configured_tab_cap() {
  configured_env_value "CODEX_CHROME_TAB_CAP" "$TAB_CAP_DEFAULT"
}

configured_tab_target() {
  configured_env_value "CODEX_CHROME_TAB_TARGET" "$TAB_TARGET_DEFAULT"
}

print_isolated_session_summary() {
  local session_file
  local -a session_lines=()

  shopt -s nullglob
  for session_file in "${LOG_DIR}"/codex-chrome-session-*.env; do
    local port
    local profile
    local working_tab_id
    local tab_cap
    local tab_target
    local page_count

    port="$(sed -n 's/^PORT=//p' "$session_file" | head -n 1)"
    profile="$(sed -n 's/^PROFILE_DIR=//p' "$session_file" | head -n 1)"
    working_tab_id="$(sed -n 's/^WORKING_TAB_ID=//p' "$session_file" | head -n 1)"
    tab_cap="$(sed -n 's/^TAB_CAP=//p' "$session_file" | head -n 1)"
    tab_target="$(sed -n 's/^TAB_TARGET=//p' "$session_file" | head -n 1)"
    if [[ -n "$port" ]] && chrome_endpoint_reachable "$port"; then
      page_count="$(chrome_page_count "$port")"
    else
      page_count="missing"
    fi
    session_lines+=("  - isolated port ${port:-missing}: pages=${page_count} target=${tab_target:-1} max=${tab_cap:-3} working_tab=${working_tab_id:-unset} profile=${profile:-unknown}")
  done
  shopt -u nullglob

  if (( ${#session_lines[@]} == 0 )); then
    echo "[chrome-devtools-mcp] Live isolated sessions: none"
  else
    echo "[chrome-devtools-mcp] Live isolated sessions:"
    printf '%s\n' "${session_lines[@]}"
  fi
}

collect_shared_client_processes() {
  ps -axo pid,ppid,command | awk -v self="$$" -v parent="$PPID" '
    BEGIN { IGNORECASE = 1 }
    $1 == self || $1 == parent { next }
    /chrome-devtools-mcp-stop-conflicts\.sh|chrome-devtools-mcp-status\.sh/ { next }
    /chrome-devtools-mcp --browserUrl http:\/\/127\.0\.0\.1:9222/ {
      if ($0 !~ /codex-chrome-devtools-mcp\.sh/ && $0 !~ /scripts\/chrome-devtools-mcp-status\.sh/) {
        print $0
      }
    }
  '
}

collect_external_conflicts() {
  local mode="${1:-shared}"
  # In isolated mode each Codex session has its own Chrome on a unique port.
  # External clients (Claude in Chrome, Playwright --isolated) connect to the
  # shared port 9222 or their own Chromium, so they cannot interfere with
  # isolated sessions.  Skip the scan entirely to avoid false positives.
  if [[ "$mode" == "isolated" ]]; then
    return 0
  fi
  ps -axo pid,ppid,command | awk -v self="$$" -v parent="$PPID" '
    BEGIN { IGNORECASE = 1 }
    $1 == self || $1 == parent { next }
    /chrome-devtools-mcp-stop-conflicts\.sh|chrome-devtools-mcp-status\.sh/ { next }
    # Skip Playwright running with --isolated (its own Chromium, no port overlap)
    /@playwright\/mcp.*--isolated|playwright-mcp.*--isolated/ { next }
    /chrome-control\/server\/index\.js/ { print "external_claude_control\t" $0; next }
    /chrome-native-host/ { print "external_native_host\t" $0; next }
    /@playwright\/mcp|playwright-mcp/ { print "external_playwright\t" $0; next }
  '
}

print_conflict_summary() {
  local conflicts="$1"
  local count
  count="$(printf '%s\n' "$conflicts" | sed '/^$/d' | wc -l | tr -d ' ')"
  echo "[chrome-devtools-mcp] Conflict risk count: ${count}"
  if [[ "$count" == "0" ]]; then
    echo "[chrome-devtools-mcp] Conflicting browser-control clients: none detected"
    return 0
  fi
  echo "[chrome-devtools-mcp] Conflicting browser-control clients:"
  printf '%s\n' "$conflicts" | sed '/^$/d' | while IFS=$'\t' read -r kind line; do
    echo "  - ${kind}: ${line}"
  done
}

print_shared_client_summary() {
  local clients="$1"
  local count
  count="$(printf '%s\n' "$clients" | sed '/^$/d' | wc -l | tr -d ' ')"
  echo "[chrome-devtools-mcp] Active shared Chrome MCP clients: ${count}"
  if [[ "$count" == "0" ]]; then
    return 0
  fi
  echo "[chrome-devtools-mcp] Active shared clients are expected when multiple Codex chats are open."
}

print_conflict_summary_short() {
  local conflicts="$1"
  local mode="${2:-shared}"
  local count
  count="$(printf '%s\n' "$conflicts" | sed '/^$/d' | wc -l | tr -d ' ')"
  if [[ "$count" == "0" ]]; then
    return 0
  fi
  # In isolated mode, external clients are on port 9222 while Codex sessions
  # use their own ports.  Conflicts cannot cause interference, so downgrade
  # from WARNING to NOTE.
  if [[ "$mode" == "isolated" ]]; then
    echo "[chrome-devtools-mcp] NOTE: ${count} other browser-control process(es) detected (Claude/Playwright)." >&2
    echo "[chrome-devtools-mcp] NOTE: These do not affect isolated Codex sessions (separate Chrome per session)." >&2
    return 0
  fi
  echo "[chrome-devtools-mcp] WARNING: ${count} other browser-control process(es) may contend with shared Chrome on port 9222." >&2
  echo "[chrome-devtools-mcp] WARNING: These come from other browser tools or extensions, not normal Codex shared sessions." >&2
  echo "[chrome-devtools-mcp] WARNING: Browser automation may act strangely until they are cleared." >&2
  echo "[chrome-devtools-mcp] WARNING: Run: bash scripts/chrome-devtools-mcp-stop-conflicts.sh --apply" >&2
}

report_stale_runtime() {
  local stale_count=0
  local cleaned_count=0
  local broken_live_count=0
  local reserve
  local pidfile
  local statefile
  local sessionfile
  local pagesfile
  local owner_pid
  local browser_pid
  local wrapper_pid
  local port

  shopt -s nullglob
  for sessionfile in "${LOG_DIR}"/codex-chrome-session-*.env; do
    wrapper_pid="$(sed -n 's/^WRAPPER_PID=//p' "$sessionfile" | head -n 1)"
    if [[ -z "$wrapper_pid" ]] || ! kill -0 "$wrapper_pid" >/dev/null 2>&1; then
      pagesfile="${sessionfile%.env}.pages"
      rm -f "$sessionfile" "$pagesfile"
      echo "[chrome-devtools-mcp] Cleaned stale isolated session: $(basename "$sessionfile") wrapper=${wrapper_pid:-missing}"
      stale_count=$((stale_count + 1))
      cleaned_count=$((cleaned_count + 1))
    fi
  done

  for pagesfile in "${LOG_DIR}"/codex-chrome-session-*.pages; do
    sessionfile="${pagesfile%.pages}.env"
    if [[ ! -f "$sessionfile" ]]; then
      rm -f "$pagesfile"
      echo "[chrome-devtools-mcp] Cleaned orphaned pages file: $(basename "$pagesfile")"
      stale_count=$((stale_count + 1))
      cleaned_count=$((cleaned_count + 1))
    fi
  done

  for reserve in "${LOG_DIR}"/codex-chrome-port-*.reserve; do
    owner_pid="$(cat "$reserve" 2>/dev/null || true)"
    if [[ -z "$owner_pid" ]] || ! kill -0 "$owner_pid" >/dev/null 2>&1; then
      rm -f "$reserve"
      echo "[chrome-devtools-mcp] Cleaned stale reserve: $(basename "$reserve") owner=${owner_pid:-missing}"
      stale_count=$((stale_count + 1))
      cleaned_count=$((cleaned_count + 1))
    fi
  done

  for pidfile in "${LOG_DIR}"/chrome-agent-*.pid; do
    browser_pid="$(cat "$pidfile" 2>/dev/null || true)"
    if [[ -z "$browser_pid" ]] || ! kill -0 "$browser_pid" >/dev/null 2>&1; then
      statefile="${pidfile%.pid}.env"
      rm -f "$pidfile" "$statefile"
      echo "[chrome-devtools-mcp] Cleaned stale pidfile: $(basename "$pidfile") pid=${browser_pid:-missing}"
      stale_count=$((stale_count + 1))
      cleaned_count=$((cleaned_count + 1))
    fi
  done

  for statefile in "${LOG_DIR}"/chrome-agent-*.env; do
    pidfile="${statefile%.env}.pid"
    if [[ ! -f "$pidfile" ]]; then
      rm -f "$statefile"
      echo "[chrome-devtools-mcp] Cleaned orphaned statefile: $(basename "$statefile")"
      stale_count=$((stale_count + 1))
      cleaned_count=$((cleaned_count + 1))
    fi
  done

  for sessionfile in "${LOG_DIR}"/codex-chrome-session-*.env; do
    port="$(sed -n 's/^PORT=//p' "$sessionfile" | head -n 1)"
    wrapper_pid="$(sed -n 's/^WRAPPER_PID=//p' "$sessionfile" | head -n 1)"
    if [[ -z "$port" || -z "$wrapper_pid" ]]; then
      continue
    fi
    if ! kill -0 "$wrapper_pid" >/dev/null 2>&1; then
      continue
    fi
    if chrome_endpoint_reachable "$port"; then
      continue
    fi
    pidfile="${LOG_DIR}/chrome-agent-${port}.pid"
    browser_pid="$(cat "$pidfile" 2>/dev/null || true)"
    if [[ -n "$browser_pid" ]] && kill -0 "$browser_pid" >/dev/null 2>&1; then
      continue
    fi
    echo "[chrome-devtools-mcp] Broken live isolated session detected: port=${port} wrapper=${wrapper_pid} endpoint=missing"
    broken_live_count=$((broken_live_count + 1))
  done
  shopt -u nullglob

  if [[ "$stale_count" -eq 0 && "$broken_live_count" -eq 0 ]]; then
    echo "[chrome-devtools-mcp] Stale runtime artifacts: none"
  else
    echo "[chrome-devtools-mcp] Stale runtime artifacts cleaned: ${cleaned_count}"
    if [[ "$broken_live_count" -gt 0 ]]; then
      echo "[chrome-devtools-mcp] Broken live isolated sessions detected: ${broken_live_count}"
    fi
  fi
}

if [[ ! -f "$CONFIG_FILE" ]]; then
  fail "Codex config not found at ${CONFIG_FILE}"
fi

if [[ ! -x "$EXPECTED_COMMAND" ]]; then
  fail "Wrapper is missing or not executable: ${EXPECTED_COMMAND}"
fi

if ! codex_cli_available; then
  fail "Codex CLI is not available on PATH"
fi

validate_repo_managed_codex_config

chrome_section="$(
  awk '
    BEGIN { in_section = 0 }
    /^\[mcp_servers\.chrome-devtools\]/ { in_section = 1; print; next }
    /^\[mcp_servers\./ { if (in_section) exit; next }
    { if (in_section) print }
  ' "$CONFIG_FILE"
)"

if [[ -z "$chrome_section" ]]; then
  fail "Missing [mcp_servers.chrome-devtools] section in ${CONFIG_FILE}"
fi

configured_command="$(printf '%s\n' "$chrome_section" | awk -F' = ' '/^command = / {gsub(/^"|"$/, "", $2); print $2; exit}')"
configured_enabled="$(printf '%s\n' "$chrome_section" | awk -F' = ' '/^enabled = / {print $2; exit}')"

if [[ "$configured_enabled" != "true" ]]; then
  fail "chrome-devtools MCP is not enabled in ${CONFIG_FILE}"
fi

if [[ "$configured_command" != "$EXPECTED_COMMAND" ]]; then
  warn "Configured command differs from workspace wrapper: ${configured_command}"
  warn "This configuration is unsupported. Restore the canonical wrapper with: bash ${ROOT}/scripts/codex-config-sync.sh install"
fi

seed_profile="${CODEX_CHROME_SEED_PROFILE_DIR:-${HOME}/.chrome-profiles/claude-agent}"
wrapper_mode="$(configured_mode)"
shared_singleton="$(configured_shared_singleton)"
isolated_headless="$(configured_isolated_headless)"
tab_cap="$(configured_tab_cap)"
tab_target="$(configured_tab_target)"
seed_profile_state="present"
if [[ ! -d "$seed_profile" ]]; then
  seed_profile_state="missing"
  warn "Seed profile not found at ${seed_profile}; isolated chats may fail if no cloned profile already exists."
fi

existing_isolated_profiles="$(isolated_profile_state)"
if [[ "$wrapper_mode" == "isolated" && "$seed_profile_state" == "missing" && "$existing_isolated_profiles" == "missing" ]]; then
  fail "Seed profile missing at ${seed_profile} and no existing isolated Chrome profiles were found."
fi

shared_heal_state="$(heal_shared_chrome_runtime_state "$LOG_DIR" "$SHARED_PORT" 2>/dev/null || true)"

shared_listener_pid="$(port_listener_pid "$SHARED_PORT")"
shared_pidfile_pid="$(shared_pidfile_value)"
shared_profile="$(shared_profile_value)"
shared_ws="$(shared_ws_url)"
shared_clients="$(collect_shared_client_processes)"
shared_client_count="$(printf '%s\n' "$shared_clients" | sed '/^$/d' | wc -l | tr -d ' ')"
conflicts="$(collect_external_conflicts "$wrapper_mode")"
conflict_count="$(printf '%s\n' "$conflicts" | sed '/^$/d' | wc -l | tr -d ' ')"
codex_registry_line="$(codex_registry_line_for_chrome)"
summary_status_line=""
summary_note_line=""
summary_warning_line=""

if is_summary_mode; then
  if [[ "$wrapper_mode" == "isolated" ]] && codex_registry_enabled "$codex_registry_line"; then
    summary_status_line="[chrome-devtools-mcp] OK: browser automation is ready (isolated default, tab cap enforceable)."
    summary_note_line="[chrome-devtools-mcp] NOTE: fresh chats will launch isolated headful Chrome with a target of ${tab_target} working tab and a hard cap of ${tab_cap} tabs."
  elif [[ "$(endpoint_state "$SHARED_PORT")" == "reachable" ]] && codex_registry_enabled "$codex_registry_line"; then
    summary_status_line="[chrome-devtools-mcp] OK: browser automation is ready."
    summary_note_line="[chrome-devtools-mcp] NOTE: if this already-open chat still lacks chrome-devtools, restart the Codex session/thread to reload MCP registrations."
  elif ! codex_registry_enabled "$codex_registry_line"; then
    fail "Codex CLI registry does not show chrome-devtools as enabled. Run: codex mcp list"
  else
    summary_warning_line="[chrome-devtools-mcp] WARNING: shared Chrome is not responding on port ${SHARED_PORT}."
  fi
else
  echo "[chrome-devtools-mcp] Config OK: ${CONFIG_FILE}"
  echo "[chrome-devtools-mcp] Repo template sync OK"
  echo "[chrome-devtools-mcp] Wrapper OK: ${EXPECTED_COMMAND}"
  echo "[chrome-devtools-mcp] Effective wrapper mode: ${wrapper_mode}"
  if [[ "$wrapper_mode" == "shared" ]]; then
    if [[ "$shared_singleton" == "1" ]]; then
      echo "[chrome-devtools-mcp] Shared session policy: singleton preemption enabled"
    else
      echo "[chrome-devtools-mcp] Shared session policy: multi-session (default)"
    fi
    echo "[chrome-devtools-mcp] Tab-cap enforcement: disabled in shared mode"
  else
    echo "[chrome-devtools-mcp] Isolated launch policy: headless=${isolated_headless} target_tabs=${tab_target} max_tabs=${tab_cap}"
    echo "[chrome-devtools-mcp] Tab-cap enforcement: active per isolated session"
  fi
  echo "[chrome-devtools-mcp] Seed profile: ${seed_profile} (${seed_profile_state})"
  if [[ "$wrapper_mode" == "shared" || "$(endpoint_state "$SHARED_PORT")" == "reachable" ]]; then
    echo "[chrome-devtools-mcp] Shared ${SHARED_PORT} endpoint: $(endpoint_state "$SHARED_PORT")"
    echo "[chrome-devtools-mcp] Shared listener PID: ${shared_listener_pid:-missing}"
    echo "[chrome-devtools-mcp] Shared pidfile PID: ${shared_pidfile_pid:-missing}"
    echo "[chrome-devtools-mcp] Shared profile: ${shared_profile:-unknown}"
    echo "[chrome-devtools-mcp] Shared websocket: ${shared_ws:-missing}"
    if [[ -n "$shared_heal_state" ]]; then
      echo "[chrome-devtools-mcp] Shared runtime metadata healed from live ${SHARED_PORT} listener."
    fi
  fi
  if codex_registry_enabled "$codex_registry_line"; then
    echo "[chrome-devtools-mcp] Codex registry: chrome-devtools enabled via ${EXPECTED_COMMAND}"
  else
    fail "Codex CLI registry does not show chrome-devtools as enabled. Current line: ${codex_registry_line:-missing}"
  fi
  if [[ "$wrapper_mode" == "shared" || "$shared_client_count" != "0" ]]; then
    print_shared_client_summary "$shared_clients"
  fi
  if [[ "$wrapper_mode" == "isolated" ]]; then
    print_isolated_session_summary
  fi
  report_stale_runtime
  print_conflict_summary "$conflicts"
fi
if ! CODEX_CHROME_SKIP_BROWSER_BOOT=1 "$EXPECTED_COMMAND" --version >/dev/null; then
  fail "Wrapper smoke check failed"
fi

if is_summary_mode; then
  if [[ -n "$summary_status_line" ]]; then
    echo "$summary_status_line"
  fi
  if [[ -n "$summary_note_line" ]]; then
    echo "$summary_note_line" >&2
  fi
  if [[ -n "$summary_warning_line" ]]; then
    echo "$summary_warning_line" >&2
  fi
  print_conflict_summary_short "$conflicts" "$wrapper_mode"
else
  echo "[chrome-devtools-mcp] Running wrapper smoke check..."
  echo "[chrome-devtools-mcp] Smoke check passed."
fi

if ! is_summary_mode && [[ "$wrapper_mode" == "shared" && "$(endpoint_state "$SHARED_PORT")" != "reachable" ]]; then
  echo "[chrome-devtools-mcp] Shared Chrome is not running, but the MCP wrapper will auto-launch it at session start." >&2
  echo "[chrome-devtools-mcp] To start it manually now:" >&2
  echo "[chrome-devtools-mcp]   CHROME_AGENT_DEBUG_PORT=${SHARED_PORT} CHROME_AGENT_PROFILE_DIR=\${HOME}/.chrome-profiles/claude-agent bash ${ROOT}/scripts/chrome-agent.sh" >&2
elif ! is_summary_mode && [[ "$conflict_count" != "0" && "$wrapper_mode" == "shared" ]]; then
  echo "[chrome-devtools-mcp] Recommended next action: inspect or stop conflicting non-Codex browser-control clients:" >&2
  echo "[chrome-devtools-mcp]   bash ${ROOT}/scripts/chrome-devtools-mcp-stop-conflicts.sh" >&2
  echo "[chrome-devtools-mcp]   bash ${ROOT}/scripts/chrome-devtools-mcp-stop-conflicts.sh --apply" >&2
elif ! is_summary_mode && [[ "$wrapper_mode" == "isolated" ]]; then
  echo "[chrome-devtools-mcp] Recommended next action: start a fresh Codex chat to pick up the isolated headful default and per-chat tab cap." >&2
elif ! is_summary_mode; then
  echo "[chrome-devtools-mcp] Recommended next action: if this chat still lacks chrome-devtools, restart the Codex session to reload MCP registrations." >&2
fi

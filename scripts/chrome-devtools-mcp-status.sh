#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${ROOT}/.codex/config.toml"
DEFAULT_USER_CONFIG_FILE="${CODEX_HOME:-$HOME/.codex}/config.toml"
EXPECTED_COMMAND="${ROOT}/scripts/codex-chrome-devtools-mcp.sh"
GLOBAL_CHROME_COMMAND="${HOME}/.codex/bin/codex-chrome-devtools-mcp-global.sh"
LOG_DIR="${ROOT}/.logs/workspace"
SHARED_PORT="9422"
STATUS_MODE="${CHROME_DEVTOOLS_MCP_STATUS_MODE:-detailed}"
VISIBLE_BROWSER_OWNER_FILE="${LOG_DIR}/chrome-devtools-visible-browser-owner.env"
PORT_DIAG=0
source "${ROOT}/scripts/lib/chrome-runtime.sh"
source "${ROOT}/scripts/lib/mcp-runtime.sh"
TAB_CAP_DEFAULT="${CODEX_CHROME_TAB_CAP:-3}"
TAB_TARGET_DEFAULT="${CODEX_CHROME_TAB_TARGET:-1}"
KEEPER_PORTS=("9222" "9422")

usage() {
  cat <<'EOF'
Usage:
  chrome-devtools-mcp-status.sh
  chrome-devtools-mcp-status.sh --diagnose-ports

Options:
  --diagnose-ports   Compare queried port, websocket URL, listener PID, /json/list,
                     and active MCP --browserUrl attachments for shared and isolated sessions.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "${1}" in
    --diagnose-ports)
      PORT_DIAG=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[chrome-devtools-mcp] ERROR: unknown argument: ${1}" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

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

current_shell_chrome_command() {
  local payload
  payload="$(codex mcp list --json 2>/dev/null || true)"
  python3 - "$payload" <<'PY'
import json
import sys

try:
    data = json.loads(sys.argv[1])
except Exception:
    raise SystemExit(0)

server = {}
if isinstance(data, dict):
    server = data.get("chrome-devtools") or {}
elif isinstance(data, list):
    for item in data:
        if isinstance(item, dict) and item.get("name") == "chrome-devtools":
            server = item
            break

transport = server.get("transport") if isinstance(server, dict) else {}
command = None
if isinstance(server, dict):
    command = server.get("command")
if not command and isinstance(transport, dict):
    command = transport.get("command")

if isinstance(command, str) and command.strip():
    print(command.strip())
PY
}

current_scope_label() {
  if [[ "$PWD" == "$ROOT"* ]]; then
    echo "workspace"
  else
    echo "external"
  fi
}

extract_chrome_section() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  awk '
    BEGIN { in_section = 0 }
    /^\[mcp_servers\.chrome-devtools\]/ { in_section = 1; print; next }
    /^\[mcp_servers\./ { if (in_section) exit; next }
    { if (in_section) print }
  ' "$file"
}

print_scope_diagnosis() {
  local scope="$1"
  local current_command="$2"

  if [[ "$scope" == "workspace" ]]; then
    if [[ "$current_command" == "$EXPECTED_COMMAND" ]]; then
      echo "[chrome-devtools-mcp] Current shell scope: workspace override active (isolated/debug path; inherited global is the canonical default)"
    elif [[ "$current_command" == "$GLOBAL_CHROME_COMMAND" ]]; then
      echo "[chrome-devtools-mcp] Current shell scope: workspace inherits the global launcher (canonical TRR default)"
    elif [[ -z "$current_command" ]]; then
      echo "[chrome-devtools-mcp] Current shell scope: registration broken"
      echo "[chrome-devtools-mcp] No chrome-devtools MCP is visible from this workspace shell."
    else
      echo "[chrome-devtools-mcp] Current shell scope: unexpected chrome-devtools binding -> ${current_command}"
    fi
    return 0
  fi

  if [[ "$current_command" == "$GLOBAL_CHROME_COMMAND" ]]; then
    echo "[chrome-devtools-mcp] Current shell scope: outside TRR, global launcher active (healthy)"
  elif [[ "$current_command" == "$EXPECTED_COMMAND" ]]; then
    echo "[chrome-devtools-mcp] Current shell scope: outside TRR, but the TRR wrapper is still bound in this shell"
    echo "[chrome-devtools-mcp] This usually means the current Codex session was opened from TRR and has stale workspace registrations."
  elif [[ -z "$current_command" ]]; then
    echo "[chrome-devtools-mcp] Current shell scope: registration broken"
    echo "[chrome-devtools-mcp] Global chrome-devtools should be available outside TRR, but it is missing from this shell."
  else
    echo "[chrome-devtools-mcp] Current shell scope: unexpected chrome-devtools binding -> ${current_command}"
  fi
}

validate_repo_managed_codex_config() {
  if ! CODEX_CONFIG_FILE= bash "${ROOT}/scripts/codex-config-sync.sh" validate >/dev/null; then
    fail "Codex config drift detected. Run: bash ${ROOT}/scripts/codex-config-sync.sh bootstrap"
  fi
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

ws_url_for_port() {
  local port="$1"
  local payload
  payload="$(curl -sf "http://127.0.0.1:${port}/json/version" 2>/dev/null || true)"
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

shared_ws_url() {
  ws_url_for_port "$SHARED_PORT"
}

ws_port_for_port() {
  local port="$1"
  local ws
  ws="$(ws_url_for_port "$port")"
  if [[ "$ws" =~ :([0-9]+)/devtools/browser/ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
  fi
}

port_listener_pid() {
  chrome_listener_pid "$1"
}

owner_field() {
  local key="$1"
  [[ -f "$VISIBLE_BROWSER_OWNER_FILE" ]] || return 0
  sed -n "s/^${key}=//p" "$VISIBLE_BROWSER_OWNER_FILE" | head -n 1
}

process_has_live_ancestor_matching() {
  local pid="$1"
  local regex="$2"
  local current="$pid"
  local depth=0
  local command=""

  while [[ -n "$current" && "$current" =~ ^[0-9]+$ && "$current" != "0" && "$depth" -lt 24 ]]; do
    command="$(process_command "$current" 2>/dev/null || true)"
    if [[ -n "$command" && "$command" =~ $regex ]] && kill -0 "$current" >/dev/null 2>&1; then
      return 0
    fi
    current="$(process_parent_pid "$current")"
    depth=$((depth + 1))
  done

  return 1
}

count_matching_processes() {
  local regex="$1"
  ps -axo pid=,command= | awk -v self="$$" -v regex="$regex" '
    $1 == self { next }
    $0 ~ regex { print $1 }
  '
}

process_rss_mb_for_regex() {
  local regex="$1"
  ps -axo rss=,command= | awk -v regex="$regex" '
    $0 ~ regex {
      sum += $1
    }
    END {
      printf "%.1f\n", sum / 1024
    }
  '
}

managed_chrome_root_count() {
  local count=0
  local port
  for port in "${KEEPER_PORTS[@]}"; do
    if chrome_endpoint_reachable "$port"; then
      count=$((count + 1))
    fi
  done
  shopt -s nullglob
  for _ in "${LOG_DIR}"/codex-chrome-session-*.env; do
    count=$((count + 1))
  done
  shopt -u nullglob
  printf '%s\n' "$count"
}

orphaned_figma_console_count() {
  local pid
  local count=0
  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    if process_has_live_ancestor_matching "$pid" "codex-figma-console-mcp\\.sh"; then
      continue
    fi
    count=$((count + 1))
  done < <(count_matching_processes "figma-console-mcp")
  printf '%s\n' "$count"
}

visible_browser_owner_state() {
  if [[ ! -f "$VISIBLE_BROWSER_OWNER_FILE" ]]; then
    echo "none"
    return 0
  fi

  local owner_pid
  local wrapper_pid
  local owner_port
  local listener_pid

  owner_pid="$(owner_field BROWSER_PID)"
  if [[ -z "$owner_pid" ]]; then
    owner_pid="$(owner_field OWNER_PID)"
  fi
  wrapper_pid="$(owner_field WRAPPER_PID)"
  owner_port="$(owner_field PORT)"
  listener_pid=""
  if [[ -n "$owner_port" ]]; then
    listener_pid="$(chrome_listener_pid "$owner_port")"
  fi

  if [[ -z "$owner_pid" ]]; then
    echo "none"
    return 0
  fi

  if kill -0 "$owner_pid" >/dev/null 2>&1; then
    if [[ -n "$owner_port" ]] && chrome_endpoint_reachable "$owner_port"; then
      if [[ -n "$wrapper_pid" ]] && kill -0 "$wrapper_pid" >/dev/null 2>&1; then
        echo "live"
      else
        echo "stale-wrapper"
      fi
    else
      echo "stale-browser"
    fi
    return 0
  fi

  if [[ -n "$listener_pid" ]] && chrome_endpoint_reachable "$owner_port"; then
    if [[ -n "$wrapper_pid" ]] && kill -0 "$wrapper_pid" >/dev/null 2>&1; then
      echo "live"
    else
      echo "stale-wrapper"
    fi
    return 0
  fi

  echo "stale-browser"
}

print_shared_keeper_summary() {
  local port
  local listener_pid
  local ws_url
  local ws_port
  local label

  echo "[chrome-devtools-mcp] Shared keepers:"
  for port in "${KEEPER_PORTS[@]}"; do
    listener_pid="$(port_listener_pid "$port")"
    ws_url="$(ws_url_for_port "$port")"
    ws_port="$(ws_port_for_port "$port")"
    if [[ "$port" == "9222" ]]; then
      label="managed shared headful"
    else
      label="managed shared headless"
    fi
    echo "  - keeper ${label} port=${port} endpoint=$(port_query_state "$port") listener=${listener_pid:-missing} ws_port=${ws_port:-missing}"
    if [[ -n "$ws_url" ]]; then
      echo "    ws_url=${ws_url}"
    fi
  done
}

print_visible_browser_owner_summary() {
  if [[ ! -f "$VISIBLE_BROWSER_OWNER_FILE" ]]; then
    echo "[chrome-devtools-mcp] Visible browser owner: none"
    return 0
  fi

  local owner_pid
  local wrapper_pid
  local owner_mode
  local owner_port
  local owner_headless
  local owner_claimed_at

  owner_pid="$(owner_field BROWSER_PID)"
  if [[ -z "$owner_pid" ]]; then
    owner_pid="$(owner_field OWNER_PID)"
  fi
  wrapper_pid="$(owner_field WRAPPER_PID)"
  owner_mode="$(owner_field MODE)"
  owner_port="$(owner_field PORT)"
  owner_headless="$(owner_field HEADLESS)"
  owner_claimed_at="$(owner_field CLAIMED_AT)"
  local owner_state
  owner_state="$(visible_browser_owner_state)"

  echo "[chrome-devtools-mcp] Visible browser owner: state=${owner_state} browser_pid=${owner_pid:-missing} wrapper_pid=${wrapper_pid:-missing} mode=${owner_mode:-unknown} port=${owner_port:-unknown} headless=${owner_headless:-unknown} claimed_at=${owner_claimed_at:-unknown}"
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

default_shared_port_for_command() {
  local command="$1"
  if [[ "$command" == "$GLOBAL_CHROME_COMMAND" ]]; then
    printf '%s\n' "9422"
  else
    printf '%s\n' "9222"
  fi
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

configured_shared_port() {
  configured_env_value "CODEX_CHROME_SHARED_PORT" "$(default_shared_port_for_command "$configured_command")"
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

port_query_state() {
  local port="$1"
  if chrome_endpoint_reachable "$port"; then
    echo "reachable"
  else
    echo "missing"
  fi
}

mcp_browser_urls_for_port() {
  local port="$1"
  ps -axo command= | awk -v browser_url="http://127.0.0.1:""${port}" '
    index($0, "chrome-devtools-mcp") && index($0, "--browserUrl " browser_url) { print browser_url }
  ' | awk '!seen[$0]++'
}

diagnostic_ports() {
  local port
  local -a ports=("$SHARED_PORT")

  shopt -s nullglob
  for session_file in "${LOG_DIR}"/codex-chrome-session-*.env; do
    port="$(sed -n 's/^PORT=//p' "$session_file" | head -n 1)"
    if [[ -n "$port" ]]; then
      ports+=("$port")
    fi
  done
  shopt -u nullglob

  printf '%s\n' "${ports[@]}" | awk '!seen[$0]++'
}

print_port_routing_diagnostics() {
  local port
  local ws_url
  local ws_port
  local listener_pid
  local page_count
  local routing_state
  local mcp_urls
  local mcp_count

  echo "[chrome-devtools-mcp] Port routing diagnostics:"
  while IFS= read -r port; do
    [[ -n "$port" ]] || continue
    ws_url="$(ws_url_for_port "$port")"
    ws_port="$(ws_port_for_port "$port")"
    listener_pid="$(port_listener_pid "$port")"
    page_count="$(chrome_page_count "$port" 2>/dev/null || echo 0)"
    mcp_urls="$(mcp_browser_urls_for_port "$port")"
    mcp_count="$(printf '%s\n' "$mcp_urls" | sed '/^$/d' | wc -l | tr -d ' ')"
    routing_state="missing"
    if [[ -n "$ws_port" && "$ws_port" == "$port" ]]; then
      routing_state="match"
    elif [[ -n "$ws_port" ]]; then
      routing_state="mismatch"
    fi
    echo "  - port ${port}: endpoint=$(port_query_state "$port") listener=${listener_pid:-missing} ws_port=${ws_port:-missing} routing=${routing_state} pages=${page_count} mcp_clients=${mcp_count}"
    if [[ -n "$ws_url" ]]; then
      echo "    ws_url=${ws_url}"
    fi
    if [[ -n "$mcp_urls" ]]; then
      printf '%s\n' "$mcp_urls" | sed '/^$/d' | while IFS= read -r url; do
        echo "    mcp_browserUrl=${url}"
      done
    fi
  done < <(diagnostic_ports)
}

collect_shared_client_processes() {
  ps -axo pid,ppid,command | awk -v self="$$" -v parent="$PPID" -v shared_port="$SHARED_PORT" '
    BEGIN { IGNORECASE = 1 }
    $1 == self || $1 == parent { next }
    /chrome-devtools-mcp-stop-conflicts\.sh|chrome-devtools-mcp-status\.sh/ { next }
    index($0, "--browserUrl http://127.0.0.1:" shared_port) {
      if ($0 !~ /codex-chrome-devtools-mcp\.sh/ && $0 !~ /scripts\/chrome-devtools-mcp-status\.sh/) {
        print $0
      }
    }
  '
}

collect_external_conflicts() {
  local mode="${1:-shared}"
  local shared_port="${2:-$SHARED_PORT}"
  # In isolated mode each Codex session has its own Chrome on a unique port.
  # External clients (Claude in Chrome, Playwright --isolated) connect to the
  # shared port 9222 or their own Chromium, so they cannot interfere with
  # isolated sessions.  Skip the scan entirely to avoid false positives.
  if [[ "$mode" == "isolated" ]]; then
    return 0
  fi
  if [[ "$shared_port" != "9222" ]]; then
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
  local figma_orphans
  local reserve
  local pidfile
  local statefile
  local sessionfile
  local pagesfile
  local owner_pid
  local browser_pid
  local listener_pid
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
    port="${pidfile##*chrome-agent-}"
    port="${port%.pid}"
    listener_pid="$(chrome_listener_pid "$port")"
    if [[ -n "$listener_pid" ]] && chrome_endpoint_reachable "$port"; then
      if [[ "$browser_pid" != "$listener_pid" ]]; then
        printf '%s\n' "$listener_pid" >"$pidfile"
      fi
      continue
    fi
    statefile="${pidfile%.pid}.env"
    rm -f "$pidfile" "$statefile"
    echo "[chrome-devtools-mcp] Cleaned stale pidfile: $(basename "$pidfile") pid=${browser_pid:-missing}"
    stale_count=$((stale_count + 1))
    cleaned_count=$((cleaned_count + 1))
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

  if [[ -f "$VISIBLE_BROWSER_OWNER_FILE" ]]; then
    owner_pid="$(owner_field BROWSER_PID)"
    if [[ -z "$owner_pid" ]]; then
      owner_pid="$(owner_field OWNER_PID)"
    fi
    port="$(owner_field PORT)"
    listener_pid=""
    [[ -n "$port" ]] && listener_pid="$(chrome_listener_pid "$port")"
    if { [[ -z "$owner_pid" ]] || ! kill -0 "$owner_pid" >/dev/null 2>&1; } && [[ -z "$listener_pid" ]]; then
      rm -f "$VISIBLE_BROWSER_OWNER_FILE"
      echo "[chrome-devtools-mcp] Cleaned stale visible-browser owner lock: $(basename "$VISIBLE_BROWSER_OWNER_FILE") owner=${owner_pid:-missing}"
      stale_count=$((stale_count + 1))
      cleaned_count=$((cleaned_count + 1))
    fi
  fi

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

  figma_orphans="$(orphaned_figma_console_count)"
  if [[ "$figma_orphans" == "0" ]]; then
    echo "[chrome-devtools-mcp] Orphaned figma-console trees: none"
  else
    echo "[chrome-devtools-mcp] Orphaned figma-console trees: ${figma_orphans}"
  fi
}

pressure_verdict() {
  local owner_state="$1"
  local managed_root_count="$2"
  local chrome_rss_mb="$3"
  local figma_rss_mb="$4"
  local figma_orphans="$5"

  if [[ "$figma_orphans" != "0" ]]; then
    echo "unsafe"
    return 0
  fi

  if [[ "$owner_state" == "stale-browser" ]]; then
    echo "unsafe"
    return 0
  fi

  if [[ "$owner_state" == "stale-wrapper" ]]; then
    echo "degraded"
    return 0
  fi

  if [[ "$managed_root_count" -gt 3 ]]; then
    echo "degraded"
    return 0
  fi

  if awk -v chrome="$chrome_rss_mb" -v figma="$figma_rss_mb" 'BEGIN { exit !((chrome >= 5000.0) || (figma >= 250.0)) }'; then
    echo "unsafe"
    return 0
  fi

  if awk -v chrome="$chrome_rss_mb" -v figma="$figma_rss_mb" 'BEGIN { exit !((chrome >= 3500.0) || (figma >= 150.0)) }'; then
    echo "degraded"
    return 0
  fi

  echo "safe"
}

pressure_snapshot_line() {
  echo "[chrome-devtools-mcp] Pressure snapshot: owner_state=${owner_state} managed_roots=${managed_root_count} chrome_rss_mb=${chrome_rss_mb} figma_rss_mb=${figma_rss_mb} figma_orphans=${figma_orphans_count} shared_clients=${shared_client_count} conflicts=${conflict_count}"
}

if [[ ! -f "$CONFIG_FILE" ]]; then
  fail "Codex config not found at ${CONFIG_FILE}"
fi

if [[ -n "${CODEX_CONFIG_FILE:-}" && "${CODEX_CONFIG_FILE}" != "$CONFIG_FILE" && "${CODEX_CONFIG_FILE}" != "$DEFAULT_USER_CONFIG_FILE" ]]; then
  warn "Ignoring CODEX_CONFIG_FILE=${CODEX_CONFIG_FILE}; chrome-devtools status always reads the tracked project config."
fi

if [[ ! -x "$EXPECTED_COMMAND" ]]; then
  fail "Wrapper is missing or not executable: ${EXPECTED_COMMAND}"
fi

if ! codex_cli_available; then
  fail "Codex CLI is not available on PATH"
fi

validate_repo_managed_codex_config

project_chrome_section="$(extract_chrome_section "$CONFIG_FILE")"
user_chrome_section="$(extract_chrome_section "$DEFAULT_USER_CONFIG_FILE")"
config_source="$CONFIG_FILE"
chrome_section="$project_chrome_section"

if [[ -z "$chrome_section" ]]; then
  config_source="$DEFAULT_USER_CONFIG_FILE"
  chrome_section="$user_chrome_section"
fi

if [[ -z "$chrome_section" ]]; then
  fail "No [mcp_servers.chrome-devtools] section found in ${CONFIG_FILE} or ${DEFAULT_USER_CONFIG_FILE}."
fi

configured_command="$(printf '%s\n' "$chrome_section" | awk -F' = ' '/^command = / {gsub(/^"|"$/, "", $2); print $2; exit}')"
configured_enabled="$(printf '%s\n' "$chrome_section" | awk -F' = ' '/^enabled = / {print $2; exit}')"
if [[ -z "$configured_enabled" ]]; then
  configured_enabled="true"
fi

if [[ "$configured_enabled" != "true" ]]; then
  fail "chrome-devtools MCP is not enabled in ${config_source}"
fi

if [[ "$configured_command" != "$EXPECTED_COMMAND" && "$configured_command" != "$GLOBAL_CHROME_COMMAND" ]]; then
  warn "Configured command differs from workspace wrapper: ${configured_command}"
  warn "This configuration is unsupported. Restore the expected bootstrap state with: bash ${ROOT}/scripts/codex-config-sync.sh bootstrap"
fi

seed_profile="${CODEX_CHROME_SEED_PROFILE_DIR:-${HOME}/.chrome-profiles/claude-agent}"
wrapper_mode="$(configured_mode)"
SHARED_PORT="$(configured_shared_port)"
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
current_scope="$(current_scope_label)"
current_shell_command="$(current_shell_chrome_command)"
shared_clients="$(collect_shared_client_processes)"
shared_client_count="$(printf '%s\n' "$shared_clients" | sed '/^$/d' | wc -l | tr -d ' ')"
conflicts="$(collect_external_conflicts "$wrapper_mode" "$SHARED_PORT")"
conflict_count="$(printf '%s\n' "$conflicts" | sed '/^$/d' | wc -l | tr -d ' ')"
summary_status_line=""
summary_note_line=""
summary_warning_line=""
summary_pressure_line=""
owner_state="$(visible_browser_owner_state)"
figma_orphans_count="$(orphaned_figma_console_count)"
managed_root_count="$(managed_chrome_root_count)"
chrome_rss_mb="$(process_rss_mb_for_regex "Google Chrome|chrome-devtools-mcp|codex-chrome-devtools-mcp|Codex.app")"
figma_rss_mb="$(process_rss_mb_for_regex "figma-console-mcp|codex-figma-console-mcp")"
pressure_state="safe"

if is_summary_mode; then
  summary_pressure_line="$(pressure_verdict "$owner_state" "$managed_root_count" "$chrome_rss_mb" "$figma_rss_mb" "$figma_orphans_count")"
  if [[ "$wrapper_mode" == "isolated" ]]; then
    summary_status_line="[chrome-devtools-mcp] OK: browser automation is ready (isolated default, tab cap enforceable)."
    summary_note_line="[chrome-devtools-mcp] NOTE: fresh chats will launch isolated headless Chrome with a target of ${tab_target} working tab and a hard cap of ${tab_cap} tabs."
  elif [[ "$(endpoint_state "$SHARED_PORT")" == "reachable" ]]; then
    summary_status_line="[chrome-devtools-mcp] OK: browser automation is ready."
    summary_note_line="[chrome-devtools-mcp] NOTE: if this already-open chat still lacks chrome-devtools, restart the Codex session/thread to reload MCP registrations."
  else
    summary_warning_line="[chrome-devtools-mcp] WARNING: shared Chrome is not responding on port ${SHARED_PORT}."
  fi
else
  echo "[chrome-devtools-mcp] Config OK: ${config_source}"
  if [[ -n "$project_chrome_section" ]]; then
    echo "[chrome-devtools-mcp] Project-local Codex config OK"
  else
    echo "[chrome-devtools-mcp] Project-local Codex config OK (chrome-devtools inherits from user config; canonical TRR default)"
  fi
  echo "[chrome-devtools-mcp] Wrapper OK: ${EXPECTED_COMMAND}"
  print_scope_diagnosis "$current_scope" "$current_shell_command"
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
  print_shared_keeper_summary
  print_visible_browser_owner_summary
  echo "[chrome-devtools-mcp] Managed Chrome roots: ${managed_root_count}"
  echo "[chrome-devtools-mcp] Chrome RSS total (MB): ${chrome_rss_mb}"
  echo "[chrome-devtools-mcp] figma-console RSS total (MB): ${figma_rss_mb}"
  if [[ -n "$project_chrome_section" ]]; then
    echo "[chrome-devtools-mcp] Tracked project config defines chrome-devtools via ${configured_command}"
  else
    echo "[chrome-devtools-mcp] Tracked project config inherits chrome-devtools from ${config_source} (expected)"
  fi
  if [[ "$wrapper_mode" == "shared" || "$shared_client_count" != "0" ]]; then
    print_shared_client_summary "$shared_clients"
  fi
  if [[ "$wrapper_mode" == "isolated" ]]; then
    print_isolated_session_summary
  fi
  report_stale_runtime
  if [[ "$PORT_DIAG" == "1" ]]; then
    print_port_routing_diagnostics
  fi
  print_conflict_summary "$conflicts"
  pressure_snapshot_line
  pressure_state="$(pressure_verdict "$owner_state" "$managed_root_count" "$chrome_rss_mb" "$figma_rss_mb" "$figma_orphans_count")"
  echo "[chrome-devtools-mcp] Pressure verdict: ${pressure_state}"
fi
if ! CODEX_CHROME_SKIP_BROWSER_BOOT=1 "$EXPECTED_COMMAND" --version >/dev/null; then
  fail "Wrapper smoke check failed"
fi

if is_summary_mode; then
  if [[ -n "$summary_status_line" ]]; then
    echo "$summary_status_line"
  fi
  print_scope_diagnosis "$current_scope" "$current_shell_command" >&2
  print_visible_browser_owner_summary >&2
  echo "[chrome-devtools-mcp] Shared keepers: 9222 managed shared headful, 9422 managed shared headless" >&2
  echo "[chrome-devtools-mcp] Pressure verdict: ${summary_pressure_line}" >&2
  if [[ -n "$summary_note_line" ]]; then
    echo "$summary_note_line" >&2
  fi
  if [[ -n "$summary_warning_line" ]]; then
    echo "$summary_warning_line" >&2
  fi
  pressure_snapshot_line >&2
  if [[ "$PORT_DIAG" == "1" ]]; then
    print_port_routing_diagnostics >&2
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
  echo "[chrome-devtools-mcp] Recommended next action: start a fresh Codex chat to pick up the isolated headless default and per-chat tab cap." >&2
elif ! is_summary_mode; then
  echo "[chrome-devtools-mcp] Recommended next action: if this chat still lacks chrome-devtools, restart the Codex session to reload MCP registrations." >&2
fi

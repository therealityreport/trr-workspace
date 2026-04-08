#!/usr/bin/env bash
set -euo pipefail

# Codex MCP Session Reaper + Diagnostic Tool
# Manages session lifecycle for chrome-devtools MCP wrapper infrastructure
# Usage: codex-mcp-session-reaper.sh [diagnose|reap|watch]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_DIR="${ROOT}/.logs/workspace"
REAPER_LOG="${LOG_DIR}/mcp-session-reaper.log"
REAPER_INTERVAL_SEC="${REAPER_INTERVAL_SEC:-30}"
FIGMA_RUNTIME_DIR="${CODEX_HOME:-$HOME/.codex}/tmp/figma-console-mcp/runtime"
VISIBLE_BROWSER_OWNER_FILE="${LOG_DIR}/chrome-devtools-visible-browser-owner.env"
SHARED_HEADFUL_IDLE_SEC="${CODEX_CHROME_SHARED_HEADFUL_IDLE_TIMEOUT_SEC:-300}"

for lib in mcp-runtime.sh chrome-runtime.sh; do
  if [[ ! -f "${ROOT}/scripts/lib/${lib}" ]]; then
    echo "[mcp-session-reaper] ERROR: Missing ${lib}" >&2
    exit 1
  fi
done
source "${ROOT}/scripts/lib/mcp-runtime.sh"
source "${ROOT}/scripts/lib/chrome-runtime.sh"
source "${ROOT}/scripts/lib/workspace-terminal.sh"

shopt -s nullglob

log() { echo "[mcp-session-reaper] $*" >&2; }

log_file() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [mcp-session-reaper] $*" >>"$REAPER_LOG"
}

# Safe field extraction from env files (no source; just sed)
env_field() {
  local file="$1" key="$2"
  sed -n "s/^${key}=//p" "$file" 2>/dev/null | head -n 1
}

# Port from filename: codex-chrome-session-9333.env → 9333
port_from_session_file() {
  local base
  base="$(basename "$1")"
  base="${base#codex-chrome-session-}"
  base="${base%.env}"
  echo "$base"
}

port_from_agent_pidfile() {
  local base
  base="$(basename "$1")"
  base="${base#chrome-agent-}"
  base="${base%.pid}"
  echo "$base"
}

port_from_reserve_file() {
  local base
  base="$(basename "$1")"
  base="${base#codex-chrome-port-}"
  base="${base%.reserve}"
  echo "$base"
}

pid_alive() {
  local pid="$1"
  [[ -n "$pid" && "$pid" =~ ^[0-9]+$ && "$pid" != "1" ]] && kill -0 "$pid" 2>/dev/null
}

safe_to_kill() {
  local pid="$1"
  [[ -n "$pid" && "$pid" =~ ^[0-9]+$ && "$pid" != "1" && "$pid" != "$$" ]]
}

owner_field() {
  local key="$1"
  [[ -f "$VISIBLE_BROWSER_OWNER_FILE" ]] || return 0
  sed -n "s/^${key}=//p" "$VISIBLE_BROWSER_OWNER_FILE" 2>/dev/null | head -n 1
}

owner_browser_pid() {
  local pid
  pid="$(owner_field BROWSER_PID)"
  if [[ -n "$pid" ]]; then
    printf '%s\n' "$pid"
    return 0
  fi
  owner_field OWNER_PID
}

owner_wrapper_pid() {
  owner_field WRAPPER_PID
}

owner_timestamp_age_sec() {
  local timestamp="$1"
  [[ -n "$timestamp" ]] || return 1
  python3 - "$timestamp" <<'PY'
import datetime
import sys

raw = sys.argv[1].strip()
if not raw:
    raise SystemExit(1)
if raw.endswith("Z"):
    raw = raw[:-1] + "+00:00"
try:
    ts = datetime.datetime.fromisoformat(raw)
except ValueError:
    raise SystemExit(1)
now = datetime.datetime.now(datetime.timezone.utc)
if ts.tzinfo is None:
    ts = ts.replace(tzinfo=datetime.timezone.utc)
print(max(0, int((now - ts).total_seconds())))
PY
}

figma_wrapper_pid_from_session_file() {
  env_field "$1" WRAPPER_PID
}

figma_child_pid_from_session_file() {
  env_field "$1" CHILD_PID
}

figma_process_has_live_wrapper_ancestor() {
  local pid="$1"
  process_has_live_ancestor_matching "$pid" 'codex-figma-console-mcp\.sh'
}

figma_wrapper_is_tracked() {
  local pid="$1"
  local sf

  [[ -n "$pid" ]] || return 1
  for sf in "${FIGMA_RUNTIME_DIR}"/figma-console-session-*.env; do
    [[ -f "$sf" ]] || continue
    if [[ "$(figma_wrapper_pid_from_session_file "$sf")" == "$pid" ]]; then
      return 0
    fi
  done
  return 1
}

session_tracks_wrapper_pid() {
  local pid="$1"
  local sf

  [[ -n "$pid" ]] || return 1

  for sf in "${LOG_DIR}"/codex-chrome-session-*.env; do
    [[ -f "$sf" ]] || continue
    if [[ "$(env_field "$sf" WRAPPER_PID)" == "$pid" ]]; then
      return 0
    fi
  done

  return 1
}

wrapper_parent_is_live_wrapper() {
  local pid="$1"
  local parent_pid
  local parent_cmd

  parent_pid="$(process_parent_pid "$pid")"
  if ! pid_alive "$parent_pid"; then
    return 1
  fi
  parent_cmd="$(process_command "$parent_pid" 2>/dev/null || true)"
  [[ "$parent_cmd" == *"codex-chrome-devtools-mcp.sh"* ]]
}

wrapper_browser_port() {
  local pid="$1"
  local sf
  local tracked_port=""
  local target_pid
  local cmd
  local derived_port=""

  for sf in "${LOG_DIR}"/codex-chrome-session-*.env; do
    [[ -f "$sf" ]] || continue
    if [[ "$(env_field "$sf" WRAPPER_PID)" == "$pid" ]]; then
      tracked_port="$(env_field "$sf" PORT)"
      break
    fi
  done
  if [[ -n "$tracked_port" ]]; then
    printf '%s\n' "$tracked_port"
    return 0
  fi

  while IFS= read -r target_pid; do
    [[ -n "$target_pid" ]] || continue
    cmd="$(process_command "$target_pid" 2>/dev/null || true)"
    derived_port="$(printf '%s\n' "$cmd" | sed -n 's/.*--browserUrl http:\/\/127\.0\.0\.1:\([0-9][0-9]*\).*/\1/p' | head -n 1)"
    if [[ -n "$derived_port" ]]; then
      printf '%s\n' "$derived_port"
      return 0
    fi
  done < <(printf '%s\n' "$pid"; collect_descendants "$pid" | awk '!seen[$0]++')

  return 1
}

wrapper_is_healthy_or_tracked() {
  local pid="$1"
  local port=""

  if session_tracks_wrapper_pid "$pid"; then
    return 0
  fi
  if wrapper_parent_is_live_wrapper "$pid"; then
    return 0
  fi
  port="$(wrapper_browser_port "$pid" || true)"
  if [[ -n "$port" ]] && chrome_endpoint_reachable "$port"; then
    return 0
  fi
  return 1
}

process_has_live_wrapper_ancestor() {
  local pid="$1"
  local current="$pid"
  local depth=0
  local cmd

  while [[ -n "$current" && "$current" =~ ^[0-9]+$ && "$current" != "0" && "$depth" -lt 16 ]]; do
    cmd="$(process_command "$current" 2>/dev/null || true)"
    if [[ "$cmd" == *"codex-chrome-devtools-mcp.sh"* ]] && pid_alive "$current"; then
      return 0
    fi
    current="$(process_parent_pid "$current")"
    depth=$((depth + 1))
  done

  return 1
}

is_global_shared_keeper_process() {
  local pid="$1"
  local cmd
  cmd="$(process_command "$pid" 2>/dev/null || true)"
  [[ "$cmd" == *"--browserUrl http://127.0.0.1:9422"* || "$cmd" == *".codex/tmp/chrome-devtools-global/"* ]]
}

process_is_diagnostic_helper() {
  local pid="$1"
  local cmd
  cmd="$(process_command "$pid" 2>/dev/null || true)"
  [[ "$cmd" == *"chrome-devtools-mcp-status.sh"* || "$cmd" == *"chrome-devtools-mcp-stop-conflicts.sh"* || "$cmd" == *"codex-mcp-session-reaper.sh"* ]]
}

# ── Generic MCP plugin process detection ──────────────────────────────────
# MCP plugin processes (context7-mcp, playwright-mcp, figma-console-mcp, etc.)
# are spawned via `npm exec @pkg/*-mcp` by Claude Code / Codex sessions.
# When a conversation ends the parent claude/codex binary should die, but
# the npm exec + node children often survive as orphans under the app-server
# or get reparented to launchd (PID 1).
#
# Detection: walk the ancestor chain looking for a live claude/codex binary.
# If none is found, the process is orphaned.

# Matches known Claude Code / Codex session binary patterns.
CLAUDE_SESSION_REGEX='claude.app/Contents/MacOS/claude|/Resources/codex[[:space:]]|codex-chrome-devtools-mcp\.sh|codex-figma-console-mcp\.sh'

process_has_live_session_ancestor() {
  local pid="$1"
  local current="$pid"
  local depth=0
  local cmd

  while [[ -n "$current" && "$current" =~ ^[0-9]+$ && "$current" != "0" && "$current" != "1" && "$depth" -lt 20 ]]; do
    cmd="$(process_command "$current" 2>/dev/null || true)"
    # Skip the npm exec / node layers; look for the session owner.
    if [[ "$cmd" =~ (claude\.app/Contents/MacOS/claude|/Resources/codex[[:space:]]|codex-chrome-devtools-mcp\.sh|codex-figma-console-mcp\.sh) ]] && pid_alive "$current"; then
      return 0
    fi
    # App-server is a long-lived host — NOT proof of a live session.
    if [[ "$cmd" == *"app-server"* ]]; then
      return 1
    fi
    current="$(process_parent_pid "$current")"
    depth=$((depth + 1))
  done

  return 1
}

# List orphaned generic MCP plugin processes (npm exec *-mcp or node *-mcp).
# Returns lines: PID CMD
list_orphaned_generic_mcp_processes() {
  local pid cmd

  # Catch npm exec @*/...-mcp and node .../*-mcp processes
  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    pid_alive "$pid" || continue
    [[ "$pid" != "$$" ]] || continue

    cmd="$(process_command "$pid" 2>/dev/null || true)"

    # Skip our own scripts / diagnostic helpers
    if process_is_diagnostic_helper "$pid"; then
      continue
    fi

    # Skip chrome-devtools-mcp global shared processes (handled separately)
    if [[ "$cmd" == *".codex/tmp/chrome-devtools-global/"* || "$cmd" == *"--browserUrl http://127.0.0.1:9422"* ]]; then
      continue
    fi
    if is_global_shared_keeper_process "$pid"; then
      continue
    fi

    # Skip processes whose command line contains "plugin-dir" (these are Claude
    # Code session binaries that happen to match *-mcp in their plugin paths)
    if [[ "$cmd" == *"--plugin-dir"* ]]; then
      continue
    fi

    # The core check: does this process have a live session ancestor?
    if process_has_live_session_ancestor "$pid"; then
      continue
    fi

    printf '%s\t%s\n' "$pid" "$(printf '%s' "$cmd" | head -c 150)"
  done < <(
    # npm exec processes running MCP servers
    pgrep -f 'npm exec.*-mcp' 2>/dev/null || true
    # node processes running MCP binaries directly
    pgrep -f 'node.*/node_modules/\.bin/.*-mcp' 2>/dev/null || true
  )
}

# ============================================================================
# DIAGNOSE
# ============================================================================

diagnose_sessions() {
  local total_sessions=0 stale_sessions=0 broken_sessions=0 total_agents=0 stale_agents=0
  local total_reserves=0 stale_reserves=0 orphan_count=0 total_figma_sessions=0 stale_figma_sessions=0

  echo "=== SESSION ENV FILES ==="
  for sf in "${LOG_DIR}"/codex-chrome-session-*.env; do
    local port wrapper_pid wrapper_alive endpoint
    port="$(port_from_session_file "$sf")"
    wrapper_pid="$(env_field "$sf" WRAPPER_PID)"
    wrapper_alive="NO"; pid_alive "$wrapper_pid" && wrapper_alive="YES"
    endpoint="NO"; chrome_endpoint_reachable "$port" && endpoint="YES"
    echo "SESSION port=${port} wrapper_pid=${wrapper_pid:-?} wrapper=${wrapper_alive} endpoint=${endpoint}"
    total_sessions=$((total_sessions + 1))
    [[ "$wrapper_alive" == "NO" ]] && stale_sessions=$((stale_sessions + 1))
    [[ "$wrapper_alive" == "YES" && "$endpoint" == "NO" ]] && broken_sessions=$((broken_sessions + 1))
  done
  [[ $total_sessions -eq 0 ]] && echo "(none)"

  echo ""
  echo "=== CHROME AGENT PID FILES ==="
  for pf in "${LOG_DIR}"/chrome-agent-*.pid; do
    local port agent_pid agent_alive endpoint
    port="$(port_from_agent_pidfile "$pf")"
    agent_pid="$(cat "$pf" 2>/dev/null || true)"
    agent_alive="NO"; pid_alive "$agent_pid" && agent_alive="YES"
    endpoint="NO"; chrome_endpoint_reachable "$port" && endpoint="YES"
    echo "AGENT port=${port} pid=${agent_pid:-?} alive=${agent_alive} endpoint=${endpoint}"
    total_agents=$((total_agents + 1))
    [[ "$agent_alive" == "NO" ]] && stale_agents=$((stale_agents + 1))
  done
  [[ $total_agents -eq 0 ]] && echo "(none)"

  echo ""
  echo "=== RESERVE FILES ==="
  for rf in "${LOG_DIR}"/codex-chrome-port-*.reserve; do
    local port owner_pid owner_alive
    port="$(port_from_reserve_file "$rf")"
    owner_pid="$(cat "$rf" 2>/dev/null || true)"
    owner_alive="NO"; pid_alive "$owner_pid" && owner_alive="YES"
    echo "RESERVE port=${port} owner_pid=${owner_pid:-?} owner=${owner_alive}"
    total_reserves=$((total_reserves + 1))
    [[ "$owner_alive" == "NO" ]] && stale_reserves=$((stale_reserves + 1))
  done
  [[ $total_reserves -eq 0 ]] && echo "(none)"

  echo ""
  echo "=== FIGMA CONSOLE SESSION FILES ==="
  for sf in "${FIGMA_RUNTIME_DIR}"/figma-console-session-*.env; do
    local wrapper_pid child_pid wrapper_alive child_alive app_type
    wrapper_pid="$(figma_wrapper_pid_from_session_file "$sf")"
    child_pid="$(figma_child_pid_from_session_file "$sf")"
    wrapper_alive="NO"; pid_alive "$wrapper_pid" && wrapper_alive="YES"
    child_alive="NO"; pid_alive "$child_pid" && child_alive="YES"
    app_type="$(env_field "$sf" APP_SERVER_TYPE)"
    echo "FIGMA session=$(basename "$sf") wrapper_pid=${wrapper_pid:-?} wrapper=${wrapper_alive} child_pid=${child_pid:-?} child=${child_alive} app_server=${app_type:-unknown}"
    total_figma_sessions=$((total_figma_sessions + 1))
    [[ "$wrapper_alive" == "NO" ]] && stale_figma_sessions=$((stale_figma_sessions + 1))
  done
  [[ $total_figma_sessions -eq 0 ]] && echo "(none)"

  echo ""
  echo "=== ORPHANED GENERIC MCP PLUGIN PROCESSES ==="
  local total_generic_orphans=0
  while IFS=$'\t' read -r pid cmd; do
    [[ -n "$pid" ]] || continue
    local ppid_val
    ppid_val="$(process_parent_pid "$pid")"
    echo "ORPHAN type=generic-mcp pid=${pid} ppid=${ppid_val:-?} cmd=${cmd}"
    total_generic_orphans=$((total_generic_orphans + 1))
  done < <(list_orphaned_generic_mcp_processes)
  [[ $total_generic_orphans -gt 0 ]] || echo "(none)"

  echo ""
  echo "=== ORPHANED PROCESSES (chrome-devtools / figma specific) ==="

  # Live wrapper scripts
  local pid
  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    pid_alive "$pid" || continue
    [[ "$pid" != "$$" ]] || continue
    if wrapper_is_healthy_or_tracked "$pid"; then
      continue
    fi
    local ppid_val app_type cmd
    ppid_val="$(process_parent_pid "$pid")"
    app_type="$(classify_codex_app_server_pid "$pid")"
    cmd="$(process_command "$pid" | head -c 120)"
    echo "ORPHAN type=wrapper pid=${pid} ppid=${ppid_val:-?} app_server=${app_type} cmd=${cmd}"
    orphan_count=$((orphan_count + 1))
  done < <(pgrep -f "scripts/codex-chrome-devtools-mcp\\.sh" 2>/dev/null || true)

  # Live npm chrome-devtools-mcp processes not under a live wrapper
  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    pid_alive "$pid" || continue
    [[ "$pid" != "$$" ]] || continue
    if process_is_diagnostic_helper "$pid"; then
      continue
    fi
    local full_cmd
    full_cmd="$(process_command "$pid" 2>/dev/null || true)"
    if [[ "$full_cmd" == *".codex/tmp/chrome-devtools-global/"* || "$full_cmd" == *"--browserUrl http://127.0.0.1:9422"* ]] || process_has_live_ancestor_matching "$pid" '127\.0\.0\.1:9422|codex-chrome-devtools-mcp-global\.sh|chrome-devtools-global'; then
      continue
    fi
    if is_global_shared_keeper_process "$pid"; then
      continue
    fi
    if process_has_live_wrapper_ancestor "$pid"; then
      continue
    fi
    local ppid_val
    ppid_val="$(process_parent_pid "$pid")"
    local app_type cmd
    app_type="$(classify_codex_app_server_pid "$pid")"
    cmd="$(printf '%s' "$full_cmd" | head -c 120)"
    echo "ORPHAN type=npm pid=${pid} ppid=${ppid_val:-?} app_server=${app_type} cmd=${cmd}"
    orphan_count=$((orphan_count + 1))
  done < <(pgrep -f "chrome-devtools-mcp" 2>/dev/null || true)

  # Live telemetry/watchdog processes
  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    pid_alive "$pid" || continue
    [[ "$pid" != "$$" ]] || continue
    if process_is_diagnostic_helper "$pid"; then
      continue
    fi
    local full_cmd
    full_cmd="$(process_command "$pid" 2>/dev/null || true)"
    if [[ "$full_cmd" == *".codex/tmp/chrome-devtools-global/"* || "$full_cmd" == *"--browserUrl http://127.0.0.1:9422"* ]] || process_has_live_ancestor_matching "$pid" '127\.0\.0\.1:9422|codex-chrome-devtools-mcp-global\.sh|chrome-devtools-global'; then
      continue
    fi
    if is_global_shared_keeper_process "$pid"; then
      continue
    fi
    if process_has_live_wrapper_ancestor "$pid"; then
      continue
    fi
    local ppid_val
    ppid_val="$(process_parent_pid "$pid")"
    local app_type cmd
    app_type="$(classify_codex_app_server_pid "$pid")"
    cmd="$(printf '%s' "$full_cmd" | head -c 120)"
    echo "ORPHAN type=watchdog pid=${pid} ppid=${ppid_val:-?} app_server=${app_type} cmd=${cmd}"
    orphan_count=$((orphan_count + 1))
  done < <(pgrep -f "telemetry/watchdog" 2>/dev/null || true)

  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    pid_alive "$pid" || continue
    [[ "$pid" != "$$" ]] || continue
    if figma_wrapper_is_tracked "$pid"; then
      continue
    fi
    local ppid_val app_type cmd
    ppid_val="$(process_parent_pid "$pid")"
    app_type="$(classify_codex_app_server_pid "$pid")"
    cmd="$(process_command "$pid" | head -c 120)"
    echo "ORPHAN type=figma-wrapper pid=${pid} ppid=${ppid_val:-?} app_server=${app_type} cmd=${cmd}"
    orphan_count=$((orphan_count + 1))
  done < <(pgrep -f "codex-figma-console-mcp\\.sh" 2>/dev/null || true)

  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    pid_alive "$pid" || continue
    [[ "$pid" != "$$" ]] || continue
    if figma_process_has_live_wrapper_ancestor "$pid"; then
      continue
    fi
    local ppid_val app_type cmd
    ppid_val="$(process_parent_pid "$pid")"
    app_type="$(classify_codex_app_server_pid "$pid")"
    cmd="$(process_command "$pid" | head -c 120)"
    echo "ORPHAN type=figma pid=${pid} ppid=${ppid_val:-?} app_server=${app_type} cmd=${cmd}"
    orphan_count=$((orphan_count + 1))
  done < <(pgrep -f "figma-console-mcp" 2>/dev/null || true)

  [[ $orphan_count -gt 0 ]] || echo "(none)"

  echo ""
  echo "=== SUMMARY ==="
  echo "TOTAL_SESSIONS=${total_sessions} STALE_SESSIONS=${stale_sessions}"
  echo "BROKEN_LIVE_SESSIONS=${broken_sessions}"
  echo "TOTAL_AGENTS=${total_agents} STALE_AGENTS=${stale_agents}"
  echo "TOTAL_RESERVES=${total_reserves} STALE_RESERVES=${stale_reserves}"
  echo "TOTAL_FIGMA_SESSIONS=${total_figma_sessions} STALE_FIGMA_SESSIONS=${stale_figma_sessions}"
  echo "ORPHANED_GENERIC_MCP=${total_generic_orphans}"
  echo "ORPHANED_PROCESSES=${orphan_count}"
}

# ============================================================================
# REAP
# ============================================================================

reap_sessions() {
  local killed=0 rm_sessions=0 rm_pages=0 rm_reserves=0 rm_agents=0 stopped_chrome=0 broken_live_sessions=0 rm_figma_sessions=0 stopped_shared_headful=0

  # --- 0. Kill orphaned generic MCP plugin processes ---
  # (context7-mcp, playwright-mcp, etc. that outlive their session)
  log "Phase 0: killing orphaned generic MCP plugin processes"

  local pid cmd
  while IFS=$'\t' read -r pid cmd; do
    [[ -n "$pid" ]] || continue
    safe_to_kill "$pid" || continue
    pid_alive "$pid" || continue
    log "Killing orphaned generic MCP process pid=${pid} cmd=${cmd}"
    log_file "REAP generic-mcp pid=${pid} cmd=${cmd}"
    kill_pid_tree "$pid" "orphan-generic-mcp" 2>/dev/null && killed=$((killed + 1))
  done < <(list_orphaned_generic_mcp_processes)

  # --- 1. Kill orphaned process trees ---
  log "Phase 1: killing orphaned chrome-devtools process trees"

  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    safe_to_kill "$pid" || continue
    pid_alive "$pid" || continue
    if wrapper_is_healthy_or_tracked "$pid"; then
      continue
    fi
    log "Killing orphaned wrapper process tree pid=${pid}"
    kill_pid_tree "$pid" "orphan-wrapper" 2>/dev/null && killed=$((killed + 1))
  done < <(pgrep -f "scripts/codex-chrome-devtools-mcp\\.sh" 2>/dev/null || true)

  local pid
  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    safe_to_kill "$pid" || continue
    pid_alive "$pid" || continue
    if process_is_diagnostic_helper "$pid"; then
      continue
    fi
    local full_cmd
    full_cmd="$(process_command "$pid" 2>/dev/null || true)"
    if [[ "$full_cmd" == *".codex/tmp/chrome-devtools-global/"* || "$full_cmd" == *"--browserUrl http://127.0.0.1:9422"* ]] || process_has_live_ancestor_matching "$pid" '127\.0\.0\.1:9422|codex-chrome-devtools-mcp-global\.sh|chrome-devtools-global'; then
      continue
    fi
    if is_global_shared_keeper_process "$pid"; then
      continue
    fi
    if process_has_live_wrapper_ancestor "$pid"; then
      continue
    fi
    log "Killing orphaned npm/node process tree pid=${pid}"
    kill_pid_tree "$pid" "orphan-npm" 2>/dev/null && killed=$((killed + 1))
  done < <(pgrep -f "chrome-devtools-mcp" 2>/dev/null || true)

  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    safe_to_kill "$pid" || continue
    pid_alive "$pid" || continue
    if process_is_diagnostic_helper "$pid"; then
      continue
    fi
    local full_cmd
    full_cmd="$(process_command "$pid" 2>/dev/null || true)"
    if [[ "$full_cmd" == *".codex/tmp/chrome-devtools-global/"* || "$full_cmd" == *"--browserUrl http://127.0.0.1:9422"* ]] || process_has_live_ancestor_matching "$pid" '127\.0\.0\.1:9422|codex-chrome-devtools-mcp-global\.sh|chrome-devtools-global'; then
      continue
    fi
    if is_global_shared_keeper_process "$pid"; then
      continue
    fi
    if process_has_live_wrapper_ancestor "$pid"; then
      continue
    fi
    log "Killing orphaned telemetry watchdog pid=${pid}"
    kill_pid_tree "$pid" "orphan-watchdog" 2>/dev/null && killed=$((killed + 1))
  done < <(pgrep -f "telemetry/watchdog" 2>/dev/null || true)

  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    safe_to_kill "$pid" || continue
    pid_alive "$pid" || continue
    if figma_wrapper_is_tracked "$pid"; then
      continue
    fi
    log "Killing orphaned figma wrapper process tree pid=${pid}"
    kill_pid_tree "$pid" "orphan-figma-wrapper" 2>/dev/null && killed=$((killed + 1))
  done < <(pgrep -f "codex-figma-console-mcp\\.sh" 2>/dev/null || true)

  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    safe_to_kill "$pid" || continue
    pid_alive "$pid" || continue
    if figma_process_has_live_wrapper_ancestor "$pid"; then
      continue
    fi
    log "Killing orphaned figma-console process tree pid=${pid}"
    kill_pid_tree "$pid" "orphan-figma-console" 2>/dev/null && killed=$((killed + 1))
  done < <(pgrep -f "figma-console-mcp" 2>/dev/null || true)

  # --- 2. Stop Chrome agents for dead/broken sessions (before removing env files) ---
  log "Phase 2: stopping orphaned or broken Chrome agents"

  for sf in "${LOG_DIR}"/codex-chrome-session-*.env; do
    local port wrapper_pid agent_pid
    port="$(port_from_session_file "$sf")"
    wrapper_pid="$(env_field "$sf" WRAPPER_PID)"
    agent_pid="$(cat "${LOG_DIR}/chrome-agent-${port}.pid" 2>/dev/null || true)"
    if ! pid_alive "$wrapper_pid" && chrome_endpoint_reachable "$port"; then
      log "Stopping orphaned Chrome on port ${port} (dead wrapper ${wrapper_pid})"
      CHROME_AGENT_DEBUG_PORT="$port" bash "${ROOT}/scripts/stop-chrome-agent.sh" >/dev/null 2>&1 || true
      stopped_chrome=$((stopped_chrome + 1))
      continue
    fi
    if pid_alive "$wrapper_pid" && ! chrome_endpoint_reachable "$port"; then
      log "Stopping broken live session on port ${port} (wrapper=${wrapper_pid}, endpoint missing)"
      kill_pid_tree "$wrapper_pid" "broken-wrapper-${port}" 2>/dev/null || true
      killed=$((killed + 1))
      if pid_alive "$agent_pid"; then
        CHROME_AGENT_DEBUG_PORT="$port" bash "${ROOT}/scripts/stop-chrome-agent.sh" >/dev/null 2>&1 || true
        stopped_chrome=$((stopped_chrome + 1))
      fi
      broken_live_sessions=$((broken_live_sessions + 1))
    fi
  done

  for sf in "${FIGMA_RUNTIME_DIR}"/figma-console-session-*.env; do
    local wrapper_pid child_pid
    wrapper_pid="$(figma_wrapper_pid_from_session_file "$sf")"
    child_pid="$(figma_child_pid_from_session_file "$sf")"
    if ! pid_alive "$wrapper_pid"; then
      if pid_alive "$child_pid"; then
        log "Stopping orphaned figma-console child pid=${child_pid} from stale session $(basename "$sf")"
        kill_pid_tree "$child_pid" "stale-figma-session" 2>/dev/null || true
        killed=$((killed + 1))
      fi
      rm -f "$sf"
      rm_figma_sessions=$((rm_figma_sessions + 1))
    fi
  done

  # --- 3. Remove stale session env and .pages files ---
  log "Phase 3: removing stale session artifacts"

  for sf in "${LOG_DIR}"/codex-chrome-session-*.env; do
    local port wrapper_pid
    port="$(port_from_session_file "$sf")"
    wrapper_pid="$(env_field "$sf" WRAPPER_PID)"
    if ! pid_alive "$wrapper_pid"; then
      rm -f "$sf"
      rm_sessions=$((rm_sessions + 1))
      local pages_file="${sf%.env}.pages"
      if [[ -f "$pages_file" ]]; then
        rm -f "$pages_file"
        rm_pages=$((rm_pages + 1))
      fi
    fi
  done

  # Orphaned .pages without companion .env
  for pf in "${LOG_DIR}"/codex-chrome-session-*.pages; do
    local companion="${pf%.pages}.env"
    if [[ ! -f "$companion" ]]; then
      rm -f "$pf"
      rm_pages=$((rm_pages + 1))
    fi
  done

  # --- 4. Remove stale reserve files ---
  log "Phase 4: removing stale reserve files"

  for rf in "${LOG_DIR}"/codex-chrome-port-*.reserve; do
    local owner_pid
    owner_pid="$(cat "$rf" 2>/dev/null || true)"
    if ! pid_alive "$owner_pid"; then
      rm -f "$rf"
      rm_reserves=$((rm_reserves + 1))
    fi
  done

  # --- 5. Remove stale chrome-agent pidfiles + companion .env ---
  log "Phase 5: removing stale chrome-agent pidfiles"

  for pf in "${LOG_DIR}"/chrome-agent-*.pid; do
    local port agent_pid
    port="$(port_from_agent_pidfile "$pf")"
    agent_pid="$(cat "$pf" 2>/dev/null || true)"
    if ! pid_alive "$agent_pid"; then
      rm -f "$pf"
      rm -f "${LOG_DIR}/chrome-agent-${port}.env"
      rm_agents=$((rm_agents + 1))
    fi
  done

  # Orphaned chrome-agent .env without companion .pid
  for ef in "${LOG_DIR}"/chrome-agent-*.env; do
    local companion="${ef%.env}.pid"
    if [[ ! -f "$companion" ]]; then
      rm -f "$ef"
    fi
  done

  if [[ -f "$VISIBLE_BROWSER_OWNER_FILE" ]]; then
    local owner_pid owner_port wrapper_pid listener_pid shared_client_count claimed_at claimed_age
    owner_pid="$(owner_browser_pid)"
    wrapper_pid="$(owner_wrapper_pid)"
    owner_port="$(owner_field PORT)"
    claimed_at="$(owner_field CLAIMED_AT)"
    listener_pid=""
    [[ -n "$owner_port" ]] && listener_pid="$(chrome_listener_pid "$owner_port")"

    if [[ -z "$owner_pid" || ! "$owner_pid" =~ ^[0-9]+$ ]] || { ! pid_alive "$owner_pid" && [[ -z "$listener_pid" ]]; }; then
      rm -f "$VISIBLE_BROWSER_OWNER_FILE"
    elif [[ "$owner_port" == "9222" ]] && [[ -n "$listener_pid" ]] && ! pid_alive "$wrapper_pid"; then
      shared_client_count="$(shared_chrome_client_pids | awk '!seen[$0]++' | wc -l | tr -d ' ')"
      claimed_age="$(owner_timestamp_age_sec "$claimed_at" 2>/dev/null || true)"
      if [[ "$shared_client_count" == "0" ]] && [[ "$claimed_age" =~ ^[0-9]+$ ]] && (( claimed_age >= SHARED_HEADFUL_IDLE_SEC )); then
        log "Stopping idle shared headful Chrome on port 9222 after stale wrapper timeout (${claimed_age}s, no active shared clients)."
        CHROME_AGENT_DEBUG_PORT="9222" bash "${ROOT}/scripts/stop-chrome-agent.sh" >/dev/null 2>&1 || true
        rm -f "$VISIBLE_BROWSER_OWNER_FILE"
        stopped_shared_headful=$((stopped_shared_headful + 1))
      fi
    fi
  fi

  workspace_reaper_render_summary \
    "[mcp-session-reaper]" \
    "$killed" \
    "$rm_sessions" \
    "$rm_pages" \
    "$rm_reserves" \
    "$rm_agents" \
    "$rm_figma_sessions" \
    "$stopped_chrome" \
    "$stopped_shared_headful" \
    "$broken_live_sessions"
  log "Reap complete: killed=${killed} sessions=${rm_sessions} pages=${rm_pages} reserves=${rm_reserves} agents=${rm_agents} figma_sessions=${rm_figma_sessions} chrome=${stopped_chrome} shared_headful=${stopped_shared_headful} broken=${broken_live_sessions}"
}

# ============================================================================
# WATCH (daemon mode)
# ============================================================================

watch_sessions() {
  log "Starting watch daemon (interval=${REAPER_INTERVAL_SEC}s, log=${REAPER_LOG})"
  local iteration=0
  while true; do
    iteration=$((iteration + 1))
    log_file "=== iteration ${iteration} ==="
    diagnose_sessions >>"$REAPER_LOG" 2>&1 || true
    reap_sessions >>"$REAPER_LOG" 2>&1 || true
    log_file "iteration ${iteration} done"
    sleep "$REAPER_INTERVAL_SEC"
  done
}

# ============================================================================
# MAIN
# ============================================================================

mkdir -p "$LOG_DIR"

case "${1:-diagnose}" in
  diagnose) log "Running diagnose..."; diagnose_sessions ;;
  reap)     log "Running reap...";     reap_sessions ;;
  watch)    watch_sessions ;;
  *)
    echo "Usage: $(basename "$0") [diagnose|reap|watch]" >&2
    exit 1
    ;;
esac

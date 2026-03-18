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

for lib in mcp-runtime.sh chrome-runtime.sh; do
  if [[ ! -f "${ROOT}/scripts/lib/${lib}" ]]; then
    echo "[mcp-session-reaper] ERROR: Missing ${lib}" >&2
    exit 1
  fi
done
source "${ROOT}/scripts/lib/mcp-runtime.sh"
source "${ROOT}/scripts/lib/chrome-runtime.sh"

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

# ============================================================================
# DIAGNOSE
# ============================================================================

diagnose_sessions() {
  local total_sessions=0 stale_sessions=0 broken_sessions=0 total_agents=0 stale_agents=0
  local total_reserves=0 stale_reserves=0 orphan_count=0

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
  echo "=== ORPHANED PROCESSES ==="

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
    if process_has_live_wrapper_ancestor "$pid"; then
      continue
    fi
    local ppid_val
    ppid_val="$(process_parent_pid "$pid")"
    local app_type cmd
    app_type="$(classify_codex_app_server_pid "$pid")"
    cmd="$(process_command "$pid" | head -c 120)"
    echo "ORPHAN type=npm pid=${pid} ppid=${ppid_val:-?} app_server=${app_type} cmd=${cmd}"
    orphan_count=$((orphan_count + 1))
  done < <(pgrep -f "chrome-devtools-mcp" 2>/dev/null || true)

  # Live telemetry/watchdog processes
  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    pid_alive "$pid" || continue
    [[ "$pid" != "$$" ]] || continue
    if process_has_live_wrapper_ancestor "$pid"; then
      continue
    fi
    local ppid_val
    ppid_val="$(process_parent_pid "$pid")"
    local app_type cmd
    app_type="$(classify_codex_app_server_pid "$pid")"
    cmd="$(process_command "$pid" | head -c 120)"
    echo "ORPHAN type=watchdog pid=${pid} ppid=${ppid_val:-?} app_server=${app_type} cmd=${cmd}"
    orphan_count=$((orphan_count + 1))
  done < <(pgrep -f "telemetry/watchdog" 2>/dev/null || true)

  [[ $orphan_count -gt 0 ]] || echo "(none)"

  echo ""
  echo "=== SUMMARY ==="
  echo "TOTAL_SESSIONS=${total_sessions} STALE_SESSIONS=${stale_sessions}"
  echo "BROKEN_LIVE_SESSIONS=${broken_sessions}"
  echo "TOTAL_AGENTS=${total_agents} STALE_AGENTS=${stale_agents}"
  echo "TOTAL_RESERVES=${total_reserves} STALE_RESERVES=${stale_reserves}"
  echo "ORPHANED_PROCESSES=${orphan_count}"
}

# ============================================================================
# REAP
# ============================================================================

reap_sessions() {
  local killed=0 rm_sessions=0 rm_pages=0 rm_reserves=0 rm_agents=0 stopped_chrome=0 broken_live_sessions=0

  # --- 1. Kill orphaned process trees ---
  log "Phase 1: killing orphaned process trees"

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
    if process_has_live_wrapper_ancestor "$pid"; then
      continue
    fi
    log "Killing orphaned telemetry watchdog pid=${pid}"
    kill_pid_tree "$pid" "orphan-watchdog" 2>/dev/null && killed=$((killed + 1))
  done < <(pgrep -f "telemetry/watchdog" 2>/dev/null || true)

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

  echo "=== REAP SUMMARY ==="
  echo "KILLED_PROCESSES=${killed}"
  echo "REMOVED_SESSION_FILES=${rm_sessions}"
  echo "REMOVED_PAGES_FILES=${rm_pages}"
  echo "REMOVED_RESERVE_FILES=${rm_reserves}"
  echo "REMOVED_AGENT_PIDFILES=${rm_agents}"
  echo "STOPPED_CHROME_AGENTS=${stopped_chrome}"
  echo "BROKEN_LIVE_SESSIONS=${broken_live_sessions}"
  log "Reap complete: killed=${killed} sessions=${rm_sessions} pages=${rm_pages} reserves=${rm_reserves} agents=${rm_agents} chrome=${stopped_chrome} broken=${broken_live_sessions}"
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

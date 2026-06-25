#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/TRR-APP"
LOG_DIR="$ROOT_DIR/.logs/workspace"
STATE_FILE="$LOG_DIR/portless-managed.env"
WEB_SESSION="${TRR_PORTLESS_WEB_SESSION:-trr-portless-web}"
API_SESSION="${TRR_PORTLESS_API_SESSION:-trr-portless-api}"
WORDLE_SESSION="${TRR_PORTLESS_WORDLE_SESSION:-trr-portless-wordle}"
WEB_LOG="$LOG_DIR/portless-web.log"
API_LOG="$LOG_DIR/portless-api.log"
WORDLE_LOG="$LOG_DIR/portless-wordle.log"
READY_TIMEOUT_SECONDS="${TRR_PORTLESS_READY_TIMEOUT_SECONDS:-45}"
PORTLESS_PUBLIC_PORT_SUFFIX=""
if [[ -n "${PORTLESS_PORT:-}" && "${PORTLESS_PORT}" != "443" ]]; then
  PORTLESS_PUBLIC_PORT_SUFFIX=":${PORTLESS_PORT}"
fi

export PATH="/opt/homebrew/bin:${PATH}"

usage() {
  cat <<EOF
Usage: $0 [start|stop|status]

Starts TRR clean local URLs through Portless as separate managed sessions:
  app/admin: $WEB_SESSION
  API:       $API_SESSION
  Wordle:    $WORDLE_SESSION
EOF
}

require_command() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "[dev-portless] ERROR: required command '$name' was not found." >&2
    exit 127
  fi
}

screen_session_running() {
  local session="$1"
  local sessions
  sessions="$(screen -ls 2>/dev/null || true)"
  grep -Eq "[[:space:]][0-9]+\\.${session}[[:space:]]" <<<"$sessions"
}

stop_screen_session() {
  local session="$1"
  local sessions
  sessions="$(screen -ls 2>/dev/null | awk -v name="$session" '$1 ~ "^[0-9]+\\." name "$" { print $1 }' || true)"
  if [[ -z "$sessions" ]]; then
    return 0
  fi

  while IFS= read -r screen_id; do
    [[ -z "$screen_id" ]] && continue
    echo "[dev-portless] Stopping existing screen session: $screen_id"
    screen -S "$screen_id" -X quit >/dev/null 2>&1 || true
  done <<< "$sessions"
}

stop_sessions() {
  require_command screen
  stop_screen_session "$WEB_SESSION"
  stop_screen_session "$API_SESSION"
  stop_screen_session "$WORDLE_SESSION"
  if command -v portless >/dev/null 2>&1; then
    stop_stale_portless_route_owners
  fi
  rm -f "$STATE_FILE"
}

portless_status() {
  echo "[dev-portless] Managed sessions:"
  if screen_session_running "$WEB_SESSION"; then
    echo "  web: running ($WEB_SESSION)"
  else
    echo "  web: stopped ($WEB_SESSION)"
  fi
  if screen_session_running "$API_SESSION"; then
    echo "  api: running ($API_SESSION)"
  else
    echo "  api: stopped ($API_SESSION)"
  fi
  if screen_session_running "$WORDLE_SESSION"; then
    echo "  wordle: running ($WORDLE_SESSION)"
  else
    echo "  wordle: stopped ($WORDLE_SESSION)"
  fi
  echo
  echo "[dev-portless] Portless routes:"
  portless list || true
}

stop_stale_next_lock_holder() {
  local lock_file="$APP_DIR/apps/web/.next/dev/lock"
  if [[ ! -e "$lock_file" ]] || ! command -v lsof >/dev/null 2>&1; then
    return 0
  fi

  local pids
  pids="$(lsof -t "$lock_file" 2>/dev/null | sort -u || true)"
  if [[ -z "$pids" ]]; then
    return 0
  fi

  echo "[dev-portless] Clearing stale TRR-APP Next dev lock before starting Portless web..."
  while IFS= read -r pid; do
    [[ -z "$pid" ]] && continue
    local command_line
    command_line="$(ps -p "$pid" -o command= 2>/dev/null || true)"
    echo "[dev-portless]   terminating lock holder pid=$pid ${command_line}"
    kill "$pid" >/dev/null 2>&1 || true
  done <<< "$pids"

  sleep 1
}

stop_stale_portless_route_owners() {
  local output
  local route_owner_pattern='^[[:space:]]*https://([a-zA-Z0-9.-]+)\.localhost(:[0-9]+)?[[:space:]]+->[[:space:]].*\(pid[[:space:]]+([0-9]+)\)'
  output="$(portless list 2>/dev/null || true)"
  if [[ -z "$output" ]]; then
    return 0
  fi

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if [[ "$line" =~ $route_owner_pattern ]]; then
      local route="${BASH_REMATCH[1]}"
      local pid="${BASH_REMATCH[3]}"
      case "$route" in
        trr|api.trr|admin.trr|wordle.trr)
          if kill -0 "$pid" >/dev/null 2>&1; then
            echo "[dev-portless] Terminating stale Portless route owner: $route pid=$pid"
            kill "$pid" >/dev/null 2>&1 || true
          fi
          ;;
      esac
    fi
  done <<< "$output"
}

start_screen_session() {
  local session="$1"
  local log_file="$2"
  local command="$3"

  : > "$log_file"
  screen -dmS "$session" /bin/bash -lc "$command"
  echo "[dev-portless] Started $session"
  echo "[dev-portless]   log: $log_file"
}

wait_for_routes() {
  local deadline=$((SECONDS + READY_TIMEOUT_SECONDS))
  local output=""

  while (( SECONDS < deadline )); do
    output="$(portless list 2>/dev/null || true)"
    if grep -Eq "https://trr\.localhost(:[0-9]+)?[[:space:]]+->[[:space:]]+" <<< "$output" && grep -Eq "https://api\.trr\.localhost(:[0-9]+)?[[:space:]]+->[[:space:]]+" <<< "$output" && grep -Eq "https://wordle\.trr\.localhost(:[0-9]+)?[[:space:]]+->[[:space:]]+" <<< "$output"; then
      echo "$output"
      return 0
    fi
    sleep 1
  done

  echo "$output"
  return 1
}

write_state_file() {
  mkdir -p "$LOG_DIR"
  cat > "$STATE_FILE" <<EOF
TRR_PORTLESS_WEB_SESSION="$WEB_SESSION"
TRR_PORTLESS_API_SESSION="$API_SESSION"
TRR_PORTLESS_WORDLE_SESSION="$WORDLE_SESSION"
TRR_PORTLESS_WEB_LOG="$WEB_LOG"
TRR_PORTLESS_API_LOG="$API_LOG"
TRR_PORTLESS_WORDLE_LOG="$WORDLE_LOG"
TRR_PORTLESS_ADMIN_URL="https://admin.trr.localhost${PORTLESS_PUBLIC_PORT_SUFFIX}"
TRR_PORTLESS_APP_URL="https://trr.localhost${PORTLESS_PUBLIC_PORT_SUFFIX}"
TRR_PORTLESS_API_URL="https://api.trr.localhost${PORTLESS_PUBLIC_PORT_SUFFIX}/health/live"
TRR_PORTLESS_WORDLE_URL="https://wordle.trr.localhost${PORTLESS_PUBLIC_PORT_SUFFIX}"
EOF
}

start_sessions() {
  require_command portless
  require_command screen

  mkdir -p "$LOG_DIR"
  stop_sessions
  stop_stale_portless_route_owners
  stop_stale_next_lock_holder

  echo "[dev-portless] Repairing Portless wildcard route state..."
  PORTLESS_REPAIR_ALLOW_NO_ACTIVE_ROUTES=1 bash "$ROOT_DIR/scripts/portless-repair.sh"

  # shellcheck disable=SC1091
  source "$ROOT_DIR/scripts/lib/node-baseline.sh"
  trr_ensure_node_baseline_or_exit "dev-portless" "$APP_DIR"

  echo
  node "$APP_DIR/scripts/portless-banner.mjs"

  local api_command web_command wordle_command
  api_command="set -euo pipefail; export PATH=\"/opt/homebrew/bin:\$PATH\"; source \"$ROOT_DIR/scripts/lib/node-baseline.sh\"; cd \"$APP_DIR\"; trr_pnpm \"$APP_DIR\" run api:portless 2>&1 | tee -a \"$API_LOG\""
  web_command="set -euo pipefail; export PATH=\"/opt/homebrew/bin:\$PATH\"; source \"$ROOT_DIR/scripts/lib/node-baseline.sh\"; cd \"$APP_DIR\"; trr_pnpm \"$APP_DIR\" run dev:portless 2>&1 | tee -a \"$WEB_LOG\""
  wordle_command="set -euo pipefail; export PATH=\"/opt/homebrew/bin:\$PATH\"; source \"$ROOT_DIR/scripts/lib/node-baseline.sh\"; cd \"$APP_DIR\"; PORTLESS_WILDCARD=1 portless wordle.trr --force --app-port 5173 bash -lc 'source \"$ROOT_DIR/scripts/lib/node-baseline.sh\"; cd \"$APP_DIR\"; trr_pnpm \"$APP_DIR\" -C apps/vue-wordle run dev' 2>&1 | tee -a \"$WORDLE_LOG\""

  start_screen_session "$API_SESSION" "$API_LOG" "$api_command"
  start_screen_session "$WEB_SESSION" "$WEB_LOG" "$web_command"
  start_screen_session "$WORDLE_SESSION" "$WORDLE_LOG" "$wordle_command"
  write_state_file

  echo
  echo "[dev-portless] Waiting for managed Portless routes..."
  if ! wait_for_routes; then
    echo "[dev-portless] WARNING: routes were not ready within ${READY_TIMEOUT_SECONDS}s." >&2
    echo "[dev-portless] Check logs:" >&2
    echo "[dev-portless]   $API_LOG" >&2
    echo "[dev-portless]   $WEB_LOG" >&2
    echo "[dev-portless]   $WORDLE_LOG" >&2
    exit 1
  fi

  cat <<EOF

[dev-portless] Clean TRR URLs are managed in separate sessions:
  Admin: https://admin.trr.localhost${PORTLESS_PUBLIC_PORT_SUFFIX}
  App:   https://trr.localhost${PORTLESS_PUBLIC_PORT_SUFFIX}
  API:   https://api.trr.localhost${PORTLESS_PUBLIC_PORT_SUFFIX}/health/live
  Wordle: https://wordle.trr.localhost${PORTLESS_PUBLIC_PORT_SUFFIX}

[dev-portless] Logs:
  Web: $WEB_LOG
  API: $API_LOG
  Wordle: $WORDLE_LOG

[dev-portless] Stop:
  $0 stop
EOF
}

case "${1:-start}" in
  start)
    start_sessions
    ;;
  stop|--stop)
    stop_sessions
    ;;
  status|--status)
    require_command portless
    require_command screen
    portless_status
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

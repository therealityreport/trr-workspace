#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT}/scripts/lib/chrome-runtime.sh"

MODE="${CODEX_CHROME_MODE:-isolated}"
SHARED_PORT="${CODEX_CHROME_SHARED_PORT:-${CODEX_CHROME_PORT:-9422}}"
LOG_DIR="${ROOT}/.logs/workspace"

shared_profile_for_port() {
  local port="$1"
  case "$port" in
    9222|9422)
      echo "${CHROME_AGENT_PROFILE_DIR:-${HOME}/.chrome-profiles/codex-agent}"
      ;;
    *)
      echo "${CHROME_AGENT_PROFILE_DIR:-${HOME}/.chrome-profiles/codex-chat-${port}}"
      ;;
  esac
}

shared_headless_for_port() {
  local port="$1"
  if [[ "$port" == "9222" ]]; then
    echo "0"
  else
    echo "1"
  fi
}

shared_profile_directory_for_port() {
  default_chrome_profile_directory_for_profile_dir "$(shared_profile_for_port "$1")"
}

shared_profile_ready() {
  local expected_profile
  local expected_profile_directory
  local statefile="${LOG_DIR}/chrome-agent-${SHARED_PORT}.env"
  local current_profile
  local current_profile_directory

  expected_profile="$(shared_profile_for_port "${SHARED_PORT}")"
  expected_profile_directory="$(shared_profile_directory_for_port "${SHARED_PORT}")"
  [[ -f "$statefile" ]] || return 1

  current_profile="$(sed -n 's/^PROFILE_DIR=//p' "$statefile" | head -n 1)"
  current_profile_directory="$(sed -n 's/^PROFILE_DIRECTORY=//p' "$statefile" | head -n 1)"

  [[ "$current_profile" == "$expected_profile" ]] || return 1
  [[ -z "$expected_profile_directory" || "$current_profile_directory" == "$expected_profile_directory" ]]
}

shared_ready() {
  curl -sf "http://127.0.0.1:${SHARED_PORT}/json/version" >/dev/null 2>&1 && shared_profile_ready
}

shared_remediation() {
  cat >&2 <<EOF
[ensure-managed-chrome] Shared managed Chrome is not available on http://127.0.0.1:${SHARED_PORT}.
[ensure-managed-chrome] Shared mode will not auto-launch Chrome.
[ensure-managed-chrome] Start it explicitly:
[ensure-managed-chrome]   CHROME_AGENT_DEBUG_PORT=${SHARED_PORT} CHROME_AGENT_PROFILE_DIR=\${HOME}/.chrome-profiles/codex-agent CHROME_AGENT_PROFILE_DIRECTORY='$(shared_profile_directory_for_port "${SHARED_PORT}")' CHROME_AGENT_HEADLESS=$(shared_headless_for_port "${SHARED_PORT}") bash "${ROOT}/scripts/chrome-agent.sh"
EOF
}

case "$MODE" in
  shared)
    if [[ "$SHARED_PORT" != "9422" && "$SHARED_PORT" != "9222" ]]; then
      echo "[ensure-managed-chrome] ERROR: Shared mode supports default automation on 9422 and explicit visible/manual work on 9222." >&2
      exit 1
    fi
    if ! shared_ready; then
      if curl -sf "http://127.0.0.1:${SHARED_PORT}/json/version" >/dev/null 2>&1; then
        echo "[ensure-managed-chrome] ERROR: Shared Chrome on ${SHARED_PORT} is reachable but not using the expected codex profile." >&2
        echo "[ensure-managed-chrome] Stop it, then relaunch with scripts/chrome-agent.sh so SocialBlade uses codex@thereality.report." >&2
        exit 1
      fi
      echo "[ensure-managed-chrome] Shared Chrome not running on ${SHARED_PORT}; auto-launching..." >&2
      CHROME_AGENT_DEBUG_PORT="${SHARED_PORT}" \
        CHROME_AGENT_PROFILE_DIR="$(shared_profile_for_port "${SHARED_PORT}")" \
        CHROME_AGENT_PROFILE_DIRECTORY="$(shared_profile_directory_for_port "${SHARED_PORT}")" \
        CHROME_AGENT_HEADLESS="$(shared_headless_for_port "${SHARED_PORT}")" \
        bash "${ROOT}/scripts/chrome-agent.sh" >/dev/null
      if ! shared_ready; then
        shared_remediation
        exit 1
      fi
      echo "[ensure-managed-chrome] Shared Chrome auto-launched on ${SHARED_PORT}." >&2
    fi
    ;;
  isolated)
    if [[ -z "${CODEX_CHROME_PORT:-}" ]]; then
      echo "[ensure-managed-chrome] ERROR: CODEX_CHROME_MODE=isolated requires CODEX_CHROME_PORT." >&2
      exit 1
    fi

    CHROME_AGENT_DEBUG_PORT="${CODEX_CHROME_PORT}" \
    CHROME_AGENT_PROFILE_DIR="${CHROME_AGENT_PROFILE_DIR:-${HOME}/.chrome-profiles/codex-chat-${CODEX_CHROME_PORT}}" \
    CHROME_AGENT_HEADLESS="${CODEX_CHROME_ISOLATED_HEADLESS:-1}" \
    bash "${ROOT}/scripts/chrome-agent.sh"
    ;;
  *)
    echo "[ensure-managed-chrome] ERROR: Unsupported CODEX_CHROME_MODE=${MODE}" >&2
    exit 1
    ;;
esac

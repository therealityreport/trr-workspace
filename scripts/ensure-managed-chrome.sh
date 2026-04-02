#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${CODEX_CHROME_MODE:-isolated}"
SHARED_PORT="${CODEX_CHROME_SHARED_PORT:-${CODEX_CHROME_PORT:-9422}}"

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

shared_ready() {
  curl -sf "http://127.0.0.1:${SHARED_PORT}/json/version" >/dev/null 2>&1
}

shared_remediation() {
  cat >&2 <<EOF
[ensure-managed-chrome] Shared managed Chrome is not available on http://127.0.0.1:${SHARED_PORT}.
[ensure-managed-chrome] Shared mode will not auto-launch Chrome.
[ensure-managed-chrome] Start it explicitly:
[ensure-managed-chrome]   CHROME_AGENT_DEBUG_PORT=${SHARED_PORT} CHROME_AGENT_PROFILE_DIR=\${HOME}/.chrome-profiles/codex-agent CHROME_AGENT_HEADLESS=$(shared_headless_for_port "${SHARED_PORT}") bash "${ROOT}/scripts/chrome-agent.sh"
EOF
}

case "$MODE" in
  shared)
    if [[ "$SHARED_PORT" != "9422" && "$SHARED_PORT" != "9222" ]]; then
      echo "[ensure-managed-chrome] ERROR: Shared mode supports default automation on 9422 and explicit visible/manual work on 9222." >&2
      exit 1
    fi
    if ! shared_ready; then
      echo "[ensure-managed-chrome] Shared Chrome not running on ${SHARED_PORT}; auto-launching..." >&2
      CHROME_AGENT_DEBUG_PORT="${SHARED_PORT}" \
        CHROME_AGENT_PROFILE_DIR="$(shared_profile_for_port "${SHARED_PORT}")" \
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

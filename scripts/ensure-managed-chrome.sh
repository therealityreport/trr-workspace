#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${CODEX_CHROME_MODE:-isolated}"
SHARED_PORT="${CODEX_CHROME_PORT:-9222}"

shared_ready() {
  curl -sf "http://127.0.0.1:${SHARED_PORT}/json/version" >/dev/null 2>&1
}

shared_remediation() {
  cat >&2 <<EOF
[ensure-managed-chrome] Shared managed Chrome is not available on http://127.0.0.1:${SHARED_PORT}.
[ensure-managed-chrome] Shared mode will not auto-launch Chrome.
[ensure-managed-chrome] Start it explicitly:
[ensure-managed-chrome]   CHROME_AGENT_DEBUG_PORT=${SHARED_PORT} CHROME_AGENT_PROFILE_DIR=\${HOME}/.chrome-profiles/claude-agent bash "${ROOT}/scripts/chrome-agent.sh"
EOF
}

case "$MODE" in
  shared)
    if [[ "$SHARED_PORT" != "9222" ]]; then
      echo "[ensure-managed-chrome] ERROR: Shared mode is pinned to port 9222." >&2
      exit 1
    fi
    if ! shared_ready; then
      echo "[ensure-managed-chrome] Shared Chrome not running on ${SHARED_PORT}; auto-launching..." >&2
      CHROME_AGENT_DEBUG_PORT="${SHARED_PORT}" \
        CHROME_AGENT_PROFILE_DIR="${CHROME_AGENT_PROFILE_DIR:-${HOME}/.chrome-profiles/claude-agent}" \
        CHROME_AGENT_HEADLESS=0 \
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

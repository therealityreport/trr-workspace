#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${CODEX_CHROME_MODE:-shared}"

case "$MODE" in
  shared)
    CHROME_AGENT_DEBUG_PORT="${CODEX_CHROME_PORT:-9222}" \
    CHROME_AGENT_PROFILE_DIR="${CHROME_AGENT_PROFILE_DIR:-${HOME}/.chrome-profiles/claude-agent}" \
    bash "${ROOT}/scripts/chrome-agent.sh"
    ;;
  isolated)
    if [[ -z "${CODEX_CHROME_PORT:-}" ]]; then
      echo "[ensure-managed-chrome] CODEX_CHROME_MODE=isolated requires CODEX_CHROME_PORT in Claude hook context; falling back to shared 9222." >&2
      CHROME_AGENT_DEBUG_PORT=9222 \
      CHROME_AGENT_PROFILE_DIR="${CHROME_AGENT_PROFILE_DIR:-${HOME}/.chrome-profiles/claude-agent}" \
      bash "${ROOT}/scripts/chrome-agent.sh"
      exit 0
    fi

    CHROME_AGENT_DEBUG_PORT="${CODEX_CHROME_PORT}" \
    CHROME_AGENT_PROFILE_DIR="${CHROME_AGENT_PROFILE_DIR:-${HOME}/.chrome-profiles/codex-chat-${CODEX_CHROME_PORT}}" \
    bash "${ROOT}/scripts/chrome-agent.sh"
    ;;
  *)
    echo "[ensure-managed-chrome] ERROR: Unsupported CODEX_CHROME_MODE=${MODE}" >&2
    exit 1
    ;;
esac

#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/modal-trr.sh <modal command> [args...]

Runs a Modal CLI command with the TRR Modal profile for this command only.
This does not change the globally active Modal profile.

Examples:
  scripts/modal-trr.sh profile current
  scripts/modal-trr.sh token info
USAGE
}

if [[ $# -eq 0 || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

MODAL_BIN="${MODAL_BIN:-$(command -v modal 2>/dev/null || echo /Users/thomashulihan/.local/bin/modal)}"
MODAL_PROFILE_NAME="${MODAL_PROFILE_NAME:-admin-56995}"
MODAL_PROFILE_LABEL="${MODAL_PROFILE_LABEL:-TRR Backend Jobs}"

if [[ ! -x "$MODAL_BIN" ]]; then
  echo "Modal CLI not found or not executable: $MODAL_BIN" >&2
  exit 1
fi

echo "Using TRR Modal profile: $MODAL_PROFILE_NAME ($MODAL_PROFILE_LABEL)"
MODAL_PROFILE="$MODAL_PROFILE_NAME" "$MODAL_BIN" "$@"

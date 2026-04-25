#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON_BIN="${PYTHON_BIN:-python3}"
DOCK_PLIST="${CHROME_DOCK_PLIST:-${HOME}/Library/Preferences/com.apple.dock.plist}"
DRY_RUN=0
RESTART_DOCK=1

usage() {
  cat <<'EOF'
Usage:
  cleanup-chrome-dock-recents.sh [--dry-run] [--no-restart-dock] [--plist PATH]

Options:
  --dry-run          Report Chrome Dock recent-app entries without writing.
  --no-restart-dock  Do not run killall Dock after removing entries.
  --plist PATH       Use a custom Dock plist path, primarily for tests.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    --no-restart-dock)
      RESTART_DOCK=0
      ;;
    --plist)
      if [[ "$#" -lt 2 ]]; then
        echo "[chrome-dock-clean] ERROR: --plist requires a path." >&2
        exit 1
      fi
      DOCK_PLIST="$2"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[chrome-dock-clean] ERROR: unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

args=("--plist" "${DOCK_PLIST}")
if [[ "$DRY_RUN" == "1" ]]; then
  args+=("--dry-run")
fi
if [[ "$RESTART_DOCK" == "1" ]]; then
  args+=("--restart-dock")
fi

"${PYTHON_BIN}" "${ROOT}/scripts/macos-dock-chrome-recents.py" "${args[@]}"

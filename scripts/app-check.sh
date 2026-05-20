#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=scripts/lib/node-baseline.sh
source "$ROOT/scripts/lib/node-baseline.sh"

REQUIRED_NODE_MAJOR="$(trr_node_required_major "$ROOT")"
if ! trr_ensure_node_baseline "$ROOT"; then
  echo "[app-check] ERROR: Node $(trr_node_version_string) does not satisfy required ${REQUIRED_NODE_MAJOR}.x baseline." >&2
  echo "[app-check] Remediation:" >&2
  echo "[app-check]   source ~/.nvm/nvm.sh && nvm use ${REQUIRED_NODE_MAJOR}" >&2
  echo "[app-check]   source ~/.nvm/nvm.sh && nvm install ${REQUIRED_NODE_MAJOR}" >&2
  exit 1
fi

run_app_lint() {
  local lint_status filter_status
  local pipe_status=()
  set +e
  (
    cd "$ROOT/TRR-APP/apps/web" &&
      trr_pnpm "$ROOT/TRR-APP" run lint
  ) 2>&1 | sed -E '/^\[BABEL\] Note: The code generator has deoptimised the styling of .* as it exceeds the max of 500KB\.$/d'
  pipe_status=("${PIPESTATUS[@]}")
  lint_status="${pipe_status[0]:-1}"
  filter_status="${pipe_status[1]:-1}"
  set -e
  if (( lint_status != 0 )); then
    return "$lint_status"
  fi
  return "$filter_status"
}

echo "[app-check] node: $(trr_node_version_string)"
echo "[app-check] TRR-APP lint..."
run_app_lint

echo "[app-check] TRR-APP typecheck..."
(cd "$ROOT/TRR-APP/apps/web" && trr_pnpm "$ROOT/TRR-APP" run typecheck)

echo "[app-check] Done."

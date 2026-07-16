#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/modal-trr.sh <read-only modal command> [args...]

Runs an allowlisted read-only Modal CLI command with the TRR identity pinned.
This does not change the globally active Modal profile.

Guarded release operations are dry-run by default:
  scripts/modal-trr.sh evidence [--execute]
  scripts/modal-trr.sh rollback --version vN [--execute]

Executing rollback additionally requires TRR_MODAL_ROLLBACK_APPROVED=1 in the
same command invocation. Dry-run output is deterministic JSON and does not
contact Modal.

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
MODAL_PROFILE_NAME="admin-56995"
MODAL_PROFILE_LABEL="${MODAL_PROFILE_LABEL:-TRR Backend Jobs}"
MODAL_WORKSPACE_NAME="admin-56995"
MODAL_ENVIRONMENT_NAME="main"
MODAL_APP_NAME="trr-backend-jobs"

emit_operation_plan() {
  local operation="$1"
  local execute="$2"
  local target_version="$3"
  shift 3
  python3 - "$operation" "$execute" "$target_version" \
    "$MODAL_PROFILE_NAME" "$MODAL_WORKSPACE_NAME" "$MODAL_ENVIRONMENT_NAME" \
    "$MODAL_APP_NAME" "$@" <<'PY'
from __future__ import annotations

import json
import sys

(
    operation,
    execute,
    target_version,
    profile,
    workspace,
    environment,
    app,
    *command,
) = sys.argv[1:]

payload: dict[str, object] = {
    "operation": operation,
    "execute": execute == "1",
    "profile": profile,
    "workspace": workspace,
    "environment": environment,
    "app": app,
    "command": command,
}
if target_version:
    payload["targetVersion"] = target_version
print(json.dumps(payload, indent=2, sort_keys=True))
PY
}

run_pinned_modal() {
  if [[ ! -x "$MODAL_BIN" ]]; then
    echo "Modal CLI not found or not executable: $MODAL_BIN" >&2
    return 1
  fi
  MODAL_PROFILE="$MODAL_PROFILE_NAME" \
  MODAL_WORKSPACE="$MODAL_WORKSPACE_NAME" \
  MODAL_ENVIRONMENT="$MODAL_ENVIRONMENT_NAME" \
  TRR_MODAL_APP_NAME="$MODAL_APP_NAME" \
  "$MODAL_BIN" "$@"
}

verify_pinned_modal_identity() {
  local profile_rows
  if ! profile_rows="$(run_pinned_modal profile list --json)"; then
    echo "modal-trr.sh could not verify the pinned Modal profile/workspace; operation blocked." >&2
    return 2
  fi
  if ! MODAL_PROFILE_ROWS="$profile_rows" python3 - \
    "$MODAL_PROFILE_NAME" "$MODAL_WORKSPACE_NAME" >/dev/null 2>&1 <<'PY'
from __future__ import annotations

import json
import os
import sys

expected_profile, expected_workspace = sys.argv[1:]
payload = json.loads(os.environ.get("MODAL_PROFILE_ROWS", "[]"))
if not isinstance(payload, list):
    raise SystemExit(1)
active = [row for row in payload if isinstance(row, dict) and row.get("active") is True]
if len(active) != 1:
    raise SystemExit(1)
row = active[0]
if row.get("name") != expected_profile or row.get("workspace") != expected_workspace:
    raise SystemExit(1)
PY
  then
    echo "modal-trr.sh expected active profile/workspace ${MODAL_PROFILE_NAME}/${MODAL_WORKSPACE_NAME}; operation blocked." >&2
    return 2
  fi
}

reject_cli_identity_overrides() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      --env | --env=* | --environment | --environment=* | \
      --profile | --profile=* | --workspace | --workspace=* | \
      -e | -e?* | -p | -p?* | -w | -w?* | -[!-]*[epw]*)
        echo "modal-trr.sh CLI identity override arguments are blocked; profile, workspace, and environment are pinned." >&2
        return 2
        ;;
    esac
  done
}

if [[ "${1:-}" == "evidence" ]]; then
  shift
  execute=0
  for arg in "$@"; do
    case "$arg" in
      --execute) execute=1 ;;
      --dry-run) execute=0 ;;
      *)
        echo "modal-trr.sh evidence only accepts --dry-run or --execute." >&2
        exit 2
        ;;
    esac
  done
  evidence_command=(app history "$MODAL_APP_NAME" --env "$MODAL_ENVIRONMENT_NAME" --json)
  if [[ "$execute" == "0" ]]; then
    emit_operation_plan evidence 0 "" "${evidence_command[@]}"
    exit 0
  fi
  verify_pinned_modal_identity || exit $?
  emit_operation_plan evidence 1 "" "${evidence_command[@]}" >&2
  run_pinned_modal "${evidence_command[@]}"
  exit $?
fi

if [[ "${1:-}" == "rollback" ]]; then
  shift
  execute=0
  target_version=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --version)
        if [[ -z "${2:-}" ]]; then
          echo "modal-trr.sh rollback --version requires an exact Modal version like v7." >&2
          exit 2
        fi
        target_version="$2"
        shift 2
        ;;
      --version=*)
        target_version="${1#--version=}"
        shift
        ;;
      --execute)
        execute=1
        shift
        ;;
      --dry-run)
        execute=0
        shift
        ;;
      *)
        echo "modal-trr.sh rollback received an unsupported argument: $1" >&2
        exit 2
        ;;
    esac
  done
  if [[ ! "$target_version" =~ ^v[1-9][0-9]*$ ]]; then
    echo "modal-trr.sh rollback requires an exact Modal version like v7; got ${target_version:-<missing>}." >&2
    exit 2
  fi
  rollback_command=(app rollback "$MODAL_APP_NAME" "$target_version" --env "$MODAL_ENVIRONMENT_NAME")
  if [[ "$execute" == "0" ]]; then
    emit_operation_plan rollback 0 "$target_version" "${rollback_command[@]}"
    exit 0
  fi
  if [[ "${TRR_MODAL_ROLLBACK_APPROVED:-}" != "1" ]]; then
    echo "modal-trr.sh rollback execution requires TRR_MODAL_ROLLBACK_APPROVED=1 from the current approved invocation." >&2
    exit 2
  fi
  verify_pinned_modal_identity || exit $?
  emit_operation_plan rollback 1 "$target_version" "${rollback_command[@]}" >&2
  run_pinned_modal "${rollback_command[@]}"
  exit $?
fi

reject_cli_identity_overrides "$@" || exit $?

if [[ ! -x "$MODAL_BIN" ]]; then
  echo "Modal CLI not found or not executable: $MODAL_BIN" >&2
  exit 1
fi

command_name="${1:-}"
subcommand_name="${2:-}"
case "${command_name}:${subcommand_name}" in
  profile:current|profile:list|token:info|secret:list|environment:list|app:list)
    ;;
  app:history|app:logs)
    if [[ "${3:-}" != "$MODAL_APP_NAME" ]]; then
      echo "modal-trr.sh is read-only and only permits app target ${MODAL_APP_NAME}." >&2
      exit 2
    fi
    ;;
  *)
    echo "modal-trr.sh is read-only; deploy, run, secret mutation, app stop, and profile mutation are blocked." >&2
    echo "Use the guarded deploy/readiness scripts for authorized Modal changes." >&2
    exit 2
    ;;
esac

echo "Using read-only TRR Modal target: profile=$MODAL_PROFILE_NAME workspace=$MODAL_WORKSPACE_NAME environment=$MODAL_ENVIRONMENT_NAME app=$MODAL_APP_NAME ($MODAL_PROFILE_LABEL)"
run_pinned_modal "$@"

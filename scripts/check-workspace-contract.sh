#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEV_SCRIPT="$ROOT/scripts/dev-workspace.sh"
PROFILE_FILE="$ROOT/profiles/default.env"
ENV_CONTRACT_FILE="$ROOT/docs/workspace/env-contract.md"
TRR_APP_ENV_FILE="$ROOT/TRR-APP/apps/web/.env.example"

extract_script_default() {
  local key="$1"
  sed -nE "s/^${key}=\"\\\$\\{${key}:-([^}]*)\\}\"/\1/p" "$DEV_SCRIPT" | head -n 1
}

extract_profile_value() {
  local key="$1"
  sed -nE "s/^${key}=(.*)$/\1/p" "$PROFILE_FILE" | head -n 1
}

extract_env_contract_default() {
  local key="$1"
  python3 - "$ENV_CONTRACT_FILE" "$key" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
key = sys.argv[2]
pattern = re.compile(rf"^\| `{re.escape(key)}` \| `([^`]*)` \|")
for line in path.read_text().splitlines():
    match = pattern.match(line)
    if match:
        print(match.group(1))
        raise SystemExit(0)
raise SystemExit(1)
PY
}

extract_env_assignment() {
  local file="$1"
  local key="$2"
  sed -nE "s/^${key}=(.*)$/\1/p" "$file" | head -n 1
}

assert_equals() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  if [[ "$actual" != "$expected" ]]; then
    echo "[workspace-contract] ERROR: ${label} expected '${expected}' but found '${actual}'." >&2
    exit 1
  fi
}

modal_script_default="$(extract_script_default "WORKSPACE_TRR_MODAL_ADMIN_OPERATION_FUNCTION")"
modal_profile_default="$(extract_profile_value "WORKSPACE_TRR_MODAL_ADMIN_OPERATION_FUNCTION")"
modal_doc_default="$(extract_env_contract_default "WORKSPACE_TRR_MODAL_ADMIN_OPERATION_FUNCTION")"
assert_equals "scripts/dev-workspace.sh admin function fallback" "run_admin_operation_v2" "$modal_script_default"
assert_equals "profiles/default.env admin function" "run_admin_operation_v2" "$modal_profile_default"
assert_equals "docs/workspace/env-contract.md admin function" "run_admin_operation_v2" "$modal_doc_default"

reload_profile_default="$(extract_profile_value "TRR_BACKEND_RELOAD")"
reload_doc_default="$(extract_env_contract_default "TRR_BACKEND_RELOAD")"
route_cache_disabled_profile_default="$(extract_profile_value "TRR_ADMIN_ROUTE_CACHE_DISABLED")"
route_cache_disabled_doc_default="$(extract_env_contract_default "TRR_ADMIN_ROUTE_CACHE_DISABLED")"
assert_equals "profiles/default.env backend reload" "1" "$reload_profile_default"
assert_equals "docs/workspace/env-contract.md backend reload" "1" "$reload_doc_default"
assert_equals "profiles/default.env admin route cache disabled" "1" "$route_cache_disabled_profile_default"
assert_equals "docs/workspace/env-contract.md admin route cache disabled" "1" "$route_cache_disabled_doc_default"

job_plane_profile_default="$(extract_profile_value "WORKSPACE_TRR_JOB_PLANE_MODE")"
job_plane_doc_default="$(extract_env_contract_default "WORKSPACE_TRR_JOB_PLANE_MODE")"
remote_enforce_profile_default="$(extract_profile_value "WORKSPACE_TRR_LONG_JOB_ENFORCE_REMOTE")"
remote_enforce_doc_default="$(extract_env_contract_default "WORKSPACE_TRR_LONG_JOB_ENFORCE_REMOTE")"
remote_executor_profile_default="$(extract_profile_value "WORKSPACE_TRR_REMOTE_EXECUTOR")"
remote_executor_doc_default="$(extract_env_contract_default "WORKSPACE_TRR_REMOTE_EXECUTOR")"
modal_enabled_profile_default="$(extract_profile_value "WORKSPACE_TRR_MODAL_ENABLED")"
modal_enabled_doc_default="$(extract_env_contract_default "WORKSPACE_TRR_MODAL_ENABLED")"
remote_workers_profile_default="$(extract_profile_value "WORKSPACE_TRR_REMOTE_WORKERS_ENABLED")"
remote_workers_doc_default="$(extract_env_contract_default "WORKSPACE_TRR_REMOTE_WORKERS_ENABLED")"
remote_social_profile_default="$(extract_profile_value "WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS")"
remote_social_doc_default="$(extract_env_contract_default "WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS")"
assert_equals "profiles/default.env job plane mode" "remote" "$job_plane_profile_default"
assert_equals "docs/workspace/env-contract.md job plane mode" "remote" "$job_plane_doc_default"
assert_equals "profiles/default.env enforce remote" "1" "$remote_enforce_profile_default"
assert_equals "docs/workspace/env-contract.md enforce remote" "1" "$remote_enforce_doc_default"
assert_equals "profiles/default.env remote executor" "modal" "$remote_executor_profile_default"
assert_equals "docs/workspace/env-contract.md remote executor" "modal" "$remote_executor_doc_default"
assert_equals "profiles/default.env modal enabled" "1" "$modal_enabled_profile_default"
assert_equals "docs/workspace/env-contract.md modal enabled" "1" "$modal_enabled_doc_default"
assert_equals "profiles/default.env remote workers enabled" "1" "$remote_workers_profile_default"
assert_equals "docs/workspace/env-contract.md remote workers enabled" "1" "$remote_workers_doc_default"
assert_equals "profiles/default.env remote social workers" "1" "$remote_social_profile_default"
assert_equals "docs/workspace/env-contract.md remote social workers" "1" "$remote_social_doc_default"

echo "[workspace-contract] OK"

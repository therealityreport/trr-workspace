#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEV_SCRIPT="$ROOT/scripts/dev-workspace.sh"
PROFILE_FILE="$ROOT/profiles/default.env"
SOCIAL_DEBUG_PROFILE_FILE="$ROOT/profiles/social-debug.env"
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
assert_equals "profiles/default.env backend reload" "0" "$reload_profile_default"
assert_equals "docs/workspace/env-contract.md backend reload" "0" "$reload_doc_default"
assert_equals "profiles/default.env admin route cache disabled" "0" "$route_cache_disabled_profile_default"
assert_equals "docs/workspace/env-contract.md admin route cache disabled" "0" "$route_cache_disabled_doc_default"

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
remote_social_dispatch_profile_default="$(extract_profile_value "WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT")"
remote_social_dispatch_doc_default="$(extract_env_contract_default "WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT")"
remote_social_posts_profile_default="$(extract_profile_value "WORKSPACE_TRR_REMOTE_SOCIAL_POSTS")"
remote_social_posts_doc_default="$(extract_env_contract_default "WORKSPACE_TRR_REMOTE_SOCIAL_POSTS")"
remote_social_comments_profile_default="$(extract_profile_value "WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS")"
remote_social_comments_doc_default="$(extract_env_contract_default "WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS")"
remote_social_media_profile_default="$(extract_profile_value "WORKSPACE_TRR_REMOTE_SOCIAL_MEDIA_MIRROR")"
remote_social_media_doc_default="$(extract_env_contract_default "WORKSPACE_TRR_REMOTE_SOCIAL_MEDIA_MIRROR")"
remote_social_comment_media_profile_default="$(extract_profile_value "WORKSPACE_TRR_REMOTE_SOCIAL_COMMENT_MEDIA_MIRROR")"
remote_social_comment_media_doc_default="$(extract_env_contract_default "WORKSPACE_TRR_REMOTE_SOCIAL_COMMENT_MEDIA_MIRROR")"
social_worker_enabled_profile_default="$(extract_profile_value "WORKSPACE_SOCIAL_WORKER_ENABLED")"
social_worker_enabled_doc_default="$(extract_env_contract_default "WORKSPACE_SOCIAL_WORKER_ENABLED")"
social_worker_force_local_profile_default="$(extract_profile_value "WORKSPACE_SOCIAL_WORKER_FORCE_LOCAL")"
social_worker_force_local_doc_default="$(extract_env_contract_default "WORKSPACE_SOCIAL_WORKER_FORCE_LOCAL")"
social_worker_posts_profile_default="$(extract_profile_value "WORKSPACE_SOCIAL_WORKER_POSTS")"
social_worker_posts_doc_default="$(extract_env_contract_default "WORKSPACE_SOCIAL_WORKER_POSTS")"
social_worker_comments_profile_default="$(extract_profile_value "WORKSPACE_SOCIAL_WORKER_COMMENTS")"
social_worker_comments_doc_default="$(extract_env_contract_default "WORKSPACE_SOCIAL_WORKER_COMMENTS")"
social_worker_media_profile_default="$(extract_profile_value "WORKSPACE_SOCIAL_WORKER_MEDIA_MIRROR")"
social_worker_media_doc_default="$(extract_env_contract_default "WORKSPACE_SOCIAL_WORKER_MEDIA_MIRROR")"
social_worker_comment_media_profile_default="$(extract_profile_value "WORKSPACE_SOCIAL_WORKER_COMMENT_MEDIA_MIRROR")"
social_worker_comment_media_doc_default="$(extract_env_contract_default "WORKSPACE_SOCIAL_WORKER_COMMENT_MEDIA_MIRROR")"
social_profile_pool_min_profile_default="$(extract_profile_value "TRR_SOCIAL_PROFILE_DB_POOL_MINCONN")"
social_profile_pool_max_profile_default="$(extract_profile_value "TRR_SOCIAL_PROFILE_DB_POOL_MAXCONN")"
db_pool_min_profile_default="$(extract_profile_value "TRR_DB_POOL_MINCONN")"
db_pool_max_profile_default="$(extract_profile_value "TRR_DB_POOL_MAXCONN")"
social_profile_pool_min_doc_default="$(extract_env_contract_default "TRR_SOCIAL_PROFILE_DB_POOL_MINCONN")"
social_profile_pool_max_doc_default="$(extract_env_contract_default "TRR_SOCIAL_PROFILE_DB_POOL_MAXCONN")"
db_pool_min_doc_default="$(extract_env_contract_default "TRR_DB_POOL_MINCONN")"
db_pool_max_doc_default="$(extract_env_contract_default "TRR_DB_POOL_MAXCONN")"
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
assert_equals "profiles/default.env remote social dispatch limit" "25" "$remote_social_dispatch_profile_default"
assert_equals "docs/workspace/env-contract.md remote social dispatch limit" "25" "$remote_social_dispatch_doc_default"
assert_equals "profiles/default.env remote social posts" "2" "$remote_social_posts_profile_default"
assert_equals "docs/workspace/env-contract.md remote social posts" "2" "$remote_social_posts_doc_default"
assert_equals "profiles/default.env remote social comments" "2" "$remote_social_comments_profile_default"
assert_equals "docs/workspace/env-contract.md remote social comments" "2" "$remote_social_comments_doc_default"
assert_equals "profiles/default.env remote social media mirror" "1" "$remote_social_media_profile_default"
assert_equals "docs/workspace/env-contract.md remote social media mirror" "1" "$remote_social_media_doc_default"
assert_equals "profiles/default.env remote social comment media mirror" "1" "$remote_social_comment_media_profile_default"
assert_equals "docs/workspace/env-contract.md remote social comment media mirror" "1" "$remote_social_comment_media_doc_default"
assert_equals "profiles/default.env local social worker enabled" "0" "$social_worker_enabled_profile_default"
assert_equals "docs/workspace/env-contract.md local social worker enabled" "0" "$social_worker_enabled_doc_default"
assert_equals "profiles/default.env local social worker force local" "0" "$social_worker_force_local_profile_default"
assert_equals "docs/workspace/env-contract.md local social worker force local" "0" "$social_worker_force_local_doc_default"
assert_equals "profiles/default.env local social worker posts" "1" "$social_worker_posts_profile_default"
assert_equals "docs/workspace/env-contract.md local social worker posts" "1" "$social_worker_posts_doc_default"
assert_equals "profiles/default.env local social worker comments" "1" "$social_worker_comments_profile_default"
assert_equals "docs/workspace/env-contract.md local social worker comments" "1" "$social_worker_comments_doc_default"
assert_equals "profiles/default.env local social worker media mirror" "0" "$social_worker_media_profile_default"
assert_equals "docs/workspace/env-contract.md local social worker media mirror" "0" "$social_worker_media_doc_default"
assert_equals "profiles/default.env local social worker comment media mirror" "0" "$social_worker_comment_media_profile_default"
assert_equals "docs/workspace/env-contract.md local social worker comment media mirror" "0" "$social_worker_comment_media_doc_default"
assert_equals "profiles/default.env social profile db pool min" "1" "$social_profile_pool_min_profile_default"
assert_equals "profiles/default.env social profile db pool max" "4" "$social_profile_pool_max_profile_default"
assert_equals "profiles/default.env db pool min" "1" "$db_pool_min_profile_default"
assert_equals "profiles/default.env db pool max" "2" "$db_pool_max_profile_default"
assert_equals "docs/workspace/env-contract.md social profile db pool min" "1" "$social_profile_pool_min_doc_default"
assert_equals "docs/workspace/env-contract.md social profile db pool max" "4" "$social_profile_pool_max_doc_default"
assert_equals "docs/workspace/env-contract.md db pool min" "1" "$db_pool_min_doc_default"
assert_equals "docs/workspace/env-contract.md db pool max" "2" "$db_pool_max_doc_default"

default_app_pool_max="$(extract_profile_value "WORKSPACE_TRR_APP_POSTGRES_POOL_MAX")"
default_app_max_ops="$(extract_profile_value "WORKSPACE_TRR_APP_POSTGRES_MAX_CONCURRENT_OPERATIONS")"
social_debug_app_pool_max="$(extract_env_assignment "$SOCIAL_DEBUG_PROFILE_FILE" "WORKSPACE_TRR_APP_POSTGRES_POOL_MAX")"
social_debug_app_max_ops="$(extract_env_assignment "$SOCIAL_DEBUG_PROFILE_FILE" "WORKSPACE_TRR_APP_POSTGRES_MAX_CONCURRENT_OPERATIONS")"
doc_app_pool_max_default="$(extract_env_contract_default "WORKSPACE_TRR_APP_POSTGRES_POOL_MAX")"
doc_app_max_ops_default="$(extract_env_contract_default "WORKSPACE_TRR_APP_POSTGRES_MAX_CONCURRENT_OPERATIONS")"
assert_equals "profiles/default.env app postgres pool max remains unset" "" "$default_app_pool_max"
assert_equals "profiles/default.env app postgres max concurrent operations remains unset" "" "$default_app_max_ops"
assert_equals "profiles/social-debug.env app postgres pool max" "2" "$social_debug_app_pool_max"
assert_equals "profiles/social-debug.env app postgres max concurrent operations" "2" "$social_debug_app_max_ops"
assert_equals "docs/workspace/env-contract.md app postgres pool max default" "" "$doc_app_pool_max_default"
assert_equals "docs/workspace/env-contract.md app postgres max concurrent operations default" "" "$doc_app_max_ops_default"

echo "[workspace-contract] OK"

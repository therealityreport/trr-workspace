#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEV_SCRIPT="$ROOT/scripts/dev-workspace.sh"
source "$ROOT/scripts/lib/node-baseline.sh"
PROFILE_FILE="$ROOT/profiles/default.env"
SOCIAL_DEBUG_PROFILE_FILE="$ROOT/profiles/social-debug.env"
LOCAL_CLOUD_PROFILE_FILE="$ROOT/profiles/local-cloud.env"
ENV_CONTRACT_FILE="$ROOT/docs/workspace/env-contract.md"
TRR_APP_WEB_DIR="$ROOT/TRR-APP/apps/web"
TRR_APP_ENV_FILE="$TRR_APP_WEB_DIR/.env.example"
TRR_APP_POSTGRES_CONTRACT_TEST="$TRR_APP_WEB_DIR/tests/postgres-connection-string-resolution.test.ts"
WORKSPACE_HYGIENE_DOC="$ROOT/docs/workspace/workspace-hygiene.md"
TEST_SKIP_INVENTORY_DOC="$ROOT/docs/workspace/test-skip-inventory.md"
WORKSPACE_HYGIENE_REPORT_SCRIPT="$ROOT/scripts/workspace/hygiene_report.sh"
WORKSPACE_HYGIENE_CLEAN_SCRIPT="$ROOT/scripts/workspace/hygiene_clean.sh"
WORKSPACE_ENV_HYGIENE_SCRIPT="$ROOT/scripts/workspace/env_hygiene.py"

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

assert_workspace_app_projection_behavior() {
  python3 - "$DEV_SCRIPT" <<'PY'
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path


dev_script = Path(sys.argv[1])
text = dev_script.read_text(encoding="utf-8")
try:
    start = text.index("workspace_positive_int_or_default() {")
    end = text.index("\nruntime_reconcile_artifact_path() {", start)
except ValueError as exc:
    print(f"[workspace-contract] ERROR: unable to extract workspace projection helpers: {exc}", file=sys.stderr)
    raise SystemExit(1)

helper_block = text[start:end]


def run_helper(helper_call: str, env_overrides: dict[str, str]) -> str:
    env = {"PATH": os.environ.get("PATH", "/usr/bin:/bin"), **env_overrides}
    result = subprocess.run(
        ["bash", "-c", f"set -euo pipefail\n{helper_block}\n{helper_call}\n"],
        env=env,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print(result.stderr, file=sys.stderr)
        raise SystemExit(result.returncode)
    return result.stdout.strip()


checks = [
    (
        "malformed inherited POSTGRES_POOL_MAX projection",
        "workspace_projected_app_postgres_pool_max",
        {"POSTGRES_POOL_MAX": "bad"},
        "",
    ),
    (
        "explicit WORKSPACE_TRR_APP_POSTGRES_POOL_MAX projection",
        "workspace_projected_app_postgres_pool_max",
        {"POSTGRES_POOL_MAX": "bad", "WORKSPACE_TRR_APP_POSTGRES_POOL_MAX": "2"},
        "2",
    ),
    (
        "default local DB holder budget",
        "workspace_effective_db_holder_budget",
        {},
        "app=1, backend=6, social_profile=4, social_control=2, social_progress=2, health=1, total=16",
    ),
]

for label, helper_call, env_overrides, expected in checks:
    actual = run_helper(helper_call, env_overrides)
    if actual != expected:
        print(
            f"[workspace-contract] ERROR: {label} expected '{expected}' but found '{actual}'.",
            file=sys.stderr,
        )
        raise SystemExit(1)
PY
}

assert_app_postgres_pool_contract() {
  if [[ ! -f "$TRR_APP_POSTGRES_CONTRACT_TEST" ]]; then
    echo "[workspace-contract] NOTE: skipping app postgres contract test; ${TRR_APP_POSTGRES_CONTRACT_TEST} is not present in this worktree." >&2
    return 0
  fi

  local required_node_major
  required_node_major="$(trr_node_required_major "$ROOT")"
  if ! trr_ensure_node_baseline "$ROOT"; then
    echo "[workspace-contract] ERROR: Node $(trr_node_version_string) does not satisfy required ${required_node_major}.x baseline." >&2
    exit 1
  fi
  trr_pnpm "$ROOT/TRR-APP" -C "$TRR_APP_WEB_DIR" exec vitest run tests/postgres-connection-string-resolution.test.ts --reporter=dot
}

assert_root_path_trackable() {
  local path="$1"
  local label="$2"
  local rel="${path#$ROOT/}"

  if [[ "$rel" == "$path" ]]; then
    echo "[workspace-contract] ERROR: ${label} is not under workspace root: ${path}" >&2
    exit 1
  fi

  if git -C "$ROOT" ls-files --error-unmatch "$rel" >/dev/null 2>&1; then
    return 0
  fi

  if git -C "$ROOT" ls-files --others --exclude-standard -- "$rel" | grep -qxF "$rel"; then
    return 0
  fi

  echo "[workspace-contract] ERROR: ${label} is hidden by git excludes or missing from trackable status: ${rel}" >&2
  exit 1
}

assert_workspace_hygiene_contract() {
  local missing=0

  for path in "$WORKSPACE_HYGIENE_DOC" "$TEST_SKIP_INVENTORY_DOC" "$WORKSPACE_HYGIENE_REPORT_SCRIPT" "$WORKSPACE_HYGIENE_CLEAN_SCRIPT" "$WORKSPACE_ENV_HYGIENE_SCRIPT"; do
    if [[ ! -f "$path" ]]; then
      echo "[workspace-contract] ERROR: missing workspace hygiene contract file: ${path}" >&2
      missing=1
    fi
  done
  if [[ "$missing" -ne 0 ]]; then
    exit 1
  fi

  bash -n "$WORKSPACE_HYGIENE_REPORT_SCRIPT"
  bash -n "$WORKSPACE_HYGIENE_CLEAN_SCRIPT"
  bash "$WORKSPACE_HYGIENE_REPORT_SCRIPT" >/dev/null
  bash "$WORKSPACE_HYGIENE_CLEAN_SCRIPT" --dry-run >/dev/null
  assert_root_path_trackable "$WORKSPACE_HYGIENE_DOC" "workspace hygiene doc"
  assert_root_path_trackable "$TEST_SKIP_INVENTORY_DOC" "test skip inventory doc"
  assert_root_path_trackable "$WORKSPACE_HYGIENE_REPORT_SCRIPT" "workspace hygiene report script"
  assert_root_path_trackable "$WORKSPACE_HYGIENE_CLEAN_SCRIPT" "workspace hygiene clean script"
  assert_root_path_trackable "$WORKSPACE_ENV_HYGIENE_SCRIPT" "workspace env hygiene script"

  if ! grep -q '^workspace-hygiene-report:' "$ROOT/Makefile"; then
    echo "[workspace-contract] ERROR: Makefile is missing workspace-hygiene-report target." >&2
    exit 1
  fi
  if ! grep -q '^workspace-hygiene-clean-dry-run:' "$ROOT/Makefile"; then
    echo "[workspace-contract] ERROR: Makefile is missing workspace-hygiene-clean-dry-run target." >&2
    exit 1
  fi
  if ! grep -q 'No files were deleted' "$WORKSPACE_HYGIENE_REPORT_SCRIPT"; then
    echo "[workspace-contract] ERROR: hygiene report must explicitly state that no files were deleted." >&2
    exit 1
  fi
  if ! grep -q 'Dry-run complete. No files were deleted.' "$WORKSPACE_HYGIENE_CLEAN_SCRIPT"; then
    echo "[workspace-contract] ERROR: hygiene clean script must explicitly remain dry-run only." >&2
    exit 1
  fi
  if grep -Eq 'rm -rf|rm -f' "$WORKSPACE_HYGIENE_CLEAN_SCRIPT"; then
    echo "[workspace-contract] ERROR: hygiene clean script must not contain deletion commands." >&2
    exit 1
  fi
  if ! git -C "$ROOT/TRR-Backend" check-ignore -q -- .locks/social-auth-refresh/instagram.json; then
    echo "[workspace-contract] ERROR: TRR-Backend/.locks/ must remain ignored runtime lock state." >&2
    exit 1
  fi
  if ! grep -q 'TRR-Backend/.locks/' "$WORKSPACE_HYGIENE_DOC"; then
    echo "[workspace-contract] ERROR: workspace hygiene doc must explain TRR-Backend/.locks/ protection." >&2
    exit 1
  fi
}

assert_env_hygiene_contract() {
  if [[ ! -f "$WORKSPACE_ENV_HYGIENE_SCRIPT" ]]; then
    echo "[workspace-contract] ERROR: missing env hygiene script: ${WORKSPACE_ENV_HYGIENE_SCRIPT}" >&2
    exit 1
  fi

  python3 "$WORKSPACE_ENV_HYGIENE_SCRIPT" --check

  if ! grep -q 'values are never printed' "$WORKSPACE_ENV_HYGIENE_SCRIPT"; then
    echo "[workspace-contract] ERROR: env hygiene script must state that values are never printed." >&2
    exit 1
  fi
  if ! grep -q 'Env File Authority Classes' "$ROOT/docs/workspace/env-contract-inventory.md"; then
    echo "[workspace-contract] ERROR: env contract inventory must document env file authority classes." >&2
    exit 1
  fi
}

assert_runtime_failure_lane_contract() {
  local debug_log_enabled_doc_default
  debug_log_enabled_doc_default="$(extract_env_contract_default "TRR_REMOTE_DEBUG_LOG_ENABLED")"
  assert_equals "docs/workspace/env-contract.md remote debug log kill switch default" "0" "$debug_log_enabled_doc_default"

  for phrase in \
    "## Operator Failure Lanes" \
    "Direct URL" \
    "Pooler URL" \
    "Health pool" \
    "Social pools" \
    "Local fallback" \
    "Auth" \
    "Modal deployment state"; do
    if ! grep -qF "$phrase" "$ENV_CONTRACT_FILE"; then
      echo "[workspace-contract] ERROR: env contract missing operator failure lane phrase: ${phrase}" >&2
      exit 1
    fi
  done
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
modal_social_job_concurrency_profile_default="$(extract_profile_value "WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT")"
modal_social_job_concurrency_doc_default="$(extract_env_contract_default "WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT")"
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
social_control_pool_min_profile_default="$(extract_profile_value "TRR_SOCIAL_CONTROL_DB_POOL_MINCONN")"
social_control_pool_max_profile_default="$(extract_profile_value "TRR_SOCIAL_CONTROL_DB_POOL_MAXCONN")"
social_progress_pool_min_profile_default="$(extract_profile_value "TRR_SOCIAL_PROGRESS_DB_POOL_MINCONN")"
social_progress_pool_max_profile_default="$(extract_profile_value "TRR_SOCIAL_PROGRESS_DB_POOL_MAXCONN")"
health_pool_min_profile_default="$(extract_profile_value "TRR_HEALTH_DB_POOL_MINCONN")"
health_pool_max_profile_default="$(extract_profile_value "TRR_HEALTH_DB_POOL_MAXCONN")"
db_pool_min_profile_default="$(extract_profile_value "TRR_DB_POOL_MINCONN")"
db_pool_max_profile_default="$(extract_profile_value "TRR_DB_POOL_MAXCONN")"
social_profile_pool_min_social_debug="$(extract_env_assignment "$SOCIAL_DEBUG_PROFILE_FILE" "TRR_SOCIAL_PROFILE_DB_POOL_MINCONN")"
social_profile_pool_max_social_debug="$(extract_env_assignment "$SOCIAL_DEBUG_PROFILE_FILE" "TRR_SOCIAL_PROFILE_DB_POOL_MAXCONN")"
social_control_pool_min_social_debug="$(extract_env_assignment "$SOCIAL_DEBUG_PROFILE_FILE" "TRR_SOCIAL_CONTROL_DB_POOL_MINCONN")"
social_control_pool_max_social_debug="$(extract_env_assignment "$SOCIAL_DEBUG_PROFILE_FILE" "TRR_SOCIAL_CONTROL_DB_POOL_MAXCONN")"
social_progress_pool_min_social_debug="$(extract_env_assignment "$SOCIAL_DEBUG_PROFILE_FILE" "TRR_SOCIAL_PROGRESS_DB_POOL_MINCONN")"
social_progress_pool_max_social_debug="$(extract_env_assignment "$SOCIAL_DEBUG_PROFILE_FILE" "TRR_SOCIAL_PROGRESS_DB_POOL_MAXCONN")"
health_pool_min_social_debug="$(extract_env_assignment "$SOCIAL_DEBUG_PROFILE_FILE" "TRR_HEALTH_DB_POOL_MINCONN")"
health_pool_max_social_debug="$(extract_env_assignment "$SOCIAL_DEBUG_PROFILE_FILE" "TRR_HEALTH_DB_POOL_MAXCONN")"
db_pool_min_social_debug="$(extract_env_assignment "$SOCIAL_DEBUG_PROFILE_FILE" "TRR_DB_POOL_MINCONN")"
db_pool_max_social_debug="$(extract_env_assignment "$SOCIAL_DEBUG_PROFILE_FILE" "TRR_DB_POOL_MAXCONN")"
social_profile_pool_min_local_cloud="$(extract_env_assignment "$LOCAL_CLOUD_PROFILE_FILE" "TRR_SOCIAL_PROFILE_DB_POOL_MINCONN")"
social_profile_pool_max_local_cloud="$(extract_env_assignment "$LOCAL_CLOUD_PROFILE_FILE" "TRR_SOCIAL_PROFILE_DB_POOL_MAXCONN")"
social_control_pool_min_local_cloud="$(extract_env_assignment "$LOCAL_CLOUD_PROFILE_FILE" "TRR_SOCIAL_CONTROL_DB_POOL_MINCONN")"
social_control_pool_max_local_cloud="$(extract_env_assignment "$LOCAL_CLOUD_PROFILE_FILE" "TRR_SOCIAL_CONTROL_DB_POOL_MAXCONN")"
social_progress_pool_min_local_cloud="$(extract_env_assignment "$LOCAL_CLOUD_PROFILE_FILE" "TRR_SOCIAL_PROGRESS_DB_POOL_MINCONN")"
social_progress_pool_max_local_cloud="$(extract_env_assignment "$LOCAL_CLOUD_PROFILE_FILE" "TRR_SOCIAL_PROGRESS_DB_POOL_MAXCONN")"
health_pool_min_local_cloud="$(extract_env_assignment "$LOCAL_CLOUD_PROFILE_FILE" "TRR_HEALTH_DB_POOL_MINCONN")"
health_pool_max_local_cloud="$(extract_env_assignment "$LOCAL_CLOUD_PROFILE_FILE" "TRR_HEALTH_DB_POOL_MAXCONN")"
db_pool_min_local_cloud="$(extract_env_assignment "$LOCAL_CLOUD_PROFILE_FILE" "TRR_DB_POOL_MINCONN")"
db_pool_max_local_cloud="$(extract_env_assignment "$LOCAL_CLOUD_PROFILE_FILE" "TRR_DB_POOL_MAXCONN")"
social_profile_pool_min_doc_default="$(extract_env_contract_default "TRR_SOCIAL_PROFILE_DB_POOL_MINCONN")"
social_profile_pool_max_doc_default="$(extract_env_contract_default "TRR_SOCIAL_PROFILE_DB_POOL_MAXCONN")"
social_control_pool_min_doc_default="$(extract_env_contract_default "TRR_SOCIAL_CONTROL_DB_POOL_MINCONN")"
social_control_pool_max_doc_default="$(extract_env_contract_default "TRR_SOCIAL_CONTROL_DB_POOL_MAXCONN")"
social_progress_pool_min_doc_default="$(extract_env_contract_default "TRR_SOCIAL_PROGRESS_DB_POOL_MINCONN")"
social_progress_pool_max_doc_default="$(extract_env_contract_default "TRR_SOCIAL_PROGRESS_DB_POOL_MAXCONN")"
health_pool_min_doc_default="$(extract_env_contract_default "TRR_HEALTH_DB_POOL_MINCONN")"
health_pool_max_doc_default="$(extract_env_contract_default "TRR_HEALTH_DB_POOL_MAXCONN")"
db_pool_min_doc_default="$(extract_env_contract_default "TRR_DB_POOL_MINCONN")"
db_pool_max_doc_default="$(extract_env_contract_default "TRR_DB_POOL_MAXCONN")"
assert_equals "profiles/default.env job plane mode" "local" "$job_plane_profile_default"
assert_equals "docs/workspace/env-contract.md job plane mode" "local" "$job_plane_doc_default"
assert_equals "profiles/default.env enforce remote" "0" "$remote_enforce_profile_default"
assert_equals "docs/workspace/env-contract.md enforce remote" "0" "$remote_enforce_doc_default"
assert_equals "profiles/default.env remote executor" "modal" "$remote_executor_profile_default"
assert_equals "docs/workspace/env-contract.md remote executor" "modal" "$remote_executor_doc_default"
assert_equals "profiles/default.env modal enabled" "0" "$modal_enabled_profile_default"
assert_equals "docs/workspace/env-contract.md modal enabled" "0" "$modal_enabled_doc_default"
assert_equals "profiles/default.env remote workers enabled" "0" "$remote_workers_profile_default"
assert_equals "docs/workspace/env-contract.md remote workers enabled" "0" "$remote_workers_doc_default"
assert_equals "profiles/default.env remote social workers" "0" "$remote_social_profile_default"
assert_equals "docs/workspace/env-contract.md remote social workers" "0" "$remote_social_doc_default"
assert_equals "profiles/default.env remote social dispatch limit" "4" "$remote_social_dispatch_profile_default"
assert_equals "docs/workspace/env-contract.md remote social dispatch limit" "4" "$remote_social_dispatch_doc_default"
assert_equals "profiles/default.env modal social job concurrency limit" "4" "$modal_social_job_concurrency_profile_default"
assert_equals "docs/workspace/env-contract.md modal social job concurrency limit" "4" "$modal_social_job_concurrency_doc_default"
assert_equals "profiles/default.env remote social posts" "1" "$remote_social_posts_profile_default"
assert_equals "docs/workspace/env-contract.md remote social posts" "1" "$remote_social_posts_doc_default"
assert_equals "profiles/default.env remote social comments" "1" "$remote_social_comments_profile_default"
assert_equals "docs/workspace/env-contract.md remote social comments" "1" "$remote_social_comments_doc_default"
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
assert_equals "profiles/default.env social control db pool min" "1" "$social_control_pool_min_profile_default"
assert_equals "profiles/default.env social control db pool max" "2" "$social_control_pool_max_profile_default"
assert_equals "profiles/default.env social progress db pool min" "1" "$social_progress_pool_min_profile_default"
assert_equals "profiles/default.env social progress db pool max" "2" "$social_progress_pool_max_profile_default"
assert_equals "profiles/default.env health db pool min" "1" "$health_pool_min_profile_default"
assert_equals "profiles/default.env health db pool max" "1" "$health_pool_max_profile_default"
assert_equals "profiles/default.env db pool min" "1" "$db_pool_min_profile_default"
assert_equals "profiles/default.env db pool max" "6" "$db_pool_max_profile_default"
assert_equals "profiles/social-debug.env social profile db pool min" "1" "$social_profile_pool_min_social_debug"
assert_equals "profiles/social-debug.env social profile db pool max" "4" "$social_profile_pool_max_social_debug"
assert_equals "profiles/social-debug.env social control db pool min" "1" "$social_control_pool_min_social_debug"
assert_equals "profiles/social-debug.env social control db pool max" "2" "$social_control_pool_max_social_debug"
assert_equals "profiles/social-debug.env social progress db pool min" "1" "$social_progress_pool_min_social_debug"
assert_equals "profiles/social-debug.env social progress db pool max" "2" "$social_progress_pool_max_social_debug"
assert_equals "profiles/social-debug.env health db pool min" "1" "$health_pool_min_social_debug"
assert_equals "profiles/social-debug.env health db pool max" "1" "$health_pool_max_social_debug"
assert_equals "profiles/social-debug.env db pool min" "1" "$db_pool_min_social_debug"
assert_equals "profiles/social-debug.env db pool max" "4" "$db_pool_max_social_debug"
assert_equals "profiles/local-cloud.env social profile db pool min" "1" "$social_profile_pool_min_local_cloud"
assert_equals "profiles/local-cloud.env social profile db pool max" "2" "$social_profile_pool_max_local_cloud"
assert_equals "profiles/local-cloud.env social control db pool min" "1" "$social_control_pool_min_local_cloud"
assert_equals "profiles/local-cloud.env social control db pool max" "2" "$social_control_pool_max_local_cloud"
assert_equals "profiles/local-cloud.env social progress db pool min" "1" "$social_progress_pool_min_local_cloud"
assert_equals "profiles/local-cloud.env social progress db pool max" "1" "$social_progress_pool_max_local_cloud"
assert_equals "profiles/local-cloud.env health db pool min" "1" "$health_pool_min_local_cloud"
assert_equals "profiles/local-cloud.env health db pool max" "1" "$health_pool_max_local_cloud"
assert_equals "profiles/local-cloud.env db pool min" "1" "$db_pool_min_local_cloud"
assert_equals "profiles/local-cloud.env db pool max" "3" "$db_pool_max_local_cloud"
assert_equals "docs/workspace/env-contract.md social profile db pool min" "1" "$social_profile_pool_min_doc_default"
assert_equals "docs/workspace/env-contract.md social profile db pool max" "4" "$social_profile_pool_max_doc_default"
assert_equals "docs/workspace/env-contract.md social control db pool min" "1" "$social_control_pool_min_doc_default"
assert_equals "docs/workspace/env-contract.md social control db pool max" "2" "$social_control_pool_max_doc_default"
assert_equals "docs/workspace/env-contract.md social progress db pool min" "1" "$social_progress_pool_min_doc_default"
assert_equals "docs/workspace/env-contract.md social progress db pool max" "2" "$social_progress_pool_max_doc_default"
assert_equals "docs/workspace/env-contract.md health db pool min" "1" "$health_pool_min_doc_default"
assert_equals "docs/workspace/env-contract.md health db pool max" "1" "$health_pool_max_doc_default"
assert_equals "docs/workspace/env-contract.md db pool min" "1" "$db_pool_min_doc_default"
assert_equals "docs/workspace/env-contract.md db pool max" "6" "$db_pool_max_doc_default"

default_app_pool_max="$(extract_profile_value "WORKSPACE_TRR_APP_POSTGRES_POOL_MAX")"
default_app_max_ops="$(extract_profile_value "WORKSPACE_TRR_APP_POSTGRES_MAX_CONCURRENT_OPERATIONS")"
social_debug_app_pool_max="$(extract_env_assignment "$SOCIAL_DEBUG_PROFILE_FILE" "WORKSPACE_TRR_APP_POSTGRES_POOL_MAX")"
social_debug_app_max_ops="$(extract_env_assignment "$SOCIAL_DEBUG_PROFILE_FILE" "WORKSPACE_TRR_APP_POSTGRES_MAX_CONCURRENT_OPERATIONS")"
doc_app_pool_max_default="$(extract_env_contract_default "WORKSPACE_TRR_APP_POSTGRES_POOL_MAX")"
doc_app_max_ops_default="$(extract_env_contract_default "WORKSPACE_TRR_APP_POSTGRES_MAX_CONCURRENT_OPERATIONS")"
assert_equals "profiles/default.env app postgres pool max" "1" "$default_app_pool_max"
assert_equals "profiles/default.env app postgres max concurrent operations" "1" "$default_app_max_ops"
assert_equals "profiles/social-debug.env app postgres pool max" "1" "$social_debug_app_pool_max"
assert_equals "profiles/social-debug.env app postgres max concurrent operations" "1" "$social_debug_app_max_ops"
assert_equals "docs/workspace/env-contract.md app postgres pool max default" "1" "$doc_app_pool_max_default"
assert_equals "docs/workspace/env-contract.md app postgres max concurrent operations default" "1" "$doc_app_max_ops_default"
if [[ -f "$TRR_APP_ENV_FILE" ]]; then
  app_env_pool_max="$(extract_env_assignment "$TRR_APP_ENV_FILE" "POSTGRES_POOL_MAX")"
  app_env_max_ops="$(extract_env_assignment "$TRR_APP_ENV_FILE" "POSTGRES_MAX_CONCURRENT_OPERATIONS")"
  assert_equals "TRR-APP/apps/web/.env.example postgres pool max baseline" "1" "$app_env_pool_max"
  assert_equals "TRR-APP/apps/web/.env.example postgres max concurrent operations baseline" "1" "$app_env_max_ops"
else
  echo "[workspace-contract] NOTE: skipping app .env.example assertions; ${TRR_APP_ENV_FILE} is not present in this worktree." >&2
fi
assert_workspace_app_projection_behavior
assert_app_postgres_pool_contract
assert_workspace_hygiene_contract
assert_env_hygiene_contract
assert_runtime_failure_lane_contract

echo "[workspace-contract] OK"

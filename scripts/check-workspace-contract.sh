#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEV_SCRIPT="$ROOT/scripts/dev-workspace.sh"
PROFILE_FILE="$ROOT/profiles/default.env"
ENV_CONTRACT_FILE="$ROOT/docs/workspace/env-contract.md"
TRR_APP_ENV_FILE="$ROOT/TRR-APP/apps/web/.env.example"
SCREENALYTICS_ENV_FILE="$ROOT/screenalytics/.env.example"

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
assert_equals "profiles/default.env backend reload" "0" "$reload_profile_default"
assert_equals "docs/workspace/env-contract.md backend reload" "0" "$reload_doc_default"

screenalytics_port_default="$(extract_script_default "SCREENALYTICS_API_PORT")"
screenalytics_port_doc="$(extract_env_contract_default "SCREENALYTICS_API_PORT")"
trr_app_screenalytics_url="$(extract_env_assignment "$TRR_APP_ENV_FILE" "SCREENALYTICS_API_URL")"
screenalytics_env_url="$(extract_env_assignment "$SCREENALYTICS_ENV_FILE" "SCREENALYTICS_API_URL")"
assert_equals "scripts/dev-workspace.sh screenalytics API port" "8001" "$screenalytics_port_default"
assert_equals "docs/workspace/env-contract.md screenalytics API port" "8001" "$screenalytics_port_doc"
assert_equals "TRR-APP/apps/web/.env.example screenalytics API URL" "http://127.0.0.1:8001" "$trr_app_screenalytics_url"
assert_equals "screenalytics/.env.example screenalytics API URL" "http://127.0.0.1:8001" "$screenalytics_env_url"

echo "[workspace-contract] OK"

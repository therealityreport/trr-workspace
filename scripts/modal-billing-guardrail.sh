#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="${TRR_MODAL_BACKEND_DIR:-$ROOT/TRR-Backend}"
BACKEND_ENV_EXAMPLE="$BACKEND_DIR/.env.example"
SOURCE_ENV="${TRR_MODAL_SOURCE_ENV:-$BACKEND_DIR/.env}"
MODAL_JOBS="$BACKEND_DIR/trr_backend/modal_jobs.py"

allow_always_on="${WORKSPACE_ALLOW_MODAL_ALWAYS_ON_BILLING:-0}"
failures=()

is_truthy() {
  case "$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')" in
    1|true|yes|on) return 0 ;;
    *) return 1 ;;
  esac
}

is_positive_int() {
  [[ "${1:-}" =~ ^[1-9][0-9]*$ ]]
}

require_file_contains() {
  local file="$1"
  local pattern="$2"
  local label="$3"

  if [[ ! -f "$file" ]]; then
    failures+=("$label does not exist at $file")
    return
  fi

  if ! grep -Fq "$pattern" "$file"; then
    failures+=("$label is missing expected safe default: $pattern")
  fi
}

env_file_value() {
  local key="$1"
  if [[ ! -f "$SOURCE_ENV" ]]; then
    return 0
  fi
  python3 - "$SOURCE_ENV" "$key" <<'PY'
from __future__ import annotations

import shlex
import sys
from pathlib import Path

path = Path(sys.argv[1])
target = sys.argv[2]

for raw_line in path.read_text(encoding="utf-8").splitlines():
    line = raw_line.strip()
    if not line or line.startswith("#") or "=" not in line:
        continue
    key, value = line.split("=", 1)
    key = key.strip()
    if key.startswith("export "):
        key = key[len("export ") :].strip()
    if key != target:
        continue
    try:
        print(shlex.split(value, comments=True, posix=True)[0] if value.strip() else "")
    except Exception:
        print(value.strip().strip("'\""))
    break
PY
}

check_always_on_value() {
  local key="$1"
  local value="$2"
  local source_label="$3"

  case "$key" in
    TRR_MODAL_ALWAYS_ON_SCHEDULES_ENABLED)
      if is_truthy "$value"; then
        failures+=("$key=$value from $source_label would re-enable deployed Modal cron schedules")
      fi
      ;;
    TRR_MODAL_API_MIN_CONTAINERS)
      if is_positive_int "$value"; then
        failures+=("$key=$value from $source_label would keep Modal API containers warm")
      fi
      ;;
    TRR_MODAL_ADMIN_KEEP_WARM)
      if is_positive_int "$value"; then
        failures+=("$key=$value from $source_label would keep Modal admin containers warm")
      fi
      ;;
  esac
}

effective_env_value() {
  local key="$1"
  local default_value="$2"
  local process_value="${!key-}"
  local source_value=""

  source_value="$(env_file_value "$key")"
  if [[ -n "$process_value" ]]; then
    printf '%s' "$process_value"
  elif [[ -n "$source_value" ]]; then
    printf '%s' "$source_value"
  else
    printf '%s' "$default_value"
  fi
}

check_exactly_one_modal_owner() {
  local always_on_value="$1"
  local runtime_scheduler_value="$2"
  local owner_required_value="$3"
  local active_owners=()

  if ! is_truthy "$owner_required_value"; then
    failures+=("TRR_MODAL_MAINTENANCE_OWNER_REQUIRED=$owner_required_value would disable Modal maintenance owner enforcement")
    return
  fi

  if is_truthy "$always_on_value"; then
    active_owners+=("TRR_MODAL_ALWAYS_ON_SCHEDULES_ENABLED")
  fi
  if is_truthy "$runtime_scheduler_value"; then
    active_owners+=("TRR_MODAL_RUNTIME_SCHEDULER_ENABLED")
  fi

  if [[ "${#active_owners[@]}" -ne 1 ]]; then
    failures+=(
      "Modal maintenance requires exactly one owner: "\
"TRR_MODAL_ALWAYS_ON_SCHEDULES_ENABLED=$always_on_value, "\
"TRR_MODAL_RUNTIME_SCHEDULER_ENABLED=$runtime_scheduler_value, "\
"TRR_MODAL_MAINTENANCE_OWNER_REQUIRED=$owner_required_value"
    )
  fi
}

if is_truthy "$allow_always_on"; then
  echo "[modal-billing] WARNING: WORKSPACE_ALLOW_MODAL_ALWAYS_ON_BILLING is set; runtime always-on settings are allowed for this run."
else
  check_always_on_value "TRR_MODAL_ALWAYS_ON_SCHEDULES_ENABLED" "${TRR_MODAL_ALWAYS_ON_SCHEDULES_ENABLED:-0}" "process environment"
  check_always_on_value "TRR_MODAL_API_MIN_CONTAINERS" "${TRR_MODAL_API_MIN_CONTAINERS:-0}" "process environment"
  check_always_on_value "TRR_MODAL_ADMIN_KEEP_WARM" "${TRR_MODAL_ADMIN_KEEP_WARM:-0}" "process environment"

  check_always_on_value "TRR_MODAL_ALWAYS_ON_SCHEDULES_ENABLED" "$(env_file_value "TRR_MODAL_ALWAYS_ON_SCHEDULES_ENABLED")" "$SOURCE_ENV"
  check_always_on_value "TRR_MODAL_API_MIN_CONTAINERS" "$(env_file_value "TRR_MODAL_API_MIN_CONTAINERS")" "$SOURCE_ENV"
  check_always_on_value "TRR_MODAL_ADMIN_KEEP_WARM" "$(env_file_value "TRR_MODAL_ADMIN_KEEP_WARM")" "$SOURCE_ENV"
fi

check_exactly_one_modal_owner \
  "$(effective_env_value "TRR_MODAL_ALWAYS_ON_SCHEDULES_ENABLED" "0")" \
  "$(effective_env_value "TRR_MODAL_RUNTIME_SCHEDULER_ENABLED" "1")" \
  "$(effective_env_value "TRR_MODAL_MAINTENANCE_OWNER_REQUIRED" "1")"

require_file_contains "$BACKEND_ENV_EXAMPLE" "TRR_MODAL_ALWAYS_ON_SCHEDULES_ENABLED=0" "TRR-Backend/.env.example"
require_file_contains "$BACKEND_ENV_EXAMPLE" "TRR_MODAL_RUNTIME_SCHEDULER_ENABLED=1" "TRR-Backend/.env.example"
require_file_contains "$BACKEND_ENV_EXAMPLE" "TRR_MODAL_MAINTENANCE_OWNER_REQUIRED=1" "TRR-Backend/.env.example"
require_file_contains "$BACKEND_ENV_EXAMPLE" "TRR_MODAL_API_MIN_CONTAINERS=0" "TRR-Backend/.env.example"
require_file_contains "$BACKEND_ENV_EXAMPLE" "TRR_MODAL_ADMIN_KEEP_WARM=0" "TRR-Backend/.env.example"
require_file_contains "$MODAL_JOBS" 'os.getenv("TRR_MODAL_API_MIN_CONTAINERS", "0")' "trr_backend/modal_jobs.py"
require_file_contains "$MODAL_JOBS" 'os.getenv("TRR_MODAL_ADMIN_KEEP_WARM", "0")' "trr_backend/modal_jobs.py"
require_file_contains "$MODAL_JOBS" '_env_flag("TRR_MODAL_ALWAYS_ON_SCHEDULES_ENABLED", default=False)' "trr_backend/modal_jobs.py"
require_file_contains "$MODAL_JOBS" '_env_flag("TRR_MODAL_RUNTIME_SCHEDULER_ENABLED", default=False)' "trr_backend/modal_jobs.py"
require_file_contains "$MODAL_JOBS" '_env_flag("TRR_MODAL_MAINTENANCE_OWNER_REQUIRED", default=False)' "trr_backend/modal_jobs.py"

if [[ "${#failures[@]}" -gt 0 ]]; then
  echo "[modal-billing] ERROR: Modal always-on billing guardrail failed." >&2
  for failure in "${failures[@]}"; do
    echo "[modal-billing] - $failure" >&2
  done
  echo "[modal-billing] Set WORKSPACE_ALLOW_MODAL_ALWAYS_ON_BILLING=1 only for an intentional, time-boxed always-on run." >&2
  exit 1
fi

echo "[modal-billing] Guardrail OK: deployed schedules and warm containers are off by default."

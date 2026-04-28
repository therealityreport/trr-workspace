#!/usr/bin/env bash

trr_read_env_file_value() {
  local file="$1"
  local key="$2"
  local value=""

  [[ -f "$file" ]] || return 1

  value="$(
    awk -v key="$key" '
    /^[[:space:]]*#/ { next }
    {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      if (line !~ ("^" key "=")) next
      sub("^" key "=", "", line)
      print line
      found = 1
      exit
    }
    END {
      if (!found) exit 1
    }
  ' "$file"
  )" || return 1

  if [[ "${value:0:1}" == '"' && "${value: -1}" == '"' ]]; then
    value="${value:1:${#value}-2}"
  elif [[ "${value:0:1}" == "'" && "${value: -1}" == "'" ]]; then
    value="${value:1:${#value}-2}"
  fi

  printf '%s\n' "$value"
}

trr_export_env_value_from_file_if_unset() {
  local env_file="$1"
  local key="$2"
  local value=""

  [[ -n "${!key:-}" ]] && return 0

  if value="$(trr_read_env_file_value "$env_file" "$key" 2>/dev/null)"; then
    export "${key}=${value}"
  fi
}

trr_runtime_db_env_present() {
  local env_file="$1"
  [[ -n "${TRR_DB_DIRECT_URL:-}" ]] && return 0
  [[ -n "${TRR_DB_SESSION_URL:-}" ]] && return 0
  [[ -n "${TRR_DB_URL:-}" ]] && return 0
  [[ -n "${TRR_DB_FALLBACK_URL:-}" ]] && return 0

  trr_read_env_file_value "$env_file" "TRR_DB_DIRECT_URL" >/dev/null 2>&1 && return 0
  trr_read_env_file_value "$env_file" "TRR_DB_SESSION_URL" >/dev/null 2>&1 && return 0
  trr_read_env_file_value "$env_file" "TRR_DB_URL" >/dev/null 2>&1 && return 0
  trr_read_env_file_value "$env_file" "TRR_DB_FALLBACK_URL" >/dev/null 2>&1 && return 0
  return 1
}

trr_legacy_runtime_db_env_present() {
  local env_file="$1"
  [[ -n "${SUPABASE_DB_URL:-}" ]] && return 0
  [[ -n "${DATABASE_URL:-}" ]] && return 0

  trr_read_env_file_value "$env_file" "SUPABASE_DB_URL" >/dev/null 2>&1 && return 0
  trr_read_env_file_value "$env_file" "DATABASE_URL" >/dev/null 2>&1 && return 0
  return 1
}

trr_export_runtime_db_env_from_file() {
  local env_file="$1"

  trr_export_env_value_from_file_if_unset "$env_file" "TRR_DB_DIRECT_URL"
  trr_export_env_value_from_file_if_unset "$env_file" "TRR_DB_SESSION_URL"
  trr_export_env_value_from_file_if_unset "$env_file" "TRR_DB_URL"
  trr_export_env_value_from_file_if_unset "$env_file" "TRR_DB_TRANSACTION_URL"
  trr_export_env_value_from_file_if_unset "$env_file" "TRR_DB_RUNTIME_LANE"
  trr_export_env_value_from_file_if_unset "$env_file" "TRR_DB_TRANSACTION_FLIGHT_TEST"
  trr_export_env_value_from_file_if_unset "$env_file" "TRR_DB_FALLBACK_URL"
}

trr_runtime_db_expected_project_ref() {
  printf '%s\n' "${TRR_SUPABASE_PROJECT_REF:-vwxfvzutyufrkhfgoeaa}"
}

trr_runtime_db_url_lane() {
  local url="$1"
  python3 - "$url" <<'PY'
import sys
from urllib.parse import urlsplit

try:
    parsed = urlsplit(sys.argv[1])
except Exception:
    print("unknown")
    raise SystemExit(0)

host = (parsed.hostname or "").lower()
try:
    port = parsed.port
except ValueError:
    port = None

if host in {"localhost", "127.0.0.1", "::1"}:
    print("local")
elif host.endswith("pooler.supabase.com") and port == 5432:
    print("session")
elif host.endswith("pooler.supabase.com") and port == 6543:
    print("transaction")
elif host.endswith(".supabase.co"):
    print("direct")
elif host:
    print("other")
else:
    print("unknown")
PY
}

trr_runtime_db_derive_direct_url() {
  local url="$1"
  local expected_ref
  expected_ref="$(trr_runtime_db_expected_project_ref)"
  python3 - "$url" "$expected_ref" <<'PY'
import sys
from urllib.parse import urlsplit, urlunsplit

url = sys.argv[1]
expected_ref = sys.argv[2]
parsed = urlsplit(url)
host = (parsed.hostname or "").strip().lower()
if not host.endswith("pooler.supabase.com"):
    raise SystemExit(1)
username = parsed.username or ""
if not username.startswith("postgres."):
    raise SystemExit(1)
project_ref = username.split(".", 1)[1].strip()
if not project_ref or project_ref != expected_ref:
    raise SystemExit(1)
password = parsed.password or ""
auth = "postgres"
if password:
    auth = f"{auth}:{password}"
print(urlunsplit((parsed.scheme, f"{auth}@db.{project_ref}.supabase.co:5432", parsed.path, parsed.query, parsed.fragment)))
PY
}

trr_runtime_db_candidate_value() {
  local root="$1"
  local key="$2"
  local app_env="$root/TRR-APP/apps/web/.env.local"
  local backend_env="$root/TRR-Backend/.env"

  if [[ -n "${!key:-}" ]]; then
    printf '%s\n' "${!key}"
    return 0
  fi

  if trr_read_env_file_value "$app_env" "$key" >/dev/null 2>&1; then
    trr_read_env_file_value "$app_env" "$key"
    return 0
  fi

  if trr_read_env_file_value "$backend_env" "$key" >/dev/null 2>&1; then
    trr_read_env_file_value "$backend_env" "$key"
    return 0
  fi

  return 1
}

trr_runtime_db_resolve_session_url() {
  local root="$1"
  local value=""

  if value="$(trr_runtime_db_candidate_value "$root" "TRR_DB_SESSION_URL" 2>/dev/null)"; then
    printf '%s\n' "$value"
    return 0
  fi

  if value="$(trr_runtime_db_candidate_value "$root" "TRR_DB_URL" 2>/dev/null)"; then
    printf '%s\n' "$value"
    return 0
  fi

  if value="$(trr_runtime_db_candidate_value "$root" "TRR_DB_FALLBACK_URL" 2>/dev/null)"; then
    printf '%s\n' "$value"
    return 0
  fi

  return 1
}

trr_runtime_db_resolve_local_app_url() {
  local root="$1"
  local mode="${2:-local}"
  local value=""
  local derived=""

  if [[ "$mode" == "local" || "$mode" == "hybrid" ]]; then
    if value="$(trr_runtime_db_candidate_value "$root" "TRR_DB_DIRECT_URL" 2>/dev/null)"; then
      printf '%s\n' "$value"
      return 0
    fi

    if value="$(trr_runtime_db_resolve_session_url "$root" 2>/dev/null)" && derived="$(trr_runtime_db_derive_direct_url "$value" 2>/dev/null)"; then
      printf '%s\n' "$derived"
      return 0
    fi

    if [[ "${WORKSPACE_TRR_DB_LANE:-}" == "session" ]]; then
      trr_runtime_db_resolve_session_url "$root"
      return $?
    fi

    return 1
  fi

  if value="$(trr_runtime_db_resolve_session_url "$root" 2>/dev/null)"; then
    printf '%s\n' "$value"
    return 0
  fi

  return 1
}

trr_runtime_db_resolve_remote_worker_url() {
  local root="$1"
  local mode="${2:-local}"

  case "$mode" in
    cloud|hybrid)
      trr_runtime_db_resolve_session_url "$root"
      return $?
      ;;
    *)
      return 1
      ;;
  esac
}

trr_runtime_db_resolve_local_app_source() {
  local root="$1"
  local mode="${2:-local}"
  local value=""

  if [[ "$mode" == "local" || "$mode" == "hybrid" ]]; then
    if trr_runtime_db_candidate_value "$root" "TRR_DB_DIRECT_URL" >/dev/null 2>&1; then
      echo "TRR_DB_DIRECT_URL"
      return 0
    fi

    if value="$(trr_runtime_db_resolve_session_url "$root" 2>/dev/null)" && trr_runtime_db_derive_direct_url "$value" >/dev/null 2>&1; then
      echo "derived_direct_uri"
      return 0
    fi

    if [[ "${WORKSPACE_TRR_DB_LANE:-}" == "session" ]]; then
      trr_runtime_db_resolve_session_source "$root"
      return $?
    fi

    return 1
  fi

  trr_runtime_db_resolve_session_source "$root"
}

trr_runtime_db_resolve_session_source() {
  local root="$1"

  if trr_runtime_db_candidate_value "$root" "TRR_DB_SESSION_URL" >/dev/null 2>&1; then
    echo "TRR_DB_SESSION_URL"
    return 0
  fi

  if trr_runtime_db_candidate_value "$root" "TRR_DB_URL" >/dev/null 2>&1; then
    echo "TRR_DB_URL"
    return 0
  fi

  if trr_runtime_db_candidate_value "$root" "TRR_DB_FALLBACK_URL" >/dev/null 2>&1; then
    echo "TRR_DB_FALLBACK_URL"
    return 0
  fi

  return 1
}

trr_runtime_db_resolve_remote_worker_source() {
  local root="$1"
  local mode="${2:-local}"

  case "$mode" in
    cloud|hybrid)
      trr_runtime_db_resolve_session_source "$root"
      return $?
      ;;
    *)
      return 1
      ;;
  esac
}

trr_runtime_db_require_local_app_url() {
  local root="$1"
  local prefix="${2:-preflight}"
  local mode="${3:-local}"
  local app_env="$root/TRR-APP/apps/web/.env.local"

  if trr_runtime_db_resolve_local_app_url "$root" "$mode" >/dev/null 2>&1; then
    return 0
  fi

  if [[ "$mode" == "local" || "$mode" == "hybrid" ]]; then
    echo "[${prefix}] ERROR: local direct DB config is missing or cannot be fully validated." >&2
    echo "[${prefix}] Export TRR_DB_DIRECT_URL with host db.$(trr_runtime_db_expected_project_ref).supabase.co before running make dev." >&2
    echo "[${prefix}] Resolver order: TRR_DB_DIRECT_URL, validated derived direct URI, fail closed, explicit WORKSPACE_TRR_DB_LANE=session escape hatch." >&2
  else
    echo "[${prefix}] ERROR: runtime DB config is missing the canonical session DB URL." >&2
    echo "[${prefix}] Add TRR_DB_SESSION_URL or TRR_DB_URL to ${app_env} (or export one) before running make dev-cloud." >&2
  fi

  if trr_legacy_runtime_db_env_present "$app_env"; then
    echo "[${prefix}] Legacy-only app DB envs found in ${app_env}. SUPABASE_DB_URL and DATABASE_URL no longer satisfy TRR-APP runtime startup." >&2
  fi

  return 1
}

trr_runtime_db_require_remote_worker_url() {
  local root="$1"
  local prefix="${2:-preflight}"
  local mode="${3:-local}"

  if trr_runtime_db_resolve_remote_worker_url "$root" "$mode" >/dev/null 2>&1; then
    return 0
  fi

  echo "[${prefix}] ERROR: remote worker DB config is missing the session/pooler lane." >&2
  echo "[${prefix}] Add TRR_DB_SESSION_URL or TRR_DB_URL for make dev-cloud/dev-hybrid; TRR_DB_DIRECT_URL is local-only." >&2
  return 1
}

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
  [[ -n "${TRR_DB_URL:-}" ]] && return 0
  [[ -n "${TRR_DB_FALLBACK_URL:-}" ]] && return 0

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

  trr_export_env_value_from_file_if_unset "$env_file" "TRR_DB_URL"
  trr_export_env_value_from_file_if_unset "$env_file" "TRR_DB_FALLBACK_URL"
}

trr_runtime_db_resolve_local_app_url() {
  local root="$1"
  local app_env="$root/TRR-APP/apps/web/.env.local"

  if [[ -n "${TRR_DB_URL:-}" ]]; then
    printf '%s\n' "$TRR_DB_URL"
    return 0
  fi

  if trr_read_env_file_value "$app_env" "TRR_DB_URL" >/dev/null 2>&1; then
    trr_read_env_file_value "$app_env" "TRR_DB_URL"
    return 0
  fi

  return 1
}

trr_runtime_db_require_local_app_url() {
  local root="$1"
  local prefix="${2:-preflight}"
  local app_env="$root/TRR-APP/apps/web/.env.local"

  if trr_runtime_db_resolve_local_app_url "$root" >/dev/null 2>&1; then
    return 0
  fi

  echo "[${prefix}] ERROR: TRR-APP runtime DB config is missing the canonical TRR_DB_URL." >&2
  echo "[${prefix}] Add TRR_DB_URL to ${app_env} or export TRR_DB_URL before running make dev." >&2
  echo "[${prefix}] Optional explicit fallback: TRR_DB_FALLBACK_URL." >&2

  if trr_legacy_runtime_db_env_present "$app_env"; then
    echo "[${prefix}] Legacy-only app DB envs found in ${app_env}. SUPABASE_DB_URL and DATABASE_URL no longer satisfy TRR-APP runtime startup." >&2
  fi

  return 1
}

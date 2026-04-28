#!/usr/bin/env bash
# Preflight env-drift detector.
#
# Inspects TRR-APP/apps/web/.env.local and TRR-Backend/.env for known
# regression markers (legacy aliases, over-cap pool sizes, application_name
# violations) and emits one finding per drift item. Findings are warnings by
# default and hard failures under WORKSPACE_PREFLIGHT_STRICT=1.
#
# This helper reads only env var NAMES and presence/numeric tokens. It never
# echoes values whose contents could leak secrets.

# Read the value of `key` from `file` (.env style, KEY=VALUE).
# Quietly returns empty string when file or key is absent.
preflight_env_drift_read_value() {
  local file="$1"
  local key="$2"
  [[ -f "$file" ]] || { printf ''; return 0; }
  # shellcheck disable=SC2016
  local raw
  raw="$(sed -nE "s/^${key}=(.*)$/\1/p" "$file" | head -n 1)"
  raw="${raw%\"}"
  raw="${raw#\"}"
  raw="${raw%\'}"
  raw="${raw#\'}"
  printf '%s' "$raw"
}

# Returns 0 when `key` is present (any non-empty assignment) in `file`.
preflight_env_drift_key_present() {
  local file="$1"
  local key="$2"
  [[ -f "$file" ]] || return 1
  grep -qE "^${key}=" "$file"
}

# Emit a finding. Args: kind ("WARN"|"FAIL"), surface, item description.
preflight_env_drift_emit() {
  local kind="$1"
  local surface="$2"
  local item="$3"
  printf '[preflight] %s env-drift: %s (%s)\n' "$kind" "$item" "$surface"
}

# Run the env-drift detector. Returns 0 in default mode (warn-only) and
# returns the count of findings (clamped to 1) under strict mode so the
# caller propagates a non-zero exit code.
#
# Args:
#   $1  workspace ROOT path
#   $2  strict mode flag ("1" -> hard fail; anything else -> warn)
preflight_env_drift_check() {
  local root="$1"
  local strict_mode="${2:-0}"

  local app_env="${root}/TRR-APP/apps/web/.env.local"
  local backend_env="${root}/TRR-Backend/.env"

  local app_present=0 backend_present=0
  [[ -f "$app_env" ]] && app_present=1
  [[ -f "$backend_env" ]] && backend_present=1

  if [[ "$app_present" == "0" && "$backend_present" == "0" ]]; then
    echo "[preflight] env-drift: skipped (TRR-APP/.env.local and TRR-Backend/.env absent)"
    return 0
  fi

  local kind="WARN"
  [[ "$strict_mode" == "1" ]] && kind="FAIL"

  local findings=0

  # ---- TRR-APP findings ---------------------------------------------------
  if [[ "$app_present" == "1" ]]; then
    if preflight_env_drift_key_present "$app_env" "DATABASE_URL"; then
      preflight_env_drift_emit "$kind" "TRR-APP/.env.local" "legacy alias DATABASE_URL present"
      findings=$((findings + 1))
    fi
    if preflight_env_drift_key_present "$app_env" "SUPABASE_DB_URL"; then
      preflight_env_drift_emit "$kind" "TRR-APP/.env.local" "legacy alias SUPABASE_DB_URL present"
      findings=$((findings + 1))
    fi

    local app_pool_max app_max_ops app_app_name
    app_pool_max="$(preflight_env_drift_read_value "$app_env" "POSTGRES_POOL_MAX")"
    app_max_ops="$(preflight_env_drift_read_value "$app_env" "POSTGRES_MAX_CONCURRENT_OPERATIONS")"
    app_app_name="$(preflight_env_drift_read_value "$app_env" "POSTGRES_APPLICATION_NAME")"

    # Pool max policy: production allows up to 2; local default allows up to 1.
    local app_pool_cap=1
    if [[ "${VERCEL_ENV:-}" == "production" ]]; then
      app_pool_cap=2
    fi
    if [[ -n "$app_pool_max" && "$app_pool_max" =~ ^[0-9]+$ ]]; then
      if (( app_pool_max > app_pool_cap )); then
        preflight_env_drift_emit "$kind" "TRR-APP/.env.local" \
          "POSTGRES_POOL_MAX=${app_pool_max} exceeds cap ${app_pool_cap}"
        findings=$((findings + 1))
      fi
    fi

    # Concurrency cap is local-only (cap = 1).
    if [[ "${VERCEL_ENV:-}" != "production" ]]; then
      if [[ -n "$app_max_ops" && "$app_max_ops" =~ ^[0-9]+$ ]]; then
        if (( app_max_ops > 1 )); then
          preflight_env_drift_emit "$kind" "TRR-APP/.env.local" \
            "POSTGRES_MAX_CONCURRENT_OPERATIONS=${app_max_ops} exceeds cap 1 (local)"
          findings=$((findings + 1))
        fi
      fi
    fi

    # Application-name prefix policy.
    if [[ -n "$app_app_name" && ! "$app_app_name" =~ ^trr-app: ]]; then
      preflight_env_drift_emit "$kind" "TRR-APP/.env.local" \
        "POSTGRES_APPLICATION_NAME does not start with 'trr-app:' prefix"
      findings=$((findings + 1))
    fi
  fi

  # ---- TRR-Backend findings ----------------------------------------------
  if [[ "$backend_present" == "1" ]]; then
    if preflight_env_drift_key_present "$backend_env" "SUPABASE_DB_URL"; then
      preflight_env_drift_emit "$kind" "TRR-Backend/.env" "legacy alias SUPABASE_DB_URL present"
      findings=$((findings + 1))
    fi
    if preflight_env_drift_key_present "$backend_env" "DATABASE_URL"; then
      preflight_env_drift_emit "$kind" "TRR-Backend/.env" "legacy alias DATABASE_URL present"
      findings=$((findings + 1))
    fi

    local backend_pool_max backend_app_name
    backend_pool_max="$(preflight_env_drift_read_value "$backend_env" "TRR_DB_POOL_MAXCONN")"
    backend_app_name="$(preflight_env_drift_read_value "$backend_env" "TRR_DB_APPLICATION_NAME")"

    if [[ -n "$backend_pool_max" && "$backend_pool_max" =~ ^[0-9]+$ ]]; then
      if (( backend_pool_max > 2 )); then
        preflight_env_drift_emit "$kind" "TRR-Backend/.env" \
          "TRR_DB_POOL_MAXCONN=${backend_pool_max} exceeds cap 2 (default lane)"
        findings=$((findings + 1))
      fi
    fi

    if [[ -n "$backend_app_name" && ! "$backend_app_name" =~ ^trr-backend: ]]; then
      preflight_env_drift_emit "$kind" "TRR-Backend/.env" \
        "TRR_DB_APPLICATION_NAME does not start with 'trr-backend:' prefix"
      findings=$((findings + 1))
    fi
  fi

  if (( findings == 0 )); then
    echo "[preflight] env-drift OK"
    return 0
  fi

  if [[ "$strict_mode" == "1" ]]; then
    echo "[preflight] env-drift: ${findings} drift item(s) detected under strict mode."
    echo "[preflight] Remediation: clean TRR-APP/apps/web/.env.local and TRR-Backend/.env per docs/workspace/env-contract.md."
    return 1
  fi

  echo "[preflight] env-drift: ${findings} drift item(s) detected; continuing because WORKSPACE_PREFLIGHT_STRICT=0."
  echo "[preflight] Remediation: clean TRR-APP/apps/web/.env.local and TRR-Backend/.env per docs/workspace/env-contract.md."
  return 0
}

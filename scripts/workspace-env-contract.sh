#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEV_SCRIPT="$ROOT/scripts/dev-workspace.sh"
RUNTIME_RECONCILE_CONTRACT="$ROOT/scripts/lib/workspace-runtime-reconcile-contract.sh"
PROFILE_FILE="$ROOT/profiles/default.env"
OUT_FILE="$ROOT/docs/workspace/env-contract.md"

MODE="${1:---generate}"
if [[ "$MODE" != "--generate" && "$MODE" != "--check" ]]; then
  echo "Usage: $0 [--generate|--check]" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUT_FILE")"

extract_var_rows() {
  {
    grep -E '^[A-Z][A-Z0-9_]*="\$\{[A-Z0-9_]+:-[^}]*\}"' "$DEV_SCRIPT" "$RUNTIME_RECONCILE_CONTRACT" \
      | sed -E 's|^[^:]+:||' \
      | sed -E 's/^([A-Z0-9_]+)="\$\{[A-Z0-9_]+:-([^}]*)\}".*/\1\t\2/'
    printf 'TRR_DB_POOL_MINCONN\t\n'
    printf 'TRR_DB_POOL_MAXCONN\t\n'
    printf 'TRR_SOCIAL_PROFILE_DB_POOL_MINCONN\t\n'
    printf 'TRR_SOCIAL_PROFILE_DB_POOL_MAXCONN\t\n'
    printf 'ADMIN_AUTH_EXTERNAL_TIMEOUT_MS\t3000\n'
    printf 'TRR_INTERNAL_ADMIN_ALLOW_RAW_SECRET_FALLBACK\t\n'
    printf 'TRR_ADMIN_ALLOW_SERVICE_ROLE\t\n'
    printf 'TRR_INTERNAL_ADMIN_ALLOW_SERVICE_ROLE\t\n'
  } | awk -F '\t' '!seen[$1]++' | sort
}

visibility_tier() {
  local key="$1"
  case "$key" in
    WORKSPACE_OPEN_BROWSER|WORKSPACE_CLEAN_NEXT_CACHE|WORKSPACE_BROWSER_TAB_SYNC_MODE|WORKSPACE_TRR_JOB_PLANE_MODE|WORKSPACE_TRR_REMOTE_EXECUTOR|WORKSPACE_TRR_MODAL_ENABLED|WORKSPACE_TRR_REMOTE_WORKERS_ENABLED|WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS|WORKSPACE_BACKEND_AUTO_RESTART|TRR_BACKEND_RELOAD|TRR_ADMIN_ROUTE_CACHE_DISABLED)
      echo "common"
      ;;
    WORKSPACE_RUNTIME_RECONCILE_ENABLED|WORKSPACE_RUNTIME_DB_AUTO_APPLY_ENABLED|WORKSPACE_RUNTIME_MODAL_AUTO_DEPLOY|WORKSPACE_RUNTIME_EXTERNAL_VERIFY_ENABLED)
      echo "common"
      ;;
    WORKSPACE_*)
      echo "advanced"
      ;;
    *)
      echo "internal"
      ;;
  esac
}

accepted_values() {
  local key="$1"
  case "$key" in
    WORKSPACE_TRR_APP_POSTGRES_POOL_MAX|WORKSPACE_TRR_APP_POSTGRES_MAX_CONCURRENT_OPERATIONS)
      echo "integer"
      ;;
    ADMIN_AUTH_EXTERNAL_TIMEOUT_MS)
      echo "integer milliseconds"
      ;;
    TRR_DB_POOL_MINCONN|TRR_DB_POOL_MAXCONN|TRR_SOCIAL_PROFILE_DB_POOL_MINCONN|TRR_SOCIAL_PROFILE_DB_POOL_MAXCONN)
      echo "integer"
      ;;
    TRR_INTERNAL_ADMIN_ALLOW_RAW_SECRET_FALLBACK|TRR_ADMIN_ALLOW_SERVICE_ROLE|TRR_INTERNAL_ADMIN_ALLOW_SERVICE_ROLE)
      echo '`0` or `1`'
      ;;
    WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS)
      echo '`0` or `1`'
      ;;
    WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT|WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT|WORKSPACE_TRR_REMOTE_SOCIAL_POSTS|WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS|WORKSPACE_TRR_REMOTE_SOCIAL_MEDIA_MIRROR|WORKSPACE_TRR_REMOTE_SOCIAL_COMMENT_MEDIA_MIRROR)
      echo "integer"
      ;;
    WORKSPACE_RUNTIME_DB_MAX_AUTO_APPLY)
      echo "integer"
      ;;
    ADMIN_ENFORCE_HOST|ADMIN_STRICT_HOST_ROUTING)
      echo '`true` or `false`'
      ;;
    *MODE)
      if [[ "$key" == "WORKSPACE_TRR_JOB_PLANE_MODE" ]]; then
        echo '`local` or `remote`'
      else
        echo "string"
      fi
      ;;
    *PORT)
      echo "integer port"
      ;;
    *TIMEOUT*|*INTERVAL*|*WORKERS|*RETRIES|*_SECONDS|*_MAX_TIME)
      echo "integer"
      ;;
    *ENABLED|*AUTO_RESTART|*FORCE_KILL_PORT_CONFLICTS|*CLEAN_NEXT_CACHE|*OPEN_BROWSER|*RELOAD|*DISABLED|*REQUIRE_REDIS_FOR_MULTI_WORKER|*LONG_JOB_ENFORCE_REMOTE|*STRICT)
      echo '`0` or `1`'
      ;;
    *)
      echo "string"
      ;;
  esac
}

description_for() {
  local key="$1"
  case "$key" in
    WORKSPACE_TRR_APP_POSTGRES_POOL_MAX)
      echo "Optional TRR-APP child-process override for \`POSTGRES_POOL_MAX\`. Leave unset in the default profile; set it in targeted debug profiles such as \`social-debug\`."
      ;;
    WORKSPACE_TRR_APP_POSTGRES_MAX_CONCURRENT_OPERATIONS)
      echo "Optional TRR-APP child-process override for \`POSTGRES_MAX_CONCURRENT_OPERATIONS\`. Leave unset in the default profile; set it in targeted debug profiles such as \`social-debug\`."
      ;;
    TRR_DB_POOL_MINCONN)
      echo "Backend default psycopg2 pool minimum for local workspace runs. Keep conservative when using the Supabase session pooler."
      ;;
    TRR_DB_POOL_MAXCONN)
      echo "Backend default psycopg2 pool maximum for local workspace runs. This remains the conservative general pool, separate from the dedicated social-profile lane."
      ;;
    TRR_SOCIAL_PROFILE_DB_POOL_MINCONN)
      echo "Dedicated TRR-Backend social-profile read pool minimum for local workspace runs."
      ;;
    TRR_SOCIAL_PROFILE_DB_POOL_MAXCONN)
      echo "Dedicated TRR-Backend social-profile read pool maximum for local workspace runs. This local lane may be higher than the general backend pool to keep social admin pages responsive."
      ;;
    ADMIN_AUTH_EXTERNAL_TIMEOUT_MS)
      echo "Timeout for external auth fallbacks in TRR-APP, including Identity Toolkit lookup and Supabase token shadow verification."
      ;;
    TRR_INTERNAL_ADMIN_ALLOW_RAW_SECRET_FALLBACK)
      echo "Dev-only backend escape hatch that allows raw shared-secret internal admin requests. Leave unset in production."
      ;;
    TRR_ADMIN_ALLOW_SERVICE_ROLE)
      echo "Dev-only backend escape hatch that allows service-role tokens through human-admin routes. Leave unset in production."
      ;;
    TRR_INTERNAL_ADMIN_ALLOW_SERVICE_ROLE)
      echo "Dev-only backend escape hatch that allows service-role tokens through internal-admin routes. Leave unset in production."
      ;;
    WORKSPACE_OPEN_BROWSER)
      echo "Enable automatic browser tab sync/open after startup."
      ;;
    WORKSPACE_BROWSER_TAB_SYNC_MODE)
      echo 'Tab synchronization strategy (`reuse_no_reload`, `reload_first`, `reload_all`).'
      ;;
    WORKSPACE_TRR_JOB_PLANE_MODE)
      echo 'Long-job ownership mode (`local` API-owned or `remote` worker-owned).'
      ;;
    WORKSPACE_TRR_REMOTE_EXECUTOR)
      echo 'Remote long-job backend (`modal` by default, `legacy_worker` for rollback/debug only).'
      ;;
    WORKSPACE_TRR_MODAL_ENABLED)
      echo "Enable Modal-backed remote dispatch in workspace dev."
      ;;
    WORKSPACE_TRR_REMOTE_WORKERS_ENABLED)
      echo "Enable remote background execution. When executor is Modal, local claim loops are skipped and Modal-owned dispatch remains active."
      ;;
    WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS)
      echo "Enable or disable the Modal social lane in the remote execution contract; this is not a worker-count knob."
      ;;
    WORKSPACE_RUNTIME_RECONCILE_ENABLED)
      echo "Enable the startup runtime reconcile phase that checks hosted DB, Modal, Render, and Decodo contracts."
      ;;
    WORKSPACE_RUNTIME_DB_AUTO_APPLY_ENABLED)
      echo "Allow startup to auto-apply a bounded allowlisted Supabase migration suffix."
      ;;
    WORKSPACE_RUNTIME_DB_MAX_AUTO_APPLY)
      echo "Maximum number of allowlisted pending migrations startup may auto-apply."
      ;;
    WORKSPACE_RUNTIME_MODAL_AUTO_DEPLOY)
      echo "Allow startup to auto-apply Modal secrets and redeploy the app when readiness or fingerprint drift is detected."
      ;;
    WORKSPACE_RUNTIME_EXTERNAL_VERIFY_ENABLED)
      echo "Enable verify-only checks for external hosted contracts such as Render and Decodo."
      ;;
    WORKSPACE_RUNTIME_RENDER_VERIFY_ONLY)
      echo "Keep Render checks advisory-only during startup."
      ;;
    WORKSPACE_RUNTIME_DECODO_VERIFY_ONLY)
      echo "Keep Decodo credential checks advisory-only during startup."
      ;;
    WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT)
      echo "Maximum number of queued social jobs the backend will dispatch per Modal sweep."
      ;;
    WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT)
      echo 'Maximum concurrent Modal containers allowed for `run_social_job`.'
      ;;
    WORKSPACE_TRR_REMOTE_SOCIAL_POSTS)
      echo "Posts-stage cap used by Modal social dispatch and by legacy local social worker mode."
      ;;
    WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS)
      echo "Comments-stage cap used by Modal social dispatch and by legacy local social worker mode."
      ;;
    WORKSPACE_TRR_REMOTE_SOCIAL_MEDIA_MIRROR)
      echo "Post media mirror stage cap used by Modal social dispatch and by legacy local social worker mode."
      ;;
    WORKSPACE_TRR_REMOTE_SOCIAL_COMMENT_MEDIA_MIRROR)
      echo "Comment media mirror stage cap used by Modal social dispatch and by legacy local social worker mode."
      ;;
    WORKSPACE_BACKEND_AUTO_RESTART)
      echo "Enable the backend process watchdog that restarts TRR-Backend after repeated failed liveness probes or unexpected process exits."
      ;;
    WORKSPACE_BACKEND_HEALTH_BUSY_TIMEOUT_IGNORE)
      echo "When set to 1, active-traffic curl timeouts log warnings but do not trigger backend auto-restarts."
      ;;
    WORKSPACE_BACKEND_HEALTH_BUSY_TIMEOUT_STREAK)
      echo "Advisory busy-timeout streak denominator used in watchdog logs while active-traffic timeout ignore mode is enabled."
      ;;
    TRR_BACKEND_RELOAD)
      echo "Enable backend reload mode (1) instead of non-reload server mode (0)."
      ;;
    TRR_ADMIN_ROUTE_CACHE_DISABLED)
      echo "Disable Next.js in-memory admin route caching during managed local workspace runs."
      ;;
    *)
      echo 'Workspace runtime variable consumed by `scripts/dev-workspace.sh`.'
      ;;
  esac
}

used_by() {
  local key="$1"
  case "$key" in
    TRR_DB_POOL_MINCONN|TRR_DB_POOL_MAXCONN|TRR_SOCIAL_PROFILE_DB_POOL_MINCONN|TRR_SOCIAL_PROFILE_DB_POOL_MAXCONN)
      echo '`TRR-Backend/trr_backend/db/pg.py`, `profiles/default.env`'
      ;;
    ADMIN_AUTH_EXTERNAL_TIMEOUT_MS)
      echo '`TRR-APP/apps/web/src/lib/server/auth.ts`, `TRR-APP/apps/web/.env.example`'
      ;;
    TRR_INTERNAL_ADMIN_ALLOW_RAW_SECRET_FALLBACK|TRR_ADMIN_ALLOW_SERVICE_ROLE|TRR_INTERNAL_ADMIN_ALLOW_SERVICE_ROLE)
      echo '`TRR-Backend/api/auth.py`, `TRR-Backend/.env.example`'
      ;;
    *)
      echo '`scripts/dev-workspace.sh`, `Makefile`'
      ;;
  esac
}

profile_default_for() {
  local key="$1"

  if [[ ! -f "$PROFILE_FILE" ]]; then
    return 1
  fi

  awk -F '=' -v target="$key" '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    {
      key = $1
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
      if (key != target) {
        next
      }

      value = substr($0, index($0, "=") + 1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      print value
      exit 0
    }
  ' "$PROFILE_FILE"
}

generate_contract() {
  local out="$1"
  {
    echo "# Workspace Environment Contract"
    echo
    echo 'This file is generated by `scripts/workspace-env-contract.sh`.'
    echo
    echo 'Defaults reflect the effective `make dev` baseline (`PROFILE=default`) when that profile overrides the raw script fallback.'
    echo
    echo 'Preferred contract: `make dev` is the cloud-first baseline for normal workspace development. Docker-backed `make dev-local` remains an explicit fallback for local-only Screenalytics / Redis / MinIO cases.'
    echo
    echo 'Route-scoped browser envs for disabled Flashback gameplay are intentionally excluded from the workspace startup contract.'
    echo
    echo "Visibility tiers:"
    echo '- `common`: frequently used day-to-day toggles'
    echo '- `advanced`: less common tuning and troubleshooting controls'
    echo '- `internal`: runtime/plumbing variables usually left at defaults'
    echo
    echo "| Variable | Default | Accepted Values | Used By | Visibility | Notes |"
    echo "|---|---|---|---|---|---|"

    while IFS=$'\t' read -r key default_value; do
      [[ -z "$key" ]] && continue

      effective_default="$default_value"
      if profile_default="$(profile_default_for "$key")"; then
        if [[ -n "$profile_default" ]]; then
          effective_default="$profile_default"
        fi
      fi

      printf '| `%s` | `%s` | %s | %s | `%s` | %s |\n' \
        "$key" \
        "$effective_default" \
        "$(accepted_values "$key")" \
        "$(used_by "$key")" \
        "$(visibility_tier "$key")" \
        "$(description_for "$key")"
    done < <(extract_var_rows)
  } > "$out"
}

TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT

generate_contract "$TMP_FILE"

if [[ "$MODE" == "--generate" ]]; then
  if [[ ! -f "$OUT_FILE" ]] || ! cmp -s "$TMP_FILE" "$OUT_FILE"; then
    mv "$TMP_FILE" "$OUT_FILE"
    echo "[env-contract] Wrote $OUT_FILE"
  else
    echo "[env-contract] No changes ($OUT_FILE is up to date)"
  fi
  exit 0
fi

if [[ ! -f "$OUT_FILE" ]]; then
  echo "[env-contract] ERROR: missing $OUT_FILE" >&2
  echo "[env-contract] Run: make env-contract" >&2
  exit 1
fi

if ! cmp -s "$TMP_FILE" "$OUT_FILE"; then
  echo "[env-contract] ERROR: $OUT_FILE is out of date." >&2
  echo "[env-contract] Run: make env-contract" >&2
  exit 1
fi

echo "[env-contract] OK"

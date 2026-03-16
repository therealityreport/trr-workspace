#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEV_SCRIPT="$ROOT/scripts/dev-workspace.sh"
PROFILE_FILE="$ROOT/profiles/default.env"
OUT_FILE="$ROOT/docs/workspace/env-contract.md"

MODE="${1:---generate}"
if [[ "$MODE" != "--generate" && "$MODE" != "--check" ]]; then
  echo "Usage: $0 [--generate|--check]" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUT_FILE")"

extract_var_rows() {
  grep -E '^[A-Z][A-Z0-9_]*="\$\{[A-Z0-9_]+:-[^}]*\}"' "$DEV_SCRIPT" \
    | sed -E 's/^([A-Z0-9_]+)="\$\{[A-Z0-9_]+:-([^}]*)\}".*/\1\t\2/' \
    | awk -F '\t' '!seen[$1]++' \
    | sort
}

visibility_tier() {
  local key="$1"
  case "$key" in
    WORKSPACE_OPEN_BROWSER|WORKSPACE_OPEN_SCREENALYTICS_TABS|WORKSPACE_CLEAN_NEXT_CACHE|WORKSPACE_BROWSER_TAB_SYNC_MODE|WORKSPACE_SCREENALYTICS|WORKSPACE_SCREENALYTICS_SKIP_DOCKER|WORKSPACE_TRR_JOB_PLANE_MODE|WORKSPACE_TRR_REMOTE_EXECUTOR|WORKSPACE_TRR_MODAL_ENABLED|WORKSPACE_TRR_REMOTE_WORKERS_ENABLED|WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS|WORKSPACE_BACKEND_AUTO_RESTART|TRR_BACKEND_RELOAD)
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
    WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS)
      echo '`0` or `1`'
      ;;
    WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT|WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT|WORKSPACE_TRR_REMOTE_SOCIAL_POSTS|WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS|WORKSPACE_TRR_REMOTE_SOCIAL_MEDIA_MIRROR|WORKSPACE_TRR_REMOTE_SOCIAL_COMMENT_MEDIA_MIRROR)
      echo "integer"
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
    *TIMEOUT*|*INTERVAL*|*WORKERS|*RETRIES)
      echo "integer"
      ;;
    *ENABLED|*AUTO_RESTART|*SKIP_DOCKER|*FORCE_KILL_PORT_CONFLICTS|*CLEAN_NEXT_CACHE|*OPEN_BROWSER|*OPEN_SCREENALYTICS_TABS|*RELOAD|*REQUIRE_REDIS_FOR_MULTI_WORKER|*LONG_JOB_ENFORCE_REMOTE|*STRICT)
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
    WORKSPACE_SCREENALYTICS)
      echo "Enable or disable screenalytics service startup in workspace dev mode."
      ;;
    WORKSPACE_SCREENALYTICS_SKIP_DOCKER)
      echo "Use screenalytics without local Docker infra (Redis/MinIO bypass mode)."
      ;;
    WORKSPACE_OPEN_BROWSER)
      echo "Enable automatic browser tab sync/open after startup."
      ;;
    WORKSPACE_OPEN_SCREENALYTICS_TABS)
      echo "Include screenalytics tabs in browser sync flow."
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
    TRR_BACKEND_RELOAD)
      echo "Enable backend reload mode (1) instead of non-reload server mode (0)."
      ;;
    *)
      echo 'Workspace runtime variable consumed by `scripts/dev-workspace.sh`.'
      ;;
  esac
}

used_by() { echo '`scripts/dev-workspace.sh`, `Makefile`'; }

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

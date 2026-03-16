#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

API_BASE_URL="${TRR_CAST_SCREENTIME_LIVE_API_BASE_URL:-${TRR_API_URL:-}}"

run_if_configured() {
  local label="$1"
  shift
  echo "[cast-screentime-live] ${label}"
  "$@"
}

if [[ -z "${API_BASE_URL}" ]]; then
  echo "[cast-screentime-live] skipped: TRR_CAST_SCREENTIME_LIVE_API_BASE_URL or TRR_API_URL is not set"
  exit 0
fi

if [[ -n "${CAST_SCREENTIME_EPISODE_VIDEO_FILE:-}" && -n "${CAST_SCREENTIME_EPISODE_OWNER_SCOPE:-}" && -n "${CAST_SCREENTIME_EPISODE_OWNER_ID:-}" ]]; then
  run_if_configured "episode upload/run smoke" \
    python "$ROOT_DIR/TRR-Backend/scripts/ops/cast_screentime_deployed_smoke.py" \
      --api-base-url "$API_BASE_URL" \
      --owner-scope "$CAST_SCREENTIME_EPISODE_OWNER_SCOPE" \
      --owner-id "$CAST_SCREENTIME_EPISODE_OWNER_ID" \
      --video-class episode \
      --wait \
      upload-run \
      --video-file "$CAST_SCREENTIME_EPISODE_VIDEO_FILE"
else
  echo "[cast-screentime-live] skipped episode upload/run smoke: set CAST_SCREENTIME_EPISODE_VIDEO_FILE, CAST_SCREENTIME_EPISODE_OWNER_SCOPE, CAST_SCREENTIME_EPISODE_OWNER_ID"
fi

if [[ -n "${CAST_SCREENTIME_PROMO_VIDEO_FILE:-}" && -n "${CAST_SCREENTIME_PROMO_OWNER_SCOPE:-}" && -n "${CAST_SCREENTIME_PROMO_OWNER_ID:-}" ]]; then
  run_if_configured "promo upload/run smoke" \
    python "$ROOT_DIR/TRR-Backend/scripts/ops/cast_screentime_deployed_smoke.py" \
      --api-base-url "$API_BASE_URL" \
      --owner-scope "$CAST_SCREENTIME_PROMO_OWNER_SCOPE" \
      --owner-id "$CAST_SCREENTIME_PROMO_OWNER_ID" \
      --video-class promo \
      --promo-subtype "${CAST_SCREENTIME_PROMO_SUBTYPE:-trailer}" \
      --wait \
      upload-run \
      --video-file "$CAST_SCREENTIME_PROMO_VIDEO_FILE"
else
  echo "[cast-screentime-live] skipped promo upload/run smoke: set CAST_SCREENTIME_PROMO_VIDEO_FILE, CAST_SCREENTIME_PROMO_OWNER_SCOPE, CAST_SCREENTIME_PROMO_OWNER_ID"
fi

if [[ -n "${CAST_SCREENTIME_YOUTUBE_OWNER_SCOPE:-}" && -n "${CAST_SCREENTIME_YOUTUBE_OWNER_ID:-}" && ( -n "${CAST_SCREENTIME_YOUTUBE_URL:-}" || -n "${CAST_SCREENTIME_SOCIAL_YOUTUBE_VIDEO_ID:-}" ) ]]; then
  if [[ -n "${CAST_SCREENTIME_SOCIAL_YOUTUBE_VIDEO_ID:-}" ]]; then
    run_if_configured "social youtube import smoke" \
      python "$ROOT_DIR/TRR-Backend/scripts/ops/cast_screentime_deployed_smoke.py" \
        --api-base-url "$API_BASE_URL" \
        --owner-scope "$CAST_SCREENTIME_YOUTUBE_OWNER_SCOPE" \
        --owner-id "$CAST_SCREENTIME_YOUTUBE_OWNER_ID" \
        --video-class promo \
        --promo-subtype "${CAST_SCREENTIME_YOUTUBE_PROMO_SUBTYPE:-trailer}" \
        --wait \
        import-run \
        --source-mode social_youtube_row \
        --social-youtube-video-id "$CAST_SCREENTIME_SOCIAL_YOUTUBE_VIDEO_ID"
  else
    run_if_configured "youtube/external import smoke" \
      python "$ROOT_DIR/TRR-Backend/scripts/ops/cast_screentime_deployed_smoke.py" \
        --api-base-url "$API_BASE_URL" \
        --owner-scope "$CAST_SCREENTIME_YOUTUBE_OWNER_SCOPE" \
        --owner-id "$CAST_SCREENTIME_YOUTUBE_OWNER_ID" \
        --video-class promo \
        --promo-subtype "${CAST_SCREENTIME_YOUTUBE_PROMO_SUBTYPE:-trailer}" \
        --wait \
        import-run \
        --source-mode "${CAST_SCREENTIME_REMOTE_SOURCE_MODE:-youtube_url}" \
        --source-url "$CAST_SCREENTIME_YOUTUBE_URL"
  fi
else
  echo "[cast-screentime-live] skipped remote import smoke: set CAST_SCREENTIME_YOUTUBE_OWNER_SCOPE, CAST_SCREENTIME_YOUTUBE_OWNER_ID, and CAST_SCREENTIME_YOUTUBE_URL or CAST_SCREENTIME_SOCIAL_YOUTUBE_VIDEO_ID"
fi

if [[ -n "${CAST_SCREENTIME_STALE_RUN_ID:-}" ]]; then
  run_if_configured "stale-run drill" \
    python "$ROOT_DIR/TRR-Backend/scripts/ops/cast_screentime_stale_run_drill.py" \
      --api-base-url "$API_BASE_URL" \
      --run-id "$CAST_SCREENTIME_STALE_RUN_ID" \
      --stale-after-seconds "${CAST_SCREENTIME_STALE_AFTER_SECONDS:-1800}"
else
  echo "[cast-screentime-live] skipped stale-run drill: set CAST_SCREENTIME_STALE_RUN_ID"
fi

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "[cast-screentime] backend tests"
(cd "$ROOT_DIR/TRR-Backend" && pytest tests/api/test_admin_cast_screentime.py tests/services/test_retained_cast_screentime_runtime.py tests/services/test_retained_cast_screentime_dispatch.py tests/services/test_retained_cast_screentime_review.py -q)

echo "[cast-screentime] retained runtime checks now live in TRR-Backend; no separate screenalytics repo checks are required"

echo "[cast-screentime] app checks"
(cd "$ROOT_DIR/TRR-APP" && pnpm -C apps/web exec vitest run -c vitest.config.ts tests/cast-screentime-proxy-route.test.ts)
(cd "$ROOT_DIR/TRR-APP" && pnpm -C apps/web exec eslint 'src/app/admin/cast-screentime/page.tsx' 'src/app/admin/cast-screentime/CastScreentimePageClient.tsx' 'src/app/api/admin/trr-api/cast-screentime/[...path]/route.ts' 'src/lib/server/admin/cast-screentime-access.ts' 'src/lib/admin/show-admin-routes.ts' 'src/lib/server/admin/covered-shows-repository.ts' 'src/components/admin/design-system/TypographyTab.tsx')
if [[ "${CAST_SCREENTIME_STRICT_APP_TYPECHECK:-0}" == "1" ]]; then
  echo "[cast-screentime] strict app typecheck"
  (cd "$ROOT_DIR/TRR-APP" && pnpm -C apps/web typecheck)
else
  echo "[cast-screentime] skipping app-wide typecheck by default; set CAST_SCREENTIME_STRICT_APP_TYPECHECK=1 to enforce it"
fi

echo "[cast-screentime] no separate screenalytics golden manifest validation is required"

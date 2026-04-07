---
phase: 05
slug: runtime-retirement-cutover-cleanup
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-04-03
---

# Phase 05 — Validation Strategy

> Per-phase validation contract for retiring the remaining screentime dependency on the standalone Screenalytics runtime.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Backend framework** | pytest + FastAPI TestClient + Ruff |
| **App framework** | Vitest + Next.js build + ESLint |
| **Quick backend command** | `cd TRR-Backend && pytest -q tests/api/test_admin_cast_screentime.py tests/services/test_retained_cast_screentime_dispatch.py tests/test_startup_config.py` |
| **Quick app command** | `cd TRR-APP && pnpm -C apps/web exec vitest run tests/cast-screentime-proxy-route.test.ts tests/cast-screentime-run-state.test.ts tests/cast-screentime-page.test.tsx` |
| **Full backend command** | `cd TRR-Backend && ruff check api/main.py api/routers/admin_cast_screentime.py api/routers/screenalytics.py api/routers/screenalytics_runs_v2.py api/screenalytics_auth.py trr_backend/services/retained_cast_screentime_dispatch.py trr_backend/clients/screenalytics_cast_screentime.py tests/api/test_admin_cast_screentime.py tests/services/test_retained_cast_screentime_dispatch.py tests/test_startup_config.py tests/api/test_screenalytics_runs_v2.py && ruff format --check api/main.py api/routers/admin_cast_screentime.py api/routers/screenalytics.py api/routers/screenalytics_runs_v2.py api/screenalytics_auth.py trr_backend/services/retained_cast_screentime_dispatch.py trr_backend/clients/screenalytics_cast_screentime.py tests/api/test_admin_cast_screentime.py tests/services/test_retained_cast_screentime_dispatch.py tests/test_startup_config.py tests/api/test_screenalytics_runs_v2.py && pytest -q tests/api/test_admin_cast_screentime.py tests/services/test_retained_cast_screentime_dispatch.py tests/test_startup_config.py tests/api/test_screenalytics_runs_v2.py` |
| **Full app command** | `cd TRR-APP && pnpm -C apps/web run lint && pnpm -C apps/web exec next build --webpack && pnpm -C apps/web run test:ci` |
| **Estimated runtime** | Backend: ~30-90s scoped. App: ~2-5m depending on build cache. |

---

## Sampling Rate

- **After every backend retirement slice:** run the quick backend command or the task-specific pytest command.
- **After any app continuity change:** run the quick app command.
- **After the full wave:** run the Phase 5 backend full command and the Phase 5 app full command.
- **Before `$gsd-verify-work`:** both touched repos must pass the scoped validation contract and the live parity/manual checks must be recorded.
- **Max feedback latency:** 5 minutes

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 05-01-01 | 01 | 1 | MIGR-04 | backend dispatch + route contract | `cd TRR-Backend && pytest -q tests/api/test_admin_cast_screentime.py tests/services/test_retained_cast_screentime_dispatch.py` | ✅ partial | ⬜ pending |
| 05-01-02 | 01 | 1 | MIGR-04 | startup/env retirement + legacy route coverage | `cd TRR-Backend && pytest -q tests/test_startup_config.py tests/api/test_screenalytics_runs_v2.py` | ✅ partial | ⬜ pending |
| 05-01-03 | 01 | 1 | ADMIN-02 | app proxy + operator continuity | `cd TRR-APP && pnpm -C apps/web exec vitest run tests/cast-screentime-proxy-route.test.ts tests/cast-screentime-run-state.test.ts tests/cast-screentime-page.test.tsx` | ✅ partial | ⬜ pending |
| 05-01-04 | 01 | 1 | ADMIN-02, MIGR-04 | full phase lint/build/test + docs | `cd TRR-Backend && ruff check api/main.py api/routers/admin_cast_screentime.py trr_backend/services/retained_cast_screentime_dispatch.py tests/api/test_admin_cast_screentime.py tests/services/test_retained_cast_screentime_dispatch.py tests/test_startup_config.py && pytest -q tests/api/test_admin_cast_screentime.py tests/services/test_retained_cast_screentime_dispatch.py tests/test_startup_config.py && cd ../TRR-APP && pnpm -C apps/web run lint && pnpm -C apps/web exec next build --webpack && pnpm -C apps/web run test:ci` | ✅ partial | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Backend-owned screentime runtime, review state, and publication state already exist.
- [x] `TRR-APP` already uses a backend-owned screentime proxy route.
- [ ] Donor runtime dispatch modes and `SCREENALYTICS_*` startup requirements still remain and must be retired.
- [ ] Screentime-specific legacy `screenalytics` routes and tests still need final scope decisions or cleanup.
- [ ] Live parity sanity for one real screentime asset still needs to be recorded before retirement is considered operationally closed.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Backend-only screentime run works in a live media environment | MIGR-04 | CI does not prove object storage, ffmpeg/OpenCV, and real-media execution together | Run one real screentime asset end-to-end through the backend lane and confirm no `SCREENALYTICS_*` envs are needed |
| TRR-APP admin flow is unchanged for operators after retirement | ADMIN-02 | Automated tests prove contract continuity, not full operator confidence | Load `/admin/cast-screentime`, inspect an existing run, and verify evidence, exclusions, clips, reviewed totals, and publish history still resolve |
| Retirement docs match real runtime state | ADMIN-02, MIGR-04 | Docs can drift even when tests pass | Confirm decommission/status docs explicitly say screentime no longer depends on the standalone Screenalytics runtime |

---

## Validation Sign-Off

- [x] All planned tasks have automated or explicit manual verification coverage
- [x] Validation spans both touched repos for this phase
- [x] Sampling continuity avoids long unverified stretches
- [x] No watch-mode commands
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

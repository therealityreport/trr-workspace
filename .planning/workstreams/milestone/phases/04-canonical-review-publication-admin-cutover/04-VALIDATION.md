---
phase: 04
slug: canonical-review-publication-admin-cutover
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-04-03
---

# Phase 04 — Validation Strategy

> Per-phase validation contract for canonical review, publication, and app cutover work.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Backend framework** | pytest + FastAPI TestClient + Ruff |
| **App framework** | Vitest + Testing Library + Next.js build + ESLint |
| **Quick backend command** | `cd TRR-Backend && pytest -q tests/api/test_admin_cast_screentime.py tests/repositories/test_cast_screentime_repository.py` |
| **Quick app command** | `cd TRR-APP && pnpm -C apps/web exec vitest run tests/cast-screentime-proxy-route.test.ts tests/cast-screentime-run-state.test.ts` |
| **Full backend command** | `cd TRR-Backend && ruff check api/routers/admin_cast_screentime.py trr_backend/repositories/cast_screentime.py trr_backend/services/retained_cast_screentime_review.py tests/api/test_admin_cast_screentime.py tests/repositories/test_cast_screentime_repository.py && ruff format --check api/routers/admin_cast_screentime.py trr_backend/repositories/cast_screentime.py trr_backend/services/retained_cast_screentime_review.py tests/api/test_admin_cast_screentime.py tests/repositories/test_cast_screentime_repository.py && pytest -q tests/api/test_admin_cast_screentime.py tests/repositories/test_cast_screentime_repository.py` |
| **Full app command** | `cd TRR-APP && pnpm -C apps/web run lint && pnpm -C apps/web exec next build --webpack && pnpm -C apps/web run test:ci` |
| **Estimated runtime** | Backend: ~30-60s scoped. App: ~2-5m depending on build cache. |

---

## Sampling Rate

- **After every backend task slice:** run the task-specific backend pytest command.
- **After every app task slice:** run the targeted Vitest command.
- **After the full wave:** run the Phase 4 backend full command and the Phase 4 app full command.
- **Before `$gsd-verify-work`:** both touched repos must pass their scoped validation contract.
- **Max feedback latency:** 5 minutes

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 04-01-01 | 01 | 1 | REVW-01, REVW-02, REVW-05 | backend route + repository + review-service | `cd TRR-Backend && pytest -q tests/api/test_admin_cast_screentime.py tests/repositories/test_cast_screentime_repository.py` | ✅ partial | ⬜ pending |
| 04-01-02 | 01 | 1 | REVW-03, REVW-04, REVW-05 | backend publication + rollup semantics | `cd TRR-Backend && pytest -q tests/api/test_admin_cast_screentime.py tests/repositories/test_cast_screentime_repository.py` | ✅ partial | ⬜ pending |
| 04-01-03 | 01 | 1 | ADMIN-01, ADMIN-03 | app proxy + page behavior | `cd TRR-APP && pnpm -C apps/web exec vitest run tests/cast-screentime-proxy-route.test.ts tests/cast-screentime-run-state.test.ts` | ✅ partial | ⬜ pending |
| 04-01-04 | 01 | 1 | REVW-01, REVW-02, REVW-03, REVW-04, REVW-05, ADMIN-01, ADMIN-03 | full phase lint/build/test + docs | `cd TRR-Backend && ruff check api/routers/admin_cast_screentime.py trr_backend/repositories/cast_screentime.py trr_backend/services/retained_cast_screentime_review.py tests/api/test_admin_cast_screentime.py tests/repositories/test_cast_screentime_repository.py && pytest -q tests/api/test_admin_cast_screentime.py tests/repositories/test_cast_screentime_repository.py && cd ../TRR-APP && pnpm -C apps/web run lint && pnpm -C apps/web exec next build --webpack && pnpm -C apps/web run test:ci` | ✅ partial | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Retained backend run, artifact, evidence, review-status, suggestion-decision, unknown-review, and publication routes already exist.
- [x] `TRR-APP` already has a dedicated `/admin/cast-screentime` page and proxy route.
- [ ] Canonical reviewed-results regeneration is not explicit yet and must be added.
- [ ] Supplementary publication semantics are not complete yet and must be added.
- [ ] App-level tests for the full screentime review/publication surface are still thin and must be expanded.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Immutable-vs-reviewed separation is understandable to operators | REVW-01, REVW-02 | Automated tests prove contracts, not operator clarity | Load `/admin/cast-screentime` and confirm raw run artifacts remain inspectable while reviewed totals/publication status are clearly differentiated |
| Supplementary publication does not contaminate canonical rollups | REVW-04 | Needs end-to-end sanity across UI and backend | Publish one supplementary asset and verify it appears as internal reference only, not in episode/season/show rollups |
| TRR-APP is the real operator surface | ADMIN-01, ADMIN-03 | Build/test coverage does not prove usability alone | Complete one full intake -> run -> review -> publish inspection path in the app against a live backend |

---

## Validation Sign-Off

- [x] All planned tasks have automated or explicit manual verification coverage
- [x] Validation spans both touched repos for this phase
- [x] Sampling continuity avoids long unverified stretches
- [x] No watch-mode commands
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

---
phase: 01
slug: contract-freeze-asset-foundation
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-02
---

# Phase 01 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | pytest + FastAPI TestClient + Ruff |
| **Config file** | `TRR-Backend/pytest.ini` |
| **Quick run command** | `cd TRR-Backend && pytest -q tests/api/test_admin_cast_screentime.py` |
| **Full suite command** | `cd TRR-Backend && ruff check api/routers/admin_cast_screentime.py tests/api/test_admin_cast_screentime.py trr_backend/services/cast_screentime_artifacts.py && ruff format --check api/routers/admin_cast_screentime.py tests/api/test_admin_cast_screentime.py trr_backend/services/cast_screentime_artifacts.py && pytest -q tests/api/test_admin_cast_screentime.py` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `cd TRR-Backend && pytest -q tests/api/test_admin_cast_screentime.py`
- **After every plan wave:** Run `cd TRR-Backend && ruff check api/routers/admin_cast_screentime.py tests/api/test_admin_cast_screentime.py trr_backend/services/cast_screentime_artifacts.py && ruff format --check api/routers/admin_cast_screentime.py tests/api/test_admin_cast_screentime.py trr_backend/services/cast_screentime_artifacts.py && pytest -q tests/api/test_admin_cast_screentime.py`
- **Before `$gsd-verify-work`:** Phase-scoped full suite must be green
- **Max feedback latency:** 20 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | INTK-01, INTK-02, INTK-03, INTK-04, MIGR-01 | route + lint | `cd TRR-Backend && pytest -q tests/api/test_admin_cast_screentime.py` | ✅ | ⬜ pending |
| 01-01-02 | 01 | 1 | MIGR-01, MIGR-02 | lint + targeted route | `cd TRR-Backend && ruff check api/routers/admin_cast_screentime.py tests/api/test_admin_cast_screentime.py trr_backend/services/cast_screentime_artifacts.py && ruff format --check api/routers/admin_cast_screentime.py tests/api/test_admin_cast_screentime.py trr_backend/services/cast_screentime_artifacts.py` | ✅ | ⬜ pending |
| 01-01-03 | 01 | 1 | MIGR-01, MIGR-02 | docs + manual contract review | `test -f TRR-Backend/docs/ai/local-status/cast-screentime-phase1-asset-contract-freeze.md` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Existing backend test infrastructure covers the screentime route surface.
- [x] Existing Ruff and pytest commands are sufficient for this phase slice.
- [x] No new framework install or fixture bootstrap is required.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Asset-only legacy bridge scope | MIGR-01 | SQL intent and migration boundaries are easier to verify by reading than by a single automated command | Read `TRR-Backend/supabase/migrations/20260402233000_cast_screentime_phase1_asset_contract_freeze.sql` and confirm it adds the bridge column, backfills legacy asset rows, and does not touch runs/review/publication tables |
| App parity no-op decision | INTK-01, INTK-02 | The correct outcome may be no app change | Read `TRR-APP/apps/web/src/app/admin/cast-screentime/CastScreentimePageClient.tsx` and confirm the existing upload/import modes already match the backend contract |

---

## Validation Sign-Off

- [x] All tasks have automated verify or explicit manual verification coverage
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all missing references
- [x] No watch-mode flags
- [x] Feedback latency < 20s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

---
phase: 03
slug: backend-execution-port
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-04-03
---

# Phase 03 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | pytest + FastAPI TestClient + Ruff |
| **Config file** | `TRR-Backend/pytest.ini` |
| **Quick run command** | `cd TRR-Backend && pytest -q tests/api/test_admin_cast_screentime.py tests/services/test_retained_cast_screentime_dispatch.py` |
| **Full suite command** | `cd TRR-Backend && ruff check api/routers/admin_cast_screentime.py trr_backend/services/retained_cast_screentime_dispatch.py trr_backend/services/retained_cast_screentime_runtime.py tests/api/test_admin_cast_screentime.py tests/services/test_retained_cast_screentime_dispatch.py tests/services/test_retained_cast_screentime_runtime.py && ruff format --check api/routers/admin_cast_screentime.py trr_backend/services/retained_cast_screentime_dispatch.py trr_backend/services/retained_cast_screentime_runtime.py tests/api/test_admin_cast_screentime.py tests/services/test_retained_cast_screentime_dispatch.py tests/services/test_retained_cast_screentime_runtime.py && pytest -q tests/api/test_admin_cast_screentime.py tests/services/test_retained_cast_screentime_dispatch.py tests/services/test_retained_cast_screentime_runtime.py` |
| **Estimated runtime** | ~30-60 seconds once runtime tests exist |

---

## Sampling Rate

- **After every task commit:** Run the task’s targeted pytest command first.
- **After every plan wave:** Run the Phase 3 full suite command.
- **Before `$gsd-verify-work`:** Phase-scoped backend suite must be green.
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 1 | RUN-01, RUN-02, RUN-06, MIGR-03 | dispatch + route contract | `cd TRR-Backend && pytest -q tests/api/test_admin_cast_screentime.py tests/services/test_retained_cast_screentime_dispatch.py` | ✅ partial | ⬜ pending |
| 03-01-02 | 01 | 1 | RUN-03, RUN-04, RUN-05 | runtime + artifact persistence | `cd TRR-Backend && pytest -q tests/services/test_retained_cast_screentime_runtime.py tests/api/test_admin_cast_screentime.py` | ✅ partial | ⬜ pending |
| 03-01-03 | 01 | 1 | RUN-01, RUN-02, RUN-03, RUN-04, RUN-05, RUN-06, MIGR-03 | lint + parity + docs | `cd TRR-Backend && ruff check api/routers/admin_cast_screentime.py trr_backend/services/retained_cast_screentime_dispatch.py trr_backend/services/retained_cast_screentime_runtime.py tests/api/test_admin_cast_screentime.py tests/services/test_retained_cast_screentime_dispatch.py tests/services/test_retained_cast_screentime_runtime.py && pytest -q tests/api/test_admin_cast_screentime.py tests/services/test_retained_cast_screentime_dispatch.py tests/services/test_retained_cast_screentime_runtime.py` | ✅ partial | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Retained backend run, artifact, segment, evidence, and excluded-section tables already exist.
- [x] Existing backend route and repository coverage already exercises the retained screentime control plane.
- [ ] Backend-owned executor modules and targeted runtime tests do not exist yet and must be created during execution.
- [ ] A reversible runtime-mode flag or equivalent config gate must be introduced during execution.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Runtime cutover reversibility | MIGR-03 | A flag can exist in code and still be wired unsafely for rollback | Read `retained_cast_screentime_dispatch.py` and confirm donor HTTP and backend executor modes are both addressable without API changes |
| Run-config reproducibility | RUN-02, RUN-05 | Tests can prove fields exist but not always that the stored config tells the full execution story | Read the runtime manifest/config snapshot code and confirm thresholds, embedding contract key, artifact schema version, execution backend, and candidate cast snapshot are persisted per run |
| App parity no-op decision | RUN-01, RUN-06 | The correct outcome may still be backend-only work | Re-read the TRR-APP screentime proxy surface and confirm no app edits were required unless the backend response contract changed |
| Donor/backend parity confidence | RUN-03, RUN-04, MIGR-03 | Automated parity helpers may cover golden fixtures but not every operator-facing nuance | Compare at least one donor-backed run and one backend-backed run for artifact-key presence, totals shape, segment windows, and evidence availability |

---

## Validation Sign-Off

- [x] All tasks have automated verify or explicit manual verification coverage
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Validation strategy acknowledges the new runtime module and cutover-flag work required for this phase
- [x] No watch-mode flags
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

---
phase: 02
slug: identity-reset-embedding-governance
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-04-03
---

# Phase 02 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | pytest + FastAPI TestClient + Ruff |
| **Config file** | `TRR-Backend/pytest.ini` |
| **Quick run command** | `cd TRR-Backend && pytest -q tests/repositories/test_face_references_repository.py tests/vision/test_people_count_retained_embeddings.py` |
| **Full suite command** | `cd TRR-Backend && ruff check api/routers/admin_person_images.py api/routers/admin_face_references.py trr_backend/repositories/face_references.py trr_backend/services/face_reference_embeddings.py trr_backend/vision/people_count_engine.py tests/repositories/test_face_references_repository.py tests/api/routers/test_admin_person_images.py tests/api/test_admin_face_references.py tests/vision/test_people_count_retained_embeddings.py && ruff format --check api/routers/admin_person_images.py api/routers/admin_face_references.py trr_backend/repositories/face_references.py trr_backend/services/face_reference_embeddings.py trr_backend/vision/people_count_engine.py tests/repositories/test_face_references_repository.py tests/api/routers/test_admin_person_images.py tests/api/test_admin_face_references.py tests/vision/test_people_count_retained_embeddings.py && pytest -q tests/repositories/test_face_references_repository.py tests/api/routers/test_admin_person_images.py tests/api/test_admin_face_references.py tests/vision/test_people_count_retained_embeddings.py` |
| **Estimated runtime** | ~30-45 seconds once new router/service tests exist |

---

## Sampling Rate

- **After every task commit:** Run the task’s targeted pytest command first.
- **After every plan wave:** Run the Phase 2 full suite command.
- **Before `$gsd-verify-work`:** Phase-scoped backend suite must be green.
- **Max feedback latency:** 45 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | IDEN-01, IDEN-04 | repository + admin route | `cd TRR-Backend && pytest -q tests/repositories/test_face_references_repository.py tests/api/routers/test_admin_person_images.py` | ✅ partial | ⬜ pending |
| 02-01-02 | 01 | 1 | IDEN-02, IDEN-03 | service + vision contract | `cd TRR-Backend && pytest -q tests/vision/test_people_count_retained_embeddings.py tests/api/test_admin_face_references.py` | ✅ partial | ⬜ pending |
| 02-01-03 | 01 | 1 | IDEN-01, IDEN-02, IDEN-03, IDEN-04 | lint + docs + route contract | `cd TRR-Backend && ruff check api/routers/admin_person_images.py api/routers/admin_face_references.py trr_backend/repositories/face_references.py trr_backend/services/face_reference_embeddings.py trr_backend/vision/people_count_engine.py && pytest -q tests/repositories/test_face_references_repository.py tests/api/routers/test_admin_person_images.py tests/api/test_admin_face_references.py tests/vision/test_people_count_retained_embeddings.py` | ✅ partial | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Retained backend tables for `ml.face_reference_images` and `ml.face_reference_embeddings` already exist.
- [x] Existing pytest and Ruff infrastructure is sufficient for repository/router/service validation.
- [ ] `DeepFace` is not yet a `TRR-Backend` dependency and must be added during execution.
- [ ] New route/service tests for backend-owned search/verify flows must be created during execution.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| ArcFace-class contract freeze | IDEN-02, IDEN-03 | Provenance design and contract-key semantics need architecture review in addition to tests | Read the Phase 2 migration and service module; confirm provider/model/detector/normalization are explicit and one active contract key gates search consumers |
| Duplicate and review semantics | IDEN-01, IDEN-04 | The correctness of “pending vs approved vs duplicate” often depends on policy encoded across route, repository, and migration layers | Read the review-state transitions in `face_references.py` and `admin_face_references.py`; confirm unreviewed/duplicate rows cannot become active seeds |
| App parity no-op or minimal-additive choice | IDEN-01 | The correct outcome may be a backend-only contract with no page redesign | Re-read the person-gallery seed toggle proxy flow and confirm execution only touches `TRR-APP` if backend route exposure requires it |

---

## Validation Sign-Off

- [x] All tasks have automated verify or explicit manual verification coverage
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Validation strategy acknowledges the new dependency/bootstrap work required for DeepFace
- [x] No watch-mode flags
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

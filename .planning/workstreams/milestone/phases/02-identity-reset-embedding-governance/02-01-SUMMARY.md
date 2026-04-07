---
phase: 02-identity-reset-embedding-governance
plan: 01
subsystem: api
tags: [fastapi, postgres, deepface, pgvector, face-references, migration]
requires: [01-01]
provides:
  - canonical retained face-reference governance in `ml.face_reference_images`
  - backend-owned DeepFace ArcFace register/search/verify lane
  - internal-admin face-reference review and re-embed endpoints
affects: [03-backend-execution-port, retained-identity, admin-governance]
tech-stack:
  added: [deepface]
  patterns:
    - reviewed face-reference governance with donor bridge semantics
    - explicit ArcFace-class contract key on retained embeddings
    - backend-owned admin identity governance routes
key-files:
  created:
    - TRR-Backend/supabase/migrations/20260403021500_face_reference_identity_reset_phase2.sql
    - TRR-Backend/trr_backend/services/face_reference_embeddings.py
    - TRR-Backend/api/routers/admin_face_references.py
    - TRR-Backend/tests/api/test_admin_face_references.py
    - TRR-Backend/docs/ai/local-status/cast-screentime-phase2-identity-reset.md
  modified:
    - TRR-Backend/trr_backend/repositories/face_references.py
    - TRR-Backend/api/main.py
    - TRR-Backend/api/routers/admin_person_images.py
    - TRR-Backend/trr_backend/vision/people_count_engine.py
    - TRR-Backend/tests/repositories/test_face_references_repository.py
    - TRR-Backend/tests/api/routers/test_admin_person_images.py
    - TRR-Backend/tests/vision/test_people_count_retained_embeddings.py
    - TRR-Backend/requirements.in
    - TRR-Backend/requirements.txt
    - TRR-Backend/requirements.lock.txt
    - TRR-Backend/docs/ai/local-status/screenalytics-decommission-ledger.md
key-decisions:
  - "The existing gallery `facebank_seed` toggle stays as enrollment input, but approval state is now explicit backend governance instead of an implicit side effect."
  - "DeepFace is adopted only as the backend register/search/verify layer while the active matching contract remains ArcFace-class and versioned under one contract key."
  - "Legacy `screenalytics.face_bank_images` rows are bridge-only donor input and are backfilled only when a deterministic TRR media-link join exists."
patterns-established:
  - "Review-gated identity state: approved, pending_review, rejected, and duplicate live in retained backend tables."
  - "Reader safety: retained consumers filter to approved, active, contract-matching ready embeddings only."
requirements-completed: [IDEN-01, IDEN-02, IDEN-03, IDEN-04]
duration: 96 min
completed: 2026-04-03
---

# Phase 2 Plan 1: Identity Reset & Embedding Governance Summary

**Backend-owned face-reference governance, DeepFace ArcFace registration/search/verification, and the internal-admin review surface now live in `TRR-Backend`, with legacy donor facebank rows reduced to an explicit bridge.**

## Performance

- **Duration:** 96 min
- **Started:** 2026-04-03T01:11:00Z
- **Completed:** 2026-04-03T02:46:44Z
- **Tasks:** 3
- **Files modified:** 15

## Accomplishments

- Added a Phase 2 retained migration that introduces explicit face-reference review state, duplicate tracking, a legacy donor bridge, and a pgvector HNSW search index.
- Reworked retained face-reference persistence so seed enrollment creates pending-review candidates instead of auto-approved active seeds.
- Added backend-owned DeepFace ArcFace register/search/verify helpers and an internal-admin router for list, review, search, verify, and re-embed operations.
- Tightened retained readers so only approved, active, contract-matching ready embeddings feed identity matching.

## Task Commits

This execute-phase pass was implemented inline without task-by-task git commits.

1. **Task 1: Harden canonical face-reference governance and donor bridge behavior** — added the retained Phase 2 migration and repository review-state semantics, while preserving the existing seed-toggle route.
2. **Task 2: Freeze the DeepFace ArcFace embedding contract and backend search lane** — added `DeepFace`, backend register/search/verify helpers, embedding contract metadata, and consumer filtering.
3. **Task 3: Expose admin identity governance APIs and publish Phase 2 continuity docs** — added internal-admin face-reference routes plus updated local-status and decommission-ledger docs.

## Files Created/Modified

- `TRR-Backend/supabase/migrations/20260403021500_face_reference_identity_reset_phase2.sql` - Adds review-state columns, duplicate tracking, legacy donor bridging, and embedding indexes/backfill.
- `TRR-Backend/trr_backend/repositories/face_references.py` - Owns canonical retained face-reference list/resolve/review/embedding persistence and search helpers.
- `TRR-Backend/trr_backend/services/face_reference_embeddings.py` - Defines the backend DeepFace ArcFace contract and register/search/verify helpers.
- `TRR-Backend/api/routers/admin_face_references.py` - Exposes internal-admin face-reference governance routes.
- `TRR-Backend/trr_backend/vision/people_count_engine.py` - Filters retained identity matches to approved contract-key embeddings only.
- `TRR-Backend/tests/repositories/test_face_references_repository.py` - Covers list/resolve/review-state and vector serialization behavior.
- `TRR-Backend/tests/api/test_admin_face_references.py` - Covers internal-admin identity governance endpoints.
- `TRR-Backend/tests/api/routers/test_admin_person_images.py` - Confirms the existing seed-toggle route still enrolls retained candidates.
- `TRR-Backend/tests/vision/test_people_count_retained_embeddings.py` - Confirms the reader filters by the explicit contract key.
- `TRR-Backend/docs/ai/local-status/cast-screentime-phase2-identity-reset.md` - Documents the Phase 2 identity contract and next-phase handoff.

## Decisions Made

- `ml.face_reference_images` and `ml.face_reference_embeddings` are now the retained face-reference source of truth.
- `screenalytics.face_bank_images` remains only as a donor/bridge source through `legacy_screenalytics_face_bank_image_id`.
- The active v1 embedding contract is `deepface:arcface:retinaface:base:512d:l2_unit`.

## Deviations from Plan

The app layer remained intentionally unchanged in Phase 2. The new admin surface is backend-only for now, and the existing `facebank_seed` app proxy still matches the preserved enrollment contract.

## Issues Encountered

- Adding `DeepFace` expands the backend dependency graph substantially because TensorFlow and related runtime packages are pulled into the retained lockfile.
- The lockfile compile succeeded, but broad backend verification outside the screentime/identity slice still has unrelated pre-existing noise from other areas of the repo.

## User Setup Required

None for code integration. Runtime environments that execute DeepFace-backed routes will need the compiled backend dependency set installed from the updated lockfile.

## Next Phase Readiness

- Phase 2 is ready to hand off to Phase 3 with reviewed retained face references, versioned embeddings, and backend-owned identity/search primitives in place.
- Phase 3 can now port screentime execution onto this identity contract without relying on donor facebank tables as active runtime state.

---
*Phase: 02-identity-reset-embedding-governance*
*Completed: 2026-04-03*

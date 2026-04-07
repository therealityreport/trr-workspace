# Phase 2: Identity Reset & Embedding Governance - Research

**Researched:** 2026-04-03
**Domain:** Backend-owned face reference governance, DeepFace enrollment/search, and ArcFace-class embedding contract freeze
**Confidence:** HIGH

<user_constraints>
## User Constraints (from PROJECT.md, ROADMAP.md, and prior phase decisions)

### Locked Decisions
- `TRR-Backend` is the permanent home of screentime and identity ownership. `screenalytics` is donor code plus a temporary runtime dependency only.
- Phase 1 already fixed `ml.*` as the canonical retained schema direction. Phase 2 must build identity on `ml.face_reference_images` and `ml.face_reference_embeddings`, not on `screenalytics.face_bank_images`.
- The system remains internal admin-first. Phase 2 should favor backend-owned admin APIs and parity-preserving operator flows over public or end-user identity tooling.
- The embedding contract for v1 stays ArcFace-class. DeepFace is the new registration/search/verify orchestration layer, not permission to invent a second active matching standard.
- Direct uploads and external imports remain in scope for the broader project, but Phase 2 is specifically about the face-reference lane, not screentime runtime porting.
- Unreviewed or duplicate face-reference material must not become active matching seeds.
- Operator reviewability matters more than maximizing automation. Enrollment, approval, duplicate control, and provenance are all part of the contract.
- `TRR-APP` should stay minimally changed in Phase 2. Existing person-gallery seed toggles and admin proxies are the parity surface to preserve; full UI cutover belongs later.

### the agent's Discretion
- Exact repository split between repository helpers, service modules, and admin router modules.
- Whether provenance lives entirely in explicit columns, entirely in metadata, or in a hybrid model, as long as provider/model/detector/normalization are explicit and queryable.
- Exact API path layout for review/search/verify/re-embed endpoints.
- Whether backfill from donor facebank rows happens in one migration or via one migration plus one repository/service bridge.

### Deferred Ideas (OUT OF SCOPE)
- Replacing the standalone screentime executor belongs to Phase 3.
- Full TRR-APP review/publication cutover belongs to Phase 4.
- Final removal of `SCREENALYTICS_API_URL` and `SCREENALYTICS_SERVICE_TOKEN` belongs to Phase 5.
- Public identity tools, annotation-studio workflows, and broader multimodal analytics remain out of scope.

</user_constraints>

<research_summary>
## Summary

The repo already contains the beginnings of the right Phase 2 target shape. `TRR-Backend` now owns `ml.face_reference_images` and `ml.face_reference_embeddings`, and the existing person-gallery `facebank_seed` toggle already syncs candidate references into `ml.face_reference_images`. At the same time, the donor implementation still lives in `screenalytics`: `facebank_v2.py` exposes upload/approve/set-seed flows, `facebank.py` manages legacy/manifests plus similarity heuristics, and the DeepFace integration plan explicitly recommends a parallel search layer rather than replacing the existing ArcFace-class runtime lane wholesale.

The main gap is governance, not storage. The retained backend tables exist, but the current enrollment path auto-approves candidate references and there is no backend-owned DeepFace registration/search/verify layer, no explicit duplicate/review controls, and no fully frozen ArcFace-class embedding provenance contract. That means Phase 2 should be built as a backend-first governance phase: formalize review states and donor bridges, add DeepFace-backed embedding generation and ANN/exact search under one contract, and expose admin APIs for listing, reviewing, approving, searching, verifying, and re-embedding references.

The strongest recommendation is to keep the donor/runtime split explicit during this phase. Port the face-reference workflow into backend-owned modules and schemas, but do not entangle that work with screentime run execution. Also do not let DeepFace silently redefine the matching contract; provider/model/model_version/detector/normalization and the active contract key must be explicit so later runtime phases can rely on one stable identity lane.

**Primary recommendation:** Build Phase 2 around backend-owned reference governance plus a DeepFace ArcFace/RetinaFace bridge, with donor backfill from `screenalytics.face_bank_images`, exact-plus-ANN search, and approval/duplicate controls that keep only reviewed references active.
</research_summary>

<standard_stack>
## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| FastAPI | Repo-pinned in `TRR-Backend` | Admin enrollment/review/search/verify route surface | Existing internal admin control plane already lives here |
| PostgreSQL + `pgvector` | Enabled in retained runtime migration | Durable storage for embeddings plus HNSW search | Canonical `ml.face_reference_embeddings.embedding vector(512)` table already exists |
| DeepFace | Planned new backend dependency | Register/search/verify orchestration using ArcFace + RetinaFace semantics | Matches the migration plan and user direction for the reset |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Pytest + FastAPI TestClient | Repo-pinned | Repository, router, and contract verification | Existing backend testing infrastructure already covers related routes and vision loaders |
| Ruff | Repo-pinned | Lint and formatting checks | Phase-scoped validation for new backend identity files |
| Existing `screenalytics` donor docs and services | Current repo state | Source of truth for legacy facebank shape and migration boundaries | Use as donor reference, not as long-term runtime ownership |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Backend-owned DeepFace bridge | Continue calling `screenalytics` facebank endpoints | Keeps the exact split runtime dependency the reset is trying to retire |
| One explicit ArcFace-class contract | Multiple active embedding families in one shared index | High migration risk and ambiguous threshold semantics |
| Review-state gating in `ml.face_reference_images` | Keep using `facebank_seed` as implicit approval | Too weak for duplicate control and operator-reviewable seed governance |

**Installation note:** `pgvector` is already enabled by the retained-runtime migration. `DeepFace` is not currently a `TRR-Backend` dependency and must be added during execution.
</standard_stack>

<architecture_patterns>
## Architecture Patterns

### Recommended Project Structure
```text
TRR-Backend/
├── api/routers/admin_person_images.py
├── api/routers/admin_face_references.py
├── trr_backend/repositories/face_references.py
├── trr_backend/services/face_reference_embeddings.py
├── trr_backend/vision/people_count_engine.py
├── supabase/migrations/
└── docs/ai/local-status/
```

### Pattern 1: Governance-first enrollment
**What:** Treat person-gallery `facebank_seed` as enrollment input, then gate actual active matching through backend-owned review status and duplicate control.
**When to use:** When the UI already has a seed toggle but the system still needs explicit approval and duplicate handling.
**Example direction:**
```python
face_references.sync_face_reference_image(
    link_id=str(link_id),
    enabled=bool(payload.facebank_seed),
)
# Candidate enters `ml.face_reference_images`, but active matching is controlled by review state.
```

### Pattern 2: Explicit embedding contract provenance
**What:** Store provider/model/model_version plus detector/normalization/distance semantics explicitly with each embedding row and filter consumers to one active contract key.
**When to use:** When DeepFace is introduced alongside an existing ArcFace-class runtime lane and threshold reuse must stay safe.
**Example direction:**
```sql
-- Keep 512-d vector storage, but make the contract queryable and enforceable
-- through columns and/or structured metadata.
```

### Pattern 3: ANN retrieval with exact fallback
**What:** Use pgvector HNSW for top-K candidate retrieval but keep exact cosine fallback and operator review semantics above the ANN layer.
**When to use:** When the seed set is growing but recall and auditability still matter more than raw search speed.
**Example direction:**
```python
matches = search_reference_matches(query_embedding, contract_key=ACTIVE_FACE_REFERENCE_CONTRACT)
if not matches or matches[0]["similarity"] < review_band_min:
    matches = exact_reference_matches(query_embedding, contract_key=ACTIVE_FACE_REFERENCE_CONTRACT)
```

### Anti-Patterns to Avoid
- **Auto-approving every enrolled gallery image:** It makes duplicate or low-quality seeds active before review.
- **Mixing old donor embeddings and new DeepFace embeddings in one active index without provenance filtering:** Similarity scores stop meaning the same thing.
- **Using ANN as identity truth:** Candidate retrieval is useful; final acceptance still needs threshold bands and reviewable semantics.
</architecture_patterns>

<dont_hand_roll>
## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Reference candidate review | Ad hoc booleans across multiple tables | One review-state contract on `ml.face_reference_images` | Keeps approval and duplicate semantics queryable and portable |
| Embedding storage | S3-only `.npy` pointers as the canonical search store | `ml.face_reference_embeddings.embedding vector(512)` with provenance | The backend already has a canonical retained embedding table |
| DeepFace integration | Screenalytics-only helper owned by the donor repo | Backend-owned bridge/service module | Avoids preserving the donor runtime dependency unnecessarily |
| Search correctness | ANN-only acceptance | ANN retrieval plus exact fallback and review bands | Preserves trust in borderline matches |

**Key insight:** Phase 2 is mostly about making implicit identity policy explicit. The tables and parity surface already exist; the missing pieces are governance, provenance, and backend-owned search/verify behavior.
</dont_hand_roll>

<common_pitfalls>
## Common Pitfalls

### Pitfall 1: Treating `facebank_seed` as equivalent to “approved active reference”
**What goes wrong:** Every gallery toggle becomes an immediately active seed even if the image is low quality, duplicated, or wrong.
**Why it happens:** The seed toggle is the only existing operator affordance.
**How to avoid:** Preserve the toggle as enrollment input, but make approval and duplicate state explicit in `ml.face_reference_images`.
**Warning signs:** Enrollment code writes `approved = true` and `is_active = true` unconditionally.

### Pitfall 2: Losing provenance when migrating embeddings
**What goes wrong:** Teams know they are storing 512-d vectors, but cannot tell which detector, normalization, or checkpoint produced them.
**Why it happens:** “ArcFace-compatible” sounds good enough until thresholds drift.
**How to avoid:** Persist provider/model/model_version plus detector and normalization semantics, and filter all retrieval consumers to one active contract key.
**Warning signs:** Query code only checks `embedding_status = 'ready'` and ignores model provenance.

### Pitfall 3: Over-scoping the phase into runtime replacement
**What goes wrong:** Face-reference governance work gets entangled with screentime execution porting and becomes impossible to validate cleanly.
**Why it happens:** Both systems use embeddings and donor `screenalytics` logic.
**How to avoid:** Keep Phase 2 focused on enrollment, storage, search, verify, and operator review semantics. Leave screentime executor cutover to Phase 3.
**Warning signs:** The plan starts modifying `retained_cast_screentime_dispatch` or `screenalytics_cast_screentime.py`.
</common_pitfalls>

<code_examples>
## Code Examples

Verified patterns from current repo sources:

### Existing backend-owned enrollment sync
```python
def sync_face_reference_image(*, link_id: str, enabled: bool) -> dict[str, Any] | None:
    ...
    INSERT INTO ml.face_reference_images (
      person_id,
      media_link_id,
      media_asset_id,
      is_active,
      approved,
      embedding_status,
      ...
    )
```

### Existing retained embedding storage target
```sql
create table if not exists ml.face_reference_embeddings (
  id uuid primary key default gen_random_uuid(),
  reference_image_id uuid not null references ml.face_reference_images(id) on delete cascade,
  provider text not null,
  model_name text not null,
  model_version text,
  embedding_status text not null default 'pending',
  embedding vector(512),
  metadata jsonb not null default '{}'::jsonb,
  ...
);
```

### Existing consumer already reading retained embeddings
```python
SELECT
  fri.person_id::text AS person_id,
  p.full_name AS person_name,
  fre.embedding
FROM ml.face_reference_images AS fri
JOIN ml.face_reference_embeddings AS fre
  ON fre.reference_image_id = fri.id
...
WHERE fri.approved = true
  AND fri.is_active = true
  AND fre.embedding_status = 'ready'
```
</code_examples>

<sota_updates>
## State of the Art (2024-2026)

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manifest-owned or file-owned facebank | Database-owned face-reference tables plus pgvector | Modern identity/search systems | Makes stateless search and audit trails possible |
| One-step seed enrollment | Multi-step enrollment with approval and duplicate handling | Current production ML governance practice | Prevents seed-bank pollution and silent matching regressions |
| Unversioned embeddings | Provenance-tagged embeddings with contract keys | Needed once multiple detectors/models are in play | Keeps thresholds and ANN indexes interpretable |

**New tools/patterns to consider:**
- Backend-owned DeepFace bridge with deterministic config and mocks for tests.
- Contract-key filtering for all embedding consumers, including fast-path heuristics that currently only check `ready`.
- Donor bridge columns mirroring Phase 1’s asset bridge pattern for legacy facebank rows.

**Deprecated/outdated:**
- Treating `screenalytics.face_bank_images` as the long-term active source of truth.
- Using gallery seed toggles alone as the approval and duplicate policy.
</sota_updates>

<open_questions>
## Open Questions

1. **Should legacy donor `screenalytics.face_bank_images` rows backfill into `ml.face_reference_images` in the migration or through a service script?**
   - What we know: Phase 1 chose migration-time bridge/backfill for screentime assets, and the donor facebank rows are a real migration input.
   - What's unclear: Whether every donor row has enough linkage to `core.media_links`/`core.media_assets` for a pure SQL backfill.
   - Recommendation: Use a migration for schema plus bridge columns and a deterministic backfill where linkage is safe; leave unresolved edge cases to repository/service reconciliation rather than blocking the phase.

2. **Should newly enrolled gallery seeds start as `pending_review` or stay `approved` until explicit duplicate controls land?**
   - What we know: The current sync path auto-approves, but the requirement says unreviewed or duplicate material cannot become active.
   - What's unclear: How much operator friction is acceptable before Phase 4 UI work.
   - Recommendation: Move new enrollments to `pending_review` in backend semantics now, then expose lightweight admin review endpoints so the contract is correct even before a richer UI arrives.
</open_questions>

<sources>
## Sources

### Primary (HIGH confidence)
- `.planning/PROJECT.md`
- `.planning/REQUIREMENTS.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/phases/01-contract-freeze-asset-foundation/01-01-SUMMARY.md`
- `.planning/phases/01-contract-freeze-asset-foundation/01-VERIFICATION.md`
- `.planning/research/SUMMARY.md`
- `docs/plans/2026-03-22-deepface-integration-plan.md`
- `TRR-Backend/docs/cross-collab/TASK24/PLAN.md`
- `screenalytics/docs/cross-collab/TASK13/PLAN.md`
- `screenalytics/docs/cross-collab/TASK13/STATUS.md`
- `TRR-APP/docs/cross-collab/TASK23/PLAN.md`
- `TRR-Backend/supabase/migrations/20260402183000_create_ml_retained_runtime_tables.sql`
- `TRR-Backend/trr_backend/repositories/face_references.py`
- `TRR-Backend/api/routers/admin_person_images.py`
- `TRR-Backend/trr_backend/vision/people_count_engine.py`
- `screenalytics/apps/api/routers/facebank_v2.py`
- `screenalytics/apps/api/services/facebank.py`
- `screenalytics/docs/reference/facebank.md`
- `TRR-APP/apps/web/src/app/api/admin/trr-api/people/[personId]/gallery/[linkId]/facebank-seed/route.ts`

### Secondary (MEDIUM confidence)
- `TRR-Backend/tests/repositories/test_face_references_repository.py`
- `TRR-Backend/tests/vision/test_people_count_retained_embeddings.py`
- `TRR-Backend/tests/api/routers/test_admin_person_images.py`
- `TRR-Backend/trr_backend/repositories/tagging_references.py`
</sources>

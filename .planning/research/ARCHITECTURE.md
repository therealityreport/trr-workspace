# Architecture Patterns

**Domain:** Internal cast screentime analysis and DeepFace reset
**Researched:** 2026-04-02
**Recommendation:** Consolidate runtime ownership into `TRR-Backend`, keep `TRR-APP` as the admin proxy/UI, move canonical screentime and identity state to `ml.*`, and treat `screenalytics` as donor code plus temporary execution adapter only.
**Overall confidence:** MEDIUM-HIGH

## Decision

Build the retained screentime system as a backend-owned control plane plus backend-owned worker lane, not as a backend that still talks to a separate long-lived Screenalytics service over HTTP.

That means:

- `TRR-Backend` owns API, orchestration, schema, dispatch, review state, and publish state.
- `TRR-APP` keeps the current admin-facing routes and page flows, but continues to talk only to backend-owned admin endpoints.
- `screenalytics` becomes a donor library and migration source for pipeline logic, artifact generation, and metadata helpers.
- `ml.*` becomes the final schema for retained screentime and DeepFace-backed face-reference state.
- `screenalytics.*` stays transitional and read-only once parity is reached.

This is the cleanest cut because the codebase already has the seam started:

- The new retained schema exists in [`TRR-Backend/supabase/migrations/20260402183000_create_ml_retained_runtime_tables.sql`](../../TRR-Backend/supabase/migrations/20260402183000_create_ml_retained_runtime_tables.sql).
- The backend already exposes the admin control plane in [`TRR-Backend/api/routers/admin_cast_screentime.py`](../../TRR-Backend/api/routers/admin_cast_screentime.py).
- The current service split is isolated behind [`TRR-Backend/trr_backend/services/retained_cast_screentime_dispatch.py`](../../TRR-Backend/trr_backend/services/retained_cast_screentime_dispatch.py).
- The app already uses a stable catch-all proxy in [`TRR-APP/apps/web/src/app/api/admin/trr-api/cast-screentime/[...path]/route.ts`](../../TRR-APP/apps/web/src/app/api/admin/trr-api/cast-screentime/[...path]/route.ts).

## Recommended Architecture

```text
TRR-APP admin UI
  -> /api/admin/trr-api/cast-screentime/[...path]
  -> TRR-Backend admin screentime API
      -> Screentime control-plane services
          -> ml.analysis_media_*         (asset intake + candidate cast)
          -> ml.screentime_*            (runs, artifacts, metrics, review, publish)
          -> ml.face_reference_*        (reference images + embeddings)
          -> object storage             (manifests, JSON artifacts, evidence, clips)
          -> backend-owned worker lane  (local / Modal / queue-backed executor)
              -> donor pipeline modules ported from screenalytics
              -> DeepFace-backed seed registration/search
              -> ArcFace-class frame matching during migration

Temporary migration seam only:
TRR-Backend retained dispatch adapter
  -> screenalytics internal HTTP + Celery worker
```

### Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|----------------|-------------------|
| `TRR-APP` admin pages | Operator workflows for intake, run creation, review, clip generation, approval, publish, rerun | Backend admin proxy routes only |
| App admin proxy | Preserve stable app-facing route contract and auth boundary | `TRR-Backend` admin endpoints |
| Backend screentime API | Validate admin actions, expose run/read/review/publish endpoints, keep app contract stable | Backend repositories and orchestration services |
| Backend intake service | Create upload/import sessions, verify/promote source media, derive owner scope and candidate cast | `ml.analysis_media_*`, object storage, metadata helpers |
| Backend run orchestrator | Create runs, merge config, dispatch execution, reconcile stale runs, manage reruns | `ml.screentime_runs`, worker adapter, review state |
| Backend identity service | Manage face reference images, DeepFace embedding jobs, ANN search, verification, model partitioning | `ml.face_reference_images`, `ml.face_reference_embeddings`, pgvector, object storage |
| Backend worker lane | Localize video, run analysis, emit artifacts/evidence/metrics, finalize run | `ml.screentime_*`, object storage, backend-owned pipeline package |
| Review/publication service | Persist decisions, unknown-review state, reference fingerprints, published rollups | `ml.screentime_review_state`, `ml.screentime_publications`, `ml.screentime_reference_fingerprints` |
| Transitional adapter | Keep current `screenalytics` service callable while backend-owned worker parity lands | `screenalytics` HTTP routes and Celery only during migration |

## Canonical Data Ownership

### Final canonical schema

Use the new `ml.*` schema as the end-state source of truth.

| Schema/table family | Owns | Why |
|---------------------|------|-----|
| `ml.analysis_media_*` | Upload sessions, promoted analysis assets, cast candidate snapshots | This is already backend-shaped control-plane state, not generic Screenalytics state |
| `ml.screentime_runs` + related tables | Runs, artifacts, segments, evidence, exclusions, review state, publications, reference fingerprints, unknown clusters | These are the retained runtime entities the app and backend need long term |
| `ml.face_reference_images` | Canonical face reference image registry linked to TRR media links/assets | It ties identity state directly to TRR-owned media and avoids separate facebank manifests |
| `ml.face_reference_embeddings` | Provider/model-specific embeddings and ANN-searchable vectors | It supports DeepFace + pgvector cleanly and keeps model lineage explicit |
| `core.*` | Shows, seasons, episodes, people, media links/assets | Shared canonical metadata remains backend-owned |

### Transitional schema

`screenalytics.*` should be treated as migration input, not final design:

- `screenalytics.runs_v2`
- `screenalytics.video_assets`
- `screenalytics.cast_screentime_*`
- `screenalytics.face_bank_images`

Those tables are useful for parity and backfill, but the new `ml.*` schema is better aligned with backend ownership and app-facing control-plane responsibilities.

## Data Flow

### 1. Face reference and DeepFace seed flow

1. Operator marks or uploads candidate face reference media from the existing people/gallery admin flows in `TRR-APP`.
2. `TRR-APP` proxies to backend-owned face-reference endpoints, not to `screenalytics`.
3. Backend writes the canonical image row to `ml.face_reference_images`, keyed to `core.media_links` and `core.media_assets`.
4. A backend-owned embedding job runs DeepFace against the approved image, writing one row per `(provider, model_name, model_version)` into `ml.face_reference_embeddings`.
5. pgvector indexes the embedding column for ANN lookup.
6. Search and verification endpoints query only embeddings for the active model partition. If ANN misses or confidence is ambiguous, exact search/verification is used as fallback.
7. Result summaries, not raw model internals, flow back to the app.

Architecture implication:

- DeepFace is the registration/search layer.
- It should not be the app-facing system of record.
- Model lineage must be persisted in the DB so ArcFace-compatible migration and rollback stay possible.

### 2. Media intake and run creation flow

1. Operator uploads media directly or imports from YouTube/external URL using the current app screentime page.
2. `TRR-APP` forwards to backend admin screentime routes.
3. Backend creates `ml.analysis_media_upload_sessions`, verifies the object, and promotes it into `ml.analysis_media_assets`.
4. Backend derives candidate cast from `core.v_episode_cast`, `core.v_season_cast`, or explicit override logic and stores both:
   - normalized candidates in `ml.analysis_media_cast_candidates`
   - immutable snapshot JSON on `ml.screentime_runs`
5. Backend creates `ml.screentime_runs` with run config, candidate scope policy, and coverage summary.
6. Backend dispatches execution through a worker port, not directly through app code.

### 3. Run execution and artifact flow

1. Worker loads run contract and localized source media from `ml.*` plus object storage.
2. Worker runs the donor pipeline logic ported from `screenalytics`, producing:
   - `manifest.json`
   - `segments.json`
   - `shots.json`
   - `scenes.json`
   - `excluded_sections.json`
   - `person_metrics.json`
   - suggestion and unknown-review artifacts
   - evidence stills and generated clips
3. Worker uploads immutable artifacts to object storage using stable run-scoped keys.
4. Worker writes normalized run state into:
   - `ml.screentime_artifacts`
   - `ml.screentime_segments`
   - `ml.screentime_evidence`
   - `ml.screentime_person_metrics`
   - `ml.screentime_unknown_clusters`
5. Worker finalizes `ml.screentime_runs` with status, heartbeat, effective runtime, and manifest pointer.
6. Backend API serves the review surface entirely from `ml.*` plus artifact objects.

### 4. Review, decision, and publish flow

1. Operator opens run details in `TRR-APP`.
2. App requests leaderboard, segments, evidence, exclusions, artifact payloads, and decision state through backend-only routes.
3. Review decisions are stored separately from immutable run outputs:
   - suggestions and unknown-review decisions live in `ml.screentime_review_state`
   - run status/review progression lives on `ml.screentime_runs`
4. Publish writes a new row to `ml.screentime_publications` and stores reference fingerprints in `ml.screentime_reference_fingerprints`.
5. Aggregated show/season rollups read only current publication rows.

This separation is important: review state is mutable; raw run outputs are not.

## Migration Seams

### Seam 1: Dispatch seam

Current seam:

- `TRR-Backend` calls `retained_cast_screentime_dispatch`
- that delegates to `screenalytics_cast_screentime`
- which posts to `SCREENALYTICS_API_URL`

Keep that interface, but change the implementation in phases:

1. `retained_cast_screentime_dispatch` calls current `screenalytics` HTTP runtime.
2. Replace implementation with a backend-owned queue/executor adapter.
3. Remove `SCREENALYTICS_API_URL` and `SCREENALYTICS_SERVICE_TOKEN` once no route uses the external service.

This is the cleanest migration cut line because the app never sees it.

### Seam 2: Schema seam

Do not “flip” from `screenalytics.*` to `ml.*` in one step.

Use:

1. one-time backfill from `screenalytics.face_bank_images` to `ml.face_reference_*`
2. one-time backfill from `screenalytics.runs_v2` and related artifact tables to `ml.screentime_*` for retained runs
3. backend read/write switch flags so new runs go to `ml.*` while historical reads can still bridge to `screenalytics.*` during migration

Cut line:

- new writes: `ml.*`
- historical compatibility reads: bridge layer only
- no new product features on `screenalytics.*`

### Seam 3: Artifact seam

Keep artifact filenames and semantic payloads stable during migration:

- `manifest.json`
- `segments.json`
- `scenes.json`
- `excluded_sections.json`
- `person_metrics.json`
- evidence stills/clips

This avoids rewriting the app review surface while the runtime moves.

### Seam 4: Identity seam

The existing S3 manifest-based facebank store in `screenalytics/apps/api/services/facebank_store.py` should become read-only compatibility code during migration.

Target cut:

- canonical reference inventory: `ml.face_reference_images`
- canonical embeddings: `ml.face_reference_embeddings`
- optional compatibility importer: legacy `screenalytics.face_bank_images` plus manifest blobs

### Seam 5: App contract seam

Keep these app contracts stable until after runtime consolidation:

- `/api/admin/trr-api/cast-screentime/[...path]`
- `/api/admin/trr-api/people/[personId]/gallery/[linkId]/facebank-seed`
- `/screenalytics` picker and handoff into show workspaces

The app should not need to know whether execution is happening in `screenalytics`, in-process backend workers, or a backend-owned remote executor.

## Suggested Build Order

1. **Lock the schema cut**
   - Make `ml.*` the target canonical schema.
   - Add any missing indexes, constraints, and compatibility views before moving runtime code.
   - Rationale: every later phase depends on stable storage contracts.

2. **Build backend-owned repositories and ports**
   - Create backend domain modules for:
     - screentime runs
     - face references
     - embedding/search
     - artifact registry
     - review/publication
   - Keep API handlers thin.
   - Rationale: this isolates the system from both the old `screenalytics` service shell and giant route files.

3. **Migrate face references and DeepFace search first**
   - Backfill `screenalytics.face_bank_images` and legacy manifest data into `ml.face_reference_*`.
   - Stand up backend-owned seed registration, embedding generation, ANN search, and verification.
   - Rationale: screentime matching quality depends on this foundation, and it is independently testable before full video execution moves.

4. **Port the screentime execution engine behind the dispatch interface**
   - Keep `retained_cast_screentime_dispatch` as the port.
   - Replace its `screenalytics` HTTP implementation with a backend-owned job executor.
   - Reuse donor pipeline code from `screenalytics/apps/api/services/cast_screentime.py` and `screenalytics/packages/py-screenalytics/`.
   - Rationale: this removes the service split without forcing an app/API rewrite.

5. **Switch backend reads and writes from `screenalytics.*` to `ml.*`**
   - Move admin routes, stale-run reconciliation, publish logic, and review state to read from `ml.*`.
   - Keep fallback bridges for historical runs only.
   - Rationale: once execution is backend-owned, the backend should stop depending on transitional tables.

6. **Finish TRR-APP parity and cleanup**
   - Keep the same route shapes, but update copy and page assumptions from “screenalytics” runtime to “analysis” runtime where appropriate.
   - Add any missing UI affordances for DeepFace search, embedding status, and rerun-needed signals.
   - Rationale: app work should be last because the current proxy boundary is already sufficient.

7. **Retire the standalone Screenalytics topology**
   - Remove backend HTTP clients, service token dependency, Celery-only execution assumptions, and Streamlit-only operator flows.
   - Preserve the donor package or copy the necessary modules into backend-owned packages.

## Patterns To Follow

### Pattern 1: Backend-owned ports and adapters

**What:** Define narrow interfaces for dispatch, artifact storage, embedding/search, and metadata hydration.

**When:** Any place current backend code still reaches across a service boundary or depends on Screenalytics implementation details.

**Use because:** It lets you replace the service shell without rewriting app contracts.

### Pattern 2: Immutable run outputs, mutable review state

**What:** Keep artifacts and normalized segment/evidence/metric rows immutable per run; store operator decisions separately.

**When:** Review, approval, unknown-resolution, and publish workflows.

**Use because:** It preserves trust and makes reruns explicit instead of silently rewriting history.

### Pattern 3: Model-partitioned embeddings

**What:** Every embedding row carries provider, model name, and version; searches only compare compatible embeddings.

**When:** DeepFace reset, ArcFace compatibility, re-embedding migrations, rollback.

**Use because:** mixing embeddings from different checkpoints in one ANN space is a correctness bug, not a tuning choice.

### Pattern 4: Artifact-first reviewability

**What:** Persist machine-readable JSON artifacts plus evidence media before exposing a run as reviewable.

**When:** All successful runs, including supplementary assets.

**Use because:** the product value is auditable screentime, not just totals.

## Anti-Patterns To Avoid

### Anti-Pattern 1: Backend loopback over HTTP after consolidation

**What:** A backend-owned worker posting back into backend HTTP endpoints once both sides live in the same retained runtime.

**Why bad:** It keeps unnecessary auth, transport, and failure modes after the service boundary is gone.

**Instead:** Call repositories/services directly inside the backend worker lane; reserve HTTP only for app and true external callers.

### Anti-Pattern 2: Leaving `screenalytics.*` as the long-term canonical schema

**What:** Continuing to build new features on transitional Screenalytics-owned tables after `ml.*` exists.

**Why bad:** It preserves ownership ambiguity and makes final retirement harder.

**Instead:** Freeze `screenalytics.*` after backfill and move forward on `ml.*`.

### Anti-Pattern 3: Treating DeepFace as the whole video runtime

**What:** Replacing the entire frame-processing pipeline with raw DeepFace calls in one step.

**Why bad:** It couples identity reset with full vision-engine replacement and raises migration risk unnecessarily.

**Instead:** Use DeepFace for seed registration/search/verification first, while keeping ArcFace-class frame matching compatibility during migration.

### Anti-Pattern 4: Binding app pages to storage keys or raw artifact formats

**What:** Letting `TRR-APP` infer runtime behavior from S3 keys, legacy prefixes, or donor-specific JSON structure.

**Why bad:** It hard-codes transitional internals into the admin surface.

**Instead:** Backend returns typed review payloads and artifact metadata; storage details stay server-side.

## Failure Modes And Containment

| Failure mode | Likely cause | First containment move |
|--------------|--------------|------------------------|
| DeepFace ANN results drift from ArcFace expectations | Mixed models or bad backfill | Partition by model, fall back to exact verification, keep previous embedding set active |
| Worker crashes after artifact upload but before finalize | Long-running compute or transient storage/DB failure | Use heartbeat + stale-run reconciliation and make finalization idempotent |
| Partial migration leaves reads split across schemas | Dual-write/backfill mismatch | Add per-surface read switch and compare `screenalytics.*` vs `ml.*` results before cutover |
| App review page breaks during migration | Artifact payload drift | Freeze artifact contract and add compatibility serializers in backend |
| Queue/executor instability during cutover | Replacing Celery/service topology too early | Keep dispatch adapter stable and swap backend executor behind it only after repository parity |

## Why This Architecture Wins

### Recommended

`TRR-Backend` owns control plane plus worker lane, `ml.*` is canonical, and `screenalytics` becomes donor code only.

**Strengths:**

- Matches existing repo ownership rules and app flow.
- Removes the most brittle dependency: backend -> external Screenalytics HTTP runtime.
- Preserves reviewable artifacts and publish history.
- Uses the already-created `ml.*` schema instead of inventing another migration path.
- Gives DeepFace a clean role: reference-image registration and search, not whole-system sprawl.

### Alternative rejected: keep the split service topology

**Why not:** The current split already causes duplicated schemas, service-token coupling, dispatch indirection, and transitional runtime drift. It is acceptable only as a migration bridge.

### Alternative rejected: port everything directly into giant backend routers

**Why not:** The workspace already has large, fragile route modules. Screentime reset work must land behind domain services and repository boundaries or it will recreate the same maintenance problem inside `TRR-Backend`.

## Scalability Considerations

| Concern | At 100 users | At 10K users | At 1M users |
|---------|--------------|--------------|-------------|
| Admin API load | Single backend instance with local workers is acceptable | Separate API and worker concurrency knobs; cached artifact metadata reads | Dedicated job plane plus background aggregation and observability required |
| Vector search | Exact search fallback tolerable | pgvector HNSW search should be default for active embedding set | Shard/search strategy may need per-show or per-model partitioning and hot/cold embedding policies |
| Artifact storage | Run-scoped object storage prefixes are fine | Need lifecycle/TTL policies for evidence and clips | Must tier evidence retention and avoid loading large JSON artifacts in hot request paths |
| Reruns and publish history | Manual review loop is manageable | Need explicit rerun queues and diff tooling | Need stronger publication/version governance and backpressure on expensive reruns |

## Sources

### Internal repo evidence

- `TRR-Backend/api/routers/admin_cast_screentime.py`
- `TRR-Backend/trr_backend/services/retained_cast_screentime_dispatch.py`
- `TRR-Backend/trr_backend/clients/screenalytics_cast_screentime.py`
- `TRR-Backend/trr_backend/repositories/cast_screentime.py`
- `TRR-Backend/supabase/migrations/20260402183000_create_ml_retained_runtime_tables.sql`
- `TRR-Backend/supabase/migrations/0181_cast_screentime_control_plane.sql`
- `TRR-Backend/supabase/migrations/0183_cast_screentime_publish_and_flashbacks.sql`
- `TRR-Backend/supabase/migrations/0185_cast_screentime_review_state_and_title_refs.sql`
- `screenalytics/apps/api/services/cast_screentime.py`
- `screenalytics/apps/api/routers/cast_screentime.py`
- `screenalytics/apps/api/services/facebank_store.py`
- `screenalytics/apps/api/services/trr_metadata_db.py`
- `screenalytics/apps/api/services/trr_ingest.py`
- `TRR-APP/apps/web/src/app/api/admin/trr-api/cast-screentime/[...path]/route.ts`
- `TRR-APP/apps/web/src/app/api/admin/trr-api/people/[personId]/gallery/[linkId]/facebank-seed/route.ts`

### External verification

- DeepFace official GitHub README: database-backed `register` / `search`, ANN search, and supported vector backends including pgvector and postgres  
  https://github.com/serengil/deepface
  Confidence: HIGH

- Supabase vector index guidance: pgvector supports HNSW and IVFFlat; Supabase recommends HNSW for performance and changing data robustness  
  https://supabase.com/docs/guides/ai/going-to-prod
  https://supabase.com/docs/guides/ai/vector-indexes
  Confidence: HIGH

## Implementation Owner Handoff

- `TRR-Backend`: Own schema cutover, domain services, DeepFace integration, worker consolidation, and final removal of Screenalytics service dependencies.
- `screenalytics`: Provide donor extraction only. No new long-term service investment.
- `TRR-APP`: Preserve admin flow parity and add any DeepFace/search status UI after backend contracts settle.

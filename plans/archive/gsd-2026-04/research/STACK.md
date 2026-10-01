# Technology Stack

**Project:** TRR Cast Screentime Reset
**Researched:** 2026-04-02

## Recommended Stack

The reset should keep the existing TRR split of responsibilities where `TRR-Backend` owns API, orchestration, and runtime contracts, `TRR-APP` owns admin workflows, and object storage owns binary media. The key change is to collapse the standalone `screenalytics` runtime into backend-owned worker lanes instead of preserving a second service shell.

The correct 2026 shape for this system is:
- `TRR-Backend` FastAPI control plane for intake, run creation, review APIs, and internal auth
- Supabase Postgres as the durable system of record
- `pgvector` in Postgres for seed ANN lookup and verification support
- Modal for long-running CPU/GPU execution, with Postgres as the durable job ledger
- S3-compatible object storage for source video, evidence frames, and generated clips
- DeepFace for seed registration/search/verification only
- Existing ArcFace-class embedding lane preserved as the canonical matching baseline during migration
- `TRR-APP` existing admin UI as the only operator surface

### Core Framework

| Technology | Version / maturity note | Purpose | Why | Confidence |
|------------|--------------------------|---------|-----|------------|
| FastAPI | Keep the repo’s validated FastAPI line; do not do a framework upgrade inside the reset | Backend-owned admin/control-plane API | FastAPI remains the right fit for internal admin APIs, but its own docs still treat `BackgroundTasks` as a small-task mechanism and recommend real workers for heavy computation. This reset is exactly a real-worker problem, not a `BackgroundTasks` problem. | HIGH |
| Next.js in `TRR-APP` | Keep existing app line | Admin-first review and correction UI | The admin workflows already live here. Reintroducing Streamlit would recreate the split-brain operator surface the reset is meant to remove. | HIGH |

### Database

| Technology | Version / maturity note | Purpose | Why | Confidence |
|------------|--------------------------|---------|-----|------------|
| Supabase Postgres | Keep current shared operational Postgres | Canonical run, artifact, review, and asset metadata store | The system already uses shared Postgres across repos. Screentime runs, evidence, review decisions, and asset lineage are transactional application data, so they belong in the main database, not in separate pipeline state stores. | HIGH |
| `pgvector` extension | Require Supabase `vector` extension on `0.7.0+` | ANN lookup for seed embeddings | Supabase and pgvector both now treat HNSW as the default ANN index choice. A 512-d ArcFace-class embedding fits comfortably inside the supported dimension limits. This keeps search inside the system of record instead of creating a parallel vector service. | HIGH |

### Infrastructure

| Technology | Version / maturity note | Purpose | Why | Confidence |
|------------|--------------------------|---------|-----|------------|
| Modal | Use the current repo-supported Modal line; keep execution stateless and externally durable | Remote CPU/GPU workers for video and face workloads | Modal’s current job-processing pattern is a strong fit for backend-owned long-running work: spawn work from the API, poll results, and scale out only when needed. This matches the existing TRR direction better than rebuilding Celery/Redis inside `TRR-Backend`. | HIGH |
| S3-compatible object storage | Keep existing backend abstraction; R2 is acceptable if already provisioned | Canonical source video mirror, evidence frames, derived clips, debug artifacts | Video assets and review artifacts are large binary objects. They do not belong in Postgres. Keeping the existing object-storage abstraction avoids a simultaneous storage migration. | HIGH |
| `ffmpeg` + `ffprobe` CLI | Pin at the container/image layer, not through Python wrapper drift | Decode, probe, clip extraction, frame sampling, artifact rendering | This is the standard toolchain for deterministic video work. Use CLI invocations as the canonical media path and keep OpenCV as a convenience library, not the source of truth for metadata. | HIGH |

### Face / Vision Layer

| Library | Version / maturity note | Purpose | When to Use | Confidence |
|---------|--------------------------|---------|-------------|------------|
| DeepFace | `0.0.99` is current on PyPI as of 2026-03-01; validate postgres/pgvector packaging during lockfile work because the latest release notes mention postgres dependency changes | Seed registration, seed search, pairwise verification, seed QA | Use for facebank flows only. Force `model_name="ArcFace"` and `detector_backend="retinaface"` for seed registration/search/verify. Do not accept its default `VGG-Face` model or default OpenCV detector. | HIGH |
| InsightFace donor lane | Keep current donor model lane only until migration parity is proven | Existing ArcFace-class embedding provenance and face analysis donor logic | Keep this lane for compatibility and re-embedding validation while the new backend-owned runtime comes online. Treat it as compatibility infrastructure, not the future operator-facing service. | MEDIUM |
| ONNX Runtime | Pin to the version already validated against current donor models | CPU inference baseline for face pipelines | Use as the default portable inference path. It is the safest way to keep model execution reproducible across local and remote workers. | MEDIUM |
| TensorRT donor path | Optional acceleration, not a reset dependency | Performance optimization for high-throughput embedding lanes | Keep it as a later optimization path. Making TensorRT required on day one would turn the reset into an infrastructure migration. | MEDIUM |
| OpenCV headless | Current stable line, pinned with the ML environment | Crop/extract helpers and fallback image operations | Useful for image ops and selected fallback paths, but not as the canonical detector for seed registration or the primary source of video metadata. | HIGH |

## Prescriptive Design Decisions

### 1. Canonical runtime shape

Use `TRR-Backend` as the single runtime owner:
- FastAPI accepts intake and run orchestration requests.
- Postgres records durable run state.
- Modal executes long-running work.
- Object storage holds binaries.
- `TRR-APP` reviews and corrects results.

Do not preserve a second long-lived `screenalytics` API, worker, or UI process after parity.

### 2. Canonical embedding contract

Store one canonical embedding family for the seed ANN index:
- 512-d normalized ArcFace-class vectors
- explicit columns for `embedding_family`, `embedding_model_name`, `embedding_version`, `detector_backend`, and normalization profile
- one active ANN index per embedding family/version

Do not mix existing donor ArcFace vectors and newly generated DeepFace ArcFace vectors in the same index unless they are proven numerically compatible. DeepFace’s own docs note that results can differ because of detection, normalization, and reimplementation choices. The safe migration is re-embed into one canonical family and cut over cleanly.

### 3. Search/indexing choice

Use Postgres + `pgvector` + HNSW:
- `vector(512)` column
- cosine distance operator class
- HNSW index
- Postgres remains the durable source of truth

Do not make FAISS the primary index of record. DeepFace documents pgvector as a backend that handles indexing internally, and Supabase now recommends HNSW as the default vector index. FAISS is only justified as an optional benchmark or later accelerator, not as the canonical store.

### 4. DeepFace scope

Use DeepFace only where it is strongest for this reset:
- `register` for seed ingestion
- `search` for candidate lookup
- `verify` for pairwise confirmation
- optional seed quality checks

Do not use DeepFace as the wholesale replacement for the existing frame-by-frame screentime pipeline in the first reset milestone. That would change the operator UX, the service boundary, and the embedding baseline all at once.

### 5. Worker durability

Persist job truth in Postgres:
- requested
- queued
- running
- produced artifacts
- review required
- accepted/rejected
- rerun lineage

Use Modal to execute jobs, not to own durable job state. Modal’s own Queue docs say queues are backed by replicated in-memory storage, are cleared after inactivity, and should not be relied on for persistence. That makes Modal an execution fabric, not the source of truth.

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Runtime ownership | Backend-owned FastAPI + Modal workers | Preserve standalone `screenalytics` FastAPI/Celery service | Keeps the exact topology the reset is meant to retire: duplicated env contracts, extra service auth, extra deployment surface, and continued app/backend proxy indirection. |
| Async execution | Modal `.spawn()` / function-call pattern with Postgres job ledger | Celery + Redis | Celery solves the wrong problem here. It recreates a donor-era ops stack and adds more moving parts than the existing TRR backend needs. |
| Durable queue state | Postgres tables | Modal Queue / Redis as truth | Modal Queue is not positioned as persistent storage, and Redis would reintroduce a separate runtime dependency just to track work already modeled in the database. |
| Vector store | Supabase Postgres + `pgvector` HNSW | Separate FAISS service or file index | FAISS adds a second index lifecycle and weakens transactional traceability. The system already has Postgres, and pgvector is now the standard path for this size of internal seed search workload. |
| Seed model in DeepFace | `ArcFace` | DeepFace default `VGG-Face` | The default breaks the compatibility goal. The reset explicitly needs ArcFace-class preservation. |
| Seed detector in DeepFace | `retinaface` | DeepFace default OpenCV detector | DeepFace documents RetinaFace/MTCNN as the more accurate path and OpenCV/SSD as the speed-biased path. Seed registration is an accuracy problem, not a speed problem. |
| Operator surface | Existing `TRR-APP` admin flows | Streamlit workspace UI | Streamlit would split auth, reviews, and reruns across two control planes. The reset should converge, not diversify. |
| Media metadata path | `ffprobe` / `ffmpeg` CLI | OpenCV-only metadata probing | `ffprobe` is the right canonical media probe. OpenCV is fine as a fallback utility, but it should not define the truth for duration, fps, or clip generation. |

## What Not To Use During The Reset

- Do not keep `SCREENALYTICS_API_URL` or `SCREENALYTICS_SERVICE_TOKEN` as first-class runtime dependencies after parity.
- Do not ship a new Streamlit admin path.
- Do not make Redis a required production dependency for screentime v1.
- Do not trust DeepFace defaults. Its default model is `VGG-Face`, and its default detector is OpenCV; both are wrong for this migration.
- Do not mix embedding families or checkpoints in one ANN index.
- Do not turn TensorRT into a prerequisite for the first backend-owned release.
- Do not broaden reliance on pretrained InsightFace model packs without license review. The current InsightFace project states that training data and trained models are non-commercial-research only by default and now directs users to contact them for licensing of open-sourced face recognition models such as `buffalo_l`.

## Suggested Package Set

Exact pins should be validated in repo lockfiles, but the reset stack should be built around a package set like:

```bash
# backend runtime
uv add fastapi modal boto3 pydantic-settings numpy pillow

# face / vector / media lane
uv add deepface onnxruntime opencv-python-headless pgvector

# keep existing donor-compatible lane until cutover is complete
uv add insightface
```

If new backend-owned DB helpers need typed vector I/O, add a modern Postgres client in the implementation phase rather than coupling that decision to the research phase.

## Confidence Notes

- **High confidence:** Backend-owned FastAPI control plane, Postgres + pgvector HNSW, Modal execution, object storage for binaries, `TRR-APP` as the only operator surface.
- **High confidence:** DeepFace is appropriate for seed registration/search/verification, but only when explicitly pinned to ArcFace + RetinaFace behavior.
- **Medium confidence:** The exact donor path for ArcFace compatibility between existing InsightFace embeddings and DeepFace ArcFace embeddings still needs migration testing; do not assume numerical interchangeability.
- **Medium confidence:** InsightFace licensing constraints are material enough that legal/procurement review should happen before the reset broadens usage of those model packs.

## Sources

- Local project context:
  - `/Users/thomashulihan/Projects/TRR/.planning/PROJECT.md`
  - `/Users/thomashulihan/Projects/TRR/.planning/codebase/STACK.md`
  - `/Users/thomashulihan/Projects/TRR/.planning/codebase/INTEGRATIONS.md`
  - `/Users/thomashulihan/Projects/TRR/docs/plans/2026-03-22-deepface-integration-plan.md`
  - `/Users/thomashulihan/Projects/TRR/screenalytics/docs/cross-collab/TASK13/PLAN.md`
  - `/Users/thomashulihan/Projects/TRR/TRR-Backend/docs/cross-collab/TASK24/PLAN.md`
  - `/Users/thomashulihan/Projects/TRR/TRR-APP/docs/cross-collab/TASK23/PLAN.md`
- FastAPI background task caveat: https://fastapi.tiangolo.com/tutorial/background-tasks/
- DeepFace PyPI page (`0.0.99`, released 2026-03-01): https://pypi.org/project/deepface/
- DeepFace README (model defaults, search/register backends, detector guidance): https://github.com/serengil/deepface/blob/master/README.md
- DeepFace releases: https://github.com/serengil/deepface/releases
- pgvector docs: https://github.com/pgvector/pgvector
- Supabase vector indexes overview: https://supabase.com/docs/guides/ai/vector-indexes
- Supabase HNSW indexes: https://supabase.com/docs/guides/ai/vector-indexes/hnsw-indexes
- Modal job processing: https://modal.com/docs/guide/job-queue
- Modal queues durability caveat: https://modal.com/docs/guide/queues
- InsightFace repository and licensing note: https://github.com/deepinsight/insightface

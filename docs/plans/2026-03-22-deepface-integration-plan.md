# DeepFace v0.9.7 Integration Plan — TRR Screenalytics

**Date:** 2026-03-22
**Scope:** Integrate DeepFace's new `register` / `build_index` / `search` pipeline into the existing TRR face bank workflow for managing seeded reference images.

---

## Current State

The TRR Screenalytics pipeline already has a mature face recognition stack:

- **Detection:** RetinaFace via InsightFace (`antelopev2`, `buffalo_l`, `buffalo_s`)
- **Embedding:** ArcFace R100 V1 → 512-d L2-normalized vectors, TensorRT (fp16) with PyTorch fallback
- **Storage:** Supabase Postgres (`screenalytics.face_bank_images`) + S3/MinIO for artifacts
- **Matching:** Cosine similarity with configurable thresholds (`VISION_FACE_MATCH_SIMILARITY_MIN=0.73`)
- **Seed system:** `is_seed` boolean on `face_bank_images`, facebank manifests in S3, `facebank_v2` REST API
- **S3 layout:** `{prefix}/inputs/facebank/{person_id}/{image_id}/` with `original.jpg`, `aligned_112x112.jpg`, `embedding.npy`

There's also a legacy manifest-based store (`facebank_store.py`) that keeps per-cast facebank manifests as JSON in S3 with embeddings stored inline. The DB table (`face_bank_images`) is the newer canonical source.

**Key gap:** Identity search is brute-force (O(n) cosine similarity against all seeds). There's no ANN indexing, no database-backed stateless search, and the REST API can't expose `find`-style search because it's stateful.

---

## Why DeepFace v0.9.7

DeepFace's new `register`/`build_index`/`search` functions solve problems the current stack has:

1. **Stateless search** — No pickle files or in-memory state. Search can be exposed via REST API.
2. **ANN indexing** — O(log n) search via FAISS, critical as face bank grows past 10K embeddings.
3. **Database backends** — Native Postgres and pgvector support, which aligns with the existing Supabase stack.
4. **Multi-model support** — Can run Facenet, VGG-Face, ArcFace, etc. side-by-side for ensemble decisions.

---

## Integration Strategy: Parallel Engine, Not Replacement

**Do not replace** the existing InsightFace/ArcFace pipeline. Instead, run DeepFace as a **parallel search/verification layer** specifically for the face bank seed workflow.

### Rationale

- The existing TensorRT-accelerated ArcFace pipeline is optimized for high-throughput video frame processing. Ripping it out is high risk for low gain.
- DeepFace's value is in its new **database-backed search** and **ANN indexing** — features the current stack lacks.
- The seed registration and lookup workflow is a clean integration point with clear boundaries.

---

## Architecture

```
┌─────────────────────────────────────┐
│         Existing Pipeline           │
│  (video frames → detection →        │
│   alignment → ArcFace embedding →   │
│   cosine match against seeds)       │
└──────────────┬──────────────────────┘
               │ query embedding (512-d)
               ▼
┌─────────────────────────────────────┐
│     DeepFace Search Layer (NEW)     │
│                                     │
│  Postgres/pgvector ← register()     │
│  FAISS index      ← build_index()  │
│  ANN search       ← search()       │
│                                     │
│  Exposed via Screenalytics REST API │
└─────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│   screenalytics.face_bank_images    │
│   (existing Supabase table)         │
│   + new: embedding vector column    │
│   + new: deepface_model_name col    │
└─────────────────────────────────────┘
```

---

## Implementation Phases

### Phase 1: pgvector + Schema Extension

**Goal:** Enable vector storage natively in Supabase so DeepFace can use it as a backend.

**Tasks:**

1. Enable the `pgvector` extension in Supabase (it's already available on Supabase, just needs `CREATE EXTENSION vector`).

2. Add an embedding vector column to `screenalytics.face_bank_images`:
   ```sql
   ALTER TABLE screenalytics.face_bank_images
     ADD COLUMN embedding vector(512),
     ADD COLUMN model_name text DEFAULT 'ArcFace';
   ```

3. Backfill: read existing `s3_embedding_key` `.npy` files and write the vectors into the new column. This eliminates the S3 round-trip for search and lets pgvector index them.

4. Create an IVFFlat or HNSW index:
   ```sql
   CREATE INDEX face_bank_embedding_idx
     ON screenalytics.face_bank_images
     USING hnsw (embedding vector_cosine_ops);
   ```

**Why pgvector over standalone FAISS:** The embeddings already live in Supabase Postgres. pgvector keeps everything in one database, avoids a separate FAISS index lifecycle, and DeepFace v0.9.7 supports pgvector as a backend (no `build_index()` call needed — indexing is internal).

---

### Phase 2: DeepFace Seed Registration Service

**Goal:** Wire `DeepFace.register()` into the existing seed upload flow.

**Current flow** (in `facebank_v2.py`):
1. Admin uploads image via presigned S3 URL
2. Image stored at `s3_original_key`
3. Alignment + embedding computed separately (or manually triggered)
4. Row inserted into `face_bank_images`

**New flow:**
1. Admin uploads image (same presigned URL flow)
2. **New step:** Call `DeepFace.register(img=<s3_url>, database_type="pgvector")` which:
   - Detects the face
   - Extracts the embedding (using configured model)
   - Writes the embedding directly to Postgres via pgvector
3. Row in `face_bank_images` now has the `embedding` column populated automatically
4. `is_seed = True` set via existing `set-seed` endpoint

**Integration point:** Add a `deepface_register()` helper in a new module `screenalytics/services/deepface_bridge.py` that wraps the DeepFace call and maps it to the existing DB schema.

**Config additions to `.env`:**
```
DEEPFACE_MODEL_NAME=ArcFace          # or Facenet512 for 512-d compatibility
DEEPFACE_DETECTOR_BACKEND=retinaface # match existing detector
DEEPFACE_DATABASE_TYPE=pgvector
DEEPFACE_DB_URL=${SUPABASE_DB_URL}
```

---

### Phase 3: ANN Search Endpoint

**Goal:** Expose DeepFace's stateless search via the Screenalytics REST API.

**New endpoints in `facebank_v2.py`:**

```
POST /v2/facebank/search
  Body: { "img": "<base64 or URL>", "search_type": "ann" }
  Returns: top-K matches with person_id, similarity, image metadata

POST /v2/facebank/search/verify
  Body: { "img1": "...", "img2": "..." }
  Returns: same/different decision with distance
```

**Under the hood:**
- `search` calls `DeepFace.search(img=..., database_type="pgvector", search_type="ann")`
- pgvector handles the ANN lookup natively (HNSW index)
- Results mapped back to `face_bank_images` rows with `person_id` for identity resolution

**Fallback:** If pgvector search returns no results above threshold, fall back to exact brute-force search (same endpoint, automatic).

---

### Phase 4: Seed Image Quality Pipeline

**Goal:** Use DeepFace's multi-model capability to score and rank seed images.

**Current state:** `quality_score` column exists on `face_bank_images` but isn't consistently populated.

**New pipeline:**
1. On seed registration, run DeepFace with multiple models (e.g., ArcFace + Facenet512)
2. Compute intra-person consistency: how similar is this new seed to existing seeds for the same `person_id`?
3. Flag outliers (wrong person uploaded as seed, poor quality face)
4. Auto-populate `quality_score` based on: face detection confidence, embedding consistency, image resolution, face alignment score

**Integration with existing `tagging_references.py`:**
- `FacebankInitialReferenceImage` already has `rank` and `selection_reasons` fields
- Populate these from the quality pipeline
- `TAGGING_REFERENCE_MAX_DEFAULT = 12` — use quality scores to select the best 12 seeds per person

---

### Phase 5: Retire Legacy Manifest Store

**Goal:** Consolidate on the DB-backed approach and remove the S3 manifest system.

**Current state:** `facebank_store.py` maintains parallel JSON manifests in S3 with inline embeddings. This is the older pattern.

**Migration:**
1. Ensure all manifests are synced to `face_bank_images` table (one-time migration script)
2. Update any code paths that read from manifests to read from DB instead
3. Deprecate `facebank_store.py` — keep it for read-only backward compat for 1 release cycle
4. Remove in subsequent release

---

## Embedding Compatibility Note

The existing pipeline uses ArcFace R100 V1 (512-d). DeepFace also supports ArcFace and produces 512-d embeddings, but the model weights may differ slightly. **You cannot mix embeddings from different model checkpoints in the same index.**

**Options:**

1. **Use DeepFace's ArcFace for new seeds only** and keep a `model_name` column to partition searches. Query embeddings must use the same model as the index.
2. **Re-embed all existing seeds** through DeepFace on first migration to ensure consistency. This is the cleaner path — the seed bank is likely <10K images, so re-embedding is fast.
3. **Use Facenet512** (also 512-d) in DeepFace as a second opinion model alongside the existing ArcFace pipeline for ensemble matching.

**Recommendation:** Option 2. Re-embed all seeds through DeepFace's ArcFace on migration. Add `model_name` column to track provenance. This gives you a clean, consistent index from day one.

---

## File Changes Summary

| File | Change |
|------|--------|
| `supabase/migrations/XXXX_pgvector_face_bank.sql` | New migration: enable pgvector, add `embedding` + `model_name` columns, create HNSW index |
| `screenalytics/services/deepface_bridge.py` | **New file:** Wraps DeepFace `register`/`search` with TRR schema mapping |
| `screenalytics/apps/api/routers/facebank_v2.py` | Add `/search` and `/search/verify` endpoints |
| `screenalytics/config/pipeline/embedding.yaml` | Add DeepFace model config section |
| `.env.example` | Add `DEEPFACE_*` config vars |
| `requirements.txt` / `pyproject.toml` | Add `deepface>=0.9.7` dependency |
| `screenalytics/apps/api/services/facebank_store.py` | Deprecation path (Phase 5) |
| `trr_backend/repositories/tagging_references.py` | Wire quality scores into reference selection |

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| DeepFace dependency adds weight to container | Pin version, use slim install without unnecessary backends |
| Model mismatch between existing ArcFace and DeepFace ArcFace | Re-embed all seeds through DeepFace on migration; enforce single model per index |
| pgvector HNSW index memory usage | Monitor with `pg_stat_user_indexes`; IVFFlat is lighter if memory-constrained |
| DeepFace's Postgres backend expects its own schema | Use `database_type="pgvector"` which stores in standard pgvector columns — map to existing `face_bank_images` table via the bridge module |
| Breaking existing video processing pipeline | DeepFace is additive only — existing InsightFace/TensorRT pipeline untouched |

---

## Success Criteria

- Seed images can be registered via `POST /v2/facebank/search` and retrieved in <100ms for a 50K-image bank
- ANN search returns top-5 matches with >95% recall vs. brute-force baseline
- Legacy manifest store fully retired with no data loss
- Quality scoring populates `quality_score` on 100% of new seed uploads
- REST API is stateless and horizontally scalable

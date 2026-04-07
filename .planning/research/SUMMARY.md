# Research Summary

**Project:** TRR Cast Screentime Reset  
**Synthesized:** 2026-04-02

## Executive Summary

TRR Cast Screentime Reset should be built as a backend-owned, admin-first system that retires the long-term `screenalytics` runtime split without breaking the review surface operators already depend on. The winning shape is `TRR-Backend` as the control plane and worker owner, Supabase Postgres plus `pgvector` as the durable system of record, Modal as the execution fabric for long-running analysis jobs, object storage for large media artifacts, and `TRR-APP` as the only operator-facing UI. `screenalytics` should survive only as donor code and a temporary dispatch adapter during migration.

The reset is not a greenfield vision product. It is a brownfield migration where reviewability matters as much as detection quality. V1 therefore needs reviewable screentime outputs, not just totals: persisted scenes, shots, segments, exclusions, evidence media, generated clips, run history, review state, and canonical publish controls for episode-class assets. DeepFace belongs in the seed registration, search, and verification lane only. It should not replace the screentime runtime or segment logic in the first release.

The highest-risk failure mode is a migration that claims ArcFace parity while silently changing the actual embedding contract. The reset should freeze one canonical embedding/search contract, version thresholds and run configs, treat ANN as candidate retrieval rather than ground truth, and preserve immutable run outputs with separate mutable review decisions. If those guardrails hold, the system can consolidate runtime ownership without losing parity, auditability, or rollback leverage.

## Recommended Stack

- `TRR-Backend` FastAPI control plane: own intake, run orchestration, review APIs, publish state, and worker dispatch.
- Supabase Postgres: durable source of truth for runs, artifacts, review state, publications, and face reference metadata.
- `pgvector` with HNSW on `vector(512)`: canonical ANN index for one active ArcFace-class embedding family at a time.
- Modal worker lane: execute long-running video and embedding work; do not use it as the durable job ledger.
- S3-compatible object storage: store source media mirrors, manifests, JSON artifacts, evidence frames, and generated clips.
- `ffmpeg` / `ffprobe`: canonical media probe, extraction, and clip generation path.
- DeepFace pinned to `ArcFace` plus `RetinaFace`: use for seed registration, search, verification, and seed QA only.
- Existing ArcFace-class donor lane: keep temporarily for migration parity and re-embedding validation, not as the future runtime.
- `TRR-APP`: keep as the sole admin surface; do not reintroduce Streamlit or a second operator UI.

## Architecture Cut

### Final ownership

- `TRR-Backend` owns API, orchestration, schema, dispatch, review state, publish state, and identity services.
- `TRR-APP` keeps the current admin route and page flow shape, but only talks to backend-owned endpoints.
- `ml.*` is the canonical schema for retained screentime and face reference state.
- `screenalytics.*` becomes migration input and compatibility read material only.
- `screenalytics` code is donor logic to port behind backend-owned ports; it should not remain a permanent service dependency.

### Canonical boundaries

- Intake layer: `ml.analysis_media_*` for upload/import sessions, promoted assets, and candidate cast snapshots.
- Runtime layer: `ml.screentime_*` for runs, artifacts, segments, exclusions, evidence, metrics, review state, publications, and unknown clusters.
- Identity layer: `ml.face_reference_images` and `ml.face_reference_embeddings` with explicit provider/model/version provenance.
- Binary artifacts: object storage under stable run-scoped keys.

### Required migration seams

- Keep the dispatch seam stable while swapping the implementation from `screenalytics` HTTP to a backend-owned worker lane.
- Freeze artifact contracts such as `manifest.json`, `segments.json`, `scenes.json`, `excluded_sections.json`, and `person_metrics.json` so the app review surface does not churn during runtime migration.
- Separate immutable run outputs from mutable review decisions so reruns remain explicit and historical runs stay auditable.

## Feature Scope

### V1 must ship

- Asset intake for upload and remote import, including asset typing for episodes, trailers, clips, and extras.
- Candidate cast preflight and facebank readiness checks before dispatch.
- Asynchronous run launch, status, progress, history, stale-run recovery, and error visibility.
- Per-person screentime totals with named versus unassigned separation.
- Persisted scenes, shots, reviewable segments, exclusions, evidence frames, and generated clips.
- Review-state controls distinct from execution state.
- Canonical publish controls for episode-class runs and rollups from approved episode runs only.

### First meaningful differentiator after parity

- Unknown-review queues grouped by similarity with accept, reject, and defer actions.
- Decision persistence that affects future reruns without mutating historical run facts.
- Facebank-guided DeepFace seed workflows that make registration, search, and verification operationally reviewable.

### Explicitly defer

- Public-facing screentime surfaces.
- Fully autonomous official metrics with no human review gate.
- Full annotation-studio editing workflows.
- Realtime or livestream analysis.
- Audio, talk-time, transcript QA, or broader multimodal analytics.
- TensorRT or other acceleration-heavy infrastructure as a release prerequisite.

## Major Decisions

- Consolidate runtime ownership into `TRR-Backend`; do not preserve a long-lived backend-to-`screenalytics` HTTP topology after parity.
- Use `ml.*` as the permanent schema and freeze `screenalytics.*` after backfill and bridge support.
- Keep exactly one canonical embedding family active per search path; never mix old and new vectors in one ANN index without proving compatibility.
- Treat DeepFace as the face reference and verification subsystem, not as the whole screentime engine.
- Treat ANN search as candidate retrieval only; final acceptance still goes through threshold bands and operator review semantics.
- Keep object storage as the source of binary artifacts and Postgres as the source of truth for metadata, lineage, and state.

## Risks And Controls

| Risk | Why it matters | Required control |
|------|----------------|------------------|
| Embedding contract drift | “ArcFace-compatible” migrations fail when detector, normalization, or thresholds change underneath the label. | Freeze one v1 embedding contract, store provenance on every embedding and decision, and calibrate on operator-reviewed goldens. |
| Threshold reuse | Legacy cutoffs will not mean the same thing after changing pipeline behavior. | Recalibrate accept/review/reject bands for the exact migrated contract and version them. |
| ANN over-trust | pgvector recall can drop under filters and should not become identity truth. | Benchmark against exact search, use fallback paths, and keep final review semantics above ANN. |
| Reviewability loss | Totals without segments, exclusions, evidence, and reviewer decisions are not trustworthy. | Make review objects and artifact parity release gates, not cleanup work. |
| Premature retirement of `screenalytics` | Hidden donor logic or artifact dependencies can break parity and rollback. | Freeze donor contracts, capture golden runs, and decommission only behind reversible cutover flags. |
| Seed-bank pollution | Fast retrieval amplifies bad seeds rather than fixing them. | Add reviewed enrollment, quarantine, duplicate control, and canonical seed policies. |
| Non-versioned migration | Historical runs become irreproducible and unauditable. | Version embeddings, thresholds, review policy, and run config snapshots. |

## Suggested Sequencing

### Phase 1: Freeze contracts and storage cut

Lock the donor runtime contracts, artifact payloads, and `ml.*` schema as the target end state. This phase exists to prevent a false cutover where hidden `screenalytics` dependencies survive in fallback paths.

### Phase 2: Migrate face references and embedding governance

Backfill and normalize face reference state into `ml.face_reference_*`, freeze the embedding contract, and stand up backend-owned DeepFace registration, ANN search, and verification. Do not move on until mixed-index risk, seed quality rules, and threshold versioning are explicit.

### Phase 3: Port execution behind the dispatch seam

Keep the backend dispatch interface stable while replacing the `screenalytics` HTTP implementation with a backend-owned executor. Preserve artifact shapes and run-state semantics so parity can be measured without app churn.

### Phase 4: Switch review and publication to canonical backend state

Move read and write paths for review, rerun, publication, and rollups fully onto `ml.*`. This phase must preserve immutable outputs, rich adjudication states, and evidence-linked operator decisions.

### Phase 5: Add throughput differentiators and retire the split runtime

After parity and cutover prove stable, add unknown review queues, rerun-aware decision persistence, and deeper facebank tooling. Only then should the remaining `SCREENALYTICS_API_URL` and service-token dependencies be removed.

## Confidence And Gaps

| Area | Confidence | Notes |
|------|------------|-------|
| Stack direction | HIGH | Strong alignment across research: backend-owned FastAPI, Postgres plus `pgvector`, Modal, object storage, `TRR-APP` only. |
| Architecture cut | MEDIUM-HIGH | Internal seams are clear, but exact donor-module extraction and final worker packaging still need implementation detail work. |
| Feature scope | HIGH | V1 versus defer line is consistent and grounded in current admin parity needs. |
| Migration risk model | HIGH | The biggest pitfalls are well defined and materially actionable. |

Remaining gap: numerical compatibility between the current donor ArcFace lane and the migrated DeepFace ArcFace lane should not be assumed. That needs explicit parity testing on a golden set before any mixed-search or threshold reuse is allowed.

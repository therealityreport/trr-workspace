# Domain Pitfalls

**Domain:** Cast screentime reset around DeepFace, pgvector, and operator-reviewed migration
**Researched:** 2026-04-02
**Overall confidence:** HIGH for pgvector and DeepFace search/index behavior; MEDIUM for migration-pattern guidance derived from internal plans plus verified docs

## Critical Pitfalls

### Pitfall 1: “ArcFace-compatible” migration that actually changes the embedding contract
**What goes wrong:** Teams say they are preserving ArcFace compatibility, but they change one or more of the actual embedding-space inputs at the same time: model implementation, detector backend, alignment mode, normalization, crop policy, distance operator, or threshold logic. The result is a mixed index and thresholds that look familiar but are no longer calibrated.
**Why it happens:** DeepFace exposes model, detector, and alignment as configurable knobs, and its own docs note that measured results vary with detection and normalization choices. Migration teams often treat “ArcFace” as a single stable thing when the effective contract is the whole preprocessing pipeline, not just the model label.
**Consequences:** Similarity scores drift, legacy thresholds stop meaning what operators think they mean, false accepts/rejects rise, and historical comparisons become untrustworthy.
**Warning signs:**
- Existing similarity cutoffs are copied forward unchanged.
- Old and new embeddings coexist in one search path without explicit provenance.
- There is no stored `model_name`, detector/alignment contract, or threshold version on seed rows and runs.
- Known identities start scoring lower or more variably after migration despite “same model” claims.
**Prevention strategy:**
- Freeze a single embedding contract for v1 parity: model, detector backend, alignment setting, normalization, crop policy, vector dimensionality, dtype, and distance operator.
- Store embedding provenance on every registered seed and every run decision.
- Re-embed the seed bank in one controlled migration, or partition search by embedding contract until re-embedding is complete.
- Calibrate against an operator-reviewed golden set before allowing production cutover.
**Phase should address it:** Phase 2, embedding/schema migration and parity calibration.

### Pitfall 2: Reusing legacy thresholds after changing model, preprocessing, or search semantics
**What goes wrong:** A threshold that was tuned for the old InsightFace/ArcFace runtime is reused for DeepFace registration/search/verify, or the same cutoff is used for exact search, ANN search, and operator triage.
**Why it happens:** Thresholds feel like business rules, so teams copy them into the new system instead of treating them as model- and pipeline-dependent measurements.
**Consequences:** Review queues either explode or disappear, low-confidence cases get auto-assigned, and operator trust collapses because “same score” no longer means the same risk.
**Warning signs:**
- One global threshold controls accept, review, and reject behavior.
- No score-distribution analysis exists for the new pipeline.
- Teams compare only top-1 correctness instead of false-accept and false-reject rates across review bands.
- Review workload changes dramatically immediately after rollout.
**Prevention strategy:**
- Recalibrate thresholds for the exact v1 contract and data distribution.
- Use three bands, not one cutoff: accept, review, reject.
- Version thresholds and persist the threshold version on decisions.
- Evaluate candidate thresholds against operator-reviewed episodes and supplementary assets, not just seed-to-seed tests.
**Phase should address it:** Phase 3, search/verification calibration; reinforced in Phase 4 review workflow design.

### Pitfall 3: ANN search treated as authoritative truth instead of a candidate generator
**What goes wrong:** pgvector ANN results are treated as definitive identity assignments, even when queries include metadata filters or when the candidate set is sparse.
**Why it happens:** ANN search is faster and feels “production ready,” so teams skip exact-search baselines and forget that pgvector indexes trade recall for speed. Filtering makes this worse: pgvector can return fewer qualifying rows than requested unless iterative scan or an exact fallback is used.
**Consequences:** Valid matches disappear from the top-k list, low-confidence or unknown faces get incorrectly forced to the nearest seed, and operators see inconsistent candidate quality across assets.
**Warning signs:**
- Filtered queries return fewer than `k` rows even when more valid candidates exist.
- Known identities vanish only when `WHERE` clauses are applied.
- No recall@k benchmark exists against brute-force search.
- ANN parameters are left at defaults with no workload tuning.
**Prevention strategy:**
- Keep an exact-search calibration path and compare ANN recall against it on a representative corpus.
- Tune HNSW/IVFFlat settings for the real workload, not synthetic happy-path examples.
- Use iterative scans or exact fallback when filters like `is_seed`, `is_active`, show scope, or review scope are applied.
- Treat ANN as candidate retrieval; final acceptance still goes through thresholding and review semantics.
**Phase should address it:** Phase 3, vector search implementation and benchmark gate.

### Pitfall 4: DeepFace search is allowed to replace screentime logic instead of supporting it
**What goes wrong:** Teams collapse timeline reasoning into per-frame identity lookup. DeepFace becomes the de facto screentime engine instead of one component inside a larger detect-track-segment-review system.
**Why it happens:** DeepFace solves registration, search, and verification cleanly, so it is tempting to let nearest-neighbor matches drive totals directly.
**Consequences:** Identity flicker across adjacent frames, overcounting and undercounting in multi-face scenes, and loss of auditable segment-level reasoning. The system becomes less reviewable, not more.
**Warning signs:**
- Per-frame matches are turned directly into screentime totals.
- There is no stable face-track or scene/segment aggregation layer.
- Review surfaces show isolated frames rather than grouped evidence for a segment.
- Overrides apply only to a single frame and do not propagate to the underlying track or segment.
**Prevention strategy:**
- Keep the architectural boundary explicit: DeepFace handles registration/search/verify; the screentime runtime handles detection, track aggregation, temporal smoothing, exclusions, and artifact generation.
- Review identities at the track or segment level, not frame by frame.
- Preserve evidence bundles that explain how a segment total was formed.
**Phase should address it:** Phase 3 for runtime boundary design; Phase 4 for operator review parity.

### Pitfall 5: Losing operator-review semantics during migration
**What goes wrong:** The new runtime produces totals but drops or weakens the evidence chain that made the old system reviewable: scenes, segments, exclusions, evidence frames, generated clips, override reasons, reviewer attribution, and rerun traceability.
**Why it happens:** Migration teams prioritize runtime consolidation and search speed, then assume review affordances can be rebuilt later.
**Consequences:** Operators cannot explain why a person was counted, cannot correct mistakes without side channels, and cannot trust reruns. This turns an internal admin system into a black box.
**Warning signs:**
- Run outputs are reduced to aggregates plus a confidence score.
- Overrides are stored only as final labels, with no reviewer or reason metadata.
- Unknown, ambiguous, and excluded states disappear from the review model.
- Reruns overwrite prior review state or orphan prior evidence.
**Prevention strategy:**
- Define review objects as first-class migration requirements, not UI polish.
- Persist machine proposal, operator decision, reviewer identity, rationale, timestamps, and evidence references separately.
- Preserve exclusions and abstentions as valid end states.
- Require parity on review artifacts before retiring the transitional runtime.
**Phase should address it:** Phase 4, review workflow and artifact parity.

### Pitfall 6: Retiring the transitional service before donor logic and contracts are frozen
**What goes wrong:** `screenalytics` is shut down or bypassed before the donor modules, output schemas, and hidden dependencies are frozen and captured.
**Why it happens:** Teams focus on removing the extra service hop and underestimate how much runtime truth still lives in transitional code, artifact layouts, progress semantics, and admin expectations.
**Consequences:** Backend cutover lands with invisible gaps, parity disputes cannot be debugged, and rollback becomes guesswork.
**Warning signs:**
- “We can port that later” is applied to run artifacts or edge-case APIs.
- Hidden uses of `SCREENALYTICS_API_URL` or `SCREENALYTICS_SERVICE_TOKEN` remain in fallback paths.
- No golden runs or contract fixtures exist from the transitional runtime.
- Donor modules are named, but their required behaviors are not enumerated.
**Prevention strategy:**
- Freeze donor contracts up front: inputs, outputs, artifact shapes, progress/status semantics, error semantics, and review-state persistence.
- Capture golden runs and representative artifact bundles before major refactors.
- Run backend shadow mode against transitional outputs until parity is measured.
- Do not remove the network dependency until parity gates and rollback paths are documented.
**Phase should address it:** Phase 1, donor inventory and contract freeze; validated again in Phase 5 cutover.

### Pitfall 7: Seed-bank pollution gets amplified by fast vector search
**What goes wrong:** Wrong-person seeds, low-quality crops, duplicates, or stale inactive seeds enter the index and then get retrieved faster and more often.
**Why it happens:** Vector search makes retrieval scalable, but it does not improve enrollment quality. A bad seed bank poisons every downstream match.
**Consequences:** Systematic misidentification, reviewer fatigue, and bad “top matches” that appear plausible enough to slip through.
**Warning signs:**
- Multiple near-duplicate seeds dominate top-k results for the same identity.
- New seeds are indexed immediately with no approval step.
- There is no notion of canonical, inactive, superseded, or quarantined seeds.
- Side-profile, occluded, or low-resolution seeds are accepted on the same footing as reviewed frontal references.
**Prevention strategy:**
- Put seed registration behind a reviewable enrollment workflow.
- Store seed quality/provenance and allow quarantine before inclusion in the active search set.
- Maintain canonical reviewed seeds per person and keep duplicate control explicit.
- Re-rank or suppress duplicate seeds so candidate lists stay useful to operators.
**Phase should address it:** Phase 2, seed migration and registration workflow; Phase 4, operator review queue.

### Pitfall 8: Non-versioned migration makes accepted runs irreproducible
**What goes wrong:** Embeddings, thresholds, or artifact rules are updated in place. Old runs then cannot be rerun or explained against the contract under which they were accepted.
**Why it happens:** Teams optimize for “latest best model” and mutate rows in place instead of treating the migration as a versioned analytics system.
**Consequences:** Operators cannot audit historical decisions, regressions cannot be isolated, and rollback requires data archaeology.
**Warning signs:**
- Existing seed rows are overwritten without preserving prior embedding provenance.
- Search logic references only current config, not config-at-run-time.
- Accepted review decisions do not store model/index/threshold versions.
- Old evidence artifacts are deleted or repointed during backfill.
**Prevention strategy:**
- Version embeddings, thresholds, review policies, and artifact schemas.
- Store run-scoped configuration snapshots and immutable evidence references.
- Avoid rewriting accepted-run inputs in place; add new versions instead.
- Require rerun reproducibility checks on a fixed golden set before decommissioning the old path.
**Phase should address it:** Phase 2 for schema/versioning; Phase 5 for cutover verification.

## Moderate Pitfalls

### Pitfall 1: Backend selection confusion between DeepFace `postgres` and `pgvector`
**What goes wrong:** Teams wire DeepFace against plain Postgres semantics while expecting pgvector behavior, or they keep calling `build_index()` in a pgvector-backed path and assume indexing lifecycle is identical.
**Prevention strategy:** Choose one backend path explicitly. If v1 uses pgvector, treat pgvector as the canonical search backend and document that index management lives in the database, not in a separate FAISS lifecycle.
**Warning signs:**
- Design docs mix `build_index()` requirements with pgvector claims.
- Operators or jobs talk about “rebuilding DeepFace index” even when pgvector is the real index owner.
**Phase should address it:** Phase 2, architecture/spec finalization.

### Pitfall 2: Distance-operator drift during the same migration
**What goes wrong:** Teams change from cosine-style matching to inner product or L2 while also changing the registration/search implementation.
**Prevention strategy:** Preserve the existing distance semantics for parity unless benchmarking proves a change is safe after parity. If vectors are normalized and a different operator is evaluated later, treat that as a separate milestone.
**Warning signs:**
- Query SQL and threshold docs disagree on cosine vs inner-product semantics.
- Similarity scores can no longer be compared against historical operator expectations.
**Phase should address it:** Phase 3, search-query implementation and calibration.

### Pitfall 3: Cutover tests measure only accuracy, not review workload
**What goes wrong:** Migration validation focuses on top-1 accuracy or total runtime, but ignores whether the new system creates a manageable and trustworthy review queue.
**Prevention strategy:** Add operational metrics to parity tests: percent auto-accepted, percent sent to review, unknown rate, reviewer disagreement rate, correction rate, and time-to-resolution.
**Warning signs:**
- Success criteria contain latency and recall only.
- No one can estimate post-cutover operator load.
**Phase should address it:** Phase 4, review acceptance criteria.

## Minor Pitfalls

### Pitfall 1: Building the wrong index strategy for current scale
**What goes wrong:** Teams optimize immediately for massive-scale ANN when the current seed bank is still small enough that exact search is the safer calibration baseline.
**Prevention strategy:** Start with exact-search baselines and add ANN only once parity metrics justify it. HNSW is the default pgvector recommendation when ANN is needed; IVFFlat needs more careful dataset-size and rebuild discipline.
**Warning signs:**
- ANN is enabled before any brute-force parity benchmark exists.
- Index tuning is discussed without recall measurements.
**Phase should address it:** Phase 3, search-performance benchmarking.

### Pitfall 2: Review-state vocabulary is too narrow
**What goes wrong:** The system only supports matched/unmatched states and loses useful operator states like unknown, ambiguous, excluded, merged, superseded, or needs-better-seed.
**Prevention strategy:** Preserve a richer adjudication state machine so operators can express uncertainty without forcing a bad identity.
**Warning signs:**
- UI or API contracts collapse review into boolean acceptance.
- Operators rely on comments or side channels to explain exceptions.
**Phase should address it:** Phase 4, review model and admin UI parity.

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Phase 1: Donor inventory and contract freeze | Hidden dependency on retiring `screenalytics` service survives in backend fallbacks or artifact assumptions | Freeze donor contracts, capture golden runs, and enumerate every active service/env dependency before refactor |
| Phase 2: Embedding/schema migration | Mixed embedding contracts silently enter one seed bank | Add provenance fields, re-embed or partition by contract, and block mixed search paths |
| Phase 2: Seed migration | Low-quality or wrong-person seeds contaminate the new index | Require enrollment review, quarantine, and canonical-seed policies |
| Phase 3: Search/index integration | ANN recall drops under filters and defaults hide it | Benchmark against exact search, tune HNSW/IVFFlat, and use iterative scans or exact fallback |
| Phase 3: Verification logic | Legacy thresholds are reused uncritically | Recalibrate accept/review/reject bands on operator-reviewed goldens |
| Phase 4: Review workflow parity | Machine suggestions become de facto final decisions | Persist proposal vs operator decision separately and preserve unknown/ambiguous/excluded states |
| Phase 4: Artifact parity | Totals survive but evidence lineage does not | Require scenes, segments, exclusions, evidence frames, and generated clips before parity sign-off |
| Phase 5: Cutover and retirement | Old service removed before rollback and reproducibility are proven | Run shadow comparisons, snapshot config versions, and stage decommission behind reversible flags |

## Sources

- [HIGH] Internal project brief: `/Users/thomashulihan/Projects/TRR/.planning/PROJECT.md`
- [HIGH] Internal concerns audit: `/Users/thomashulihan/Projects/TRR/.planning/codebase/CONCERNS.md`
- [MEDIUM] Internal migration strategy draft: `/Users/thomashulihan/Projects/TRR/docs/plans/2026-03-22-deepface-integration-plan.md`
- [HIGH] Donor/runtime inventory: `/Users/thomashulihan/Projects/TRR/screenalytics/docs/cross-collab/TASK13/PLAN.md`
- [HIGH] Cross-repo dependency audit: `/Users/thomashulihan/Projects/TRR/TRR-Backend/docs/cross-collab/TASK24/PLAN.md`
- [HIGH] DeepFace README, verified 2026-04-02: https://github.com/serengil/deepface
- [MEDIUM] DeepFace author post on `register` / `build_index` / `search`, published 2026-01-01: https://sefiks.com/2026/01/01/introducing-brand-new-face-recognition-in-deepface/
- [HIGH] pgvector official repository docs, verified 2026-04-02: https://github.com/pgvector/pgvector
- [HIGH] Supabase vector index guidance, verified 2026-04-02: https://supabase.com/docs/guides/ai/vector-indexes
- [HIGH] Supabase HNSW guidance, verified 2026-04-02: https://supabase.com/docs/guides/ai/vector-indexes/hnsw-indexes
- [HIGH] Supabase pgvector extension docs, verified 2026-04-02: https://supabase.com/docs/guides/database/extensions/pgvector

## Notes on Confidence

- The warning that embedding compatibility depends on the full preprocessing contract, not only the model label, is an inference from DeepFace's documented variability across detection/normalization techniques plus the project's existing ArcFace baseline constraints.
- The phase mapping is opinionated and designed to help roadmap creation; it is not copied from an existing approved milestone plan.

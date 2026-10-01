# Requirements: TRR Cast Screentime Reset

**Defined:** 2026-04-02
**Core Value:** Internal operators can produce trustworthy, reviewable screentime metrics for episodes and supplementary videos without depending on a standalone Screenalytics runtime.

## v1 Requirements

### Intake

- [x] **INTK-01**: Admin can create a screentime asset from direct upload and persist a canonical promoted media asset in backend-owned storage.
- [x] **INTK-02**: Admin can create a screentime asset from a direct external source import and persist the same canonical promoted media asset shape used by uploads.
- [x] **INTK-03**: Admin can classify an asset as episode or supplementary video and persist metadata needed for show, season, episode, and source provenance.
- [x] **INTK-04**: Backend stores probe metadata, integrity checks, and source provenance for every promoted screentime asset.

### Identity

- [x] **IDEN-01**: Admin can manage approved face reference images for cast members/persons in backend-owned tables under `ml.*`.
- [x] **IDEN-02**: Backend generates and stores versioned DeepFace face-reference embeddings with explicit provider, model, detector, and normalization provenance.
- [x] **IDEN-03**: Backend supports DeepFace-backed register, search, and verify flows while keeping one canonical ArcFace-class embedding contract active for v1.
- [x] **IDEN-04**: Backend prevents unreviewed or duplicate face-reference material from becoming active matching seeds.

### Analysis Runtime

- [x] **RUN-01**: Admin can launch an asynchronous screentime analysis run for an asset from the backend-owned control plane without requiring a standalone `screenalytics` service runtime.
- [x] **RUN-02**: Backend snapshots candidate cast context and run configuration so each run is reproducible and auditable.
- [x] **RUN-03**: Backend calculates per-person screentime totals for each run, including unassigned or unknown detections when identity is not accepted.
- [x] **RUN-04**: Backend persists reviewable scenes, shots, segments, exclusions, evidence frames, and generated clips for each run.
- [x] **RUN-05**: Backend versions thresholds, embedding contract, and run configuration so historical runs remain interpretable after future changes.
- [x] **RUN-06**: Backend exposes run status, progress, failures, retries, and history to the admin workflow.

### Review And Publication

- [x] **REVW-01**: Admin can review persisted screentime artifacts and adjudicate uncertain or excluded detections without mutating immutable run outputs.
- [x] **REVW-02**: Backend stores mutable review decisions separately from immutable run artifacts and metrics lineage.
- [x] **REVW-03**: Admin can publish an approved episode-class run as the canonical screentime version for that episode.
- [x] **REVW-04**: Supplementary videos can be reviewed and published for internal reference without contaminating canonical episode rollups.
- [x] **REVW-05**: Backend can regenerate derived totals and rollups from approved review and publication state without requiring artifact reprocessing.

### Admin Surface

- [x] **ADMIN-01**: `TRR-APP` provides the sole operator-facing admin surface for screentime intake, run control, review, and publication.
- [x] **ADMIN-02**: `TRR-APP` preserves working admin flows during migration by consuming backend-owned contracts rather than a permanent `screenalytics` runtime dependency.
- [x] **ADMIN-03**: Admin can inspect evidence-linked totals, segments, exclusions, and generated clips for a run from the app.

### Migration And Retirement

- [x] **MIGR-01**: `ml.*` becomes the canonical schema for retained screentime and face-reference state used by backend-owned flows.
- [x] **MIGR-02**: Backend preserves stable artifact contracts during migration so review surfaces do not break while execution ownership changes.
- [x] **MIGR-03**: The system can cut over from the existing dispatch adapter to a backend-owned executor behind reversible flags and parity validation.
- [x] **MIGR-04**: Production screentime flows no longer require `SCREENALYTICS_API_URL` or `SCREENALYTICS_SERVICE_TOKEN`.

## v2 Requirements

### Review Intelligence

- **RINT-01**: Admin can work unknown detections through clustered review queues with accept, reject, and defer actions.
- **RINT-02**: Review decisions can improve future reruns without rewriting historical run facts.
- **RINT-03**: Backend can surface conservative cast suggestions and duplicate-seed warnings during face-reference enrollment.

### Domain Intelligence

- **DINT-01**: Backend can apply specialized heuristics for flashbacks, confessionals, title cards, and montage-heavy cuts.
- **DINT-02**: Backend can compare reruns across embedding or threshold versions with explicit parity reports.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Public screentime product surface | Initial release is internal admin-only. |
| Fully autonomous official metrics with no operator review | User explicitly wants operator-reviewable output first. |
| General-purpose annotation studio | Would expand scope beyond screentime review and publication. |
| Realtime or livestream processing | Not required for episode, trailer, or clip workflows. |
| Audio or transcript-based talk-time analytics | Separate modality and not required for this reset. |
| Long-term standalone `screenalytics` service runtime | User explicitly wants backend-owned replacement and eventual retirement. |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| INTK-01 | Phase 1 | Complete |
| INTK-02 | Phase 1 | Complete |
| INTK-03 | Phase 1 | Complete |
| INTK-04 | Phase 1 | Complete |
| IDEN-01 | Phase 2 | Complete |
| IDEN-02 | Phase 2 | Complete |
| IDEN-03 | Phase 2 | Complete |
| IDEN-04 | Phase 2 | Complete |
| RUN-01 | Phase 3 | Complete |
| RUN-02 | Phase 3 | Complete |
| RUN-03 | Phase 3 | Complete |
| RUN-04 | Phase 3 | Complete |
| RUN-05 | Phase 3 | Complete |
| RUN-06 | Phase 3 | Complete |
| REVW-01 | Phase 4 | Complete |
| REVW-02 | Phase 4 | Complete |
| REVW-03 | Phase 4 | Complete |
| REVW-04 | Phase 4 | Complete |
| REVW-05 | Phase 4 | Complete |
| ADMIN-01 | Phase 4 | Complete |
| ADMIN-02 | Phase 5 | Complete |
| ADMIN-03 | Phase 4 | Complete |
| MIGR-01 | Phase 1 | Complete |
| MIGR-02 | Phase 1 | Complete |
| MIGR-03 | Phase 3 | Complete |
| MIGR-04 | Phase 5 | Complete |

**Coverage:**
- v1 requirements: 26 total
- Mapped to phases: 26
- Unmapped: 0

---
*Requirements defined: 2026-04-02*
*Last updated: 2026-04-03 after Phase 5 execution*

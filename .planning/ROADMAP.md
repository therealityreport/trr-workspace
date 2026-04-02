# Roadmap: TRR Cast Screentime Reset

## Overview

This roadmap delivers the screentime reset as a backend-first migration rather than a greenfield rewrite. The sequence follows the research summary's five-phase direction: freeze contracts and storage targets first, migrate identity and embedding governance second, port execution behind the existing dispatch seam third, switch review and publication to canonical backend state fourth, and retire the split runtime only after parity is proven.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Contract Freeze & Asset Foundation** - Lock the canonical asset, schema, and artifact contracts that the migration will preserve.
- [ ] **Phase 2: Identity Reset & Embedding Governance** - Move face-reference ownership and DeepFace-backed identity flows into backend-owned, versioned governance.
- [ ] **Phase 3: Backend Execution Port** - Replace the standalone execution dependency with a backend-owned screentime runtime behind the existing dispatch seam.
- [ ] **Phase 4: Canonical Review, Publication & Admin Cutover** - Make backend-owned review, publication, and operator workflows the source of truth in TRR-APP.
- [ ] **Phase 5: Runtime Retirement & Cutover Cleanup** - Remove the remaining production dependency on the split `screenalytics` runtime and finalize backend-only operation.

## Phase Details

### Phase 1: Contract Freeze & Asset Foundation
**Goal**: Operators can ingest screentime assets into backend-owned canonical storage and schemas that future migration phases can preserve without contract churn.
**Depends on**: Nothing (first phase)
**Requirements**: INTK-01, INTK-02, INTK-03, INTK-04, MIGR-01, MIGR-02
**Success Criteria** (what must be TRUE):
  1. Admin can create screentime assets from both direct upload and remote import, and both paths persist the same canonical promoted media asset shape.
  2. Asset records preserve episode-versus-supplementary classification together with show, season, episode, and source provenance metadata.
  3. Every promoted screentime asset exposes probe metadata, integrity checks, and source provenance from backend-owned storage and schema.
  4. Downstream runtime and review paths can rely on `ml.*` and stable artifact payload contracts without depending on donor-only storage shapes.
**Plans**: TBD

### Phase 2: Identity Reset & Embedding Governance
**Goal**: Operators can manage trusted face references through backend-owned DeepFace registration, search, and verification flows without changing the v1 ArcFace-class matching contract.
**Depends on**: Phase 1
**Requirements**: IDEN-01, IDEN-02, IDEN-03, IDEN-04
**Success Criteria** (what must be TRUE):
  1. Admin can create, review, and manage approved face reference images for cast members or persons in backend-owned `ml.*` tables.
  2. Every active face reference stores versioned DeepFace embeddings with provider, model, detector, and normalization provenance.
  3. Backend register, search, and verify flows operate against one explicit ArcFace-class embedding contract for v1.
  4. Unreviewed or duplicate face-reference material cannot become active matching seeds.
**Plans**: TBD

### Phase 3: Backend Execution Port
**Goal**: Operators can run screentime analysis from the backend-owned control plane while preserving reproducibility, artifact parity, and reversible cutover control.
**Depends on**: Phase 2
**Requirements**: RUN-01, RUN-02, RUN-03, RUN-04, RUN-05, RUN-06, MIGR-03
**Success Criteria** (what must be TRUE):
  1. Admin can launch an asynchronous screentime analysis run from the backend-owned control plane without requiring a standalone `screenalytics` runtime.
  2. Each run snapshots candidate cast context and configuration, and operators can see status, progress, failures, retries, and history from the backend workflow.
  3. Completed runs persist per-person totals, unknown or unassigned detections, and reviewable scenes, shots, segments, exclusions, evidence frames, and generated clips.
  4. Historical runs remain interpretable because thresholds, embedding contract, and run configuration are versioned with each run.
  5. The executor can cut over from the donor adapter to backend-owned execution behind reversible flags with parity validation.
**Plans**: TBD

### Phase 4: Canonical Review, Publication & Admin Cutover
**Goal**: Operators can review, approve, publish, and inspect screentime results entirely through TRR-APP against backend-owned canonical review and publication state.
**Depends on**: Phase 3
**Requirements**: REVW-01, REVW-02, REVW-03, REVW-04, REVW-05, ADMIN-01, ADMIN-03
**Success Criteria** (what must be TRUE):
  1. Admin can review evidence-linked screentime artifacts and adjudicate uncertain or excluded detections without mutating immutable run outputs.
  2. Review decisions and lineage are stored separately from immutable run artifacts and execution metrics.
  3. Admin can publish approved episode-class runs as canonical episode screentime while keeping supplementary-video publications out of canonical episode rollups.
  4. Backend can regenerate approved totals and rollups from review and publication state without reprocessing artifacts.
  5. Operators can complete intake, run inspection, review, and publication workflows from TRR-APP, including evidence-linked totals, segments, exclusions, and generated clips.
**Plans**: TBD
**UI hint**: yes

### Phase 5: Runtime Retirement & Cutover Cleanup
**Goal**: Operators continue using TRR-APP against backend-owned contracts after the split runtime is removed from production screentime flows.
**Depends on**: Phase 4
**Requirements**: ADMIN-02, MIGR-04
**Success Criteria** (what must be TRUE):
  1. TRR-APP preserves working screentime admin flows while consuming backend-owned contracts rather than a permanent `screenalytics` runtime dependency.
  2. Production screentime flows no longer require `SCREENALYTICS_API_URL` or `SCREENALYTICS_SERVICE_TOKEN`.
  3. The remaining production service boundary to the standalone `screenalytics` runtime is retired without breaking operator-facing screentime workflows.
**Plans**: TBD
**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Contract Freeze & Asset Foundation | 0/TBD | Not started | - |
| 2. Identity Reset & Embedding Governance | 0/TBD | Not started | - |
| 3. Backend Execution Port | 0/TBD | Not started | - |
| 4. Canonical Review, Publication & Admin Cutover | 0/TBD | Not started | - |
| 5. Runtime Retirement & Cutover Cleanup | 0/TBD | Not started | - |

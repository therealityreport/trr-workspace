# Roadmap: Cloud-First / No-Docker Workspace Tooling

## Overview

This roadmap shifts the TRR workspace toward cloud-first development and validation. The sequence starts by defining the preferred remote-first contract and safety boundaries, then updates root scripts and defaults to match, and finally verifies adoption so Docker remains only an explicit fallback for special cases.

## Phases

**Phase Numbering:**
- Integer phases (6, 7, 8): Planned milestone work
- Decimal phases (6.1, 6.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 6: Cloud-First Validation Contract** - Define and document the preferred remote-first workspace and database validation path. (not started)
- [ ] **Phase 7: Workspace Defaults And Script Alignment** - Make shared scripts, profiles, and diagnostics reflect cloud-first defaults with Docker as opt-in fallback. (not started)
- [ ] **Phase 8: Adoption, Verification & Fallback Boundaries** - Prove the no-Docker path works end-to-end and document the remaining explicit fallback cases. (not started)

## Phase Details

### Phase 6: Cloud-First Validation Contract
**Goal**: Developers can understand the preferred no-Docker workflow for this workspace and safely validate schema/runtime changes against isolated remote targets.
**Depends on**: Nothing in this milestone
**Requirements**: WSDF-01, WSDF-02, WSDF-03, DBVL-01, DBVL-02, DBVL-03
**Success Criteria** (what must be TRUE):
  1. Workspace docs describe one preferred cloud-first development and verification path.
  2. The preferred database validation path uses isolated Supabase branches or disposable environments rather than assuming local Docker-backed reset.
  3. Docker-backed flows are clearly labeled as optional fallback behavior, not the default.
**Plans**: none yet

### Phase 7: Workspace Defaults And Script Alignment
**Goal**: Shared workspace scripts, profiles, and diagnostics match the cloud-first contract instead of nudging developers into Docker-heavy defaults.
**Depends on**: Phase 6
**Requirements**: SCPT-01, SCPT-02, SCPT-03
**Success Criteria** (what must be TRUE):
  1. Root `Makefile` and workspace bootstrap paths prefer cloud-first mode by default.
  2. Doctor and preflight output explain clearly when Docker is not needed and when it is a special-case requirement.
  3. Screenalytics-specific local infra assumptions are isolated behind explicit opt-in behavior.
**Plans**: none yet

### Phase 8: Adoption, Verification & Fallback Boundaries
**Goal**: The cloud-first path is proven in practice and the remaining Docker-only cases are documented honestly.
**Depends on**: Phase 7
**Requirements**: ADPT-01, ADPT-02, ADPT-03
**Success Criteria** (what must be TRUE):
  1. At least one real milestone verification path runs successfully in this workspace without Docker.
  2. Handoff/status artifacts and docs all point to the same preferred no-Docker workflow.
  3. Any remaining Docker usage is explicit, narrow, and documented as fallback.
**Plans**: none yet

## Progress

**Execution Order:**
Phases execute in numeric order: 6 -> 7 -> 8

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 6. Cloud-First Validation Contract | 0/0 | Ready to plan | - |
| 7. Workspace Defaults And Script Alignment | 0/0 | Pending | - |
| 8. Adoption, Verification & Fallback Boundaries | 0/0 | Pending | - |

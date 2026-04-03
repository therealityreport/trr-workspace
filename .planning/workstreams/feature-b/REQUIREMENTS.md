# Requirements: Cloud-First / No-Docker Workspace Tooling

**Defined:** 2026-04-03
**Core Value:** Ship repo-spanning changes through workflows that are trustworthy, repeatable, and usable on this workspace without machine-specific local infrastructure assumptions.

## v1 Requirements

### Workspace Defaults

- [ ] **WSDF-01**: The recommended workspace start path uses cloud-first defaults and does not require Docker for normal backend or app development.
- [ ] **WSDF-02**: Docker-backed local modes remain available only as explicit opt-in paths for narrow local-infra cases.
- [ ] **WSDF-03**: Workspace doctor and preflight checks explain clearly when Docker is optional versus actually required.

### Database Validation

- [ ] **DBVL-01**: The docs define a safe remote-first migration validation path using isolated Supabase branches or disposable database targets.
- [ ] **DBVL-02**: Backend schema validation guidance does not assume local `supabase start` or `supabase db reset` as the default milestone verification path.
- [ ] **DBVL-03**: The preferred remote validation path keeps production and shared persistent databases out of the blast radius.

### Script And Profile Alignment

- [ ] **SCPT-01**: Root workspace scripts and `Makefile` targets align with the cloud-first default instead of silently routing developers into Docker-dependent flows.
- [ ] **SCPT-02**: Screenalytics-specific local infra startup is isolated so unrelated backend or app work is not blocked by Docker availability.
- [ ] **SCPT-03**: Shared profiles and env docs reflect one canonical no-Docker preferred path.

### Operational Adoption

- [ ] **ADPT-01**: At least one real verification path proves milestone checks can be run in this workspace without Docker.
- [ ] **ADPT-02**: Handoff and status artifacts point to the same cloud-first validation contract as the scripts and docs.
- [ ] **ADPT-03**: Remaining Docker-only cases are explicitly documented as fallback or special-case behavior rather than hidden defaults.

## v2 Requirements

### Workspace Automation

- **AUTO-01**: Workspace commands can provision and tear down disposable remote validation databases automatically.
- **AUTO-02**: CI or helper scripts can run schema-doc validation against an isolated branch database without manual credential plumbing.

### Runtime Simplification

- **RTSM-01**: Local Screenalytics-specific container orchestration can be fully removed if no remaining workflows require it.
- **RTSM-02**: Workstream and milestone bootstrap flows can auto-surface the best remote validation target for the current task.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Banning Docker outright from the entire TRR workspace | Some narrow local-infra or legacy cases may still need it temporarily. |
| Reopening the completed screentime runtime migration milestone | This milestone is about workspace/tooling defaults, not undoing shipped screentime phases. |
| Replacing Supabase CLI with custom database tooling | The goal is to improve workflow defaults, not invent a parallel toolchain. |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| WSDF-01 | Phase 6 | Pending |
| WSDF-02 | Phase 6 | Pending |
| WSDF-03 | Phase 6 | Pending |
| DBVL-01 | Phase 6 | Pending |
| DBVL-02 | Phase 6 | Pending |
| DBVL-03 | Phase 6 | Pending |
| SCPT-01 | Phase 7 | Pending |
| SCPT-02 | Phase 7 | Pending |
| SCPT-03 | Phase 7 | Pending |
| ADPT-01 | Phase 8 | Pending |
| ADPT-02 | Phase 8 | Pending |
| ADPT-03 | Phase 8 | Pending |

**Coverage:**
- v1 requirements: 12 total
- Mapped to phases: 12
- Unmapped: 0

---
*Requirements defined: 2026-04-03*
*Last updated: 2026-04-03 after milestone v1.1 initialization*

# TRR Cast Screentime Reset

## What This Is

An internal admin-first screentime analysis system for TRR that measures how long every cast member or person appears in each episode and supplementary video for a show. It must support direct uploads and external source imports, produce auditable run artifacts such as scenes, segments, exclusions, evidence frames, and generated clips, and replace the current split `TRR-Backend` plus `screenalytics` topology with a backend-owned DeepFace reset.

## Core Value

Produce operator-reviewable screentime results that are trustworthy enough to drive episode-level analysis without depending on the retiring standalone `screenalytics` runtime.

## Requirements

### Validated

- ✓ Admin can ingest video assets through the current control plane via direct upload or remote import and persist canonical source metadata — existing transitional runtime
- ✓ The current system can create cast-screentime runs with candidate cast snapshots and facebank-backed identity matching — existing transitional runtime
- ✓ The current system can persist reviewable screentime artifacts including segments, evidence, excluded sections, metrics, and generated clips — existing transitional runtime
- ✓ TRR-APP already exposes internal admin entry points for cast-screentime and facebank-related workflows through backend-owned routes and proxies — existing transitional runtime

### Active

- [ ] Replace the standalone `screenalytics` runtime with a `TRR-Backend`-owned screentime analysis runtime, porting required donor logic and retiring the separate service topology
- [ ] Support screentime analysis for every show asset type in scope, including full episodes and supplementary videos such as trailers, clips, and other directly imported sources
- [ ] Calculate per-person screentime totals together with reviewable scenes, segments, evidence frames, exclusions, generated clips, and related run artifacts
- [ ] Implement a DeepFace reset for facebank and identity workflows while keeping ArcFace-class embeddings as the baseline matching standard during migration
- [ ] Expose internal admin workflows in TRR-APP for asset intake, run orchestration, review, corrections, and reruns
- [ ] Eliminate backend dependencies on `SCREENALYTICS_API_URL`, `SCREENALYTICS_SERVICE_TOKEN`, and other assumptions that a separate `screenalytics` runtime remains in production

### Out of Scope

- Public-facing screentime product surfaces or consumer episode pages — v1 is strictly for internal admin/operator use
- Fully autonomous “official” screentime metrics with no human review path — the initial system is explicitly operator-reviewable
- Preserving the standalone `screenalytics` FastAPI/Celery/Streamlit service as a long-term runtime — it is transitional donor code only
- Changing the embedding baseline away from ArcFace-class compatibility during the initial reset — migration risk is too high for the first release

## Context

- The current TRR screentime flow is split across `TRR-Backend`, `screenalytics`, and `TRR-APP`, with `screenalytics` now classified as a transitional runtime plus donor repo for the DeepFace reset.
- The DeepFace integration plan establishes the intended direction: database-backed seed registration, stateless search and verification, pgvector-backed ANN lookup, and retirement of legacy manifest-driven facebank storage.
- The current backend control plane already manages upload sessions, canonical video asset promotion, run dispatch, and run finalization, while the worker lane still depends on the retiring `screenalytics` runtime for actual analysis.
- The current system already produces run-scoped artifacts and review surfaces, which means the reset should preserve those audited outputs while replacing the service boundary and identity/search implementation.
- Cross-repo sequencing matters: shared contracts and runtime changes land backend-first, donor extraction from `screenalytics` is second, and TRR-APP admin workflow parity is last.

## Constraints

- **Audience**: Internal admin/operator only for v1 — public or end-user product surfaces are out of scope
- **Architecture**: `TRR-Backend` becomes the long-term home of the screentime runtime — `screenalytics` is donor code to port and retire
- **Identity baseline**: Keep ArcFace-class embedding compatibility during the reset, with DeepFace used to provide the new registration/search/verification layer
- **Input coverage**: Support direct uploads and direct imports from external sources, not only locally uploaded episode assets
- **Reviewability**: Results must stay operator-reviewable with supporting evidence, exclusions, scenes, and generated clips rather than reducing output to a single aggregate total
- **Shared contracts**: Runtime Postgres precedence remains `TRR_DB_URL` first and `TRR_DB_FALLBACK_URL` second across repos during the migration

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Build the project as a full DeepFace reset, not an additive sidecar only | The current goal is to retire the standalone `screenalytics` runtime and consolidate ownership in `TRR-Backend` | — Pending |
| Keep the system internal admin-first | Public reporting would expand the scope before runtime parity and operator review are solid | — Pending |
| v1 output includes totals plus auditable artifacts | Operators need reviewable scenes, segments, exclusions, evidence frames, generated clips, and related context to trust the results | — Pending |
| Support direct imports as well as uploads in v1 | Screentime analysis must handle real operational intake paths, not just manually uploaded assets | — Pending |
| Preserve ArcFace-class embedding compatibility during the DeepFace reset | Replacing the matching baseline and the runtime topology simultaneously would create unnecessary migration risk | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `$gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `$gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-02 after initialization*

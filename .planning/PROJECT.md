# TRR Engineering Milestones

## What This Is

An internal TRR engineering planning track for major backend, runtime, and workspace improvements that cut across the shared repos. The first completed milestone delivered the backend-owned screentime reset; the current milestone focuses on making workspace development and validation cloud-first so Docker is optional instead of assumed.

## Current Milestone: v1.1 Cloud-First / No-Docker Workspace Tooling

**Goal:** Make this workspace's development and validation flows cloud-first so Docker is optional instead of assumed.

**Target features:**
- Replace Docker-first local DB validation with remote Supabase branch or disposable-project workflows where possible
- Update workspace scripts and `Makefile` paths so Docker is not the default for normal development or milestone verification
- Narrow `local_docker` and local Screenalytics infra assumptions in doctor, preflight, and workspace bootstrap flows
- Preserve backend, app, and screentime verification paths that work without Docker in this workspace

## Core Value

Ship repo-spanning changes through workflows that are trustworthy, repeatable, and usable on this workspace without machine-specific local infrastructure assumptions.

## Requirements

### Validated

- ✓ The screentime reset delivered backend-owned asset intake, identity governance, execution, review, publication, and runtime retirement across `TRR-Backend` and `TRR-APP` — milestone v1.0
- ✓ The workspace can run backend-owned screentime verification against a remote Supabase environment without `SCREENALYTICS_*` production runtime dependencies — milestone v1.0
- ✓ The screentime admin UI can operate against backend-owned contracts while the split runtime is retired — milestone v1.0

### Active

- [ ] Workspace development defaults prefer cloud-first or remote validation flows over Docker-dependent local infrastructure
- [ ] Schema and migration validation can be performed safely against remote Supabase branches or disposable environments without requiring local `supabase start` as the default path
- [ ] Workspace scripts, profiles, and doctor checks make Docker opt-in for narrow cases instead of the assumed baseline
- [ ] Screenalytics-specific local infra assumptions are isolated so they do not block unrelated backend or app development
- [ ] Docs and handoffs clearly describe the no-Docker preferred path and when a Docker fallback is still acceptable

### Out of Scope

- Removing Docker from every repository script immediately — some narrow local infra paths may remain as explicit opt-in escape hatches
- Rewriting the completed screentime runtime milestone — this milestone is about tooling and workflow defaults, not reopening shipped screentime contracts
- Forcing all developers onto one single validation path regardless of task — the goal is to make cloud-first the preferred default, not ban all local specialization

## Context

- Milestone v1.0 completed the backend-owned screentime reset, but verification exposed that some “fresh environment” workflows still implicitly rely on Docker-backed local Supabase or local containerized services.
- The active workstream is `feature-b`, which is where the new milestone roadmap, requirements, and state will live.
- A planted seed now captures the explicit workspace preference to avoid Docker when a remote or branch-based alternative answers the same validation question.
- Current workspace tooling still references `local_docker`, `dev-local`, and Docker-gated Screenalytics infra in shared scripts and `Makefile` targets.
- Existing status notes already document one viable remote-first pattern: pushing migrations to a Supabase preview or branch database and validating there instead of assuming a local Docker reset.

## Current State

- Milestone v1.0 is complete in the prior workstream and delivered the five-phase screentime reset.
- Milestone v1.1 is starting in `feature-b` and is focused on workspace/tooling defaults rather than product/runtime feature expansion.
- The next planning target is Phase 6 of the cloud-first workspace tooling roadmap.

## Constraints

- **Workspace preference**: Avoid Docker as the default in this workspace when a safe remote-first alternative exists
- **Safety**: Remote validation paths must not encourage destructive operations against shared production resources
- **Cross-repo scope**: Changes may touch root workspace tooling, `TRR-Backend` validation scripts, and docs consumed by multiple repos
- **Continuity**: Existing Docker-based paths may remain as explicit opt-in fallbacks until cloud-first replacements are proven
- **Clarity**: The preferred path must be obvious from docs, scripts, and diagnostics rather than hidden in handoff notes

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Build the screentime reset as a backend-owned migration first | The production runtime needed to leave the standalone `screenalytics` service behind before tooling cleanup | ✓ Good |
| Keep the screentime system internal admin-first | Reviewability and operator trust mattered more than public product expansion for v1 | ✓ Good |
| Treat no-Docker workspace operation as a milestone-level tooling goal, not a one-off complaint | The preference affects validation defaults, script behavior, and future milestone planning | — Pending |
| Prefer remote Supabase branches or disposable environments over local Docker when they answer the same validation question | This reduces machine-specific friction while preserving safe, isolated verification | — Pending |

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
*Last updated: 2026-04-03 after starting milestone v1.1 Cloud-First / No-Docker Workspace Tooling*

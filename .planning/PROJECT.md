# TRR Engineering Milestones

## What This Is

An internal TRR engineering planning track for major backend, runtime, and workspace improvements that cut across the shared repos. The first completed milestone delivered the backend-owned screentime reset; the current milestone focuses on making workspace development and validation cloud-first so Docker is optional instead of assumed.

## Latest Shipped Milestone: v1.1 Cloud-First / No-Docker Workspace Tooling

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
- ✓ Phase 6 froze the preferred cloud-first workspace contract in shared docs, generated env docs, and handoff notes — milestone v1.1
- ✓ Phase 6 set backend schema-validation guidance to prefer isolated remote Supabase branches or disposable targets and explicitly exclude shared persistent databases from destructive validation — milestone v1.1
- ✓ Phase 7 aligned root help surfaces, shared profiles, and runtime messaging so Docker-backed Screenalytics infra is explicit fallback rather than assumed baseline — milestone v1.1
- ✓ Phase 8 proved a real no-Docker verification lane in this workspace and documented the remaining Docker-only cases as explicit fallback — milestone v1.1

### Active

- [ ] Define the next milestone scope

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
- Milestone v1.1 in `feature-b` is shipped and archived.
- The workspace is ready for the next milestone definition.

## Next Milestone Goals

- Decide whether the next milestone continues workspace-tooling simplification, returns to product/runtime work, or tackles a different cross-repo objective.
- Start the next milestone with fresh requirements instead of extending archived v1.1 scope.

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
| Treat no-Docker workspace operation as a milestone-level tooling goal, not a one-off complaint | The preference affects validation defaults, script behavior, and future milestone planning | ✓ Good |
| Prefer remote Supabase branches or disposable environments over local Docker when they answer the same validation question | This reduces machine-specific friction while preserving safe, isolated verification | ✓ Good |

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
*Last updated: 2026-04-04 after v1.1 milestone archival*

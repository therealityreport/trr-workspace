---
id: SEED-001
status: dormant
planted: 2026-04-03T22:45:00Z
planted_during: v1.0 milestone closeout
trigger_when: When a new milestone, phase, or tooling change proposes Docker, local Supabase reset, or `local_docker` workspace mode as the default validation or development path.
scope: Medium
---

# SEED-001: Avoid Docker in this workspace

## Why This Matters

The preferred direction for this workspace is to avoid Docker-based local workflows when there is a viable remote or branch-based alternative. Docker adds local environment friction, blocks validation when the daemon is unavailable, and pushes milestone verification toward machine-specific setup instead of reproducible shared infrastructure.

## When to Surface

**Trigger:** When a new milestone, phase, or tooling change proposes Docker, local Supabase reset, or `local_docker` workspace mode as the default validation or development path.

This seed should be presented during `$gsd-new-milestone` when the milestone
scope matches any of these conditions:
- Local database reset, schema replay, or migration validation is being planned and the default proposal is Docker-backed Supabase.
- Workspace dev scripts, `make` targets, or environment profiles are being changed in ways that assume Docker availability.
- A new runtime or verification loop proposes local container orchestration instead of remote Supabase branches, preview databases, or cloud-first validation.
- Screenalytics or other auxiliary services are being reintroduced through Docker-heavy local workflows.

## Scope Estimate

**Medium** — This is likely one phase or a coordinated tooling slice rather than a one-line tweak. It probably means changing validation defaults, documenting remote-first replacements, and updating workspace scripts or profiles so Docker is optional instead of assumed.

## Breadcrumbs

Related code and decisions found in the current codebase:

- [Makefile](/Users/thomashulihan/Projects/TRR/Makefile) — current workspace entry points still advertise `local-docker` / `dev-local` flows.
- [scripts/dev-workspace.sh](/Users/thomashulihan/Projects/TRR/scripts/dev-workspace.sh) — workspace mode handling still includes `local_docker` branches and Docker-gated Screenalytics startup.
- [scripts/doctor.sh](/Users/thomashulihan/Projects/TRR/scripts/doctor.sh) — local diagnostics treat Docker as required in `local_docker` mode.
- [scripts/down-screenalytics-infra.sh](/Users/thomashulihan/Projects/TRR/scripts/down-screenalytics-infra.sh) — local Screenalytics infra teardown is Docker-based.
- [TRR-Backend/Makefile](/Users/thomashulihan/Projects/TRR/TRR-Backend/Makefile) — schema docs guidance still points at `supabase db reset --yes`, which usually implies local Docker-backed Supabase.
- [shared-account-catalog-backfill-and-profile-ui.md](/Users/thomashulihan/Projects/TRR/docs/ai/local-status/shared-account-catalog-backfill-and-profile-ui.md) — existing handoff already documents a remote/preview-branch alternative using `supabase db push --db-url ... --include-all`.
- [STATE.md](/Users/thomashulihan/Projects/TRR/.planning/workstreams/milestone/STATE.md) — current milestone already surfaced Docker availability as a blocker for proving fresh local migration replay.

## Notes

- Treat this as a workspace preference and planning guardrail, not just a one-off operational annoyance.
- Favor remote Supabase branches, disposable projects, or cloud-first validation paths when they can answer the same question safely.
- If Docker remains necessary for a narrow case, make it opt-in rather than the default assumption for this workspace.

# AUDIT

Plan: `/Users/thomashulihan/Projects/TRR/docs/codex/plans/2026-04-27-supabase-connection-capacity-hardening-plan.md`

Rubric: `/Users/thomashulihan/Documents/Codex/2026-04-21-create-a-rubric-for-scoring-an/implementation-plan-rubric.md`

## VERDICT

Approve after the revised artifact, not the original, is used for execution.

The source plan is strong and repo-grounded. It names the real TRR app/backend/workspace surfaces, captures the new 2026-04-27 audit findings, and sequences low-cost guardrails before any pool-size or compute decision. The main weakness was not technical correctness; it was execution ergonomics for a broad multi-phase plan.

## CURRENT-STATE FIT

Fit: strong.

Evidence checked:

- Runtime DDL exists in `TRR-APP/apps/web/src/lib/server/shows/shows-repository.ts`.
- `docs/workspace/app-direct-sql-inventory.md` reports `108` app direct-SQL call sites, `14` high-fanout production-risk sites, and `22` owner-label gaps.
- Local PostgREST exposure includes `public`, `graphql_public`, `core`, and `admin` in `TRR-Backend/supabase/config.toml`.
- The plan's named workspace scripts, validation tests, and docs are present.
- RLS/advisor/capacity docs still contain pending or blocked evidence, which the plan correctly treats as a required evidence-capture phase.

## BENEFIT SCORE

Benefit score: 9/10.

The plan directly targets a real operator-facing failure mode: admin pages timing out under Supabase/Supavisor pressure. It also addresses the deeper system causes: env drift, runtime DDL, split migration ownership, high-fanout direct SQL, weak production evidence, and Vercel project/env ambiguity.

## BIGGEST RISKS

1. Scope breadth: the plan touches app, backend, workspace scripts, Vercel, Supabase config, migrations, and docs. Without explicit routing, execution could become scattered.
2. Production mutation risk: env cleanup and pool-size changes require human approval and evidence gates.
3. Migration provenance risk: Phase 8B must prove parity before quarantining app migrations.
4. Transaction-mode risk: prepared statements and session state must be proven absent before moving routes to port `6543`.

## REQUIRED PATCHES APPLIED IN REVISED_PLAN.md

1. Added measurable success criteria so the plan has observable post-rollout outcomes.
2. Added execution routing so Phases 0-2 stay inline and later workstreams can be safely delegated.
3. Added stop conditions and human checks for production env mutation, pool-size changes, destructive migrations, PostgREST exposure changes, app migration quarantine, and broad transaction-mode rollout.
4. Added the required cleanup note.

## APPROVAL DECISION

Approved for execution from `REVISED_PLAN.md`.

Execution should start with Phases 0-2 inline. After those merge, use `orchestrate-subagents` for independent backend, app, workspace/ops, and DB/schema workstreams.

## FOLLOW-UP REVISION

All 10 numbered suggestions from `SUGGESTIONS.md` were incorporated into `REVISED_PLAN.md` under `## ADDITIONAL SUGGESTIONS`.

This increases execution scope, but the added work is operationally useful and now has dependencies, affected surfaces, validation steps, acceptance criteria, and commit boundaries. The revised score estimate increases from `88.9/100` to `91.0/100`.

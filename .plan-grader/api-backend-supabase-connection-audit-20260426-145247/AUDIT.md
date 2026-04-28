# Audit: TRR API/Backend/Supabase Connection Audit And Improvement Plan

Source plan: `docs/superpowers/plans/2026-04-26-api-backend-supabase-connection-audit-and-improvement-plan.md`

## Verdict

Approve with required tightening before implementation.

The plan is directionally correct and grounded in the real TRR local-dev posture: `TRR_DB_URL`, Supavisor session mode, small local pools, named backend lanes, Vercel deployment metadata, app runtime DDL, and app direct-SQL surfaces are all correctly called out. It is strong enough to serve as the base plan, but it should not be executed unchanged because a few validation steps and stop gates are too loose for production database work.

## Current-State Fit

- Strong fit for local dev: it preserves the current cloud-first, tiny-pool, session-pooler `make dev` model instead of widening pools as the first fix.
- Strong fit for TRR ownership boundaries: backend-first for schema/API/shared contracts, app follow-through after contract changes.
- Strong fit for the present evidence gap: Supabase MCP advisor/migration/storage access was blocked, and the plan treats that as a blocker for production capacity decisions.
- Partial fit for Vercel: it identifies both `trr-app` and the nested `web` project, but needs a concrete decision gate so implementers do not patch the wrong project.

## Benefit Score

High. This plan reduces the most expensive TRR failure class around Supabase connection saturation, serverless pool fan-out, migration drift, and app/backend schema ownership. The work benefits local operators, production deploy confidence, and future scraper/admin surfaces that depend on predictable DB access.

## Required Fixes Before Execution

1. Add an explicit Phase 0 stop gate: no production env, pool-size, transaction-mode, or migration changes until Supabase advisors, Vercel env inventory, and `pg_stat_activity` evidence are captured or the permission blocker is formally recorded.
2. Replace the RLS validation SQL. The original query references `pg_tables.hasrls`, which is not a reliable catalog column. Use `pg_class.relrowsecurity` and `relforcerowsecurity`, plus grants from `information_schema.role_table_grants`.
3. Split "Vercel direct-SQL strategy" into measurable slices. The plan says to reduce direct SQL but does not define the first candidate set, acceptance metric, or owner labels well enough.
4. Add stop and rollback rules for transaction-mode experiments, Supavisor pool changes, Vercel env changes, and migration ownership moves.
5. Add an artifact requirement for the production inventory so later execution does not rely on chat memory.
6. Tighten migration validation so `supabase db push` is not run casually against the wrong remote or through the wrong connection lane.
7. Make the app runtime DDL removal test concrete enough to implement.

## Approval Decision

Original plan: good plan, execute only after revision.

Revised plan: ready for phased execution once Phase 0 evidence is captured.


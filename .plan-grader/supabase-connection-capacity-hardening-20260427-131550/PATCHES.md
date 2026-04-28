# PATCHES

Source plan:

`/Users/thomashulihan/Projects/TRR/docs/codex/plans/2026-04-27-supabase-connection-capacity-hardening-plan.md`

Revised plan:

`/Users/thomashulihan/Projects/TRR/.plan-grader/supabase-connection-capacity-hardening-20260427-131550/REVISED_PLAN.md`

## Patch 1 - Add measurable success criteria

Inserted `## measurable_success_criteria` after `## goals`.

Purpose:

- Converts broad acceptance criteria into observable outcomes.
- Names the key post-rollout checks: no repeated `EMAXCONNSESSION`, holder-budget enforcement, zero app request-time DDL, high-fanout SQL migration/exception status, ledger backfill, capacity table evidence, and Vercel env runtime proof.

## Patch 2 - Add execution routing

Inserted `## execution_routing` after `## measurable_success_criteria`.

Purpose:

- Keeps Phases 0-2 inline because they share contracts.
- Allows `orchestrate-subagents` after guardrails land.
- Defines disjoint workstreams: backend API, app compatibility/fallback, workspace/ops, and DB/schema.
- Prevents parallel edits to the same migration numbering, shared env docs, or overlapping files.

## Patch 3 - Add stop conditions and human checks

Inserted `## stop_conditions_and_human_checks` after `## risks_edge_cases_open_questions`.

Purpose:

- Prevents unsafe autonomous production env mutation.
- Prevents premature pool-size/compute changes.
- Requires approval before destructive migrations, PostgREST exposure removal, app migration quarantine, and broad transaction-mode rollout.
- Handles permission-blocked Supabase/Vercel evidence by recording blockers instead of inventing values.

## Patch 4 - Add cleanup note

Inserted the required `## Cleanup Note` before `## ready_for_execution`.

Purpose:

- Preserves Plan Grader artifacts during implementation.
- Makes cleanup explicit after the plan is fully implemented and verified.

## Patch 5 - Incorporate all numbered suggestions

Inserted `## ADDITIONAL SUGGESTIONS` after `## stop_conditions_and_human_checks`.

Purpose:

- Converts every numbered suggestion from `SUGGESTIONS.md` into accepted plan work.
- Avoids leaving useful operational improvements as a detached optional list.
- Gives each suggestion concrete changes, dependencies, affected surfaces, validation steps, acceptance criteria, and commit boundary.

Suggestion mapping:

| Source suggestion | Revised plan task |
|---|---|
| 1. Add a one-page operator runbook | `### Suggestion 1 - Add a one-page operator runbook` |
| 2. Add a fixture-backed fake `pg_stat_activity` test | `### Suggestion 2 - Add a fixture-backed fake pg_stat_activity test` |
| 3. Add a plan-owned glossary for connection terms | `### Suggestion 3 - Add a plan-owned glossary for connection terms` |
| 4. Add a migration numbering policy | `### Suggestion 4 - Add a migration numbering policy` |
| 5. Add a local pressure rehearsal command | `### Suggestion 5 - Add a local pressure rehearsal command` |
| 6. Add owner aliases for recurring Supabase surfaces | `### Suggestion 6 - Add owner aliases for recurring Supabase surfaces` |
| 7. Add exception expiry dates for retained direct SQL | `### Suggestion 7 - Add exception expiry dates for retained direct SQL` |
| 8. Add screenshot-based smoke evidence for admin fallback UI | `### Suggestion 8 - Add screenshot-based smoke evidence for admin fallback UI` |
| 9. Add a Supabase Dashboard evidence checklist | `### Suggestion 9 - Add a Supabase Dashboard evidence checklist` |
| 10. Add a final reviewer handoff template | `### Suggestion 10 - Add a final reviewer handoff template` |

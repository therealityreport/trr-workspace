# SUGGESTIONS

Status: incorporated.

All numbered suggestions in this file have been incorporated into `REVISED_PLAN.md` under `## ADDITIONAL SUGGESTIONS`. This file is retained as source traceability for the incorporated tasks, not as a remaining optional backlog.

## 1. Add a one-page operator runbook

Type: Small

Why: The plan improves diagnostics, but operators will still need a concise response path during the next timeout.

Where it would apply: `docs/workspace/dev-commands.md` or a new `docs/workspace/db-pressure-runbook.md`.

How it could improve the plan: Gives the user a quick checklist for "admin page timed out" without rereading the whole plan.

## 2. Add a fixture-backed fake `pg_stat_activity` test

Type: Medium

Why: DB pressure snapshots are important but can be hard to test against live Supabase.

Where it would apply: workspace script tests and backend health endpoint tests.

How it could improve the plan: Makes holder snapshot parsing deterministic and prevents regressions in summary output.

## 3. Add a plan-owned glossary for connection terms

Type: Small

Why: The repo uses session mode, transaction mode, direct SQL, Supabase API, Vercel attach, and service-role language together.

Where it would apply: `docs/workspace/supabase-capacity-budget.md` or `docs/workspace/env-contract.md`.

How it could improve the plan: Reduces future confusion between API calls and Postgres holders.

## 4. Add a migration numbering policy

Type: Small

Why: Duplicate migration prefixes are called out, but a lightweight policy would prevent the smell from returning.

Where it would apply: `TRR-Backend/supabase/migrations/README.md` or `docs/workspace/dev-commands.md`.

How it could improve the plan: Makes future migration ordering review faster.

## 5. Add a local "pressure rehearsal" command

Type: Medium

Why: The plan has manual validation steps, but a repeatable local rehearsal would be easier to run before major admin changes.

Where it would apply: `Makefile`, workspace scripts, and docs.

How it could improve the plan: Simulates multiple admin pages/status subscribers and captures before/after holder behavior.

## 6. Add owner aliases for recurring Supabase surfaces

Type: Small

Why: Owner labels like `admin-read-model` are useful, but human owners or team aliases would help future triage.

Where it would apply: `docs/workspace/app-direct-sql-inventory.md` and ownership docs.

How it could improve the plan: Speeds up assignment when a route keeps failing or an exception expires.

## 7. Add "exception expiry" dates for retained direct SQL

Type: Small

Why: The plan allows tracked exceptions for high-fanout direct SQL, but exceptions can become permanent.

Where it would apply: `docs/workspace/app-direct-sql-inventory.md` and `api-migration-ledger.md`.

How it could improve the plan: Keeps temporary exceptions visible until migrated or reapproved.

## 8. Add screenshot-based smoke evidence for admin fallback UI

Type: Medium

Why: Partial/stale fallback behavior is operator-facing and easy to regress visually.

Where it would apply: Playwright or browser-use verification after Phase 8.

How it could improve the plan: Confirms the UI stays usable rather than only asserting route JSON.

## 9. Add a Supabase Dashboard evidence checklist

Type: Small

Why: Advisor, Auth, Storage, SMTP, and capacity checks require external dashboard evidence.

Where it would apply: `docs/workspace/supabase-advisor-snapshot-YYYY-MM-DD.md` template.

How it could improve the plan: Ensures external checks produce consistent artifacts even when MCP access is blocked.

## 10. Add a final reviewer handoff template

Type: Small

Why: This plan will produce many commits across app, backend, workspace scripts, and docs.

Where it would apply: `.plan-grader` artifacts or `docs/workspace/`.

How it could improve the plan: Gives the reviewer a compact list of changed contracts, migrations, env behavior, and validation proof.

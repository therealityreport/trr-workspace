# Plan Audit: Supavisor Session Pool Stabilization

Source plan: `/Users/thomashulihan/Projects/TRR/docs/superpowers/plans/2026-04-26-supavisor-session-pool-stabilization.md`

Rubric: `/Users/thomashulihan/Documents/Codex/2026-04-21-create-a-rubric-for-scoring-an/implementation-plan-rubric.md`

## Verdict

Conditional pass. The original plan is valuable and mostly repo-grounded, but it should not be executed autonomously as written. Use `REVISED_PLAN.md` as the execution source of truth.

Original score: **78 / 100**

Revised plan estimate after second-pass additions: **95 / 100**

## Approval Decision

Approved after revision. The revised plan tightens repo ownership, separates local-process pressure from upstream Supavisor pressure, removes placeholder file/router decisions from core tasks, and changes the sequence so high-risk runtime choices are verified before being locked into defaults.

## Current-State Fit

The plan fits the observed failure. The triggering route was `/api/admin/social/landing`, the observed error was `(EMAXCONNSESSION) max clients reached in session mode - max clients are limited to pool_size: 15`, and the current default local holder budget can reach 15 when app, backend, named backend pools, and health pool are all counted.

The plan also matches TRR's current direction: keep local `make dev` cloud-first and session-pooled, use small bounded pools, preserve backend-owned app contracts, and avoid widening local concurrency to hide bad fan-out.

## Benefit Score

High. If implemented, the plan should reduce local and production session-pool saturation, make DB pressure diagnosable, and move repeated app direct SQL reads into backend-owned contracts. That directly helps admin operators and developers working in the local TRR workspace.

## Required Fixes Applied In Revised Plan

1. Added explicit nested-repo ownership and branch/commit boundaries for workspace root, `TRR-APP`, `TRR-Backend`, and `screenalytics`.
2. Split pressure diagnostics into local process pool snapshots versus upstream Supavisor session pressure so `/health/db-pressure` is not oversold.
3. Added a mandatory pre-edit discovery step for actual backend admin router placement and runtime DB env helper names.
4. Changed the sequence so social landing migration and cache work happen after measurement and app pool logging, not as overlapping guesses.
5. Added validation for backend burst needs before locking in a lower general backend pool.
6. Tightened Screenalytics `.env` behavior so the implementation must preserve explicit pre-existing env vars while skipping production `.env` DB values when disabled.
7. Replaced broad validation commands with targeted commands first, with full sweeps listed as optional release checks.
8. Added rollback gates and stop conditions for Supavisor pool-size changes, route-shape drift, and saturation under the capped pools.
9. Added production capacity math and deployment caps as a production rollout gate.
10. Required DB-level `pg_stat_activity` holder evidence and explicit `application_name` values before relying on pressure diagnostics.
11. Protected detailed DB pressure output behind internal/admin authorization.
12. Split social landing migration into first-slice backend summary work and a follow-up SocialBlade/cast direct-SQL removal task.
13. Added stale/partial payload semantics, cache-poisoning guards, app pressure diagnostics, frontend polling throttles, and auth-valid manual validation.

## Biggest Remaining Risks

1. The actual backend router surface for a new admin social landing endpoint still must be confirmed before editing. The revised plan makes that a blocking discovery step.
2. Supavisor pool settings are external to the repo. The revised plan requires manual evidence capture rather than treating dashboard changes as code validation.
3. App pool max `1` may expose slow direct-SQL paths. The revised plan requires targeted route timing and backend burst validation before making it the only local path.
4. Transaction pooler adoption is intentionally deferred. New env names are introduced, but transaction mode remains disabled until client compatibility is proven.

## Final Recommendation

Execute the revised plan in phases. Start with emergency relief, Supavisor holder evidence, and production capacity math, then local safety, protected observability, route migration, and caching/polling reduction. Do not start with the env-lane rename or transaction-mode work.

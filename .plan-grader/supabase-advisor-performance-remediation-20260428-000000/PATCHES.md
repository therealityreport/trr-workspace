# PATCHES

These are the material changes applied during the `revise-plan` pass.

## Patch 1 - Make canonical execution source explicit

Original issue: the generated `.plan-grader` plan could be mistaken for the execution source of truth.

Replacement behavior:

- The canonical execution plan is now `/Users/thomashulihan/Projects/TRR/docs/codex/plans/2026-04-28-supabase-advisor-performance-remediation-plan.md`.
- The `.plan-grader` copy is labeled temporary evidence only.

## Patch 2 - Gate Phase 1 with urgent security hotfix work

Original issue: the plan deferred Security Advisor work too loosely behind the performance/index sequence.

Replacement behavior:

- Added a `Parallel Safety Hotfix Gate - Before Or Alongside Phase 1`.
- Requires a separate security workstream/branch to lock down `public.__migrations`.
- Requires revoking `anon`/`authenticated` `EXECUTE` from exposed `SECURITY DEFINER` RPCs unless explicitly approved.
- Keeps remaining `search_path` and `public.vector` work in the later full safety pass.

## Patch 3 - Strengthen Phase 0 inventory

Original issue: Phase 0 captured policies, but not the rest of the effective access model.

Replacement behavior:

- Added GRANT inventory for affected tables.
- Added owner, RLS-enabled, and FORCE RLS inventory.
- Added before-state policy capture for rollback.
- Added before-state permission-matrix expectations.

## Patch 4 - Add exact command-specific policy DDL rules

Original issue: the service-role policy wording could be misread across `INSERT`, `UPDATE`, and `DELETE`.

Replacement behavior:

- Added explicit templates:
  - `INSERT` uses `WITH CHECK`.
  - `UPDATE` uses both `USING` and `WITH CHECK`.
  - `DELETE` uses `USING`.
- Required preserving or explicitly replacing existing `TO` roles instead of relying on default `PUBLIC`.

## Patch 5 - Tighten firebase survey semantics

Original issue: the owner/admin merge did not fully specify null handling, UUID casts, and old/new row checks.

Replacement behavior:

- Uses `nullif((select current_setting('app.firebase_uid', true)), '')` for the live text Firebase UID contract.
- Specifies `responses` `SELECT`, `INSERT`, and `UPDATE` semantics.
- Specifies `answers` parent-response visibility and move-prevention semantics.
- Adds a stop rule if `answers` `UPDATE` can move an answer to another user's response.

## Patch 6 - Require access matrix tests, rollback SQL, and immediate advisor recheck

Original issue: startup/connection tests were not proof of RLS equivalence, and RLS rollback was under-specified.

Replacement behavior:

- Requires per-table permission matrix tests before and after Phase 1.
- Requires generated diffs between Phase 0 and Phase 1 `pg_policies` inventories.
- Requires rollback SQL that restores exact Phase 0 policies by name.
- Requires immediate Performance Advisor verification of the seven `auth_rls_initplan` findings before Phase 2.

## Patch 7 - Change approval posture

Original issue: the plan described itself as broadly ready for execution.

Replacement behavior:

- Status now says Phase 1 local staging is approved while live DDL and Phase 2+ remain gated.
- Phase 1+ is blocked pending approval of the amended safety and access-semantics gates.

## Patch 8 - Add subagent orchestration as an executable plan section

Original issue: the plan recommended `orchestrate-subagents`, but did not define how the main session should split work, assign ownership, prevent overlap, or integrate returned changes.

Replacement behavior:

- Added a `subagent_orchestration` section to both the `.plan-grader` copy and the canonical `docs/codex/plans/` plan.
- Defined the main session as the orchestrator responsible for branch/preflight checks, dirty-worktree classification, dependency tracking, final integration, and validation.
- Added disjoint subagent workstreams for Safety hotfix DDL, RLS cleanup and rollback, verifier/tests, evidence/runbooks, Phase 2 index evidence scaffolding, and independent review.
- Added parallelization waves so local artifact work can run concurrently while live DDL, live index reporting, and destructive index work remain gated.
- Added subagent stop rules, required report format, acceptance criteria, validation checks, and risk controls.

---
name: social-ingestion-reliability
description: Workspace-local canonical owner for diagnosing and hardening TRR social ingestion auth preflight, Modal dispatch, queue and worker orchestration, persistence correctness, and observability.
---
Use this workspace-local skill for TRR social-ingestion reliability work across queue, worker, sync-session, and persistence boundaries.

## When to use
1. Social ingestion is failing, stalling, duplicating, or dropping data.
2. Auth preflight, Modal resolution, dispatch-blocked jobs, likely-stuck queue work, or fail-fast `SOCIAL_WORKER_UNAVAILABLE` paths need diagnosis.
3. Sync-session orchestration, shared-account catalog runs, or comment, media, or avatar completeness follow-ups are incomplete or misleading.
4. Persistence, idempotency, retry, rate-limit, or queue-fairness behavior needs hardening on a social ingestion path.

## When not to use
1. Generic non-social reliability work.
2. Unrelated feature implementation with no ingestion reliability risk.
3. Broad security or ops ownership outside the ingestion path.
4. Cross-repo contract delivery where `senior-fullstack` should own producer and consumer sequencing.

## Ownership boundary
1. This is the canonical TRR owner for social ingestion auth, dispatch, queue, worker, persistence, and observability failures.
2. Keep the first-response workflow anchored in `TRR-Backend` even when the symptom first appears in `TRR-APP`.
3. Pair with other workspace-local owners only when the work expands beyond social ingestion reliability:
   - `/Users/thomashulihan/Projects/TRR/.agents/skills/senior-fullstack/SKILL.md`
   - `/Users/thomashulihan/Projects/TRR/.agents/skills/senior-devops/SKILL.md`
   - `/Users/thomashulihan/Projects/TRR/.agents/skills/senior-qa/SKILL.md`
   - `/Users/thomashulihan/Projects/TRR/.agents/skills/code-reviewer/SKILL.md`

## Preflight
1. Identify the failing platform and entrypoint:
   - admin socials API route
   - sync-session route or stream
   - queue worker
   - Modal social dispatch
   - shared-account or catalog run
2. Identify the execution mode:
   - inline
   - queued with local worker ownership
   - queued with remote Modal ownership
3. Capture the first failing signal:
   - `SOCIAL_WORKER_UNAVAILABLE`
   - Modal-resolution or dispatch-blocked failure
   - stale heartbeat or stuck queue state
   - sync-session or run-state drift
   - duplicate, missing, or partial persistence
4. Capture the operator-facing diagnostics before making changes:
   - additive `alerts` arrays from worker-health or catalog-progress responses
   - queue execution diagnostics such as `queue_enabled`, `used_inline_fallback`, and `requires_modal_executor`
   - shared-account canary context, especially whether the failing or recommended order is `Sync Recent`, then `Sync Newer`, then `Backfill Posts`
5. Identify the first source of truth before making changes.

Stop conditions:
1. The failing surface cannot be stated concretely.
2. The runtime mode is unclear and changes the ownership path.
3. Intended success criteria are not knowable from the task or surrounding code.

## Execution checklist
1. Validate auth preflight before debugging deeper layers:
   - cookie or credential source
   - platform auth mode
   - worker auth capabilities
   - fail-closed behavior when auth is missing
2. Verify Modal or dispatch readiness next:
   - function resolution
   - remote execution mode
   - dispatch-blocked reasons
   - `SOCIAL_WORKER_UNAVAILABLE` or Modal-required responses
3. Verify worker heartbeat and queue state:
   - healthy worker availability
   - stale heartbeat detection
   - queue fairness and claim behavior
   - likely-stuck versus dispatch-blocked semantics
4. Verify run and sync-session orchestration:
   - run status transitions
   - sync pass sequencing
   - shared-account and catalog completion behavior
   - comment, media, and avatar follow-up gaps
   - preferred shared-account canary order: `Sync Recent`, then `Sync Newer`, then `Backfill Posts`
5. Verify persistence and idempotency:
   - upsert and dedupe behavior
   - duplicate-write protections
   - stale or partial row repair paths
   - cache or summary truthfulness versus storage truth
6. Close the loop on observability and recurrence prevention:
   - logs and queue-status visibility
   - additive `alerts` arrays as the primary operator-facing reason codes during triage
   - queue execution diagnostics such as `used_inline_fallback` and `requires_modal_executor` so inline fallback is not mistaken for healthy queued execution
   - counters or reason buckets needed for recurrence detection
   - targeted regression tests for the failing layer
7. Keep fixes tightly scoped to the ingestion path and prove them with the smallest targeted validation slice.

## TRR source-of-truth map
1. Start with `/Users/thomashulihan/Projects/TRR/.agents/skills/social-ingestion-reliability/references/source-of-truth.md`.
2. Treat the backend runbook and `TRR-Backend` queue and sync code as the primary authority for runtime behavior.
3. Use `TRR-APP` only as the symptom surface unless the issue is clearly a consumer or operator UX problem.

## Fallback routing
1. Route cross-repo contract and consumer updates to `/Users/thomashulihan/Projects/TRR/.agents/skills/senior-fullstack/SKILL.md`.
2. Route release-path, Modal deployment, rollback, and operational hardening work to `/Users/thomashulihan/Projects/TRR/.agents/skills/senior-devops/SKILL.md`.
3. Route validation strategy and regression evidence gaps to `/Users/thomashulihan/Projects/TRR/.agents/skills/senior-qa/SKILL.md`.
4. Route risk-audit and post-change bug review to `/Users/thomashulihan/Projects/TRR/.agents/skills/code-reviewer/SKILL.md`.

## Imported strengths
1. From `monitoring-expert`: observability gaps and alerting prompts.
2. From `security-reviewer`: auth/session and secret-handling prompts.
3. From `devops-engineer`: worker/runbook/recovery thinking.

## Explicit rejections
1. Do not broaden into generic platform ops ownership.
2. Do not broaden into full security-review ownership outside the ingestion path.

## Completion contract
Return:
1. `platform_surface`
2. `failure_layer`
3. `first_source_of_truth`
4. `fixes_applied`
5. `validation_evidence`
6. `observability_followups`
7. `escalation_owner`
8. `residual_ingestion_risks`

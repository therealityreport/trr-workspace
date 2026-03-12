---
name: social-ingestion-reliability
description: Workspace-local canonical owner for diagnosing and hardening TRR social ingestion reliability, including auth preflight, retries, rate limits, worker orchestration, persistence correctness, and observability.
---
Use this workspace-local skill for social-ingestion reliability work across TRR repos and worker boundaries.

## When to use
1. Social ingestion is failing, stalling, duplicating, or dropping data.
2. Auth/session refresh, rate limiting, retries, queueing, or worker coordination needs hardening.
3. Persistence or idempotency correctness is at risk for social ingestion paths.

## When not to use
1. Generic non-social reliability work.
2. Unrelated feature implementation.
3. Broad security or ops ownership outside the ingestion path.

## Preflight
1. Identify the failing ingestion path and exact platform surface.
2. Identify where the failure sits:
   - auth/session
   - fetch/retry/rate-limit
   - queue/worker
   - persistence/idempotency
   - downstream visibility/monitoring
3. Identify affected repos and the first source of truth.

## Reliability checklist
1. Validate auth preflight and token/session assumptions before debugging deeper layers.
2. Check retry rules, backoff, idempotency keys, and duplicate-write protections.
3. Verify rate-limit handling, worker concurrency, and queue visibility assumptions.
4. Confirm logs, metrics, and alarms are sufficient to detect recurrence.
5. Keep fixes tightly scoped to the ingestion path and prove them with targeted validation.

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
3. `fixes_applied`
4. `observability_followups`
5. `residual_ingestion_risks`

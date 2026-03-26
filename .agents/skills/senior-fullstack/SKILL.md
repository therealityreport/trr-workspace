---
name: senior-fullstack
description: Workspace-local canonical owner for coordinated TRR cross-repo API, data-flow, and UI changes when contracts, schema, or downstream consumers are involved.
---
Use this workspace-local skill when work spans `TRR-Backend`, `screenalytics`, and `TRR-APP`, or when one repo change can break another repo's contract.

## When to use
1. API, schema, queue, or data-shape changes affect more than one TRR repo.
2. A single feature crosses backend, consumer, and UI boundaries.
3. Error handling, retry semantics, or security behavior must stay aligned end-to-end.

## When not to use
1. Single-repo work with no contract or downstream impact.
2. Docs-only, planning-only, or review-only requests.
3. Pure frontend polish with a stable backend contract.

## Ownership boundary
1. This is the canonical TRR workspace owner for cross-repo implementation order and contract safety.
2. Keep this skill as the primary workspace owner even when the implementation reaches into multiple repos.
3. Keep `orchestrate-plan-execution` as the entrypoint for non-trivial mutation sessions.

## Preflight
1. Identify the source-of-truth contract and every downstream consumer.
2. Confirm the implementation order:
   - `TRR-Backend`
   - `screenalytics`
   - `TRR-APP`
3. Identify dataflow risks:
   - request/response shapes
   - retries/timeouts
   - auth and shared-secret behavior
   - persistence and idempotency

Stop conditions:
1. The contract owner is unclear.
2. Cross-repo impact cannot be stated concretely.

## Execution checklist
1. Change producer contracts before consumer updates.
2. Preserve additive compatibility where possible; if not, update all affected consumers in the same session.
3. Trace the full request-to-storage-to-UI path and verify failure handling, empty states, and retry behavior.
4. Apply security-aware implementation checks:
   - auth/authz boundaries
   - secret propagation
   - user-visible error leakage
5. Keep the implementation focused on delivery, not on writing a separate design artifact unless the user asked for planning.

## Imported strengths
1. From `fullstack-guardian`: end-to-end dataflow reasoning, integration failure thinking, and explicit error-path checks.
2. From TRR policy: repo ordering, shared-secret awareness, and contract drift prevention.

## Explicit rejections
1. Do not require a generic technical-design document before coding.
2. Do not act as a generic owner for isolated single-repo work.

## Fallbacks
1. Route release and operational hardening to `/Users/thomashulihan/Projects/TRR/.agents/skills/senior-devops/SKILL.md`.
2. Route architecture-heavy tradeoff work to `/Users/thomashulihan/Projects/TRR/.agents/skills/senior-architect/SKILL.md`.
3. Route validation strategy and regression coverage to `/Users/thomashulihan/Projects/TRR/.agents/skills/senior-qa/SKILL.md`.

## Completion contract
Return:
1. `repos_touched`
2. `contracts_changed`
3. `consumer_updates_completed`
4. `validation_run`
5. `residual_cross_repo_risks`

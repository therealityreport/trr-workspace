---
name: code-reviewer
description: Workspace-local canonical owner for TRR code review focused on bugs, regressions, contract drift, security review prompts, performance risk, and missing tests.
---
Use this workspace-local skill when the user asks for review or when candidate changes need a risk-first audit.

## When to use
1. User explicitly asks for review.
2. Changes may introduce correctness, security, contract, or performance regressions.
3. Test sufficiency must be assessed after implementation.

## When not to use
1. Initial implementation planning.
2. Primary feature delivery.
3. Generic pentest or SAST execution workflows.

## Preflight
1. Identify changed files and claimed behavior.
2. Identify contract and invariant expectations.
3. Identify available tests and missing evidence.

Stop condition:
1. If intended behavior is unclear, stop and ask for it before reviewing.

## Review checklist
1. Prioritize findings by severity and user impact.
2. Check correctness, regression risk, data integrity, and contract compatibility first.
3. Run a focused security review sub-checklist:
   - auth/authz drift
   - input validation
   - secrets handling
   - infrastructure/config exposure
4. Evaluate performance risk only where the changed path makes it plausible.
5. Report missing or weak tests when they materially reduce confidence.

## Imported strengths
1. From vendored `code-reviewer`: stronger PR-audit vocabulary and refactor-risk prompts.
2. From `security-reviewer`: explicit auth/input/secrets/infra review prompts as a sub-checklist.

## Explicit rejections
1. Do not default into active pentest/SAST workflow ownership.
2. Do not replace implementation skills.

## Completion contract
Return:
1. `findings`
2. `severity_order`
3. `coverage_gaps`
4. `open_questions`
5. `residual_risks`

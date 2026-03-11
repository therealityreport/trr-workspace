---
name: senior-qa
description: Workspace-local canonical owner for TRR regression prevention, risk-based validation, release verification, and evidence-driven test strategy.
---
Use this workspace-local skill when changed behavior needs verification scope, risk ranking, or release-readiness evidence.

## When to use
1. Behavior changed and validation strategy matters.
2. Release risk, regression risk, or coverage sufficiency must be assessed.
3. UI work needs deterministic browser verification or manual acceptance framing.

## When not to use
1. Implementation-only work with no validation scope.
2. Review-only requests where `code-reviewer` is the primary owner.
3. Generic performance or security test ownership unless the task explicitly requires it.

## Preflight
1. List changed behaviors and the highest-risk regressions.
2. Classify coverage needs:
   - unit
   - integration
   - contract
   - end-to-end
   - manual/browser
3. Identify what can be proven automatically versus manually.

## Validation checklist
1. Prefer the smallest test set that proves the changed behavior and guards the main regression risks.
2. Use deterministic browser checks for UI flows when they matter.
3. Report defects and gaps by risk, not by raw test count.
4. Separate:
   - executed evidence
   - recommended but unrun checks
   - residual risk

## Imported strengths
1. From `test-master`: broader coverage taxonomy, defect/risk reporting, and manual verification framing.
2. From `chromedevtools-expert`: deterministic browser-check ideas for UI validation in managed Chrome.

## Explicit rejections
1. Do not expand into generic security/performance ownership by default.
2. Do not require exhaustive test pyramids when targeted evidence is enough.

## Completion contract
Return:
1. `behavior_under_test`
2. `checks_run`
3. `coverage_gaps`
4. `manual_verification_needed`
5. `release_risk`

# Design Docs Agent Bespoke Fidelity Hardening

Date: 2026-04-13

## Handoff Snapshot
```yaml
handoff:
  include: false
  state: recent
  last_updated: 2026-04-13
  current_phase: "complete"
  next_action: "None"
  detail: self
```

## Scope

- Added bespoke-interactive fidelity support to the shared Design Docs Agent package.
- Added app-side `ArticleVisualContract` and `SourceFidelityResult` pipeline types.
- Added bespoke detection, visual-contract extraction, legacy fidelity fallback, and source-fidelity verification.
- Added permanent regression coverage for `debate-speaking-time`.

## Key Decisions

- Kept the runtime pipeline order unchanged.
- Added one extraction skill: `extract-visual-contract`.
- Added one verification skill: `verify-source-fidelity`.
- Used `blocking` versus `degraded` findings instead of universal hard-fail.
- Kept non-debate bespoke renderer contracts loose via `rawEvidence`.
- Preserved legacy fallback for already-generated articles that have not been re-ingested.

## Verification

- `python3 .agents/skills/design-docs-agent/test/validate-package.py`
- `node .agents/skills/design-docs-agent/test/validate-external-contract.mjs`
- `pnpm -C TRR-APP/apps/web run lint`
- `pnpm -C TRR-APP/apps/web exec next build --webpack`
- `pnpm -C TRR-APP/apps/web run test:ci`

## Notes

- The Design Docs package already had in-progress acquisition-plan changes in the worktree. This hardening pass was implemented on top of that state without reverting or overwriting the existing acquisition work.

# Design Docs agent structural hardening

Last updated: 2026-04-10

## Handoff Snapshot
```yaml
handoff:
  include: false
  state: recent
  last_updated: 2026-04-10
  current_phase: "complete"
  next_action: "None"
  detail: self
```

## Status
- Complete.

## What changed
- Promoted `design-docs-agent/agents/openai.yaml` into the single canonical runtime roster with explicit pipeline order, shared capabilities, per-skill versions, and portable supporting-skill source tokens.
- Added package-owned contracts under `design-docs-agent/contracts/` for the roster schema, `sourceBundle`, publisher paywall policy, and the asserted external TRR-APP contract.
- Added `validate-inputs` as the public preflight sub-skill and stripped the extraction/verification helper agents down to thin shells that resolve phase membership from the roster.
- Added executable package validation at `design-docs-agent/test/validate-package.py` plus a TypeScript AST contract check at `design-docs-agent/test/validate-external-contract.mjs`.
- Updated plugin manifests, adapters, source-html guidance, and the workspace `preflight.sh` hook; removed the broken Claude wrapper under `TRR-APP/.claude/skills/design-docs-agent/`.

## Validation
- Passed: `python3 /Users/thomashulihan/Projects/TRR/.agents/skills/design-docs-agent/test/validate-package.py`
- Passed: `node /Users/thomashulihan/Projects/TRR/.agents/skills/design-docs-agent/test/validate-external-contract.mjs`
- Passed: `python3 /Users/thomashulihan/.claude/plugins/marketplaces/claude-plugins-official/plugins/skill-creator/skills/skill-creator/scripts/quick_validate.py /Users/thomashulihan/Projects/TRR/.agents/skills/design-docs-agent`

## Notes
- The package now treats malformed or underspecified `sourceBundle` inputs as preflight failures instead of allowing them to drift into extraction.
- `sync-brand-page` stayed in its prior effective verification slot; the roster now models that order explicitly without retagging the skill’s phase metadata.

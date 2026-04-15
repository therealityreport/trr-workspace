# Design Docs References

This directory holds non-executable guidance for the shared Design Docs package.

## Ownership

- `agents/openai.yaml` is the canonical roster, status, and ordering source.
- Package `SKILL.md` is the orchestration contract.
- `skills/design-docs/SKILL.md` is the user entry wrapper only.
- Each owned subskill `SKILL.md` is the execution contract for that skill.
- `references/` is the home for long-form guidance, examples, lessons learned,
  and checklist material that should not live inside executable skills.
- Plugin manifests and host adapters do not define independent behavior.

## Reference Files

- `taxonomy.md` — the 15-section brand taxonomy and cross-population rules
- `birdkit-component-taxonomy.md` — NYT Birdkit wrapper, token, and component-pattern reference
- `source-html-modes.md` — saved-bundle modes, paywall policy, and authority split rules
- `rendering-contracts.md` — rendering, `contentBlocks`, and component fidelity rules
- `component-inventory-provenance.md` — source-component inventory recovery and provenance rules
- `reference-implementations.md` — known reference routes in TRR
- `lessons-learned.md` — condensed article-specific pitfalls and carry-forward rules
- `preflight-checklist.md` — verification checklist used before closeout

Current hardening rule:

- bespoke-interactive fidelity depends on acquisition support and uses a blocking/degraded verification split instead of universal hard-fail.

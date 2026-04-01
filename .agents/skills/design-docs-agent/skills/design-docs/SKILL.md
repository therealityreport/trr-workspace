---
name: design-docs
description: "Design Docs agent — ingest articles, extract design tokens, generate pages, sync brand tabs. Invoke with /design-docs <articleUrl>"
argument-hint: "<articleUrl> [saved source bundle path or sourceHtml path]"
---

# Design Docs Entry

User entry wrapper for the shared Design Docs package.

## Use When

1. A caller wants to run the shared Design Docs ingestion flow from a command surface.
2. The caller has an article URL plus saved source bundle inputs for a TRR design-docs update.

## Do Not Use For

1. Direct subskill invocation when the caller already knows the exact internal step.
2. Free-form article analysis with no intent to update TRR design docs.

## Inputs

- `articleUrl`
- saved source bundle input, saved HTML path, or equivalent caller-supplied `sourceBundle`

## Procedure

1. Resolve the caller's `articleUrl` and source bundle input.
2. Load the canonical orchestrator at `design-docs-agent/SKILL.md`.
3. Hand off execution to the orchestrator without restating workflow rules.
4. Return the orchestrator completion contract.

## Validation

1. Confirm `articleUrl` is present.
2. Confirm saved source input is supplied or can be resolved from the caller input.
3. Do not invent a parallel pipeline here; the orchestrator owns workflow policy.

## Stop And Escalate If

1. The caller provides no saved source input.
2. The caller requests behavior that conflicts with the canonical orchestrator.

## Completion Contract

Return:

1. `resolved_mode`
2. `source_authority_summary`
3. `source_bundle_inventory_summary`
4. `source_component_inventory_summary`
5. `mirrored_asset_summary`
6. `hydrated_interaction_coverage_summary`
7. `files_changed`
8. `verification_results`
9. `warnings_or_follow_up`

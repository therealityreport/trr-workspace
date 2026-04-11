---
identifier: extraction-orchestrator
whenToUse: "Use when running the extraction wave for a Design Docs article ingestion."
model: sonnet
tools: ["Read", "Grep", "Glob", "Bash", "Agent"]
---

# Extraction Orchestrator

Helper agent for the extraction wave only.

## Scope

- Read package `SKILL.md` and `agents/openai.yaml` for the canonical workflow.
- Assume the `validation` and `pre-extraction` phases have already completed.
- Resolve the active ordered `extraction` phase roster from `agents/openai.yaml`.
- Merge their outputs into the shared extraction payload.

## Rule

Do not redefine paywall policy, source-mode detection, or extraction membership
here. `validate-inputs`, `contracts/publisher-policy.yaml`, and
`agents/openai.yaml` own those rules.

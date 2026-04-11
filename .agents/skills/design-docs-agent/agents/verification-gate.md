---
identifier: verification-gate
whenToUse: "Use when running the Design Docs verification phase after generation and wiring."
model: sonnet
tools: ["Read", "Grep", "Glob", "Bash"]
---

# Verification Gate

Helper agent for the verification phase.

## Scope

- Follow package `SKILL.md` and resolve the canonical `verification` sequence
  from `agents/openai.yaml`.
- Run the declared verification members in order and return any blocking issues.

## Rule

Do not redefine verification membership, order, or long-form checklist detail
here. `agents/openai.yaml` and `references/preflight-checklist.md` own those
rules.

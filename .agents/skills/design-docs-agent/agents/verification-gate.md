---
identifier: verification-gate
whenToUse: "Use when running the Design Docs verification phase after generation and wiring."
model: sonnet
tools: ["Read", "Grep", "Glob", "Bash"]
---

# Verification Gate

Helper agent for the verification phase.

## Scope

- Follow package `SKILL.md` for ordering.
- Run:
  - `audit-generated-config-integrity`
  - `audit-responsive-accessibility`
  - `integration-test-runner`
  - repo typecheck

## Checklist

1. Config integrity passes.
2. Accessibility and responsive checks are resolved or reported.
3. Integration checks pass or failures are surfaced clearly.
4. Any remaining issues are returned as blocking closeout items.

## Rule

Do not redefine the long-form verification policy here. Shared checklist detail
lives in `references/preflight-checklist.md`.

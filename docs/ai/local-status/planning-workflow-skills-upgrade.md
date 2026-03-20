# Planning workflow skills upgrade

Last updated: 2026-03-18

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-03-18
  current_phase: "complete"
  next_action: "Use write-plan-codex -> plan-enhancer -> orchestrate-plan-execution for future plan-driven work; monitor only for wording drift in related docs"
  detail: self
```

## Status
- Complete.

## What changed
- Upgraded global `write-plan-codex` to produce execution-ready plans with context, phased sequencing, dependencies, acceptance criteria, risks, and follow-up improvements.
- Added global `plan-enhancer` as the default middle refinement step for existing plans before execution.
- Repositioned global `orchestrate-plan-execution` to execute approved plans phase by phase and stay aligned with acceptance criteria and dependencies.
- Updated the orchestrator's bundled implementer and reviewer prompt templates to carry plan slices, prerequisites, acceptance criteria, and scope guardrails.
- Updated TRR routing docs to document the canonical `write -> enhance -> execute` workflow.

## Validation
- Passed: `python3 /Users/thomashulihan/.codex/skills/.system/skill-creator/scripts/quick_validate.py /Users/thomashulihan/.codex/skills/write-plan-codex`
- Passed: `python3 /Users/thomashulihan/.codex/skills/.system/skill-creator/scripts/quick_validate.py /Users/thomashulihan/.codex/skills/orchestrate-plan-execution`
- Passed: `python3 /Users/thomashulihan/.codex/skills/.system/skill-creator/scripts/quick_validate.py /Users/thomashulihan/.codex/skills/plan-enhancer`
- Passed: metadata checks for all three `agents/openai.yaml` files
- Passed: static smoke checks for required planning, enhancement, and execution-alignment sections

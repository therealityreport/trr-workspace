# TRR Local Skill Retirement Record

TRR previously copied, vendored, or linked skills into workspace and nested-repository discovery directories. That model is retired. Those packages are not canonical owners and must not be required by workspace automation.

## Current Routing

| Capability area | Current owner |
|---|---|
| Architecture, backend, frontend, QA, DevOps, security, and code review | The matching maintained user-level, system-level, or plugin skill available to the active runtime |
| Browser and UI diagnosis | The maintained browser or Chrome DevTools capability selected by workspace policy |
| Design documentation | The maintained Design Docs plugin when installed and explicitly applicable |
| TRR-specific operating rules | `AGENTS.md`, `.codex/rules/`, domain documentation, runbooks, and executable tests |

## Retirement Rules

1. Do not restore local compatibility shims or copied skills merely to preserve old prompt names.
2. Do not route a task to an archived TRR skill by absolute path.
3. If TRR needs durable project behavior, express it as policy, documentation, a script, or a test. Create a reusable skill only in a maintained user/global/plugin source outside this repository.

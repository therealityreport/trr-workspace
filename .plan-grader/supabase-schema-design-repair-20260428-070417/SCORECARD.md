# Scorecard - Supabase Schema Design Repair Plan

Rubric: `/Users/thomashulihan/Documents/Codex/2026-04-21-create-a-rubric-for-scoring-an/implementation-plan-rubric.md`

## Gates

| Gate | Result | Notes |
|---|---|---|
| 30-second triage | Pass | Goal and target system are clear. |
| Hard-fail conditions | Pass with revision required | The plan is not unsafe, but it references a missing dependency file. |
| Wrong-thing-correctly guardrail | Pass | It targets the real duplicate-schema issue rather than generic advisor cleanup. |
| Current-state validation | Pass | Live Supabase schema evidence confirms the split. |
| Execution approval | Revised plan only | Original is useful but not self-contained enough. |

## Original Score

| Topic | Points | Score | Reason |
|---|---:|---:|---|
| A.1 Goal clarity, structure, metadata | 9 | 8.0 | Clear goal and boundaries. Phase numbering in summary is slightly off. |
| A.2 Repo, file, surface awareness | 9 | 8.0 | Strong file/table awareness, but references one missing plan artifact. |
| A.3 Sequencing and dependency order | 9 | 8.0 | Good additive sequence and parity gates. |
| A.4 Execution specificity | 9 | 6.5 | Major migration details delegated to a missing file; identity normalization underspecified. |
| A.5 Verification and commands | 9 | 7.0 | Good commands, but missing concrete SQL verifier/rollback stop rules. |
| B Gap coverage | 9 | 6.5 | Captures big risks, but metric policy and fallback retirement gates are incomplete. |
| C Tool usage and resources | 9 | 6.0 | Mentions execution approach, but does not call out Supabase MCP/advisor/RLS checks in enough detail. |
| D.1 Problem validity | 2 | 2.0 | Live row counts and duplicate surfaces prove the problem. |
| D.2 Solution fit | 2 | 2.0 | Canonical plus membership model fits the schema defect. |
| D.3 Measurable outcome | 2 | 1.5 | Parity goals exist but need stricter fallback/zero-drift gates. |
| D.4 Cost vs benefit | 2 | 1.5 | Benefit is high; implementation cost needs stronger stop rules. |
| D.5 Adoption and durability | 2 | 1.5 | Good rollout posture; durability improves with clearer governance. |
| E Safety and failure handling | 9 | 6.5 | Strong no-drop posture, but rollback and production DDL safety are not concrete enough. |
| F Scope control and pragmatism | 8 | 7.0 | Good Instagram-first scope with later platform review. |
| G Organization and format | 5 | 5.0 | Easy to scan and complete write-plan sections. |
| H Bonus value-add | 5 | 3.0 | Good strategic pattern; revised plan adds more operator-grade controls. |
| Total | 100 | 80.0 | Good plan; execute only after tightening. |

## Revised Score Estimate

| Topic | Points | Score | Reason |
|---|---:|---:|---|
| A.1 | 9 | 8.5 | Goal and execution status are clearer. |
| A.2 | 9 | 8.5 | Removes missing artifact dependency and inlines affected surfaces. |
| A.3 | 9 | 8.5 | Keeps safe sequencing with stronger stop rules. |
| A.4 | 9 | 8.0 | Adds concrete schema, migration, and persistence tasks. |
| A.5 | 9 | 8.5 | Adds verifier, rollback, parity, app/backend, and governance checks. |
| B | 9 | 8.0 | Covers identity normalization, metrics, observations, and fallback retirement. |
| C | 9 | 8.0 | Names Supabase MCP/SQL evidence, RLS/grants, migration lint, and browser validation. |
| D.1 | 2 | 2.0 | Unchanged high problem validity. |
| D.2 | 2 | 2.0 | Stronger fit through observation and normalized identity tables. |
| D.3 | 2 | 2.0 | Adds measurable parity and fallback gates. |
| D.4 | 2 | 1.5 | High-cost migration remains justified but substantial. |
| D.5 | 2 | 2.0 | Better durability through governance and cleanup note. |
| E | 9 | 8.0 | Adds rollback, DDL, and retirement stop rules. |
| F | 8 | 7.5 | Keeps Instagram-first scope and defers platform-wide rewrite. |
| G | 5 | 5.0 | Maintains clear structure. |
| H | 5 | 3.5 | Adds operator diagnostics and observation model. |
| Total | 100 | 91.5 | Ready to execute after approval. |

## Downgrade Caps

No hard cap applies to the revised plan. The original plan is capped below `90` because it references a missing plan artifact for required migration details.

# SCORECARD

## gates

| Gate | Result | Notes |
|---|---|---|
| 30-second triage | Pass for Phase 0 | Evidence collection scope is clear and safe. |
| Hard-fail conditions | Phase 1+ blocked | RLS DDL and urgent security exposure require the new gates before approval. |
| Wrong-thing-correctly guardrail | Pass | Plan now avoids optimizing performance while leaving urgent exposed security surfaces unhandled. |
| Automatic downgrades | Phase-gated | No downgrade for Phase 0; Phase 1+ is not approved yet. |

## topic scores

| # | Topic | Points | Original | Original Weighted | Revised | Revised Weighted | Notes |
|---|---|---:|---:|---:|---:|---:|---|
| A.1 | Goal Clarity, Structure, and Metadata | 9 | 4.5 | 8.1 | 4.8 | 8.6 | Phase 0 approval and Phase 1+ block are explicit. |
| A.2 | Repo, File, and Surface Awareness | 9 | 4.5 | 8.1 | 4.9 | 8.8 | Adds canonical plan path, grants, owner/RLS/FORCE RLS, and backend migration ownership. |
| A.3 | Task Decomposition, Sequencing, and Dependency Order | 9 | 4.5 | 8.1 | 5.0 | 9.0 | Security hotfix gate, immediate RLS advisor recheck, and subagent waves now control sequencing. |
| A.4 | Execution Specificity and Code Completeness | 9 | 4.0 | 7.2 | 4.9 | 8.8 | Adds exact command-specific RLS DDL and firebase old/new row semantics. |
| A.5 | Verification, TDD Discipline, and Commands | 9 | 4.0 | 7.2 | 4.9 | 8.8 | Adds permission matrix tests, policy diffs, GRANT checks, rollback SQL, and advisor recheck. |
| B | Gap Coverage and Blind-Spot Avoidance | 9 | 4.0 | 7.2 | 4.9 | 8.8 | Covers security hotfix ordering, GRANTs, FORCE RLS, null UUID handling, and answer move leaks. |
| C | Tool Usage and Execution Resources | 9 | 4.0 | 7.2 | 4.8 | 8.6 | Uses repo-native SQL/test commands, distinguishes canonical docs from generated artifacts, and defines bounded subagent workstreams. |
| D.1 | Problem Validity | 2 | 2.0 | 2.0 | 2.0 | 2.0 | Advisor snapshot remains concrete evidence. |
| D.2 | Solution Fit | 2 | 2.0 | 2.0 | 2.0 | 2.0 | Correct layers remain RLS policy DDL and evidence-gated index cleanup. |
| D.3 | Measurable Outcome | 2 | 1.5 | 1.5 | 2.0 | 2.0 | Phase 1 cannot unlock Phase 2 without advisor proof. |
| D.4 | Cost vs. Benefit | 2 | 1.5 | 1.5 | 2.0 | 2.0 | High-value RLS work stays first, but urgent security hotfixes no longer wait. |
| D.5 | Adoption and Durability | 2 | 1.5 | 1.5 | 2.0 | 2.0 | Adds rollback artifacts and canonical execution routing. |
| E | Risk, Assumptions, Failure Handling, Agent-Safety | 9 | 4.5 | 8.1 | 4.9 | 8.8 | Stop rules now cover policy command semantics, GRANT drift, and firebase move leaks. |
| F | Scope Control and Pragmatism | 8 | 4.5 | 7.2 | 4.7 | 7.5 | Keeps full security pass separate while including emergency security items. |
| G | Organization and Communication Format | 5 | 4.5 | 4.5 | 4.9 | 4.9 | Required changes are integrated into phases, validation, acceptance criteria, and subagent report format. |
| H | Creative Improvements and Value-Add | 5 | 3.0 | 3.0 | 4.0 | 4.0 | Adds reusable safety and rollback structure without broadening implementation. |
| — | **Total** | **100** |  | **88.5** |  | **96.6** |  |

## approval threshold

Phase 0 meets the autonomous execution threshold. The subagent execution split is now approval-ready for local implementation, but Phase 1+ live DDL is intentionally not approved until the amended safety hotfix gate, policy permission matrix tests, rollback SQL, owner-controlled rollout, and immediate advisor recheck are accepted.

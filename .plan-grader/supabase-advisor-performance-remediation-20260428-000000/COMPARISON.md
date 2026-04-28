# COMPARISON

## summary

The revised plan preserves the original performance-first structure for Phase 0 and the RLS/index sequencing, but it no longer approves Phase 1+ as-is. It adds an urgent parallel security gate, stronger RLS access proof, command-specific policy templates, rollback requirements, canonical-plan routing, and a concrete multi-subagent execution model.

| Topic | Original | Revised | Delta | Reason |
|---|---:|---:|---:|---|
| A.1 Goal clarity | 4.5 | 4.8 | +0.3 | Clarifies that Phase 1 local staging is approved while live DDL and Phase 2+ are gated. |
| A.2 Repo/surface awareness | 4.5 | 4.9 | +0.4 | Adds canonical `docs/codex/plans` source, grant inventory, table-owner inventory, and backend-owned migration boundaries. |
| A.3 Sequencing | 4.5 | 5.0 | +0.5 | Adds safety hotfix gate before/alongside Phase 1, blocks index work until RLS advisor proof exists, and sequences subagents into dependency-safe waves. |
| A.4 Execution specificity | 4.0 | 4.9 | +0.9 | Adds exact `INSERT`/`UPDATE`/`DELETE` policy DDL templates and firebase old/new row semantics. |
| A.5 Verification | 4.0 | 4.9 | +0.9 | Adds access matrix tests, GRANT checks, policy diffs, rollback SQL, and immediate advisor recheck. |
| B Gap coverage | 4.0 | 4.9 | +0.9 | Covers SECURITY DEFINER exposure, `public.__migrations`, GRANTs, FORCE RLS, UUID/null handling, and answer move leaks. |
| C Tool usage | 4.0 | 4.8 | +0.8 | Keeps repo-native SQL/test commands, separates Plan Grader evidence from canonical execution, and defines exact subagent roles with disjoint ownership scopes. |
| D.1 Problem validity | 2.0 | 2.0 | 0.0 | The advisor snapshot still proves the performance problem. |
| D.2 Solution fit | 2.0 | 2.0 | 0.0 | RLS policy rewrite and evidence-gated index cleanup remain the correct performance layers. |
| D.3 Measurable outcome | 1.5 | 2.0 | +0.5 | Immediate Phase 1 advisor recheck becomes a hard gate. |
| D.4 Cost vs. benefit | 1.5 | 2.0 | +0.5 | Avoids the expensive mistake of postponing urgent security exposure behind index cleanup. |
| D.5 Adoption/durability | 1.5 | 2.0 | +0.5 | Adds rollback artifacts and canonical source-of-truth routing. |
| E Safety | 4.5 | 4.9 | +0.4 | Adds explicit safety gate, access-matrix stop rules, and rollback restoration by policy name. |
| F Scope | 4.5 | 4.7 | +0.2 | Keeps broad security pass separate while elevating emergency security items. |
| G Format | 4.5 | 4.9 | +0.4 | Integrates required changes into phases and adds a reusable subagent report format instead of loose suggestions. |
| H Bonus | 3.0 | 4.0 | +1.0 | Adds durable verification and rollback discipline without over-expanding scope. |

## net effect

- Original: solid performance remediation plan, but too loose on security ordering and RLS equivalence proof.
- Revised: Phase 0 is safe to execute; Phase 1+ has the required gates and a concrete subagent execution split, but live DDL and Phase 2+ still need owner-controlled rollout and advisor evidence before proceeding.

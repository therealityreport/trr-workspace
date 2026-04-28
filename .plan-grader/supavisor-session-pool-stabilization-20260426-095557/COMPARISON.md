# Comparison: Original Plan vs Revised Plan

## Summary

The original plan was strong on problem validity, repo evidence, and operator value. The revised plan improves execution readiness by making discovery locks explicit, separating pressure scopes, defining nested-repo ownership, and sequencing route hardening before API migration and cache expansion.

Original score: **78 / 100**

Revised estimate after second-pass additions: **95 / 100**

## Topic Comparison

| Topic | Original | Revised | Delta | Reason |
| --- | ---: | ---: | ---: | --- |
| A.1 Goal Clarity, Structure, and Metadata | 4.5 | 5.0 | +0.5 | Revised plan adds explicit non-goals, success metrics, and execution model. |
| A.2 Repo, File, and Surface Awareness | 4.0 | 5.0 | +1.0 | Placeholder helper/router names are replaced with blocking discovery, endpoint inventory, and exact backend route contract. |
| A.3 Task Decomposition, Sequencing, and Dependency Order | 4.0 | 4.5 | +0.5 | Measurement, app hardening, backend migration, env lanes, and caching are separated. |
| A.4 Execution Specificity and Code Completeness | 3.5 | 5.0 | +1.5 | Revised plan removes core "or closest/current" decisions, adds feature flags, direct-SQL exit criteria, and exact stale/cache semantics. |
| A.5 Verification, TDD Discipline, and Commands | 4.0 | 4.8 | +0.8 | Targeted phase checks now include auth-valid validation, holder snapshots, app pressure checks, and import-removal acceptance. |
| B Gap Coverage and Blind-Spot Avoidance | 3.5 | 5.0 | +1.5 | Adds production capacity math, DB-level holder evidence, protected health, app pressure, cache poisoning, and polling controls. |
| C Tool Usage and Execution Resources | 3.5 | 4.5 | +1.0 | Multi-repo execution boundaries are explicit. |
| D.1 Problem Validity | 5.0 | 5.0 | 0.0 | Observed failure and beneficiary were already clear. |
| D.2 Solution Fit | 4.5 | 5.0 | +0.5 | Revised plan keeps transaction mode deferred and targets the correct layers. |
| D.3 Measurable Outcome | 4.0 | 5.0 | +1.0 | Adds local and production capacity metrics plus `pg_stat_activity` attribution. |
| D.4 Cost vs. Benefit | 4.0 | 4.5 | +0.5 | Revised sequence reduces rework risk for a multi-repo effort. |
| D.5 Adoption and Durability | 4.0 | 5.0 | +1.0 | Default profile, deployment caps, feature flags, and rollback ownership improve durability. |
| E Risk, Assumptions, Failure Handling, and Agent-Safety | 3.5 | 5.0 | +1.5 | Adds stop conditions, protected details, external-pool safety, production rollout gates, and nested repo guardrails. |
| F Scope Control and Pragmatism | 4.0 | 4.0 | 0.0 | Scope is larger, but the added work is directly tied to preventing session saturation. |
| G Organization and Communication Format | 4.5 | 4.5 | 0.0 | Both plans are well structured. |
| H Creative Improvements and Value-Add | 4.0 | 4.0 | 0.0 | Observability and cache ideas remain useful but not over-expanded. |

## Key Behavioral Differences

1. The revised plan does not let a backend readiness endpoint pretend to see all Supavisor sessions.
2. The revised plan prevents nested backend changes from being accidentally staged in the workspace root.
3. The revised plan requires current router/helper discovery before editing.
4. The revised plan treats the pool-size increase as an emergency operator action with evidence and rollback, not a normal implementation step.
5. The revised plan avoids moving to transaction mode while adding the naming contract for future work.
6. The revised plan now blocks production rollout on capacity math rather than assuming local pool caps generalize to production.
7. The revised plan now requires `application_name` and `pg_stat_activity` holder attribution before increasing Supavisor capacity.
8. The revised plan now makes social landing direct-SQL removal explicit, including SocialBlade/cast reads and the `@/lib/server/postgres` import removal.

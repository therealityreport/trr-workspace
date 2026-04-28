# COMPARISON: Source Plan vs Revised Plan

## Summary

The source plan already captured the user's requested data scope well. The revised plan primarily strengthens execution safety: it adds a current-state gate, profile-to-source linking, job-stage/runtime details for profile relationships, evidence-based backfill handling, and a better parallel execution handoff.

## Topic Delta

| Topic | Original | Revised | Delta | Reason |
| --- | ---: | ---: | ---: | --- |
| Goal Clarity | 8.1 | 8.6 | +0.5 | Added Plan Grader revision metadata and explicit execution gates. |
| Repo/Surface Awareness | 7.6 | 8.5 | +0.9 | Added `shared_account_sources`, scrape job, and runtime/fetcher surfaces. |
| Sequencing | 7.2 | 8.5 | +1.3 | Added Phase 0 before schema and a workstream map after coordination points. |
| Execution Specificity | 7.2 | 8.3 | +1.1 | Added stage names, fetcher contracts, and job-runner behavior. |
| Verification | 7.2 | 8.1 | +0.9 | Added baseline, job-stage, and partial-backfill verification. |
| Gap Coverage | 6.8 | 8.3 | +1.5 | Closed profile/source join and relationship execution gaps. |
| Tooling/Resources | 6.3 | 8.1 | +1.8 | Changed handoff to subagents and clarified Scrapling was not needed for audit. |
| Value: Measurable Outcome | 1.4 | 1.8 | +0.4 | Added profile/relationship coverage and completeness reporting. |
| Safety | 6.8 | 8.1 | +1.3 | Added stop rules, cap/completeness statuses, and ambiguity rejection. |
| Scope Discipline | 6.1 | 6.7 | +0.6 | Still broad, but better bounded by Phase 0 and explicit non-goals. |

## Changed Approval Status

- Source: good but risky to execute without tightening.
- Revised: approved for execution after Phase 0 baseline.

## Recommended Execution Mode

Use `orchestrate-subagents` after Phase 0. Keep schema/stage decisions centralized, then split independent workers by file ownership.

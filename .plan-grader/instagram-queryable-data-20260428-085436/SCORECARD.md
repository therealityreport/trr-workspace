# SCORECARD: Instagram Queryable Data Plan

Rubric: `/Users/thomashulihan/Documents/Codex/2026-04-21-create-a-rubric-for-scoring-an/implementation-plan-rubric.md`

## Gates

| Gate | Result | Notes |
| --- | --- | --- |
| 30-second triage | Pass | Outcome, systems, verification, and value are legible. |
| Hard-fail conditions | Pass after revision | Source plan had execution gaps for profile/source linking and job-stage/runtime work; revised plan closes them. |
| Short review form | Pass after revision | All 12 questions are answerable in the revised plan. |
| Automatic downgrade caps | None after revision | Source plan avoided hard caps but was held below autonomous-execution quality by integration gaps. |
| Wrong-thing-correctly guardrail | Pass | Beneficiary is TRR operators/admin workflows; success is typed queryability without raw JSON inspection. |

## Topic Scores

| # | Topic | Points | Original | Original Weighted | Revised | Revised Weighted | Notes |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| A.1 | Goal Clarity, Structure, and Metadata | 9 | 4.5 | 8.1 | 4.8 | 8.6 | Strong objective; revised metadata adds artifact and gate context. |
| A.2 | Repo, File, and Surface Awareness | 9 | 4.2 | 7.6 | 4.7 | 8.5 | Revised plan adds shared source linking and scrape job surfaces. |
| A.3 | Task Decomposition, Sequencing, and Dependency Order | 9 | 4.0 | 7.2 | 4.7 | 8.5 | Phase 0 and workstream map reduce sequencing risk. |
| A.4 | Execution Specificity and Code Completeness | 9 | 4.0 | 7.2 | 4.6 | 8.3 | Revised plan names job stages and runtime/fetcher contracts. |
| A.5 | Verification, TDD Discipline, and Commands | 9 | 4.0 | 7.2 | 4.5 | 8.1 | Adds baseline, job-stage, and partial-backfill checks. |
| B | Gap Coverage and Blind-Spot Avoidance | 9 | 3.8 | 6.8 | 4.6 | 8.3 | Main gaps were source/profile joins and relationship job execution. |
| C | Tool Usage and Execution Resources | 9 | 3.5 | 6.3 | 4.5 | 8.1 | Revised handoff correctly uses subagents after Phase 0. |
| D.1 | Problem Validity | 2 | 4.0 | 1.6 | 4.5 | 1.8 | User supplied concrete missing field examples. |
| D.2 | Solution Fit | 2 | 4.5 | 1.8 | 4.7 | 1.9 | Backend typed storage is the right layer. |
| D.3 | Measurable Outcome | 2 | 3.5 | 1.4 | 4.4 | 1.8 | Revised plan adds baseline and observable profile/relationship coverage. |
| D.4 | Cost vs. Benefit | 2 | 3.5 | 1.4 | 4.0 | 1.6 | Revised plan acknowledges bounded relationship cost. |
| D.5 | Adoption and Durability | 2 | 3.5 | 1.4 | 4.2 | 1.7 | Admin/API follow-through plus source links make adoption credible. |
| E | Risk, Assumptions, Failure Handling, and Agent-Safety | 9 | 3.8 | 6.8 | 4.5 | 8.1 | Revised plan adds stop gates and completeness/status handling. |
| F | Scope Control and Pragmatism | 8 | 3.8 | 6.1 | 4.2 | 6.7 | Still broad, but bounded and phased. |
| G | Organization and Communication Format | 5 | 4.2 | 4.2 | 4.5 | 4.5 | Directly executable structure. |
| H | Creative Improvements and Value-Add | 5 | 4.0 | 4.0 | 4.5 | 4.5 | Observability, drift, and relationship coverage are useful. |
| — | Total | 100 | — | 79.1 | — | 91.0 | Rounded scores: original `79`, revised `91`. |

## Score Summary

- Original rating: good plan, execute with tightening.
- Revised rating: ready to execute.

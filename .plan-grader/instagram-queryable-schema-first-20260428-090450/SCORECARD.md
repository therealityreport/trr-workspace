# SCORECARD: Instagram Queryable Schema-First Revision

Rubric: `/Users/thomashulihan/Documents/Codex/2026-04-21-create-a-rubric-for-scoring-an/implementation-plan-rubric.md`

## Gates

| Gate | Result | Notes |
| --- | --- | --- |
| 30-second triage | Pass | Outcome, schema-first gate, storage map, and validation are explicit. |
| Hard-fail conditions | Pass after revision | Previous duplicate-storage risk is now controlled by Phase 0. |
| Short review form | Pass | All 12 review questions are answerable. |
| Automatic downgrade caps | None | Concrete files, schema surfaces, validation, and value are present. |
| Wrong-thing-correctly guardrail | Pass | Beneficiary and success mechanism remain operator queryability without raw JSON. |

## Topic Scores

| # | Topic | Points | Previous Revised | New Revised | Notes |
| --- | --- | ---: | ---: | ---: | --- |
| A.1 | Goal Clarity, Structure, and Metadata | 9 | 8.6 | 8.8 | Schema-first objective is now front-loaded. |
| A.2 | Repo, File, and Surface Awareness | 9 | 8.5 | 8.9 | Adds `social.social_posts` family and legacy compatibility boundaries. |
| A.3 | Sequencing | 9 | 8.5 | 8.8 | Phase 0 prevents wrong migration order. |
| A.4 | Execution Specificity | 9 | 8.3 | 8.7 | Storage decision rules are concrete. |
| A.5 | Verification | 9 | 8.1 | 8.5 | Adds schema-decision and RLS/grant checks. |
| B | Gap Coverage | 9 | 8.3 | 8.8 | Duplicate storage and raw/private exposure gaps are addressed. |
| C | Tool Usage | 9 | 8.1 | 8.4 | Supabase/schema review incorporated; subagent handoff retained. |
| D.1 | Problem Validity | 2 | 1.8 | 1.8 | Problem remains concrete and user-evidenced. |
| D.2 | Solution Fit | 2 | 1.9 | 2.0 | Canonicalization is a better schema fit. |
| D.3 | Measurable Outcome | 2 | 1.8 | 1.9 | Adds coverage view and schema decision evidence. |
| D.4 | Cost vs. Benefit | 2 | 1.6 | 1.7 | More upfront design, less migration rework risk. |
| D.5 | Adoption/Durability | 2 | 1.7 | 1.9 | Aligning with canonical tables improves durability. |
| E | Safety | 9 | 8.1 | 8.7 | RLS/private raw boundaries and rollback note are included. |
| F | Scope Discipline | 8 | 6.7 | 7.0 | Suggestions are integrated, but scope remains large. |
| G | Organization | 5 | 4.5 | 4.6 | Long but structured and execution-oriented. |
| H | Bonus | 5 | 4.5 | 4.7 | Suggestions add useful operational quality. |
| — | Total | 100 | 91 | 94 | Ready to execute after Phase 0. |

## Score Summary

The revised plan is stronger because it now prevents schema duplication before implementation and turns optional follow-ups into traceable execution tasks.

# SCORECARD

Rubric: `/Users/thomashulihan/Documents/Codex/2026-04-21-create-a-rubric-for-scoring-an/implementation-plan-rubric.md`

## Gates

| Gate | Result | Notes |
|---|---|---|
| 30-second triage | Pass | Goal and phases are clear. |
| Hard-fail conditions | Pass with blockers | No destructive action is proposed early, but current-state mismatch blocks execution. |
| Wrong-thing-correctly guardrail | Needs revision | Twitter/X and YouTube are modeled incorrectly as catalog-only. |
| Approval threshold | Not met | Source plan needs revision before execution. |

## Downgrade Caps

- Current-state mismatch cap: final source score capped below approval-ready because Supabase live schema disproves the Twitter/X and YouTube assumptions.
- Security/governance cap: source score capped because public-read raw payload exposure is not safely handled.

## Topic Scores

| Topic | Source Score | Revised Estimate | Notes |
|---|---:|---:|---|
| A.1 Goal clarity /9 | 8 | 8 | Clear objective and non-goals. |
| A.2 Repo and surface awareness /9 | 6 | 8 | Revised plan includes `twitter_tweets`, `youtube_videos`, comments, bridge refs. |
| A.3 Sequencing /9 | 7 | 8 | Revised migration is split into safer subphases. |
| A.4 Execution specificity /9 | 6 | 8 | Revised plan adds concrete integrity, raw-data, and key-normalization tasks. |
| A.5 Verification /9 | 7 | 8 | Revised validation includes live schema, parity, RLS/grant checks. |
| B Gap coverage /9 | 6 | 8 | Revised plan handles public raw data, comments bridge, catalog-only vs materialized differences. |
| C Tool usage /9 | 7 | 8 | Supabase MCP/Fullstack and Plan Grader roles are explicit. |
| D.1 Problem validity /2 | 2 | 2 | Real duplicated storage and drift. |
| D.2 Solution fit /2 | 1 | 2 | Revised adapter model fits better. |
| D.3 Measurable outcome /2 | 2 | 2 | Parity and route/test checks are measurable. |
| D.4 Cost vs benefit /2 | 1 | 1 | Large migration; still expensive. |
| D.5 Adoption/durability /2 | 2 | 2 | Durable if parity-gated. |
| E Safety /9 | 5 | 8 | Revised plan closes raw-data and FK integrity risks. |
| F Scope discipline /8 | 6 | 7 | Revised plan keeps comments unification separate. |
| G Communication /5 | 4 | 4 | Clear structure. |
| H Bonus /5 | 3 | 4 | Revised observation/private-table split improves design. |

## Final Scores

- Source plan score: `73/100` (`Borderline; revise before execution`)
- Revised plan estimate: `88/100` (`Good plan; execute with minor tightening`)


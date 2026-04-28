# AUDIT: Instagram Queryable Execution Guardrails Revision

## Verdict

`APPROVED_WITH_REVISIONS`

Original score: `94/100` from the previous schema-first revised package.

Revised score estimate: `96/100`.

Recommended next execution skill: `orchestrate-subagents`, but only after explicit user approval of Phase 0.

## Current-State Fit

The user's concerns are correct and repo-backed:

- `TRR-Backend/trr_backend/repositories/social_season_analytics.py` is 60,646 lines.
- `_upsert_instagram_post` is defined in that file and has seven call sites.
- `20260323173500_add_instagram_post_search_columns.sql` already added Instagram search columns to `social.instagram_posts`.
- `20260428114500_instagram_catalog_post_collaborators.sql` already added `social.instagram_account_catalog_post_collaborators`.

Without revision, the plan could still fail operationally even with a good schema strategy: parallel agents would collide in the monolith, Phase 0 could be self-approved by the executor, profile uniqueness could break when id-less rows later receive ids, and recent migrations could be duplicated.

## Required Revisions Integrated

1. Added a hard one-writer rule for `social_season_analytics.py`.
2. Added a Phase 0 human approval gate before Phase 1 or any subagent fan-out.
3. Replaced vague profile uniqueness with explicit partial unique index requirements.
4. Added a profile ID-upgrade merge flow for id-less row promotion.
5. Added Phase 0 reconciliation requirements for the Instagram search-columns migration and catalog collaborators migration.
6. Added validation and acceptance criteria for all of the above.
7. Synced the revised plan back to the canonical docs plan.

## Biggest Risks Remaining

- Phase 0 must not be rushed. It is now a human-reviewed architecture gate.
- The monolith owner will be a bottleneck, but that is preferable to merge-conflict churn.
- The ID-upgrade merge flow must be tested with realistic id-less and id-bearing profile rows.

## Approval Decision

Approved for execution only after the Phase 0 schema decision note is written and the user explicitly approves it.

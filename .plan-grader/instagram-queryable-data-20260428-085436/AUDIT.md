# AUDIT: Instagram Queryable Data Plan

## Verdict

`APPROVED_WITH_REVISIONS`

Original score: `79/100`

Revised score estimate: `91/100`

Recommended next execution skill: `orchestrate-subagents`

## Current-State Fit

The source plan is aimed at the right problem: Instagram scrape payloads contain meaningful post, profile, relationship, and comment fields that should be searchable/queryable instead of buried in `raw_data`. The plan correctly keeps backend schema and persistence as the source of truth and preserves `raw_data` for forensic coverage.

Repo checks support the main premise:

- `social.shared_account_sources` exists as the shared account registry with `platform`, `source_scope`, `account_handle`, scrape run/job metadata, RLS, and service-role grants.
- `social.instagram_posts`, `social.instagram_account_catalog_posts`, and `social.instagram_comments` exist and already have partial enriched surfaces.
- `social.instagram_comments` already has parent/reply support, reply counts, author avatar columns, and a same-post parent trigger.
- Instagram runtime protocol currently exposes a reduced `ProfileInfo` shape, not the full NASA-style profile/about/external-link/following contract.
- `posts_scrapling/persistence.py` uses a narrowed `_ScraplingPostDTO` that confirms the plan's concern about dropped source fields.

Scrapling plugin assistance was not needed for this audit because the plan quality issue is repo contract and execution sequencing, not live extraction behavior or Scrapling API usage.

## Required Fixes Integrated In `REVISED_PLAN.md`

1. Added Phase 0 current-state gate before migrations.
2. Added explicit linking between `social.instagram_profiles` and `social.shared_account_sources`.
3. Added concrete profile snapshot and profile relationship job-stage/runtime requirements.
4. Made profile backfill evidence-based instead of assuming raw full profile payloads already exist.
5. Changed execution handoff to `orchestrate-subagents` because the work naturally splits into independent schema, normalizer, fetcher/job, persistence, API, and validation workstreams.
6. Applied the user's scope correction: do not scrape follower lists. Keep follower counts from profile payloads, and store only following-list relationship rows.

## Biggest Risks Remaining

- Instagram following-list endpoints may require authenticated sessions, checkpoint handling, or different runtime support than current posts/comments lanes. Follower-list endpoints are intentionally out of scope.
- Full relationship crawling can be expensive and incomplete by design; completeness metadata must be visible to operators.
- Profile identity must prefer durable Instagram user id while still supporting username-only fallback rows.
- Backfill will likely be partial unless current raw profile/about payloads are present.

## Approval Decision

Approve the revised plan for execution after the Phase 0 baseline confirms current table columns, chosen job-stage names, and profile raw-backfill availability.

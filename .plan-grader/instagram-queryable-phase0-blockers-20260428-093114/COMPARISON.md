# Comparison

## Before

The previous plan was broadly execution-ready after Phase 0 approval and still included an implementation path for embedded/latest comments as persisted rows. It also assumed the canonical post foundation, raw payload privacy, and profile/following job-stage compatibility without making those hard blockers.

## After

The revised plan is execution-ready only through Commit -1 and Phase 0. Phase 1+ is conditional on the Phase 0 storage decision, and Phase 2+ is blocked until four issues are documented:

- canonical foundation existence on the target branch and local/live schema;
- `scrape_jobs` job-type or `config.stage` strategy for profile snapshot/following work;
- raw-data exposure strategy accounting for legacy grants;
- closed non-persistence decision for embedded/latest comments.

## Key Scope Change

Embedded/latest comments are now explicitly out of persistence scope. Full comments scrape rows are the only persisted/queryable comment source.

## Supabase Review Outcome

The requested blockers are correct. Live schema checks show the canonical post foundation tables exist, but legacy Instagram raw-data-bearing tables are broadly selectable by `anon` and `authenticated`, while `social_post_observations` is service-role only. The live `scrape_jobs` constraint does not currently contain `instagram_profile_snapshot`, `instagram_profile_following`, or `instagram_profile_relationships`, so profile/following runner work needs the new hard job-stage criterion.

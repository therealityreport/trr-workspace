# AUDIT: Instagram Queryable Schema-First Revision

## Verdict

`APPROVED_WITH_REVISIONS`

Original score: `91/100` from the previous revised package.

Revised score estimate: `94/100`.

Recommended next execution skill: `orchestrate-subagents`.

## Current-State Fit

The user's schema-first correction is right. TRR now has both legacy Instagram-specific tables and the newer cross-platform canonical foundation:

- Legacy/source surfaces: `social.instagram_posts`, `social.instagram_account_catalog_posts`, `social.instagram_comments`.
- Account registry: `social.shared_account_sources`.
- Newer canonical foundation: `social.social_posts`, `social.social_post_observations`, `social.social_post_legacy_refs`, `social.social_post_memberships`, `social.social_post_entities`, `social.social_post_media_assets`.

Without a schema architecture gate, the prior plan could have deepened duplicate post-level storage by adding the same durable fields to legacy Instagram tables and the canonical `social.social_posts` family. The revised plan now requires a Phase 0 field-to-table decision before migrations.

## Required Revisions Integrated

1. Added `Phase 0: Schema Architecture Decision Gate`.
2. Aligned post-level storage with `social.social_posts` and child canonical tables before adding Instagram-only tables.
3. Kept `social.instagram_posts` and `social.instagram_account_catalog_posts` as compatibility/source tables unless a temporary bridge is documented.
4. Made raw observations service-role/admin-only and kept curated read surfaces separate from raw payload access.
5. Preserved following-only scope and kept follower-list scraping out of scope.
6. Incorporated all ten prior optional suggestions as concrete tasks under `ADDITIONAL SUGGESTIONS`.
7. Synced the revised plan back to the canonical docs plan.

## Biggest Risks Remaining

- Phase 0 must be done seriously; otherwise workers may still duplicate canonical post fields into legacy tables.
- Existing admin reads in `social_season_analytics.py` still rely heavily on legacy Instagram tables, so bridge decisions must be explicit and temporary.
- The new following/profile tables need careful RLS and API exposure decisions because they can contain sensitive/raw scrape context.

## Approval Decision

Approved for execution after Phase 0 writes the schema decision note and confirms the storage map. Do not start migrations before that decision is recorded.

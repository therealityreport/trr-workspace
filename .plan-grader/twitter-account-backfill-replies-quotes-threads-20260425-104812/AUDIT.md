# Twitter/X Account Backfill Plan Audit

## Verdict

APPROVE AFTER PATCHING.

The plan is directionally strong and targets the right existing pipeline: Twitter account catalog backfill in `TRR-Backend`, the existing Twitter scraper/repository path, and the existing `Backfill Posts` action in `TRR-APP`. It is not quite execution-ready as written because it duplicates some current-state work, leaves the comment-lane completion semantics underspecified, and misses several exact call-site/config names needed to wire `twitter_comments_in_posts_stage` safely.

## Current-State Fit

- Correct: `_scrape_shared_twitter_posts()` currently builds `TwitterScrapeConfig(... include_replies=False ...)` and filters `catalog_posts = [tweet for tweet in posts if not tweet.is_reply]`, so account-authored replies are excluded from account catalog inventory.
- Correct: `_scrape_shared_twitter_posts()` currently persists only catalog rows in shared catalog mode; it does not also persist account-authored posts into `social.twitter_tweets`.
- Correct: `fetch_tweet_replies()` and `fetch_tweet_quotes()` already exist and can be reused for direct interactions.
- Partial mismatch: `social.twitter_account_catalog_posts` already has `shares`; the migration should add `bookmarks`, thread fields, and indexes there, but should not assume `shares` is missing.
- Partial mismatch: the scraper already parses `bookmark_count` in detail-summary/syndication paths, but `Tweet` does not expose `bookmarks`, `shares`, or `conversation_id`, so persistence cannot use it consistently yet.
- Important gap: `start_social_account_catalog_backfill()` currently only accepts `tiktok_comments_in_posts_stage`; it does not accept or propagate a Twitter-specific stage flag. The plan names the flag but needs exact updates at the function signature, run config, job config, metadata merge, and shared-posts stage read sites.
- Important UI nuance: backend selected-task normalization defaults to `["post_details", "comments", "media"]` when `selected_tasks` is absent. The app currently only sends defaults for Instagram/TikTok, so the UI copy can use response `effective_selected_tasks` for Twitter/Youtube, but tests should also cover request-body fallback only if the app is changed to send defaults.

## Benefit Score

High. The implementation would make Twitter/X account backfill materially more complete for operator review by capturing account replies, text-only posts, direct replies, quote tweets, parent context, and self-reply thread grouping without adding a second UI flow.

## Approval Decision

Do not execute the original text verbatim. Execute the revised plan in `REVISED_PLAN.md`, especially the schema/idempotency, config propagation, current-state correction, and completion-metadata patches.

## Blocking Fixes

1. Correct the migration scope: `shares` already exists on `social.twitter_account_catalog_posts`; make all column additions `if not exists` and add only missing catalog columns plus `social.twitter_tweets` fields.
2. Add exact propagation for `twitter_comments_in_posts_stage` through `start_social_account_catalog_backfill()`, `_create_shared_account_catalog_backfill_run()`/run config, posts job config, recovery/requeue paths, and retrieval metadata.
3. Define incomplete interaction-hydration status: reply/quote fetch failures must set `twitter_interactions_complete=false`, include per-post failure metadata, and keep comments lane from being reported complete.
4. Specify how account-authored replies are persisted to both catalog and rich tweet tables with context/thread fields, not just "persist every account-authored result".
5. Update tests to assert no duplicate hydration for thread roots and to verify the actual non-Instagram UI copy path.

## Non-Blocking Improvements

- Add targeted indexes for `thread_root_tweet_id`, `twitter_context_role`, `reply_to_tweet_id`, and `quoted_tweet_id` if query surfaces depend on them.
- Add a small fixture factory for Twitter `Tweet` objects in repository tests to keep the new thread/reply cases readable.
- Record interaction-hydration counters separately from fetch counters so comments/quotes counts remain explainable in run metadata.

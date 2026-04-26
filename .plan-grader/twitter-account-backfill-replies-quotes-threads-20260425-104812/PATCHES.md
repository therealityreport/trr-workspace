# Plan Patches

## Patch 1: Correct Schema Scope

Replace:

```md
Add `bookmarks`, `shares`, `thread_root_source_id`, `thread_position`, and `is_thread_part` to `social.twitter_account_catalog_posts`.
```

With:

```md
`social.twitter_account_catalog_posts` already has `shares`; add only missing `bookmarks`, `thread_root_source_id`, `thread_position`, and `is_thread_part`, using `add column if not exists`.
```

## Patch 2: Correct Scraper Current State

Replace:

```md
Update `_parse_tweet_result()` and detail-summary parsing to capture `bookmark_count`, `share_count` when present, and `conversation_id_str`.
```

With:

```md
`fetch_tweet_detail_summary()` and syndication summary parsing already read `bookmark_count` into dictionaries. Extend the `Tweet` dataclass and all Tweet construction paths so `bookmarks`, `shares`, and `conversation_id` are available to persistence. Then update `_parse_tweet_result()` to populate those fields from `legacy.bookmark_count`, any exposed share count, and `conversation_id_str`.
```

## Patch 3: Add Exact Config Propagation

Add after the `twitter_comments_in_posts_stage` task:

```md
Update the exact config surfaces: `start_social_account_catalog_backfill()` signature, run config creation, shared account posts job config, recovery/requeue config preservation, launch metadata merge, and `_scrape_shared_twitter_posts()` retrieval metadata. Do not overload `tiktok_comments_in_posts_stage`.
```

## Patch 4: Define Completion Semantics

Replace:

```md
Ensure incomplete reply/quote fetches set retryable metadata and do not report a fully complete comments lane.
```

With:

```md
For reply/quote hydration, write `twitter_interactions_complete=false`, `retryable=true`, and `twitter_interaction_errors=[...]` in retrieval metadata when any per-root fetch fails. Keep `comments_status`/comments lane out of a complete state until all requested root interactions either succeed or are explicitly skipped with a non-retryable reason.
```

## Patch 5: UI Copy Scope

Replace:

```md
For Twitter/X, show selected task labels the same way TikTok does.
```

With:

```md
For non-Instagram backfill success messages, show selected task labels whenever `selectedTaskLabels` is non-empty for TikTok, Twitter/X, and YouTube. Preserve the generic fallback only for platforms without selected task labels.
```

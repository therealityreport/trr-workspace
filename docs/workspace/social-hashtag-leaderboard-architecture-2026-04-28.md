# Social Hashtag Leaderboard Architecture

Status: unresolved / stub

## Decision Needed

Should hashtag leaderboard/search be served from raw platform tables, or from a normalized `social.hashtag_mentions` plus rollup/materialized-view layer?

## Current Blocker

Do not approve deletion of social `*_search_hashtags_idx`, `*_search_text_trgm_idx`, `*_search_handles_idx`, or `*_search_handle_identities_idx` until this architecture is resolved or each index is proven unrelated to future hashtag/search/leaderboard paths.

## Preferred Direction

```text
raw posts/comments
  -> ingest/backfill hashtag extraction
  -> social.hashtag_mentions
  -> leaderboard rollups/materialized views
  -> Page/API reads
```

## Review Impact

The unused-index decision matrix should classify affected social search rows as `keep_pending_product_architecture_decision` or a replacement candidate until this stub is replaced by a real product/architecture decision.

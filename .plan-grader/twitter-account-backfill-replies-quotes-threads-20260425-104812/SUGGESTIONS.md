# Suggestions

1. Title: Add a Twitter Tweet fixture factory
   Type: Small
   Why: The repository tests will need many Tweet variants.
   Where it would apply: `TRR-Backend/tests/repositories/test_social_season_analytics.py`
   How it could improve the plan: Keeps thread, quote, reply, and text-only cases readable.

2. Title: Add migration smoke assertions
   Type: Small
   Why: This migration is additive but touches two operational tables.
   Where it would apply: Backend migration tests or a focused schema assertion.
   How it could improve the plan: Catches missed columns before runtime payload builders fail.

3. Title: Separate interaction counters from catalog counters
   Type: Small
   Why: `posts_upserted`, `comments_upserted`, and `quotes_upserted` answer different operator questions.
   Where it would apply: Twitter retrieval metadata.
   How it could improve the plan: Makes progress/status UI and debugging less ambiguous.

4. Title: Add per-root hydration cache diagnostics
   Type: Small
   Why: Thread root dedupe is central to avoiding duplicate quote/reply fetches.
   Where it would apply: `_hydrate_twitter_account_post_interactions()`
   How it could improve the plan: Makes it easy to confirm one fetch per root in tests and logs.

5. Title: Keep parent-context rows visually distinguishable
   Type: Medium
   Why: Parent rows are context, not account catalog inventory.
   Where it would apply: Future comments/thread UI consuming `twitter_context_role`.
   How it could improve the plan: Prevents operators from mistaking external parent tweets for account-authored posts.

6. Title: Add bounded max-depth for parent chain resolution
   Type: Medium
   Why: Bad data or API loops can otherwise waste scraper time.
   Where it would apply: `_resolve_twitter_thread_root()`
   How it could improve the plan: Improves reliability without changing the feature scope.

7. Title: Store thread resolution provenance
   Type: Medium
   Why: Some roots will be inferred from incomplete API data.
   Where it would apply: `raw_data` or retrieval metadata.
   How it could improve the plan: Helps debug why a tweet was or was not grouped into a thread.

8. Title: Add a small UI label helper test
   Type: Small
   Why: The copy change is easy to regress.
   Where it would apply: `SocialAccountProfilePage` tests around `formatBackfillTaskLabel`.
   How it could improve the plan: Keeps Twitter/Youtube/TikTok success messages consistent.

9. Title: Add a saved-count reconciliation query
   Type: Medium
   Why: Manual verification names concrete tweet IDs.
   Where it would apply: Backend manual verification notes or a local SQL snippet.
   How it could improve the plan: Lets the implementer confirm catalog and rich tweet rows without hunting through the UI.

10. Title: Consider a future thread detail view
    Type: Large
    Why: The data model will support grouped self-reply threads after this change.
    Where it would apply: Future `TRR-APP` social comments/thread UI.
    How it could improve the plan: Turns the new persisted structure into a more useful operator review surface later.

11. Title: Add hydration sampling logs
    Type: Small
    Why: Twitter scraping can fail inconsistently by endpoint.
    Where it would apply: Twitter interaction hydration logging.
    How it could improve the plan: Makes production diagnosis easier when replies work but quotes fail, or vice versa.

12. Title: Document the actor-list limitation near the schema
    Type: Small
    Why: Bookmarks are often misunderstood as a list of users.
    Where it would apply: Migration comments or repository code comment near `bookmarks`.
    How it could improve the plan: Prevents future work from expecting unavailable private actor data.

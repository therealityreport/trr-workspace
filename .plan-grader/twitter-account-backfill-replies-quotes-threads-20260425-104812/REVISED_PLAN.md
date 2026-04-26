# Twitter/X Account Backfill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update Twitter/X Backfill Posts so `thetraitorsus` and future Twitter/X accounts scrape and persist the full account surface: text-only posts, account-authored replies, quote posts, video/media posts, direct replies, quote tweets, external reply-parent context, and grouped self-reply threads.

**Architecture:** The main session acts as the orchestrator: it owns repo boot, task dispatch, review, integration, and final verification. Fresh subagents implement bounded tasks with explicit file ownership; the orchestrator reviews each task before dispatching the next task that touches the same file. The implementation extends the existing Twitter scraper, repository, migration, launch-config, and admin UI paths rather than adding a separate Twitter flow.

**Tech Stack:** Python, pytest, Supabase/Postgres SQL migrations, Twitter/X GraphQL scraping, Next.js/React/TypeScript, Vitest/RTL runtime tests.

---

## Summary

Update Twitter/X Backfill Posts so `thetraitorsus` and future Twitter/X accounts scrape the full account surface through the existing Twitter scraper/repository pipeline: text-only posts, account-authored replies, quote posts, video/media posts, replies to each account-authored post, quote tweets for each account-authored post, parent context for account replies, and self-reply threads grouped under one root. Do not add a separate Twitter UI flow.

## Non-Goals

- Do not scrape private bookmark/save actor lists; persist engagement counts only when X exposes them.
- Do not recursively scrape replies to audience replies.
- Do not add a per-task Twitter modal unless later product work explicitly asks for it.
- Do not replace the existing Twitter scraper/repository pipeline.

## Current-State Corrections

- `social.twitter_account_catalog_posts` already has `shares`; do not add it again.
- `social.twitter_tweets` does not currently have `bookmarks`, `shares`, thread fields, or `twitter_context_role`.
- `Tweet` currently has `reply_to_tweet_id` and `quoted_tweet_id`, and scraper helper paths already parse `bookmark_count` in some summary dictionaries, but the `Tweet` dataclass and main parser do not expose `bookmarks`, `shares`, or `conversation_id`.
- `_scrape_shared_twitter_posts()` currently uses `include_replies=False` and filters out account-authored replies before catalog persistence.
- `start_social_account_catalog_backfill()` currently has `tiktok_comments_in_posts_stage`; add a Twitter equivalent instead of overloading the TikTok flag.
- Backend selected-task normalization defaults missing `selected_tasks` to `["post_details", "comments", "media"]`, but the app currently only sends defaults for Instagram/TikTok.

## Files and Ownership

The orchestrator must keep write ownership explicit so subagents do not collide in large shared files.

- Create: `TRR-Backend/supabase/migrations/20260425_twitter_account_threads_and_bookmarks.sql`
  - Owner: Schema subagent.
  - Responsibility: Add additive, idempotent Twitter account/thread/bookmark columns, constraints, and indexes.
- Modify: `TRR-Backend/trr_backend/socials/twitter/scraper.py`
  - Owner: Scraper subagent.
  - Responsibility: Extend `Tweet`, keep text-only tweets, parse bookmark/share/conversation metrics, and add `fetch_tweet_by_id()`.
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
  - Owner: Repository orchestration subagent, dispatched only after schema and scraper patches are merged.
  - Responsibility: Payload builders, thread/context helpers, Twitter shared account backfill orchestration, interaction hydration, config propagation, counters, and retryable metadata.
- Modify: `TRR-Backend/tests/repositories/test_social_season_analytics.py`
  - Owner: Repository orchestration subagent.
  - Responsibility: Backfill, thread, parent-context, selected-task, and counter tests.
- Modify: `TRR-Backend/tests/socials/test_comment_scraper_fixes.py` or `TRR-Backend/tests/socials/test_twitter_runtime_metadata.py`
  - Owner: Scraper subagent.
  - Responsibility: Parser and `fetch_tweet_by_id()` tests.
- Modify: `TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx`
  - Owner: UI subagent.
  - Responsibility: Non-Instagram selected-task success copy for Twitter/X and YouTube.
- Modify: the existing `SocialAccountProfilePage` test file that covers catalog backfill runtime behavior.
  - Owner: UI subagent.
  - Responsibility: Twitter selected-task label assertion after launch.
- Modify if contract changes cross app/backend boundary: `/Users/thomashulihan/Projects/TRR/TRR Workspace Brain/api-contract.md`
  - Owner: Main orchestrator only.
  - Responsibility: Record additive backend response/config behavior if API response fields change.

## Orchestrator and Subagent Execution Model

The main session is the orchestrator. It reads repo state, dispatches subagents, reviews patches, resolves merge conflicts, runs focused verification, and keeps the final integration coherent.

- Use fresh subagents per implementation task.
- Parallelize only disjoint write sets:
  - Schema and scraper work can run in parallel.
  - UI copy/tests can run in parallel with backend schema/scraper work if it only reads backend response shape.
  - Repository orchestration must run after schema and scraper results are available because it touches the central shared file and depends on the new `Tweet` contract.
- Tell every subagent that it is not alone in the codebase, must not revert unrelated edits, and must list changed files.
- Main orchestrator review checklist after each subagent:
  - Confirm write scope stayed inside the assigned files.
  - Run or request the focused test attached to that task.
  - Inspect diffs for current-state drift, column existence checks, and selected-task metadata consistency.
  - Dispatch the next dependent task only after the current patch is integrated.

### Task 0: Orchestrator Boot and Dispatch

**Files:**
- Read: `/Users/thomashulihan/Projects/TRR/AGENTS.md`
- Read: `/Users/thomashulihan/Projects/TRR/TRR Workspace Brain/BRAIN.md`
- Read if app/backend contract changes are confirmed: `/Users/thomashulihan/Projects/TRR/TRR Workspace Brain/api-contract.md`

- [ ] **Step 1: Confirm clean enough baseline**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
git status --short
```

Expected: identify existing dirty files before subagents start. Do not revert unrelated user changes.

- [ ] **Step 2: Dispatch schema and scraper subagents in parallel**

Assign:

```text
Schema subagent write scope:
- TRR-Backend/supabase/migrations/20260425_twitter_account_threads_and_bookmarks.sql
- any focused migration/schema test file if one already exists

Scraper subagent write scope:
- TRR-Backend/trr_backend/socials/twitter/scraper.py
- TRR-Backend/tests/socials/test_comment_scraper_fixes.py or TRR-Backend/tests/socials/test_twitter_runtime_metadata.py
```

Expected: subagents return changed paths, tests run, and any blockers.

- [ ] **Step 3: Review and integrate schema/scraper results**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
git diff -- TRR-Backend/supabase/migrations/20260425_twitter_account_threads_and_bookmarks.sql TRR-Backend/trr_backend/socials/twitter/scraper.py
```

Expected: migration is idempotent; `Tweet` contract exposes `bookmarks`, `shares`, and `conversation_id`; text-only tweets are not filtered out.

- [ ] **Step 4: Dispatch repository orchestration subagent**

Assign:

```text
Repository subagent write scope:
- TRR-Backend/trr_backend/repositories/social_season_analytics.py
- TRR-Backend/tests/repositories/test_social_season_analytics.py
```

Expected: repository patch uses the new scraper contract and migration columns.

- [ ] **Step 5: Dispatch UI subagent when backend response shape is stable**

Assign:

```text
UI subagent write scope:
- TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx
- the existing SocialAccountProfilePage test file that covers runtime backfill messages
```

Expected: Twitter/X and YouTube backfill success messages show selected task labels without adding a modal.

- [ ] **Step 6: Run final focused verification**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest tests/repositories/test_social_season_analytics.py tests/socials/test_comment_scraper_fixes.py -q -k "twitter"
```

Expected: all selected Twitter tests pass.

- [ ] **Step 7: Commit in reviewable chunks**

Preferred commits:

```bash
git add TRR-Backend/supabase/migrations/20260425_twitter_account_threads_and_bookmarks.sql
git add TRR-Backend/trr_backend/socials/twitter/scraper.py TRR-Backend/tests/socials/test_comment_scraper_fixes.py
git commit -m "feat: extend twitter tweet parsing for account backfill"
```

```bash
git add TRR-Backend/trr_backend/repositories/social_season_analytics.py TRR-Backend/tests/repositories/test_social_season_analytics.py
git commit -m "feat: hydrate twitter account replies quotes and threads"
```

```bash
git add TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx
git add TRR-APP/apps/web/src/components/admin/*test*
git commit -m "fix: show selected twitter backfill tasks"
```

## Schema Migration

Add `TRR-Backend/supabase/migrations/20260425_twitter_account_threads_and_bookmarks.sql`.

Use idempotent DDL:

- `alter table if exists social.twitter_tweets add column if not exists bookmarks integer not null default 0`
- `alter table if exists social.twitter_tweets add column if not exists shares integer not null default 0`
- `alter table if exists social.twitter_tweets add column if not exists thread_root_tweet_id text`
- `alter table if exists social.twitter_tweets add column if not exists thread_position integer`
- `alter table if exists social.twitter_tweets add column if not exists is_thread_part boolean not null default false`
- `alter table if exists social.twitter_tweets add column if not exists twitter_context_role text`
- `alter table if exists social.twitter_account_catalog_posts add column if not exists bookmarks bigint not null default 0`
- `alter table if exists social.twitter_account_catalog_posts add column if not exists thread_root_source_id text`
- `alter table if exists social.twitter_account_catalog_posts add column if not exists thread_position integer`
- `alter table if exists social.twitter_account_catalog_posts add column if not exists is_thread_part boolean not null default false`

Add lightweight indexes if absent:

- `social.twitter_tweets(thread_root_tweet_id)` where not null
- `social.twitter_tweets(twitter_context_role)` where not null
- `social.twitter_account_catalog_posts(thread_root_source_id)` where not null

Add a check constraint for `twitter_context_role` allowing null, `account_post`, `reply_parent`, `account_reply`, `audience_reply`, and `quote`.

## Scraper Support

Update `TRR-Backend/trr_backend/socials/twitter/scraper.py`.

1. Extend `Tweet` with:
   - `bookmarks: int = 0`
   - `shares: int = 0`
   - `conversation_id: str | None = None`

2. Update `_parse_tweet_result()` and related Tweet construction paths to populate:
   - `bookmarks` from `legacy.bookmark_count`
   - `shares` from any exposed `share_count`, defaulting to `0` if absent
   - `conversation_id` from `legacy.conversation_id_str` or equivalent result payload field

3. Preserve text-only tweets:
   - Keep tweets when `media_urls=[]`.
   - Ensure no parser branch treats missing media as a reason to return `None`.

4. Add `fetch_tweet_by_id(tweet_id, delay=0.0) -> Tweet | None`:
   - Use TweetDetail GraphQL parsing where possible.
   - Return a full `Tweet` object with author, text, metrics, media, `reply_to_tweet_id`, `quoted_tweet_id`, and `conversation_id`.
   - Reuse existing TweetDetail feature-flag retry behavior.
   - Fall back to the existing summary/syndication path only if enough fields are available to build a valid `Tweet`.

## Persistence Builders

Update `TRR-Backend/trr_backend/repositories/social_season_analytics.py`.

1. Update `_build_twitter_tweet_payload()`:
   - Persist `bookmarks`, `shares`, `thread_root_tweet_id`, `thread_position`, `is_thread_part`, and `twitter_context_role` when columns exist.
   - Keep new fields nullable/defaulted.
   - Preserve raw tweet data.

2. Update `_upsert_shared_catalog_twitter_post()`:
   - Persist `bookmarks`, existing `shares`, `thread_root_source_id`, `thread_position`, and `is_thread_part`.
   - Keep `media_type="text"` for text-only tweets.

3. Add helper setters for temporary in-memory thread/context attributes on `Tweet` objects if the dataclass should not permanently grow repository-only fields.

## Twitter Backfill Enrichment

Create focused helpers inside `social_season_analytics.py`.

### `_twitter_account_tweet_role(tweet, account_handle)`

Return one of:

- `account_post`
- `account_reply`
- `quote`
- `audience_reply`

Use normalized handle comparison against `tweet.username`.

### `_resolve_twitter_thread_root(scraper, tweet, account_handle, cache)`

For account-authored replies:

- Follow `reply_to_tweet_id` through `fetch_tweet_by_id()`.
- If the parent author is the same account, continue until the earliest same-account ancestor is found.
- Cache fetched parent tweets and root resolutions by tweet ID.
- Return root tweet ID, ordered same-account ancestors, and any external parent context tweet.
- Stop safely on missing parents, cycles, or fetch errors and record retryable metadata.

### `_hydrate_twitter_account_post_interactions(...)`

For each canonical account post or thread root:

- Fetch replies once with `fetch_tweet_replies(root_or_post_id)`.
- Fetch quotes once with `fetch_tweet_quotes(root_or_post_id)`.
- Persist replies as `is_reply=true`, `reply_to_tweet_id=<account post/root id>`, `twitter_context_role="audience_reply"` unless authored by the account.
- Persist quotes as `is_quote=true`, `quoted_tweet_id=<account post/root id>`, `twitter_context_role="quote"`.
- Enqueue or run Twitter comment-media mirror jobs for reply/quote media when `media` is selected.
- Return counters: `comments_fetched`, `comments_upserted`, `quotes_fetched`, `quotes_upserted`, `interaction_fetch_failures`, and `interaction_fetch_complete`.

## Shared Account Twitter Backfill Flow

Update `_scrape_shared_twitter_posts()`.

1. Use `include_replies=True` in `TwitterScrapeConfig`.
2. Stop filtering out account-authored replies.
3. Persist every account-authored result to both:
   - `social.twitter_account_catalog_posts`
   - `social.twitter_tweets`
4. Do not persist non-account-authored search results as catalog posts.
5. For account-authored external replies:
   - Fetch the parent with `fetch_tweet_by_id(reply_to_tweet_id)`.
   - Persist parent to `social.twitter_tweets` with `twitter_context_role="reply_parent"`.
6. For self-reply threads:
   - Resolve and cache the earliest same-account root.
   - Mark all thread members with `is_thread_part=true`, `thread_root_tweet_id`/`thread_root_source_id`, and stable `thread_position`.
   - Hydrate replies/quotes once per thread root, not once per thread member.
7. If `config["twitter_comments_in_posts_stage"]` is true:
   - Run interaction hydration during the Twitter shared posts stage.
   - Merge interaction counters into `retrieval_meta["persist_counters"]`.
   - Set `retrieval_meta["twitter_interactions_complete"]` to false if any reply/quote fetch is incomplete.
   - Include per-post or per-root fetch failures under `retrieval_meta["twitter_interaction_errors"]`.
8. If interaction fetch is incomplete:
   - Mark metadata retryable.
   - Do not report a fully complete comments lane.

## Launch and Config Wiring

Add `twitter_comments_in_posts_stage` alongside the existing TikTok flag.

Update exact surfaces:

- `start_social_account_catalog_backfill()` signature.
- `_create_shared_account_catalog_backfill_run()` or equivalent config creation path.
- Shared account posts job config in discovery/backfill scheduling.
- Requeue/recovery paths that preserve run config.
- Run metadata merge after launch.
- Retrieval metadata emitted by `_scrape_shared_twitter_posts()`.

In `launch_social_account_catalog_backfill()`:

- For Twitter, pass `twitter_comments_in_posts_stage="comments" in effective_selected_tasks`.
- Preserve selected/effective task metadata.
- Keep `comments_run_id=None` because Twitter comments are hydrated inside the posts stage for this plan.

## Admin UI Copy

Update `TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx`.

- Keep `Backfill Posts` as the operator action.
- For Twitter/X and YouTube, display selected task labels in the same non-Instagram success message path used for TikTok.
- Use response `effective_selected_tasks`/`selected_tasks` first, then request-body fallback.
- Expected Twitter success copy: `Twitter/X backfill queued for Post Details, Comments, Media. Catalog <id>.`
- Do not add a Twitter modal.

## Tests

### Backend repository tests

Update `TRR-Backend/tests/repositories/test_social_season_analytics.py`.

- Twitter backfill includes text-only account tweets with `media_type="text"`.
- Twitter backfill includes account-authored replies instead of filtering them out.
- Account reply to external parent persists the parent as `twitter_context_role="reply_parent"`.
- Self-reply thread parts share one `thread_root_tweet_id`; replies/quotes are fetched once for the root.
- `selected_tasks=["post_details","comments","media"]` sets `twitter_comments_in_posts_stage=true`.
- Replies and quotes update `comments_upserted`, `quotes_upserted`, `total_comments_in_db`, and `total_quotes_in_db`.
- Partial reply/quote fetch errors set retryable/incomplete metadata and do not mark comments complete.

### Scraper tests

Update `TRR-Backend/tests/socials/test_comment_scraper_fixes.py` or `TRR-Backend/tests/socials/test_twitter_runtime_metadata.py`.

- Tweet parser keeps text-only tweets.
- Tweet parser captures `bookmark_count`.
- Tweet parser captures `conversation_id_str`.
- `fetch_tweet_by_id()` returns a `Tweet` with `reply_to_tweet_id`, `quoted_tweet_id`, metrics, and author fields.

### API/UI tests

- Existing catalog backfill API tests continue to pass with default selected tasks.
- Add/update a `SocialAccountProfilePage` runtime test asserting Twitter Backfill Posts displays selected task labels after launch.
- Add/update a YouTube assertion if the same copy path is changed for YouTube.

## Manual Verification

Run focused tests:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest tests/repositories/test_social_season_analytics.py tests/socials/test_comment_scraper_fixes.py -q -k "twitter"
```

Restart the managed backend.

Use Browser Use on:

```text
http://admin.localhost:3000/social/twitter/thetraitorsus
```

Run Backfill Posts and verify:

- `2034027230708314407` is saved even if text-only.
- `/status/2034027230708314407/quotes` quote tweets are saved.
- `/status/2034027230708314407` replies are saved.
- `1987986989191491889` saves parent `1987602505157546232`.
- `1987994011265818828` and `1987994004655665268` are tagged as one thread.

## Suggestions Integrated Into Execution

These are the non-blocking improvements from `SUGGESTIONS.md`, now included in this revised execution plan so the orchestrator can choose which ones to fold into implementation without losing them.

1. **Add a Twitter Tweet fixture factory**
   - Type: Small
   - Why: The repository tests need many Tweet variants.
   - Where it applies: `TRR-Backend/tests/repositories/test_social_season_analytics.py`
   - Execution guidance: Add a small local helper such as `_twitter_tweet(...)` near the Twitter tests. It should default to a valid account-authored text tweet and allow overrides for `tweet_id`, `username`, `text`, `is_reply`, `reply_to_tweet_id`, `is_quote`, `quoted_tweet_id`, `media_urls`, `bookmarks`, `shares`, and `conversation_id`.

2. **Add migration smoke assertions**
   - Type: Small
   - Why: The migration is additive but touches two operational tables.
   - Where it applies: backend migration/schema tests if an existing pattern exists; otherwise keep this as a manual SQL verification step.
   - Execution guidance: Verify the migration creates the new columns and does not fail when rerun. If no migration test harness exists, record this as manual Supabase migration verification instead of inventing a new harness.

3. **Separate interaction counters from catalog counters**
   - Type: Small
   - Why: `posts_upserted`, `comments_upserted`, and `quotes_upserted` answer different operator questions.
   - Where it applies: Twitter retrieval metadata in `_scrape_shared_twitter_posts()` and `_hydrate_twitter_account_post_interactions(...)`.
   - Execution guidance: Keep `persist_counters.posts_upserted` for account catalog inventory and add/maintain distinct `comments_upserted`, `quotes_upserted`, `comments_fetched`, and `quotes_fetched` fields for interaction hydration.

4. **Add per-root hydration cache diagnostics**
   - Type: Small
   - Why: Thread root dedupe is central to avoiding duplicate quote/reply fetches.
   - Where it applies: `_hydrate_twitter_account_post_interactions(...)`.
   - Execution guidance: Include metadata such as `twitter_interaction_roots_checked`, `twitter_interaction_roots_hydrated`, and/or `twitter_thread_roots_deduped` if it fits the existing metadata shape. Tests should assert the scraper reply/quote methods are called once for a self-thread root.

5. **Keep parent-context rows visually distinguishable**
   - Type: Medium
   - Why: Parent rows are context, not account catalog inventory.
   - Where it applies: `twitter_context_role` persistence and future Twitter thread/comment UI.
   - Execution guidance: Persist external parents only to `social.twitter_tweets` with `twitter_context_role="reply_parent"`. Do not insert external parents into `social.twitter_account_catalog_posts`.

6. **Add bounded max-depth for parent chain resolution**
   - Type: Medium
   - Why: Bad data or API loops can waste scraper time.
   - Where it applies: `_resolve_twitter_thread_root(...)`.
   - Execution guidance: Add a small max-depth guard and visited-ID set. On cycle or depth limit, stop resolution, keep the current tweet persisted, and add retryable diagnostic metadata if parent context remains incomplete.

7. **Store thread resolution provenance**
   - Type: Medium
   - Why: Some roots are inferred from incomplete API data.
   - Where it applies: tweet `raw_data` or run retrieval metadata.
   - Execution guidance: Record whether the root came from an already-scraped account tweet, fetched parent chain, missing parent fallback, cycle guard, or depth guard.

8. **Add a small UI label helper test**
   - Type: Small
   - Why: The copy change is easy to regress.
   - Where it applies: the existing `SocialAccountProfilePage` test file.
   - Execution guidance: Assert the Twitter/X success message includes `Post Details, Comments, Media` after a mocked backfill response returns selected/effective task fields.

9. **Add a saved-count reconciliation query**
   - Type: Medium
   - Why: Manual verification names concrete tweet IDs.
   - Where it applies: manual verification notes or a local SQL snippet in the final implementation summary.
   - Execution guidance: Use a direct query that checks both `social.twitter_account_catalog_posts` and `social.twitter_tweets` for the named tweet IDs, thread root IDs, and context roles.

10. **Consider a future thread detail view**
    - Type: Large
    - Why: The data model will support grouped self-reply threads after this change.
    - Where it applies: future `TRR-APP` social comments/thread UI.
    - Execution guidance: Do not implement this in the current pass. Keep it as future product work after the data model and backfill are verified.

11. **Add hydration sampling logs**
    - Type: Small
    - Why: Twitter scraping can fail inconsistently by endpoint.
    - Where it applies: Twitter interaction hydration logging.
    - Execution guidance: Add concise per-root log context for reply and quote fetch counts/failures without logging large payloads.

12. **Document the actor-list limitation near the schema**
    - Type: Small
    - Why: Bookmarks are often misunderstood as a list of users.
    - Where it applies: migration comments or a short repository comment near `bookmarks`.
    - Execution guidance: State that `bookmarks` is a count only and bookmark actors are private/unavailable.

## Cleanup Note

After this plan is completely implemented and verified, delete any temporary planning artifacts that are no longer needed, including generated audit, scorecard, suggestions, comparison, patch, benchmark, and validation files. Do not delete them before implementation is complete because they are part of the execution evidence trail.

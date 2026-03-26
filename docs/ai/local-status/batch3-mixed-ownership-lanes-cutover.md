# Batch 3 mixed-ownership lanes cutover

Last updated: 2026-03-26

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-03-26
  current_phase: "Batch 3A through 3F implemented as narrow ownership cutovers with focused validation"
  next_action: "treat these lanes as complete unless a concrete regression appears; keep broader Reddit/discover, surveys, brands/profile, and Screenalytics architecture work deferred"
  detail: self
```

## Scope completed

- `3A networks-streaming/detail`
  - backend-owned detail and suggestions reads now live in `TRR-Backend/api/routers/admin_networks_streaming_reads.py`
  - app detail route is now a thin proxy in `TRR-APP/apps/web/src/app/api/admin/networks-streaming/detail/route.ts`
- `3B social-posts`
  - backend-owned show-list/detail/create/update/delete routes now live in `TRR-Backend/api/routers/admin_social_posts.py`
  - app routes now proxy in:
    - `TRR-APP/apps/web/src/app/api/admin/trr-api/shows/[showId]/social-posts/route.ts`
    - `TRR-APP/apps/web/src/app/api/admin/social-posts/[postId]/route.ts`
- `3C Reddit post detail`
  - backend-owned detail read now lives in `TRR-Backend/api/routers/admin_reddit_reads.py`
  - app route now proxies in `TRR-APP/apps/web/src/app/api/admin/reddit/communities/[communityId]/posts/[postId]/details/route.ts`
- `3D covered-shows writes`
  - backend-owned POST/DELETE now live in `TRR-Backend/api/routers/admin_covered_shows.py`
  - app write routes now proxy in:
    - `TRR-APP/apps/web/src/app/api/admin/covered-shows/route.ts`
    - `TRR-APP/apps/web/src/app/api/admin/covered-shows/[showId]/route.ts`
- `3E recent-people`
  - backend-owned list/record routes now live in `TRR-Backend/api/routers/admin_recent_people.py`
  - app route now proxies in `TRR-APP/apps/web/src/app/api/admin/recent-people/route.ts`
- `3F full=1 asset compatibility/debug mode`
  - show and season `full=1` asset reads now flow through backend-owned `admin_show_reads` endpoints
  - thin app proxies live in:
    - `TRR-APP/apps/web/src/app/api/admin/trr-api/shows/[showId]/assets/route.ts`
    - `TRR-APP/apps/web/src/app/api/admin/trr-api/shows/[showId]/seasons/[seasonNumber]/assets/route.ts`

## Validation

- Backend targeted tests:
  - `python -m pytest tests/api/test_admin_networks_streaming_reads.py tests/repositories/test_admin_networks_streaming_reads_repository.py tests/api/test_admin_covered_shows_reads.py tests/api/test_admin_reddit_reads.py tests/repositories/test_admin_reddit_reads_repository.py tests/api/test_admin_social_posts.py tests/repositories/test_social_posts_repository.py tests/api/test_admin_recent_people.py tests/repositories/test_recent_people_repository.py`
  - result: `33 passed`
- Backend targeted lint/format:
  - `python -m ruff check ...`
  - `python -m ruff format --check ...`
  - result: passed
- App targeted tests:
  - `pnpm -C /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web exec vitest run tests/networks-streaming-detail-route.test.ts tests/social-posts-show-route.test.ts tests/social-posts-postid-route.test.ts tests/reddit-community-post-details-route.test.ts tests/recent-people-route.test.ts tests/covered-shows-route-cache-dedupe.test.ts tests/covered-show-route-parity.test.ts tests/show-assets-route.test.ts`
  - result: `8` files passed, `31` tests passed

## Deferred on purpose

- broad Reddit discover/live/episode-discussion/backfill/runs migration
- surveys outside a normalized-editor-only batch
- brands/profile aggregate rewrite
- Screenalytics direct DB abstraction or `admin.covered_shows` decoupling
- single-image detail as a standalone phase

## Carry-forward caveats

- Batch `2.6` remains complete with caveats only; no managed-Chrome/live browser verification or live backend query-count profiling was added here.
- Batch `2.7` default-mode metadata/crop/variant dependencies still remain real; Batch `3F` preserved `full=1` compatibility/debug behavior rather than trimming payloads.

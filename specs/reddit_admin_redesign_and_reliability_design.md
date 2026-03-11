# Reddit Admin Redesign and Reliability Design

## Scope
- Rework the Reddit admin surface in `TRR-APP` for the show landing, community, window, and post-detail flows.
- Harden the Reddit refresh runtime in `TRR-Backend` without changing non-Reddit workers or `screenalytics`.
- Keep backend API changes additive and maintain legacy deep links while introducing canonical slug-based post detail URLs.

## Frontend Impact Matrix
| Surface | Change | Risk | Mitigation |
| --- | --- | --- | --- |
| Show-level Reddit landing | Promote dashboard-style summary and community entry points | Medium | Keep existing data sources and only recompose UI |
| Community view | Add stronger summary/status layout and preserve manager behaviors | Medium | Reuse `RedditSourcesManager` state and keep handlers intact |
| Window view | Add shared scaffold, stat cards, stronger grouping, canonical detail links | High | Add shared helpers and focused route tests before broad refactor |
| Post detail view | Resolve posts by canonical detail slug and redirect legacy `/post/:id` routes | High | Add additive resolver route, preserve `post_id` fallback, canonicalize after resolution |

## Backend Impact Matrix
| Surface | Change | Risk | Mitigation |
| --- | --- | --- | --- |
| `start_remote_job_workers.sh` | Normalize Reddit worker enable/count logging and no-worker exit semantics | Low | Keep invocation contract unchanged and only add defensive normalization |
| `reddit_refresh_worker.py` | Explicit boot/exit logging, enable guard, deterministic once-mode exits | Low | Preserve CLI args and return codes for successful claims |
| `reddit_refresh.py` | Stable `sync_details` progress keys, terminal summaries, clearer claim lifecycle logs | Medium | Keep status values unchanged and extend diagnostics only |

## Canonical URL Contract
- Canonical detail route:
  - `/:showId/social/reddit/:communitySlug/s:seasonNumber/:windowKey/:detailSlug`
- `detailSlug` format:
  - default: `{title-slug}--u-{author-slug}`
  - collision form: `{title-slug}--u-{author-slug}--p-{redditPostId}`
- Slugging rules:
  - lowercase kebab-case
  - strip punctuation
  - collapse duplicate separators
  - fallback author token: `unknown-author`
- Legacy routes continue to resolve:
  - `.../post/:postId`
  - mismatched slug paths that still identify a valid post

## Security and Validation
- Validate UUID route/query inputs in app routes before database access.
- Validate detail slug segments before lookup and reject malformed resolver requests with `400`.
- Keep all SQL parameterized inside `TRR-APP` repository helpers.
- Do not expose raw Reddit payload blobs in resolver responses.

## Data Flow
1. Window/detail pages resolve show/community/season/window context from route plus existing query fallbacks.
2. Detail pages call `GET /api/admin/reddit/communities/[communityId]/posts/resolve`.
3. Resolver maps `{season_id, window_key, slug, author, post_id?}` to:
   - `reddit_post_id`
   - canonical `detail_slug`
   - collision flag
   - minimal post metadata
4. Detail page fetches existing details payload using the resolved `reddit_post_id`.
5. Legacy and mismatched URLs redirect to the canonical slug route after resolution.

## Reliability Goals
- Every running Reddit refresh has stable `diagnostics.progress` keys for polling.
- Every terminal Reddit refresh has a compact `terminal_summary` the UI can reason about.
- Claim/heartbeat lifecycle is logged with worker identity for claim, completion, failure, and no-work exits.
- `sync_details` distinguishes:
  - completed
  - partial
  - failed
  - cancelled

## Test Strategy
- Backend:
  - extend repository tests for once-mode/no-work exits, terminal summaries, and stable `sync_details` progress keys
- App:
  - update canonical route tests
  - add resolver route tests
  - update window/detail page tests for new links and legacy redirect behavior

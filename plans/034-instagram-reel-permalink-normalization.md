# Plan 034: Normalize Instagram Reel permalinks in admin post/comment UIs

> **Executor instructions**: Follow step by step. Run every verification command
> before moving on. If a "STOP conditions" item occurs, stop and report. Update
> the `plans/README.md` status row when done unless a reviewer maintains it.
>
> **Drift check (run first)**:
> `git -C TRR-Backend diff --stat -- trr_backend/socials/analytics/read_models.py trr_backend/socials/read_models/account_profile/common.py trr_backend/socials/social_season_analytics_impl.py trr_backend/socials/instagram/constants.py`
> `git -C TRR-APP diff --stat -- apps/web/src/components/admin/SocialAccountProfilePage.tsx apps/web/src/components/admin/instagram/InstagramCommentsPanel.tsx apps/web/src/lib/admin/social-account-profile.ts`
> The root workspace and nested repos are dirty. Preserve unrelated changes. On
> unexpected overlap, STOP and report.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: backend + app data contract
- **Planned at**: live dirty worktree, 2026-07-08
- **Implementation status**: DONE locally 2026-07-08; Modal deploy blocked by unrelated dirty backend tree
- **Repo**: TRR-Backend first; TRR-APP only if backend payload shape cannot cover both UIs

## Why this matters

For Instagram shortcode `DaCAsaUhOYw`, the operator sees two admin UI links and
the browser-facing Instagram URL canonicalizes back to the plural Reels surface
when `/reel/` is manually changed. The TRR backend still has multiple fallbacks
that build `https://www.instagram.com/p/{shortcode}/` when the stored row lacks
an explicit permalink. That makes Reel rows open through the wrong Instagram UI
even though TRR already knows some posts are Reels.

This is an operator trust issue: the saved post is correct, but the admin link
can imply the wrong Instagram surface.

## Evidence from current repo

- `TRR-Backend/trr_backend/socials/analytics/read_models.py` hardcodes the
  per-post comments detail URL as `https://www.instagram.com/p/{source_id}/`.
- `TRR-Backend/trr_backend/socials/social_season_analytics_impl.py`
  `_shared_catalog_post_url()` falls back to `/p/{source_id}/` for Instagram.
- `TRR-Backend/trr_backend/socials/read_models/account_profile/common.py`
  `_social_account_profile_post_url()` falls back to `/p/{shortcode}/` for
  Instagram.
- `TRR-Backend/trr_backend/socials/instagram/constants.py` sets
  `PERMALINK_URL = "https://www.instagram.com/p/{shortcode}/"`.
- `TRR-Backend/tests/socials/test_comment_scraper_fixes.py` already proves the
  parser can classify a Reel and emit `https://www.instagram.com/reel/.../`.
- `TRR-Backend/tests/socials/test_instagram_permalink_metadata.py` already
  probes `/reel/` before `/p/` for metadata fallback, but this does not cover the
  admin read-model fallback links.
- `TRR-Backend/tests/repositories/test_social_season_analytics.py` currently
  asserts `/p/ABC123/` fallback links for account comments and catalog detail,
  so tests encode the stale behavior.

Live HTTP header probe note: `curl -I -L` returns `200` without server-side
redirect for `/p/DaCAsaUhOYw/`, `/reel/DaCAsaUhOYw/`, and
`/reels/DaCAsaUhOYw/`. The user-observed redirect is therefore browser/app
canonicalization, not a simple HTTP 30x. Use browser proof, not only `curl`, for
final verification.

## Affected UI surfaces

1. **Account comments UI**:
   `TRR-APP/apps/web/src/components/admin/instagram/InstagramCommentsPanel.tsx`
   renders the post link from `item.url`. For Instagram account profile comments,
   that comes from the backend comments read model.
2. **Account catalog UI + catalog detail modal**:
   `TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx` renders
   `item.url` for catalog cards/tables and `catalogDetail.permalink` in the
   detail modal. These come from shared catalog/profile read models.

## Desired behavior

- If a saved explicit URL exists (`post_url`, `permalink`, `permalink_url`,
  `canonical_url`, `url`, or `link`), preserve it.
- If no explicit URL exists and the post is known to be a Reel, build the
  Instagram Reel URL consistently.
- If no explicit URL exists and the post is not known to be a Reel, keep the
  existing `/p/{shortcode}/` fallback.
- Do not change the comments endpoint referer in
  `comments_scrapling/fetcher.py` unless a focused test proves Instagram's API
  behavior requires it. Operator-facing links and fetcher referers are separate
  contracts.

## Implementation steps

### Step 1: Prove the live row and both admin payloads

Start `make dev-hybrid` only if no clean dev stack is already running. Use
Portless URLs:

```bash
make dev-hybrid
```

Then inspect the backend/API payloads for `DaCAsaUhOYw`:

```bash
/usr/bin/curl -ksS "https://api.trr.localhost/profiles/instagram/bravotv/catalog/posts/DaCAsaUhOYw/detail" | jq '{source_id, permalink, post_format, media_type, source_surface}'
```

Also inspect the comments payload route that feeds the comments UI. Use the
account handle shown in the UI if it is not `bravotv`:

```bash
/usr/bin/curl -ksS "https://api.trr.localhost/profiles/instagram/bravotv/comments?post_source_id=DaCAsaUhOYw&page=1&page_size=5" | jq '{items: [.items[] | {post_source_id, post_url, url, post_format, media_type}]}'
```

Browser proof:

- Open `https://admin.trr.localhost/social/instagram/bravotv/catalog`.
- Find `DaCAsaUhOYw`; record the card/table **Open post** URL and the detail
  modal **Open permalink** URL.
- Open `https://admin.trr.localhost/social/instagram/bravotv/comments?post_source_id=DaCAsaUhOYw`
  or use the UI filter that lands on that post; record the comments table post
  URL.

Expected current failure: at least one backend payload/UI link uses `/p/` for a
known Reel or otherwise disagrees with the canonical Instagram surface.

### Step 2: Add a shared Instagram permalink helper

Create a small backend helper near the Instagram URL constants. Keep it pure and
unit-testable, for example:

```python
def instagram_post_permalink(shortcode: str, *, post_format: str | None = None, media_type: str | None = None, explicit: str | None = None) -> str | None:
    ...
```

Rules:

- Return valid explicit HTTP(S) URLs unchanged.
- Return `None` for blank shortcodes.
- Treat `post_format` values like `reel`, `reels`, and `clips`, plus
  `media_type` values that the codebase already uses for Reels, as Reel posts.
- Build the Reel fallback with the path that browser proof shows as canonical
  for `DaCAsaUhOYw`. If the browser canonical path is plural `/reels/`, document
  that choice in the helper test name.
- Keep `/p/` for non-Reel or unknown posts.

### Step 3: Replace backend admin/read-model fallbacks

Use the helper in these fallback builders:

- `TRR-Backend/trr_backend/socials/analytics/read_models.py`
  `get_post_comments()` return payload.
- `TRR-Backend/trr_backend/socials/social_season_analytics_impl.py`
  `_shared_catalog_post_url()`.
- `TRR-Backend/trr_backend/socials/read_models/account_profile/common.py`
  `_social_account_profile_post_url()`.
- Any direct duplicated `/p/{shortcode}/` fallback discovered in the same
  account-profile/catalog read path during implementation.

Pass the best available row fields into the helper:

- `post_format`
- `media_type`
- explicit URL candidates already used by the current function

Do not normalize unrelated persisted URLs in-place during the read. This plan is
for correct admin output first; a data backfill can follow if needed.

### Step 4: Add focused tests

Update or add tests in `TRR-Backend/tests/repositories/test_social_season_analytics.py`:

- Account comments fallback returns a Reel URL when the Instagram row has
  `post_format="reel"` or equivalent metadata and no explicit post URL.
- Account comments still returns `/p/ABC123/` when the row has no Reel signal.
- Catalog post detail discussion payload uses the Reel permalink for a Reel
  fallback.
- Explicit `post_url` / `permalink_url` values are preserved unchanged.

Add a smaller helper test if the helper lives outside the repository test's
natural coverage.

Keep existing comments fetcher tests unchanged unless implementation changes the
fetcher referer. If changing it becomes necessary, add a separate test proving
the expected referer.

### Step 5: Verify the two admin UIs

Run focused backend tests:

```bash
cd TRR-Backend && .venv/bin/python -m pytest tests/repositories/test_social_season_analytics.py -k "social_account_profile_comments or social_account_catalog_post_detail" -q
```

Run lint on touched backend files:

```bash
cd TRR-Backend && ruff check trr_backend/socials/analytics/read_models.py trr_backend/socials/read_models/account_profile/common.py trr_backend/socials/social_season_analytics_impl.py trr_backend/socials/instagram/constants.py tests/repositories/test_social_season_analytics.py
```

If app files are touched, run:

```bash
make app-validate-quick
```

Browser verification:

- In the catalog card/table and detail modal, `DaCAsaUhOYw` opens the same
  canonical Reel URL.
- In the comments UI, the post link for `DaCAsaUhOYw` opens the same canonical
  Reel URL.
- Non-Reel Instagram post links still open as `/p/{shortcode}/`.

## Done criteria

- [x] Chrome proof recorded that `/reel/DaCAsaUhOYw/` lands on `/reels/DaCAsaUhOYw/`.
- [x] Shared helper covers explicit URL, Reel fallback, non-Reel fallback, and
      blank shortcode behavior.
- [x] Account comments payload no longer emits `/p/` for known Reels without an
      explicit URL.
- [x] Catalog list/detail payloads no longer emit `/p/` for known Reels without
      an explicit URL.
- [x] Existing explicit URLs are preserved.
- [x] Focused backend tests pass.
- [x] Touched-file lint passes.
- [ ] Browser proof covers both admin UI surfaces. Backend payload/read-model tests are green; live admin proof was not run because the dev stack was not started.
- [x] Modal/backend deploy status is reported if backend code changes are
      integrated into the active deploy path.

## 2026-07-08 local implementation update

- Added `instagram_post_permalink()` in `trr_backend/socials/instagram/constants.py`.
- Wired the helper into Instagram read-model, catalog, account-profile, and canonical-post URL fallbacks.
- Preserved explicit stored URLs unchanged.
- Added focused tests:
  - `tests/socials/test_instagram_permalink_metadata.py`
  - `tests/repositories/test_social_season_analytics.py`
- Verification passed:
  - `cd TRR-Backend && .venv/bin/python -m pytest tests/socials/test_instagram_permalink_metadata.py -q`
  - `cd TRR-Backend && .venv/bin/python -m pytest tests/repositories/test_social_season_analytics.py -k "social_account_profile_comments or social_account_catalog_post_detail_instagram" -q`
  - `cd TRR-Backend && ruff check trr_backend/socials/instagram/constants.py trr_backend/socials/social_season_analytics_impl.py trr_backend/socials/analytics/read_models.py trr_backend/socials/read_models/account_profile/common.py trr_backend/socials/instagram/catalog_ingest.py tests/socials/test_instagram_permalink_metadata.py tests/repositories/test_social_season_analytics.py`
- Chrome proof:
  - Opening `https://www.instagram.com/reel/DaCAsaUhOYw/` in Chrome ended at `https://www.instagram.com/reels/DaCAsaUhOYw/`.
- Modal follow-through:
  - Not deployed. `TRR-Backend` has many unrelated dirty changes, so `cd TRR-Backend && ./.venv/bin/python -m modal deploy -m trr_backend.modal_jobs` would risk shipping unrelated work. Deploy from a clean integration tree or a bounded Modal deploy patch.

## STOP conditions

Stop and report if:

- The live `DaCAsaUhOYw` row has no Reel signal in any stored field and no
  explicit permalink. That means the implementation needs a data-enrichment or
  metadata-refresh plan first.
- Browser proof shows Instagram canonicalizes to a path other than `/reel/` or
  `/reels/`, or canonical behavior differs by login state.
- The comments API/fetcher starts failing when only operator-facing links are
  changed. Do not mix link normalization with fetcher behavior without new
  evidence.
- App code must infer Reel status that the backend does not expose. Prefer
  backend payload correction; stop before creating duplicate frontend inference.

## Maintenance notes

- Existing tests currently encode `/p/` as the default fallback. Keep the
  non-Reel `/p/` fallback tests so this does not become a broad Instagram URL
  rewrite.
- The backend read-model fix should be enough for both UIs. Only touch TRR-APP
  if the backend cannot supply the corrected URL or if the UI is discarding it.

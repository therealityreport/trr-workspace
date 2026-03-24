# Instagram Admin Social Profile Timeout Fix

Date: 2026-03-22

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-03-22
  current_phase: "complete"
  next_action: "Restart make dev so the local app picks up TRR_API_URL=http://127.0.0.1:8000 and verify the Instagram admin profile page no longer shows timeout banners."
  detail: self
```

## Problem

The local admin page at `http://admin.localhost:3000/admin/social/instagram/[username]` was repeatedly showing `TRR-Backend request timed out.` even after a clean `make dev`.

Two root causes were confirmed:

1. Local `make dev` was pointing `TRR-APP` at the deployed Modal backend via `TRR_API_URL`, so local code changes were not affecting the admin page at all.
2. The shared-account profile queries in `TRR-Backend` were filtering catalog rows with `lower(coalesce(source_account, '')) = %s`, which prevented Postgres from using the existing `instagram_account_catalog_posts_account_posted_at_idx` index on `lower(source_account)`.

## Changes

- Updated `profiles/default.env` so local `make dev` targets the local FastAPI server at `http://127.0.0.1:8000`.
- Kept remote job execution policy unchanged:
  - `WORKSPACE_TRR_JOB_PLANE_MODE=remote`
  - `WORKSPACE_TRR_REMOTE_EXECUTOR=modal`
  - local social workers remain disabled
- Rewrote shared-account `source_account` filters in `TRR-Backend/trr_backend/repositories/social_season_analytics.py` from `lower(coalesce(source_account, ''))` to `lower(source_account)` so the existing per-account catalog index can be used.

## Evidence

- Direct call to the deployed Modal summary endpoint for `instagram/bravowwhl` took about `174s`.
- Before the SQL rewrite, `EXPLAIN ANALYZE` on `instagram_account_catalog_posts` showed a sequential scan for the per-account query.
- After the SQL rewrite, the same query switched to `instagram_account_catalog_posts_account_posted_at_idx`.

Patched local timings:

- `get_social_account_profile_summary("instagram", "bravowwhl")`: about `8.0s`
- `get_social_account_catalog_posts(..., page=1, page_size=1)`: about `1.4s`
- `get_social_account_profile_collaborators_tags(...)`: about `4.2s`
- `get_social_account_profile_hashtags(...)`: about `9.7s`

Fresh HTTP smoke against a throwaway local backend on port `8011`:

- `/api/v1/admin/socials/profiles/instagram/bravowwhl/summary`: `200` in `7.9s`
- `/api/v1/admin/socials/profiles/instagram/bravowwhl/catalog/posts?page=1&page_size=1`: `200` in `1.4s`
- `/api/v1/admin/socials/profiles/instagram/bravowwhl/collaborators-tags`: `200` in `5.7s`

## Validation

- `pytest -q tests/api/routers/test_socials_season_analytics.py -k 'social_account_profile or catalog_backfill or catalog_sync_recent'`
- `pytest -q tests/repositories/test_social_season_analytics.py -k 'get_social_account_profile_summary or get_social_account_catalog_posts or get_social_account_profile_collaborators_tags or get_social_account_profile_hashtags'`

## Follow-up

Restart `make dev` so `TRR-APP` picks up the new `TRR_API_URL=http://127.0.0.1:8000` local profile default.

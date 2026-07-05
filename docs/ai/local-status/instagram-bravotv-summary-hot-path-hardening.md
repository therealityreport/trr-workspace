# Instagram Bravotv summary hot path hardening

Last updated: 2026-03-26

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-03-26
  current_phase: "complete"
  next_action: "If instagram summary pages regress again, profile get_social_account_profile_summary() before changing worker or Modal logic because this issue was a local summary hot path, not a dispatch failure"
  detail: self
```

## Scope
- `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- `TRR-Backend/tests/repositories/test_social_season_analytics.py`

## Problem
- `http://admin.localhost:3000/social/instagram/bravotv` was not the same failure as the earlier Modal dispatch issue on `@bravodailydish`.
- The live backend summary path for `instagram/bravotv` was repeatedly timing out or stalling because summary assembly reloaded the full Instagram account dataset while computing hashtag aggregates.

## Root Cause
- `get_social_account_profile_summary("instagram", "bravotv")` correctly loaded a bounded analysis sample first.
- The Instagram summary then called `_social_account_profile_hashtag_items(...)` without preloaded rows.
- That helper called `_social_account_profile_analysis_rows(...)` again with no limit and loaded roughly 16k rows for `@bravotv`, adding about 33 seconds to summary generation.

## Changes
- Added a `rows` parameter to `_social_account_profile_hashtag_items(...)` so callers can reuse preloaded analysis rows.
- Updated Instagram summary assembly to pass its existing `analysis_rows` into `_social_account_profile_hashtag_items(...)` instead of re-fetching the full dataset.
- Added regression coverage proving Instagram summary reuses the bounded analysis rows for hashtag generation.

## Validation
- Targeted pytest:
  - `python3.11 -m pytest tests/repositories/test_social_season_analytics.py -k 'get_social_account_profile_summary_reuses_loaded_instagram_rows_for_hashtags or instagram_social_account_profile_dataset_rows_applies_limit_to_source_queries or social_account_profile_analysis_rows_for_instagram_forwards_limit_to_dataset or get_social_account_profile_summary'`
  - Result: `15 passed`
- In-process timing:
  - `get_social_account_profile_summary("instagram", "bravotv")` completed in about `4.6s`
- Live backend after restart:
  - `GET /api/v1/admin/socials/profiles/instagram/bravotv/summary`
  - Result: `200 OK` in about `5.8s`
- App proxy after backend restart:
  - `GET /api/admin/trr-api/social/profiles/instagram/bravotv/summary`
  - First pass: `200 OK` in about `19.7s`
  - Warm cache pass: `200 OK` with `x-trr-cache: hit` in about `0.087s`

## Notes
- The live backend process was running in non-reload mode and needed a restart to pick up the repository fix.
- The first app request still includes Next dev/runtime overhead, but the backend summary is no longer failing and subsequent requests stabilize immediately from cache.

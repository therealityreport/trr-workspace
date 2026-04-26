# Plan Patches

## Patch 1: Add concrete data source and failure handling

Replace:

```md
Build the section from existing TRR sources:
- Cast membership from the existing bulk cast-summary route.
- Effective cast handles from the same merged source already used for `people_profiles`.
- SocialBlade scrape presence from `pipeline.socialblade_growth_data`.
```

With:

```md
Build the section in the social landing repository from covered shows, bulk cast summary, effective person social handles, and a new narrow SocialBlade row loader. The loader reads `pipeline.socialblade_growth_data` by normalized `(platform, account_handle)` and `person_id`, returns only summary metadata needed by the landing page, and returns an empty list if the table or query is unavailable so the rest of `/admin/social` still renders.
```

## Patch 2: Add cache behavior

Add to Key Changes:

```md
Update `coerceLandingPayload` for `cast_socialblade_shows` and bump `SOCIAL_LANDING_CACHE_KEY` so stale v1 cached payloads cannot hide the new section.
```

## Patch 3: Add backend contract ownership

Replace:

```md
Extend the bulk cast-summary backend response with optional `photo_url`.
```

With:

```md
Backend-first: extend `/admin/shows/cast-summary` in `TRR-Backend/api/routers/admin_cast.py` to include optional `photo_url` on `CastSummaryMember`, using the cast photo selection pattern already used by cast role member reads. Add targeted backend tests proving `photo_url` is present when available and omitted/null-safe when missing.
```

## Patch 4: Replace vague verification with concrete acceptance checks

Add to Test Plan:

```md
Run targeted backend cast-summary tests, targeted app social landing repository/UI tests, app typecheck/lint for touched surfaces, and an in-app browser check at `http://admin.localhost:3000/admin/social` selecting RHOSLC and opening one Instagram account at `/social/instagram/[handle]`.
```

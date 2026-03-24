# Cast Screentime pipeline revision

Last updated: 2026-03-20

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-03-20
  current_phase: "complete"
  next_action: "Use the new media_type-driven cast screentime flow, review cast-coverage warnings in admin, and treat accepted suggestions/unknown decisions as rerun inputs rather than retroactive metric edits"
  detail: self
```

- `TRR-Backend`
  - Added additive schema support for `media_type` and optional `media_kind` on cast-screentime upload sessions and video assets, plus run metadata for `candidate_scope_policy_json`, `cast_coverage_summary_json`, and durable dispatch tracking.
  - Updated admin cast-screentime APIs to normalize legacy `video_class/promo_subtype` into `episode | trailer | extras`, enforce `episode -> owner_scope=episode`, emit media-type-specific exclusion policy defaults, and gate canonical publish to approved `episode` runs only.
  - Replaced plain candidate snapshot assembly with scope-aware candidate sourcing that prefers direct asset candidates, then falls back by owner scope while tracking approved-facebank coverage and warning when fallback or sparse coverage is needed.
  - Updated decision-state and decision-write responses so accepted suggestions and unknown-review decisions clearly require a rerun before official named metrics change.
- `screenalytics`
  - Updated the internal cast-screentime start route to enqueue durable work through the Celery `visual_v2` queue instead of launching an in-process background thread.
  - Expanded the worker run contract and manifest to carry `media_type`, `media_kind`, `candidate_scope_policy`, `cast_coverage_summary`, and dispatch metadata.
  - Made title-card and flashback exclusion behavior policy-driven by media type: episodes auto-exclude configured matches, while trailers/extras still preserve review artifacts without assuming episode-style exclusions.
  - Kept run outputs reviewable even when exclusions are disabled by default for the media type.
- `TRR-APP`
  - Updated the admin cast-screentime page to use `episode | trailer | extras` throughout upload/import flows, run filtering, badges, and publishability messaging.
  - Added run-surface visibility for candidate cast coverage warnings, queued dispatch state, and rerun-required messaging for suggestion/unknown decisions.
  - Reframed non-episode runs as standalone trailer/extras reports instead of the old promo/test model.
- Validation:
  - `python3 -m py_compile /Users/thomashulihan/Projects/TRR/TRR-Backend/api/routers/admin_cast_screentime.py /Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/repositories/cast_screentime.py /Users/thomashulihan/Projects/TRR/TRR-Backend/tests/api/test_admin_cast_screentime.py`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest -q tests/api/test_admin_cast_screentime.py`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && ruff check api/routers/admin_cast_screentime.py trr_backend/repositories/cast_screentime.py tests/api/test_admin_cast_screentime.py`
  - `python3 -m py_compile /Users/thomashulihan/Projects/TRR/screenalytics/apps/api/tasks_v2.py /Users/thomashulihan/Projects/TRR/screenalytics/apps/api/routers/cast_screentime.py /Users/thomashulihan/Projects/TRR/screenalytics/apps/api/services/cast_screentime.py /Users/thomashulihan/Projects/TRR/screenalytics/tests/api/test_cast_screentime_internal.py`
  - `cd /Users/thomashulihan/Projects/TRR/screenalytics && pytest -q tests/api/test_cast_screentime_internal.py`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec eslint src/app/admin/cast-screentime/CastScreentimePageClient.tsx`
- Follow-up / known limits:
  - `make schema-docs-check` in `TRR-Backend` currently surfaces broad pre-existing schema-doc drift unrelated to this slice; I did not update that large unrelated generated surface here.
  - A full `TRR-APP` workspace type/build pass was not completed in this session; targeted lint for the touched admin page passed.

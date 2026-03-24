# BRAVOTV Get Images Pipeline CLI Foundation

Last updated: 2026-03-20

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-03-20
  current_phase: "CLI/runtime foundation shipped in tracked backend code, with show-mode smoke validation passing and person/show source-family orchestration now in place"
  next_action: "Decide whether to add a DB import path for merged artifacts next or wire the existing person-gallery/admin surfaces to consume the new standalone pipeline outputs"
  detail: self
```

## Scope
- Approved plan: `/Users/thomashulihan/Projects/TRR/BRAVOTV/plans/get-images-pipeline-plan.md`
- Delivery focus: tracked CLI/runtime foundation for the BRAVOTV multi-source image pipeline
- Consumer stance: keep TRR-APP wiring deferred; existing person-page source selector work remains the current UI-side prep

## What Shipped
- Added a reusable Bravo JSONAPI collector in `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/integrations/bravo_jsonapi.py`
  - person gallery lookup
  - show gallery lookup
  - gallery asset extraction with per-image `field_caption`, file URLs, and page metadata
- Added the BRAVOTV pipeline runtime in `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/bravotv/get_images_pipeline.py`
  - `person` and `show` modes
  - source-family selection with `all|getty|imdb|tmdb`
  - `getty` family expansion to Getty + NBCUMV + Bravo raw caches
  - deterministic bridge table generation
  - merged catalog generation with provenance and confidence
  - conservative caption matching with manual-review rows
  - cloud-first acquisition
    - NBCUMV hi-res bytes uploaded to object storage
    - Bravo CDN assets mirrored to object storage
    - Getty-only rows kept as watermarked references with Google reverse-image-search URLs
  - show-mode by-person fan-out and reports
  - person-mode supplemental IMDb/TMDb catalogs with hosted mirroring
- Added a CLI entry point in `/Users/thomashulihan/Projects/TRR/TRR-Backend/scripts/bravotv_get_images.py`

## Output Contract
The pipeline now writes:
- `raw/*.json`
- `bridge_table.json`
- `merged_catalog.json`
- `reports/source_distribution.json`
- `reports/source_distribution.txt`
- `show_summary.json`
- `run_manifest.json`
- `by_person/*/catalog.json` for show runs
- `supplemental_cast_photos.json` when IMDb/TMDb person sources are used

## Validation
- Static checks:
  - `ruff check` passed for new runtime, collector, CLI, and tests
  - `ruff format` applied
- Tests:
  - `pytest -q tests/bravotv/test_get_images_pipeline.py tests/integrations/test_bravo_jsonapi.py`
  - result: `7 passed`
- CLI smoke:
  - `python scripts/bravotv_get_images.py --help` succeeded
  - live smoke succeeded for a tiny show-scoped run:
    - `--show 'Watch What Happens Live' --season 15 --sources getty --getty-limit 1 --nbcumv-limit 1 --bravo-limit 1`
    - output written under `/tmp/bravotv-pipeline-smoke-showonly-20260320`
    - manifest confirmed `getty` refresh expanded to `getty/nbcumv/bravo`

## Important Decisions
- Kept the plan CLI/runtime in tracked backend code because `/Users/thomashulihan/Projects/TRR/BRAVOTV/` is gitignored in the workspace root.
- Did not add new TRR-APP admin integration in this pass.
- Used Google reverse-image-search URLs for Getty fallback rows instead of automated TinEye/PicDetective replacement.
- Stored acquired bytes in object storage rather than local image folders.

## Remaining Gaps
- Person-mode live smoke was not fully characterized end to end; the show-scoped smoke run is the runtime proof point from this session.
- Photo Bank remains deferred.
- No import path from the standalone artifacts into existing TRR `cast_photos` / `media_assets` tables was added here.
- Admin/social surfaces still do not consume these standalone pipeline artifacts directly.

## Next Best Steps
1. Add an import step that can write merged/artifact results into existing TRR gallery tables when desired.
2. Run a person-mode live pass with explicit external IDs if IMDb/TMDb coverage is important for the first operator workflow.
3. Decide whether the future UI consumer should be the person gallery flow, a show gallery flow, or both.

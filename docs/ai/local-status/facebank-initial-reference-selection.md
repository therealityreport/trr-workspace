# Facebank initial reference selection

Last updated: 2026-03-20

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-03-20
  current_phase: "complete"
  next_action: "Use the new backend-ranked facebank initial selection flow for cast gallery imports, then follow up later only if we want richer face-quality metadata or an explicit admin review UI for the preselected starter set"
  detail: self
```

- `TRR-Backend`
  - Added a backend-owned `facebank_initial` selection profile for `GET /screenalytics/people/{person_id}/photos` so screenalytics can request a small, ranked starter set instead of consuming raw gallery order.
  - Implemented a new facebank initial-reference ranking helper in `trr_backend/repositories/tagging_references.py` that gates out unusable rows, prioritizes manual and seeded intent, prefers solo and same-show images, caps event/glamour-heavy selections, and falls back to non-solo imagery only when sparse galleries require it.
  - Expanded the internal screenalytics ingest payload additively with ranking metadata such as selection bucket, reasons, source, hosted fields, and facebank-seed hints while preserving the existing approval gate downstream.
- `screenalytics`
  - Updated TRR ingest photo fetches to request the backend `facebank_initial` profile and thread show context through the facebank import flow.
  - Updated both show-level seed sync and episode-driven cast sync paths to pass show identifiers and show names so backend selection can prefer same-show imagery when available.
  - Preserved the existing safety behavior where imported `screenalytics.face_bank_images` rows are inserted as `is_seed=true` and `approved=false`, so the matcher still requires human approval before using new references.
- Validation:
  - `python3 -m py_compile /Users/thomashulihan/Projects/TRR/TRR-Backend/api/routers/screenalytics.py /Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/repositories/tagging_references.py`
  - `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && ./.venv/bin/pytest -q tests/api/test_screenalytics_ingest_endpoints.py tests/repositories/test_tagging_references.py`
  - `python3 -m py_compile /Users/thomashulihan/Projects/TRR/screenalytics/apps/api/services/trr_ingest.py /Users/thomashulihan/Projects/TRR/screenalytics/apps/api/routers/cast.py /Users/thomashulihan/Projects/TRR/screenalytics/apps/api/routers/episodes.py`
  - `cd /Users/thomashulihan/Projects/TRR/screenalytics && pytest -q tests/unit/test_trr_ingest.py tests/api/test_sync_show_facebank_seeds.py tests/api/test_sync_cast_from_trr.py`

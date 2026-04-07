# TRR Workspace Concerns Map

Updated from workspace scan on 2026-04-07.

## 1. Shared-Database Coupling Across Three Repos

- Canonical schema changes live in `TRR-Backend/supabase/migrations/`, but both `screenalytics` and `TRR-APP` also read the same broader data model.
- Key examples:
  - `screenalytics/apps/api/services/supabase_db.py`
  - `screenalytics/apps/api/services/trr_ingest.py`
  - `TRR-APP/apps/web/src/lib/server/postgres.ts`
- Risk: schema drift or renamed columns can break multiple repos without compile-time coordination.

## 2. Multiple Auth Lanes in the App

- `TRR-APP/apps/web/src/lib/server/auth.ts` supports Firebase and Supabase-backed paths.
- `TRR-APP/apps/web/src/lib/server/trr-api/internal-admin-auth.ts` adds a separate service-to-service JWT lane.
- Risk: auth-cutover or admin changes can regress one lane while another still passes.

## 3. Backend Router Surface Is Very Large

- `TRR-Backend/api/routers/` contains a large number of admin-heavy routers.
- Several files such as `admin_show_links.py`, `admin_person_images.py`, and `admin_cast_screentime.py` are likely high-complexity modules based on file size and grep output.
- Risk: router modules may be carrying orchestration and domain logic that is difficult to regression-test exhaustively.

## 4. screenalytics Runtime Complexity

- screenalytics combines:
  - FastAPI
  - Streamlit
  - Celery
  - Redis
  - local artifacts
  - shared Postgres
  - S3-compatible object storage
  - optional heavy ML dependencies
- Key paths:
  - `screenalytics/apps/api/main.py`
  - `screenalytics/apps/api/services/storage.py`
  - `screenalytics/apps/api/services/pipeline_orchestration.py`
  - `screenalytics/apps/api/services/cast_screentime.py`
- Risk: environment-specific failures are easy to introduce and hard to fully replay.

## 5. Direct App DB Access Bypasses Backend Contract Centralization

- The app does not exclusively go through backend HTTP APIs.
- Direct server-side reads/writes exist in modules such as:
  - `TRR-APP/apps/web/src/lib/server/postgres.ts`
  - `TRR-APP/apps/web/src/lib/server/shows/shows-repository.ts`
  - `TRR-APP/apps/web/src/lib/server/surveys/*`
- Risk: even if backend is supposed to own the contract, app-local queries can silently depend on schema details.

## 6. Object Storage Contract Is Spread Across Repos

- Backend object/media logic lives in `TRR-Backend/trr_backend/media/` and `TRR-Backend/trr_backend/object_storage.py`
- screenalytics storage logic lives in `screenalytics/apps/api/services/storage.py` and `storage_v2.py`
- App operational scripts also touch object storage in `TRR-APP/scripts/upload-fonts-to-s3.py`
- Risk: bucket naming, key layout, cache headers, and auth assumptions can drift independently.

## 7. CI Coverage Is Uneven Relative to Repo Size

- Backend main CI runs `tests/api` rather than the entire suite from `TRR-Backend/tests/`
- screenalytics uses targeted subsets and eager-mode stubs for practical reasons
- frontend has extensive tests, but route breadth is high and many admin behaviors remain integration-heavy
- Risk: some important regressions are protected only by local discipline and targeted testing, not full CI parity.

## 8. Next.js Config Surface Is Operationally Sensitive

- `TRR-APP/apps/web/next.config.ts` includes Firebase aliasing, image behavior overrides, typed-route gating, Turbopack root overrides, and a large rewrite/redirect matrix.
- Risk: seemingly small config edits can break builds, dev server behavior, or URL canonicalization in non-obvious ways.

## 9. Runtime Env Contract Strictness Is High

- Backend startup hard-validates lane/auth envs in `TRR-Backend/api/main.py`
- screenalytics validates connection class and storage readiness in `screenalytics/apps/api/services/supabase_db.py` and `screenalytics/apps/api/services/validation.py`
- app build and auth flows depend on multiple service keys and placeholders
- Risk: local/dev/test/prod parity issues can look like application bugs when they are really env contract failures.

## 10. Generated and Derived Artifacts Need Manual Freshness Discipline

- Backend schema docs under `TRR-Backend/supabase/schema_docs/` are generated and checked
- repo-map artifacts are generated in backend and screenalytics workflows
- frontend has generated font and API-reference artifacts under `TRR-APP/apps/web/src/lib/**/generated/`
- Risk: code can compile while generated reference artifacts go stale if the right verification command is skipped.

## 11. Naming and Route Drift Risk in the App

- The route tree contains similar or misspelled surfaces such as `screenalytics` and `screenlaytics`, plus multiple legacy/canonical route forms handled in rewrites.
- Risk: alias routes, auth bypass logic, and admin navigation can diverge subtly.

## 12. Planning Implication

- Safe cross-repo work should usually start by identifying:
  - the schema owner in `TRR-Backend`
  - the screenalytics consumer path
  - the app server adapter or proxy path
- Skipping any of those three checks is likely to miss a real dependency.

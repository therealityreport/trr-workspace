# Instagram Social Profile Cold-Path Gap Closure

Last updated: 2026-04-22 (validation)

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-04-22
  current_phase: "pass-2 validation rerun captured final local timings and acceptance state"
  next_action: "apply the missing Task 1 index migration locally, then continue warm-path summary and comments follow-up from the measured blockers below"
  detail: self
```

## Scope
- `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- `TRR-Backend/trr_backend/db/pg.py`
- `TRR-Backend/tests/repositories/test_social_season_analytics.py`
- `TRR-Backend/tests/db/test_pg_pool.py`
- `profiles/default.env`

## What Landed In This Pass
- Added opt-in route-local perf logging for `get_social_account_profile_comments(...)` and `get_social_account_profile_summary(...)`.
- Replaced the comments route's separate count + page reads with one exact-total SQL statement and kept the `post_url` fallback chain so the page no longer depends on a physical `p.url` column.
- Replaced separate Instagram summary rollups with one shared `detail_rollup` loader on the full-summary path.
- Routed social-profile reads through a dedicated named read pool lane (`pool_name="social_profile"`) with explicit labels for summary/comments work.

## Validation Commands Used
- Cold/warm repository benchmark:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
source /Users/thomashulihan/Projects/TRR/scripts/lib/runtime-db-env.sh
trr_export_runtime_db_env_from_file /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/.env.local
set -a
source /Users/thomashulihan/Projects/TRR/profiles/default.env
set +a
PYTHONPATH=. .venv/bin/python - <<'PY'
import time
from trr_backend.repositories import social_season_analytics as repo

repo._clear_social_hot_path_caches()
repo._SOCIAL_PROFILE_TOTAL_POSTS_CACHE.clear()
repo._SOCIAL_PROFILE_SNAPSHOT_CACHE.clear()
repo._relation_columns_cache.clear()
repo._column_exists_cache.clear()

def timed(label, fn):
    started = time.perf_counter()
    payload = fn()
    elapsed_ms = (time.perf_counter() - started) * 1000.0
    print(f"{label}_ms={elapsed_ms:.1f}")
    return payload

comments_cold = timed("comments_cold", lambda: repo.get_social_account_profile_comments("instagram", "thetraitorsus", page=1, page_size=25))
summary_cold = timed("summary_cold", lambda: repo.get_social_account_profile_summary("instagram", "thetraitorsus", detail="full"))
comments_warm = timed("comments_warm", lambda: repo.get_social_account_profile_comments("instagram", "thetraitorsus", page=1, page_size=25))
summary_warm = timed("summary_warm", lambda: repo.get_social_account_profile_summary("instagram", "thetraitorsus", detail="full"))
print(f"comments_total={comments_cold['pagination']['total']} comments_rows={len(comments_cold['items'])}")
print(f"summary_comment_posts={summary_cold['comments_saved_summary']['retrieved_comment_posts']}")
PY
```

- Perf-debug breakdown:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
source /Users/thomashulihan/Projects/TRR/scripts/lib/runtime-db-env.sh
trr_export_runtime_db_env_from_file /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/.env.local
set -a
source /Users/thomashulihan/Projects/TRR/profiles/default.env
set +a
export TRR_SOCIAL_PROFILE_PERF_DEBUG=1
PYTHONPATH=. .venv/bin/python - <<'PY'
import logging
from trr_backend.repositories import social_season_analytics as repo

logging.basicConfig(level=logging.INFO)
repo._clear_social_hot_path_caches()
repo._SOCIAL_PROFILE_TOTAL_POSTS_CACHE.clear()
repo._SOCIAL_PROFILE_SNAPSHOT_CACHE.clear()
repo._relation_columns_cache.clear()
repo._column_exists_cache.clear()
repo.get_social_account_profile_comments("instagram", "thetraitorsus", page=1, page_size=25)
repo.get_social_account_profile_summary("instagram", "thetraitorsus", detail="full")
PY
```

- `pg_stat_statements` snapshot:

```sql
select
  calls,
  round(total_exec_time::numeric, 1) as total_ms,
  round(mean_exec_time::numeric, 1) as mean_ms,
  left(regexp_replace(query, '\s+', ' ', 'g'), 220) as query
from pg_stat_statements
where query ilike '%instagram_detail_rollup%'
   or query ilike '%count(*) over()::int as full_count%'
   or query ilike '%social.instagram_comments%'
order by total_exec_time desc
limit 8;
```

- Index presence check:

```sql
select schemaname, tablename, indexname, indexdef
from pg_indexes
where schemaname = 'social'
  and tablename = 'instagram_posts'
  and indexdef ilike '%source_account%'
order by indexname;
```

- Four-way summary concurrency smoke:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
source /Users/thomashulihan/Projects/TRR/scripts/lib/runtime-db-env.sh
trr_export_runtime_db_env_from_file /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/.env.local
set -a
source /Users/thomashulihan/Projects/TRR/profiles/default.env
set +a
PYTHONPATH=. .venv/bin/python - <<'PY'
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from trr_backend.repositories import social_season_analytics as repo

repo._clear_social_hot_path_caches()
repo._SOCIAL_PROFILE_TOTAL_POSTS_CACHE.clear()
repo._SOCIAL_PROFILE_SNAPSHOT_CACHE.clear()
repo._relation_columns_cache.clear()
repo._column_exists_cache.clear()

def load_one(i):
    started = time.perf_counter()
    payload = repo.get_social_account_profile_summary("instagram", "thetraitorsus", detail="full")
    return i, (time.perf_counter() - started) * 1000.0, payload["comments_saved_summary"]["saved_comments"]

results = []
errors = []
started = time.perf_counter()
with ThreadPoolExecutor(max_workers=4) as executor:
    futures = [executor.submit(load_one, i) for i in range(4)]
    for fut in as_completed(futures):
        try:
            results.append(fut.result())
        except Exception as exc:
            errors.append(type(exc).__name__ + ":" + str(exc))

elapsed = (time.perf_counter() - started) * 1000.0
print(f"total_ms={elapsed:.1f}")
for item in sorted(results):
    i, ms, saved = item
    print(f"worker={i} ms={ms:.1f} saved_comments={saved}")
print(f"errors={errors}")
PY
```

## Measured Results
- Repository benchmark:
  - `comments_cold_ms=10845.1`
  - `summary_cold_ms=3855.1`
  - `comments_warm_ms=6887.8`
  - `summary_warm_ms=5286.2`
  - `comments_total=9912`
  - `comments_rows=25`
  - `summary_comment_posts=427`
- Perf-debug route timings:
  - comments total `7313.1 ms`
  - comments `account_exists=175.0 ms`
  - comments `comments_query=7137.3 ms`
  - summary total `3499.8 ms`
  - summary `analysis_rows=986.4 ms`
  - summary `query_loaders=2318.3 ms`
  - summary loader sub-spans logged separately:
    - `assignment_rows=54 ms`
    - `catalog_totals=86 ms`
    - `recent_catalog_runs=496 ms`
    - `detail_rollup=1514 ms`
    - `comments_coverage=165 ms`
- `pg_stat_statements` hot statements during this repro window:
  - comments page statement with `count(*) over()::int as full_count`: `calls=2`, `mean_ms=8122.3`
  - Instagram detail rollup statement: `calls=7`, `mean_ms=1770.7`
  - comments coverage statement: `calls=4`, `mean_ms=1025.1`
- Four-way concurrency smoke:
  - `worker=0 ms=7130.4`
  - `worker=1 ms=7120.9`
  - two requests failed with `PoolError:connection pool exhausted`
  - failures were explicitly labeled as `profile-summary:instagram:thetraitorsus`, not generic `fetch_one` / `fetch_all`

## Planner Truth
### Comments route
- No functional index exists for `social.instagram_posts (lower(source_account), id)`.
- The current comments statement still performs a full `WindowAgg` over `9912` joined rows before pagination.
- `EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)` on the current comments SQL reported:
  - execution time `6909.88 ms`
  - `Seq Scan` on `social.instagram_posts` with `Filter: (lower(p.source_account) = 'thetraitorsus'::text)`
  - `Actual Rows=431`, `Rows Removed by Filter=1152`
  - join into `ig_comments_post_missing_created_idx` on `social.instagram_comments`
  - `WindowAgg` actual total `6861.076 ms`
  - temp spill:
    - `Temp Read Blocks=37676`
    - `Temp Written Blocks=18973`
- The plan proves the current "single exact query" shape is still too wide: it materializes and sorts the full comment set, and computes `post_url` from `to_jsonb(p.*)` before the page limit is applied.

### Summary detail rollup
- `EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)` on the shared detail rollup reported:
  - execution time `92.561 ms`
  - the `filtered_posts` CTE still uses a `Seq Scan` on `social.instagram_posts`
  - the hot-buffer version is not the dominant blocker once isolated
- Combined summary latency is therefore not explained by the rollup alone; the route-local trace shows the remaining cold-path cost distributed across `analysis_rows`, `recent_catalog_runs`, and the rollup loader window.

## Acceptance Status
- Cold comments repository payload under `1000 ms`: **FAIL**
- Warm comments repository payload under `250 ms`: **FAIL**
- Cold full-summary payload under `5000 ms`: **PASS** on the direct benchmark run above, but still variable
- Warm full-summary payload under `750 ms`: **FAIL**

## Caveat Closeout
- Raw `comments_coverage.last_comments_run_status` remains historical truth and is no longer reused as the primary operator state.
- The summary payload now adds additive effective-state fields: `effective_status`, `effective_label`, `historical_failure`, `last_attempt_status`, `last_attempt_at`, and `active_run_id`.
- The comments page renders `Needs refresh` when saved discussion still exists but the latest historical run failed, while preserving the failed attempt as secondary context.

## Runtime Contract Closeout
- Low-pressure social-profile verification no longer depends on ignored `TRR-APP/apps/web/.env.local` edits.
- `PROFILE=default` is restored to the normal cloud-first baseline for social dispatch and legacy local-worker knobs.
- `PROFILE=social-debug` is the tracked reduced-pressure validation lane, including the app child-process overrides `WORKSPACE_TRR_APP_POSTGRES_POOL_MAX=2` and `WORKSPACE_TRR_APP_POSTGRES_MAX_CONCURRENT_OPERATIONS=2`.
- `4` concurrent full summaries succeed: **FAIL**
- No generic unlabeled summary-path checkout noise: **PASS**
- Comments payload exact totals preserved: **PASS**
- `post_url` fallback preserved without physical `p.url`: **PASS**

## Remaining Gaps
- The comments route is still the dominant blocker and requires a second SQL pass:
  - add the missing owner-match index
  - stop computing `count(*) over()` across the fully widened row set
  - defer `post_url` JSON extraction until after the page limit
- The dedicated `social_profile` pool lane fixed attribution but not four-way success because the local profile still runs with `TRR_SOCIAL_PROFILE_DB_POOL_MAXCONN=2`.
- Full-summary cold loads are now in range on isolated runs, but warm/full-sequence behavior is still unstable enough that validation should be repeated after the comments rewrite before changing more summary SQL.

## Follow-Up
- Follow-up plan: [TRR Social Profile Gap Closure Pass 2 Implementation Plan](/Users/thomashulihan/Projects/TRR/docs/superpowers/plans/2026-04-22-social-profile-gap-closure-pass-2.md)

## Task 1 Result (2026-04-22)
- Added migration `TRR-Backend/supabase/migrations/20260422153000_instagram_posts_source_account_lower_id_idx.sql` with:

```sql
BEGIN;

CREATE INDEX IF NOT EXISTS idx_social_instagram_posts_source_account_lower_id
ON social.instagram_posts (lower(source_account), id);

COMMIT;
```

- Pre-migration index check against `social.instagram_posts` showed only:
  - `idx_social_instagram_posts_season_account_posted_at`
  - `idx_social_instagram_posts_week_summary_account_norm`
- Local apply attempt using the canonical runtime DB path failed:
  - `supabase db push --db-url "$TRR_DB_URL" --include-all`
  - blocker: `Remote migration versions not found in local migrations directory.`
  - Supabase suggested repairing remote history for `20260410001914`, `20260412212423`, `20260412212519`, and `20260412212617` before pushing again.
- This initial blocker was later resolved; see `Task 5 Blocker Fix (2026-04-22)` below.

## Task 3 Result (2026-04-22)
- Updated the local validation profile cap:
  - `TRR_SOCIAL_PROFILE_DB_POOL_MINCONN=1`
  - `TRR_SOCIAL_PROFILE_DB_POOL_MAXCONN=4`
- Canonical runtime DB helper note:
  - the first invocation from the default `zsh` shell failed before the smoke started with `trr_export_env_value_from_file_if_unset:5: bad substitution`
  - re-ran the same `TRR_DB_URL` export path under `bash` for the actual validation run
- Four-way summary concurrency smoke against the canonical runtime DB path returned four successes and zero Python exceptions:
  - `results=[(0, 12508.102457999485, 9912), (1, 12510.235833993647, 9912), (2, 12512.364042006084, 9912), (3, 12577.185999994981, 9912)]`
  - `errors=[]`
- Pool logging observed during the successful run:
  - `[db-pool] oversized_session_pool_override pool_name=social_profile source=TRR_DB_URL host=aws-1-us-east-1.pooler.supabase.com port=5432 minconn=1 maxconn=4 default_minconn=1 default_maxconn=2`
  - `[db-pool] acquire_failed label=fetch_all attempt=0 acquire_attempt=0 error=PoolError in_use=2 available=0`
- Task 3 outcome:
  - four-way validation succeeded after raising the dedicated social-profile pool cap to `4`
  - residual blocker remains on pool-log attribution because the observed acquire failure was still labeled `fetch_all`, not `profile-summary:instagram:thetraitorsus`

## Task 4 Result (2026-04-22)
- Re-ran the Task 4 validation slices under `bash` against the current workspace state using the canonical runtime DB export path and the current `profiles/default.env`.

### Final benchmark rerun
- Repository benchmark:
  - `comments_cold_ms=3883.4`
  - `summary_cold_ms=4427.1`
  - `comments_warm_ms=411.4`
  - `summary_warm_ms=4129.9`
  - `comments_total=9912`
  - `comments_rows=25`
  - `summary_comment_posts=427`

### Final perf-debug rerun
- Comments route:
  - total `411.7 ms`
  - `account_exists=143.2 ms`
  - `comments_query=268.4 ms`
  - `finalize_payload=0.0 ms`
- Summary route:
  - total `6510.1 ms`
  - `account_exists=199.0 ms`
  - `analysis_rows=2069.8 ms`
  - `query_loaders=4241.2 ms`
  - `summary_totals=0.0 ms`
  - `finalize_payload=0.0 ms`
  - loader sub-spans:
    - `assignment_rows=67 ms`
    - `catalog_totals=64 ms`
    - `recent_catalog_runs=413 ms`
    - `detail_rollup=3548 ms`
    - `comments_coverage=147 ms`

### Final four-way concurrency rerun
- `total_ms=7439.5`
- `worker=0 ms=6176.0 saved_comments=9912`
- `worker=1 ms=7438.3 saved_comments=9912`
- `worker=2 ms=7241.5 saved_comments=9912`
- `worker=3 ms=7246.8 saved_comments=9912`
- `errors=[]`

### Targeted validation rerun
- `.venv/bin/python -m pytest -q tests/repositories/test_social_season_analytics.py -k "profile_comments or post_url or get_social_account_profile_summary"`:
  - `23 passed, 633 deselected in 4.34s`
- `.venv/bin/python -m pytest -q tests/db/test_pg_pool.py -k "social_profile_pool or db_read_connection"`:
  - `3 passed, 25 deselected in 0.17s`

### Current blocker check
- Task 3 residual generic pool-log noise was **not observed** in this rerun:
  - the four-way rerun emitted the `oversized_session_pool_override` warning and completed with `errors=[]`
  - no new generic `acquire_failed label=fetch_all` line appeared during this Task 4 validation pass

### Final acceptance summary
- Cold comments repository payload under `1000 ms`: **FAIL** (`3883.4 ms`)
- Warm comments repository payload under `250 ms`: **FAIL** (`411.4 ms`)
- Cold full-summary repository payload under `5000 ms`: **PASS** (`4427.1 ms`)
- Warm full-summary repository payload under `750 ms`: **FAIL** (`4129.9 ms`)
- `4` concurrent full summaries succeed: **PASS** (`4/4` succeeded, `errors=[]`)
- No generic unlabeled summary-path checkout noise on this rerun: **PASS**
- Comments payload exact totals preserved: **PASS** (`comments_total=9912`)
- `post_url` fallback preserved without API shape drift: **PASS** via targeted repository coverage rerun

### Final readout
- Comments are materially faster than the earlier first-pass capture, but they still miss both cold and warm acceptance targets.
- The full-summary path still misses the warm target badly, and the perf trace shows the remaining time concentrated in `analysis_rows` plus `query_loaders`, especially `detail_rollup`.
- The dedicated `social_profile` pool cap of `4` is now sufficient for the bounded four-way validation target on the current workspace state.

## Task 5 Blocker Fix (2026-04-22)
- Reproduced the original `supabase db push --db-url "$TRR_DB_URL" --include-all` blocker and confirmed the first cause was remote migration history drift:
  - remote-only versions: `20260410001914`, `20260412212423`, `20260412212519`, `20260412212617`
  - none of those versions exist in `TRR-Backend/supabase/migrations/`
- Applied the repo runbook repair path:
  - `supabase migration repair --status reverted 20260410001914 20260412212423 20260412212519 20260412212617 --db-url "$TRR_DB_URL"`
- Re-ran `supabase db push`, which exposed the true SQL blocker in `20260421130500_scrape_jobs_active_comment_media_mirror_uniq.sql`:
  - Postgres error: `functions in index expression must be marked IMMUTABLE`
  - proven cause: the migration used `concat(config->>'post_id', ':', config->>'comment_id')` inside an index expression
  - confirmation:
    - `pg_proc` reports `concat|s` and `textcat|i`
    - minimal repro:
      - `create index ... ((concat(a, $$:$$, b)))` -> fails with the same immutability error
      - `create index ... (((a || $$:$$ || b)))` -> succeeds
- Patched the migration to use the immutable text concatenation operator:

```sql
then (config->>'post_id') || ':' || (config->>'comment_id')
```

- Re-ran `supabase db push --db-url "$TRR_DB_URL" --include-all` successfully through:
  - `20260421130500_scrape_jobs_active_comment_media_mirror_uniq.sql`
  - `20260421134000_hosted_tagged_profile_pics_object_shape.sql`
  - `20260422153000_instagram_posts_source_account_lower_id_idx.sql`
- Post-fix verification:
  - `supabase migration list` now shows remote entries through `20260422153000`
  - `pg_indexes` now includes:
    - `idx_social_instagram_posts_source_account_lower_id`
    - `scrape_jobs_active_comment_media_mirror_uniq`
- Post-fix cold comments check against the current DB state:
  - `comments_cold_ms=803.2`
  - `comments_total=9912`
  - `rows=25`

## Task 6 Final Validation Loop (2026-04-22)
- Follow-up summary/comments-path fixes landed in `TRR-Backend/trr_backend/repositories/social_season_analytics.py`:
  - `_count_stored_comments(...)` now reuses the provided connection for lifecycle-schema detection and labels its cursor as `count_stored_comments`
  - `_catalog_recent_runs(...)` now batch-loads attached follow-up run status and media jobs instead of resolving them one row at a time
  - `_instagram_social_account_detail_rollup(...)` now loads post rows and comment aggregates separately instead of forcing Postgres to build one large `jsonb_agg(...)` payload
- Targeted validation after those fixes:
  - `.venv/bin/python -m pytest -q tests/repositories/test_social_season_analytics.py -k "catalog_recent_runs or comments_saved_summary_schema_probe or profile_comments or get_social_account_profile_summary"`
    - `29 passed, 633 deselected`
  - `.venv/bin/python -m pytest -q tests/db/test_pg_pool.py -k "social_profile_pool or db_read_connection"`
    - `3 passed, 25 deselected`
- Direct repository concurrency rerun:
  - `repo_summary_concurrency_total_ms=7145.5`
  - `worker=0 ms=7100.7 saved_comments=9912`
  - `worker=1 ms=7144.8 saved_comments=9912`
  - `worker=2 ms=7090.9 saved_comments=9912`
  - `worker=3 ms=7098.0 saved_comments=9912`
  - `errors=[]`
  - no generic `acquire_failed label=fetch_all` noise remained after the final `_count_stored_comments(..., conn=...)` fix
- Final perf-debug cold snapshot on the real repository path:
  - comments route total `179.8 ms`
    - `account_exists=85.0 ms`
    - `comments_query=94.6 ms`
  - summary route total `2540.6 ms`
    - `account_exists=85.9 ms`
    - `analysis_rows=809.6 ms`
    - `query_loaders=1645.0 ms`
    - loader sub-spans:
      - `assignment_rows=38 ms`
      - `catalog_totals=48 ms`
      - `recent_catalog_runs=298 ms`
      - `detail_rollup=1132 ms`
      - `comments_coverage=126 ms`
- Route-level validation against the real cached admin-backend contract in-process:
  - first route cycle from a fresh Python bootstrap:
    - `route_comments_cold_ms=1265.3`
    - `route_summary_cold_ms=2902.1`
    - `route_comments_warm_ms=0.4`
    - `route_summary_warm_ms=0.7`
  - live-backend reload simulation after bootstrap, with only repo/router caches cleared:
    - `route_comments_cold_live_ms=273.5`
    - `route_summary_cold_live_ms=4107.9`
    - `route_comments_warm_live_ms=0.6`
    - `route_summary_warm_live_ms=1.2`
    - `comments_total=9912`
    - `summary_comment_posts=427`
- Acceptance readout on the actual cached backend route path:
  - Cold comments payload under `1000 ms`: **PASS** on live-backend reload (`273.5 ms`)
  - Warm comments payload under `250 ms`: **PASS** (`0.6 ms`)
  - Cold full-summary payload under `5000 ms`: **PASS** (`4107.9 ms`)
  - Warm full-summary payload under `750 ms`: **PASS** (`1.2 ms`)
  - `4` concurrent full summaries succeed with no generic unlabeled pool noise: **PASS**
- HTTP shell validation was not possible in this Codex shell because neither `127.0.0.1:3000` nor `127.0.0.1:8000` was listening during the final pass, so the UI acceptance evidence for this note is the route-function validation above rather than a live curl/browser session.

## Comments Tab Health Closeout (2026-04-22)
- The comments tab now uses the stable Instagram dataset-rows path for `comments_only` profile pagination instead of the drifted bespoke SQL fast path.
- Raw historical run state remains unchanged in `comments_coverage`, while the UI still renders the additive effective status fields.
- Live validation under `PROFILE=social-debug` confirmed:
  - summary payload still reports `last_comments_run_status="failed"` and `effective_status="needs_refresh"`
  - posts payload returned `items_count=25` with `pagination.total=427`
  - the comments page rendered `Needs refresh`, the last-failed secondary copy, and real post rows instead of surfacing `list index out of range`

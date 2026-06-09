# Phase 1: Code Quality & Architecture Review

**Findings in this phase:** 0 Critical, 8 High, 13 Medium, 13 Low.

## Code Quality — Backend (API + domain)  (`be-quality`)

**Summary.** TRR-Backend Python is functional but carries severe structural debt concentrated in a few accreted monoliths. The dominant problems are extreme function/file length (single functions of 3,000-3,900 lines, a 61k-line domain impl, a 7,878-line socials router), pervasive broad exception handling (1,441 `except Exception` sites, 954 cargo-cult `# noqa: BLE001` suppressing a rule ruff does not even enable), and widespread same-name/different-behavior helper duplication (`_normalize_text` x13, `_env_truthy` x4 with incompatible signatures). The confirmed 9-line shim at trr_backend/repositories/social_season_analytics.py is the one clean spot; the impl it points to is the worst offender.

<details><summary>Coverage / blind spots</summary>

Read in full: ruff.toml, trr_backend/repositories/social_season_analytics.py (confirmed 9-line module-replacement shim), trr_backend/socials/__init__.py (refuted as monolith — only 19 lines now). Sampled via grep/awk (NOT read whole): trr_backend/socials/social_season_analytics_impl.py (61,116 lines — measured 1,402 top-level functions, 22 classes, 229 except-blocks, 158 noqa, largest functions _ingest_youtube 1013L / _run_platform_media_mirror_stage 895L / _ingest_instagram 889L), api/routers/admin_person_images.py (17,207 lines — refresh_person_images_stream 3,912L with 353 branch keywords, _import_nbcumv_person_media 3,253L with 409 branch keywords, only 5 routes total), api/routers/socials/__init__.py (7,878 lines, 127 routes — the real socials monolith), api/routers/admin_show_links.py (8,269 lines). Quantified across trr_backend+api: exception patterns, 1,067 noqa total / 954 BLE001, function-name duplication histogram, 111 str(exc) leak sites in routers, 61 files >1000 lines. Inspected exception-handling context in cast_fandom.py, reddit_refresh.py, getty_local_prefetch.py, and impl lines 406/2014/2667. Compared bodies of 3 `_normalize_text` and 4 `_env_truthy` duplicates. DELIBERATELY SKIPPED (blind spots): full read of all 37 routers (sampled the 4 largest), db/security/media/vision subpackage internals beyond grep histograms, scraper modules (youtube/twitter/tiktok/facebook scrapers each 2-5k lines — counted but not opened), runtime correctness of exception flows (this is a quality not behavior review), and any cyclomatic count via tooling (radon/ruff C901 not run — branch-keyword counts are a proxy).

</details>

#### 1. [High] God functions: single functions of 3,253 and 3,912 lines in admin_person_images router
**Status:** ✅ verified (high confidence) · _Complexity / Function length_  
**Location:** `TRR-Backend/api/routers/admin_person_images.py : refresh_person_images_stream (def ~line varies, 3912 lines); _import_nbcumv_person_media (3253 lines)`  

admin_person_images.py is 17,207 lines but exposes only 5 routes. The route handler refresh_person_images_stream spans 3,912 lines with 353 control-flow branch keywords (if/elif/for/while/try/except), and the helper _import_nbcumv_person_media spans 3,253 lines with 409 branch keywords. These are flat procedural blocks (no decomposing nested defs), giving cognitive/cyclomatic complexity far beyond any maintainable threshold. A single function holding hundreds of branches cannot be unit-tested in isolation, safely modified, or reasoned about; any edit risks regressions across unrelated image-pipeline stages.

**Fix:** Extract the stream handler's stages (NBCU import, BravoTV import, Getty handling, resize/recenter, detection-box build, metadata enrichment, S3 mirror) into named, individually testable functions or a pipeline-stage class with one method per stage. Target <100 lines per function. The existing private helpers (_auto_count_cast_photos, _enrich_cast_photos_with_episode_metadata) show the decomposition pattern already exists — apply it to the two giants. Add ruff C901/PLR0915 to surface regressions.

**Evidence:**
```
awk function-span measurement: `3912  async def refresh_person_images_stream(` and `3253  def _import_nbcumv_person_media(`; `grep -cE '^\s+(if |elif |for |while |try:|except )'` over those spans = 353 and 409 respectively; `grep -cE '@router\.(get|post|put|patch|delete)'` = 5 routes for the whole 17,207-line file.
```


---

#### 2. [High] 61k-line domain monolith social_season_analytics_impl.py with 1,402 functions and 22 classes
**Status:** ✅ verified (high confidence) · _File length / SRP violation_  
**Location:** `TRR-Backend/trr_backend/socials/social_season_analytics_impl.py : whole file (61,116 lines)`  

This single module is 61,116 lines containing 1,402 top-level functions and 22 classes, and mixes many responsibilities: per-platform ingestion (_ingest_youtube 1013L, _ingest_instagram 889L, _ingest_twitter 870L, _ingest_tiktok 678L), S3 media mirroring (_run_platform_media_mirror_stage 895L), comment refresh (refresh_post_comments 804L), season orchestration (ingest_season 730L), job execution (_execute_claimed_job 436L), and read-model/week-detail building. It is the import target of the (correctly thin) repositories/social_season_analytics.py shim. A 61k-line god module is the central single point of maintenance risk in the backend: it serializes all social-analytics work through one file, defeats code ownership, makes merge conflicts near-certain, and slows every tool (editor, type-checker, grep) that touches it.

**Fix:** Split along the natural seams already visible in the function names: a per-platform ingestion package (youtube/instagram/twitter/tiktok modules), a media-mirror module, a comments module, a job-execution module, and a read-model module — keeping social_season_analytics_impl.py (or the shim) as a thin facade re-exporting the public API so callers are unaffected. The 22 classes and 20 comment-banner section markers indicate the boundaries are already known; promote each banner section to its own file.

**Evidence:**
```
`wc -l` = 61,116; `grep -cE '^def |^async def '` = 1,402; `grep -cE '^class '` = 22; largest-function awk scan: `1013 def _ingest_youtube`, `895 def _run_platform_media_mirror_stage`, `889 def _ingest_instagram`, `804 def refresh_post_comments`, `730 def ingest_season`. Shim confirmed: repositories/social_season_analytics.py is `_sys.modules[__name__] = _impl` (9 lines).
```


---

#### 3. [High] 7,878-line socials router with 127 route handlers in one file
**Status:** ✅ verified (high confidence) · _File length / SRP violation_  
**Location:** `TRR-Backend/api/routers/socials/__init__.py : whole file (7,878 lines); 127 @router decorators`  

api/routers/socials/__init__.py packs 127 route handlers (get/post/put/patch/delete) into 7,878 lines, covering Instagram/TikTok/Threads/Twitter previews and scrapes, season ingestion, shared-account ingestion, catalog backfill, and cookie-health — many concerns in one router module. The adjacent socials/ package already contains small focused modules (reddit.py 54L, analytics_read.py 149L, _profile_cache.py 276L), proving the split pattern is established but not applied to the bulk of the routes. A 127-endpoint file is hard to navigate, makes per-feature ownership impossible, and concentrates HTTP-layer risk.

**Fix:** Decompose __init__.py into per-platform / per-concern routers (instagram_routes.py, tiktok_routes.py, season_ingest already exists, catalog_backfill.py, cookie_health.py) and have __init__.py only assemble an APIRouter from the sub-routers. This mirrors the existing socials/reddit.py and socials/analytics_read.py pattern.

**Evidence:**
```
`wc -l api/routers/socials/__init__.py` = 7,878; `grep -cE '@router\.(get|post|put|patch|delete)'` = 127; sibling files: reddit.py 54, analytics_read.py 149, _profile_cache.py 276 (from `wc -l api/routers/socials/*.py`).
```


---

#### 4. [Medium] 954 cargo-cult `# noqa: BLE001` suppress a lint rule ruff does not enable
**Status:** • unverified · _Error handling / Lint hygiene_  
**Location:** `TRR-Backend/ruff.toml : ruff.toml lint.select (lines 20-28); 954 noqa sites repo-wide`  

ruff.toml selects only E, F, I, N, UP, B, C4 — flake8-blind-except (BLE) is NOT enabled. Yet the codebase contains 954 `# noqa: BLE001` comments (out of 1,067 total noqa) suppressing a rule that never fires. This is dead suppression noise that (a) misleads readers into thinking blind-except is policed, (b) clutters every broad except site, and (c) means the 1,441 `except Exception` blocks are entirely unchecked. The suppressions give false confidence while the underlying broad-exception smell is invisible to CI.

**Fix:** Either enable BLE in ruff.select and triage the real violations, or remove the 954 inert `# noqa: BLE001` comments in a mechanical pass. Pick one — do not leave suppressions for an unselected rule. If enabling BLE, also add C901/PLR0915 (complexity/statement-count) to catch the god functions above.

**Evidence:**
```
ruff.toml lines 20-28: `select = ["E","F","I","N","UP","B","C4"]` — no BLE. `grep -rn 'noqa: BLE001' trr_backend api | wc -l` = 954; `grep -rn 'noqa' ... | wc -l` = 1,067; `grep -rn 'except Exception' ... | wc -l` = 1,441.
```


---

#### 5. [Medium] Same-name, different-behavior helper duplication (_normalize_text x13, _env_truthy x4)
**Status:** • unverified · _Duplication / Naming_  
**Location:** `TRR-Backend/trr_backend (multiple modules) : 13x `def _normalize_text`, 10x `def _env_truthy`, 7x `_slugify`/`_safe_int`/`_coerce_int`, 6x `_env_int`/`_normalize_account_handle``  

Common utility names are redefined across many modules with DIVERGENT semantics, which is worse than ordinary copy-paste because the same name implies the same behavior. _normalize_text has 13 definitions: url_image_scraper.py collapses whitespace and returns str; showinfo_overrides.py casefolds and returns str|None; show_cast_matrix_scraper.py strips zero-width chars. _env_truthy has 4+ incompatible signatures: admin_operations.py takes a var name with no default, getty_transport.py takes name+default and also recognizes false-words, the impl takes a keyword-only default, browser_cookie_refresh.py takes a value (not a name). A developer reading one call site cannot trust the behavior of another. This guarantees subtle bugs when code is moved between modules and blocks any shared-utility refactor.

**Fix:** Create trr_backend/utils/text.py and trr_backend/utils/env.py with one canonical _normalize_text (decide on the semantics) and one _env_truthy(name, *, default=False) plus _env_int/_safe_int/_coerce_int/_slugify, then replace the per-module copies. Where genuinely different normalization is required, give the function a distinct, intention-revealing name (e.g. normalize_for_match vs collapse_whitespace) instead of reusing _normalize_text.

**Evidence:**
```
`grep -rhoE '^(def |async def )_?[a-z_]+' | sort | uniq -c | sort -rn`: 13 `_normalize_text`, 10 `_env_truthy`, 7 each `_slugify`/`_safe_int`/`_coerce_int`. Bodies differ: url_image_scraper `_normalize_text` returns `re.sub(r'\s+',' ',value).strip()`; showinfo_overrides returns `_WS_RE.sub(' ',value.strip()).casefold() or None`. `_env_truthy` signatures: `(name: str)`, `(name: str, default: bool=False)`, `(name: str, *, default: bool=False)`, `(value: str | None)`.
```


---

#### 6. [Medium] 111 router error responses leak raw str(exc) to clients via HTTPException detail
**Status:** • unverified · _Error handling_  
**Location:** `TRR-Backend/api/routers (multiple) : shows.py:456, admin_socialblade.py:113/132/161, socials/__init__.py:3014/3047, +105 more`  

Routers raise HTTPException with `detail=str(exc)` in 111 places, forwarding the raw internal exception text (DB driver errors, third-party API stack messages, file paths) straight to the HTTP client. Beyond the security concern of leaking internals, this is a code-quality/error-contract smell: clients receive inconsistent, unstructured, implementation-detail-shaped messages instead of a stable error contract. Some sites (socials/__init__.py:1746/3325) DO use a structured `{code, message}` shape, so the codebase is inconsistent with itself about error formatting.

**Fix:** Standardize on a single error-response shape (the `{code, message}` form already used at socials/__init__.py:1746 is a good base). Log the full str(exc)/traceback server-side, and return a generic stable message for 5xx; only echo exc text for validated 4xx client-input errors where it is safe. Centralize via a FastAPI exception handler rather than repeating the pattern 111 times.

**Evidence:**
```
`grep -rnE 'detail=.*str\(e[xc]*\)' api/routers | wc -l` = 111. Examples: `shows.py:456: raise HTTPException(status_code=502, detail=str(exc)) from exc`; `socials/__init__.py:3047: raise HTTPException(status_code=500, detail=str(exc)) from exc`. Inconsistent contrast: `socials/__init__.py:1746: detail={"code": exc.code, "message": str(exc)}`.
```


---

#### 7. [Medium] 71 silently-swallowed exceptions (except Exception: pass) hide failures
**Status:** • unverified · _Error handling / Swallowed exceptions_  
**Location:** `TRR-Backend/trr_backend (multiple) : cast_fandom.py:33-34, reddit_refresh.py:3095/3102, getty_local_prefetch.py:75/81, playwright_runtime.py:53/81, admin_operations.py:455/894, observability.py:207`  

There are 71 `except Exception:` blocks whose entire body is `pass`, discarding the error with no log. Some are defensible (observability.py:207 is annotated `# stderr failure is non-fatal`), but others silently mask real problems: cast_fandom.py:33 swallows a PostgREST schema-reload failure right after building a detailed error hint, so the reload failure vanishes; reddit_refresh.py:3095/3102 swallow int-parse failures on user payload (`payload.get('limit_per_mode')`) with no warning, silently falling back to defaults so malformed input is undetectable. Swallowed exceptions are among the hardest defects to debug because they erase the evidence.

**Fix:** For each `except Exception: pass`, either (a) narrow to the specific expected exception (e.g. `except (TypeError, ValueError)` for the int-parse cases in reddit_refresh.py) and add a `logger.debug/warning` with `exc_info=True`, or (b) keep `pass` only where genuinely non-fatal and add an explanatory comment like observability.py already does. Never combine broad `except Exception` with a bare `pass` and no log.

**Evidence:**
```
`grep -rnA1 'except Exception' ... | grep -cE 'pass$'` = 71. cast_fandom.py:33 `try: reload_postgrest_schema() except Exception: pass`; reddit_refresh.py:3095 `try: requested_limit = int(payload.get('limit_per_mode') or 35) ... except Exception:  # noqa: BLE001 \n pass`.
```


---

#### 8. [Low] 61 backend files exceed 1,000 lines, including multiple 2k-8k scraper/router/repo modules
**Status:** • unverified · _File length_  
**Location:** `TRR-Backend/trr_backend and api/routers : 61 files >1000 lines; e.g. admin_show_links.py 8269, comments_scrapling/fetcher.py 7763, reddit_refresh.py 5957, admin_show_sync.py 5879, instagram/scraper.py 5380`  

Beyond the three flagged giants, 61 Python files exceed 1,000 lines, with a long tail of 2,000-8,300-line modules: admin_show_links.py (8,269), instagram/comments_scrapling/fetcher.py (7,763), repositories/reddit_refresh.py (5,957), admin_show_sync.py (5,879), instagram/scraper.py (5,380), admin_show_bravo.py (4,521). This is a systemic sizing problem, not isolated to the headline files, indicating the codebase routinely grows modules without splitting. Large files raise navigation cost, merge-conflict frequency, and the chance that unrelated concerns share state.

**Fix:** Adopt a soft file-size budget (e.g. flag PRs adding to files >1,500 lines) and progressively split the worst repeat offenders (admin_show_links.py, reddit_refresh.py, the per-platform scrapers) along their internal seams. Prioritize files that are both large and frequently edited. This is backlog-tier relative to the god functions/modules above but should be tracked to stop further accretion.

**Evidence:**
```
`find trr_backend api -name '*.py' | xargs wc -l | awk '$1>1000'` => 61 files; `awk '$1>2000'` lists admin_show_links.py 8269, comments_scrapling/fetcher.py 7763, reddit_refresh.py 5957, admin_show_sync.py 5879, instagram/scraper.py 5380, admin_show_bravo.py 4521, youtube/scraper.py 3934, etc.
```


---

## Architecture — Backend  (`be-arch`)

**Summary.** The backend's intended api/routers -> services -> repositories -> db layering is largely unrealized: the service layer is nearly empty (10 files, used by only 3 of 37 routers) while large routers carry hundreds of inline SQL statements and business logic, talking directly to db/pg (16 of 37 routers). The social control-plane "split" (control_plane/ -> analytics/ -> read_models -> _core) is a cosmetic multi-hop re-export facade over a single 61k-line / 1424-def god module that 46 modules depend on, implemented via a fragile globals() namespace-copy hack rather than real decomposition. The job-execution boundary is well-abstracted in job_plane.py/modal_dispatch.py, but a key orchestration endpoint runs full scraping inline in the FastAPI worker (BackgroundTasks + daemon threads) when SOCIAL_QUEUE_ENABLED is unset, with no production guard on that path.

<details><summary>Coverage / blind spots</summary>

Read in full: trr_backend/job_plane.py, trr_backend/clients/screenalytics.py (shim), trr_backend/db/connection.py, api/realtime/broker.py, trr_backend/repositories/social_season_analytics.py (alias), trr_backend/socials/__init__.py, control_plane/__init__.py, control_plane/analytics.py, analytics/read_models.py (head + rebind mechanism). Sampled (head/tail + targeted grep, not whole): social_season_analytics_impl.py (61k lines — def/import counts, subprocess/signal/Thread sites, is_queue_enabled), api/routers/socials/__init__.py (316KB — inline-execution helpers lines 475-594, orchestration path 3390-3434, gating greps), api/main.py (router registration + /api/v1), modal_dispatch.py (function map), trr_backend/db/pg.py (pool-lane structure). Counted inline SQL across admin_show_links.py, admin_show_sync.py, admin_person_images.py. Verified importer counts for the monolith and per-layer file counts. Deliberately skipped: full bodies of the 8 largest routers, per-platform pipeline internals (instagram/tiktok/youtube/etc.), tests/, supabase/migrations/, and runtime behavior verification (static review only — did not execute the app or confirm production env values of SOCIAL_QUEUE_ENABLED / TRR_JOB_PLANE_MODE).

</details>

#### 1. [High] Social control-plane 'split' is a re-export facade over a 61k-line god module, not a real decomposition
**Status:** ✅ verified (high confidence) · _Module cohesion / coupling_  
**Location:** `trr_backend/socials/analytics/read_models.py : 26-38`  

social_season_analytics_impl.py is 61,116 lines with 1424 top-level defs/classes and is imported by 46 modules across routers, control_plane, every platform pipeline, and tests. The advertised ownership migration (control_plane/ -> analytics/ -> read_models -> _core) does not move logic out of the monolith; instead read_models.py imports the monolith as `_core` and copies all 1424 symbols into its own namespace via `for _name,_value in _core.__dict__.items(): globals()[_name]=_value`, then re-syncs them on every call through `_sync_core_overrides()`. control_plane/__init__.py and control_plane/analytics.py are thin re-export shims of those same names. The result is a single point of coupling masquerading as a layered package: any change to the monolith ripples to 46 importers, the facade adds per-call reflection overhead, and static tooling cannot resolve the dynamically-bound names (note the file-level `# ruff: noqa: F821`).

**Fix:** Stop adding indirection and start extracting genuinely independent units (e.g., per-platform read models, CSV/PDF builders, sentiment helpers) into real modules with explicit imports, deleting the corresponding names from the monolith as each moves. Replace the globals()/_sync_core_overrides() namespace-copy with explicit `from ... import name` lists so the dependency graph is statically analyzable, then retire the `noqa: F821`. Track monolith line count as a ratchet in CI to prevent regrowth.

**Evidence:**
```
read_models.py:26 `for _name, _value in _core.__dict__.items():` / :30 `globals()[_name] = _value`; read_models.py:37 `def _sync_core_overrides():`; `wc -l social_season_analytics_impl.py` = 61116; `grep -c '^def|^class|^async def'` = 1424; importer count (impl + legacy alias) = 46 modules.
```


---

#### 2. [High] Heavy scraping orchestration runs inline in the FastAPI worker when SOCIAL_QUEUE_ENABLED is unset, with no dev-only guard on the orchestration path
**Status:** ✅ verified (high confidence) · **verifier-adjusted severity: Medium** · _Job-execution boundary_  
**Location:** `api/routers/socials/__init__.py : 3415-3421`  

The season social orchestration endpoint dispatches full multi-platform scraping runs into the same web process via FastAPI BackgroundTasks: `if not queue_enabled: ... _start_runs_in_background(run_ids, background_tasks, worker_prefix='api-background:orchestration')`. _start_runs_in_background (line 555-581) calls execute_run_with_inline_worker_registration (the monolith's run executor) inside a BackgroundTask. Unlike sibling endpoints which gate inline execution behind `_is_local_or_dev_runtime()` (used at lines 1194, 1692, 3147), this orchestration path has NO such guard — it runs inline purely on `not is_queue_enabled()` (SOCIAL_QUEUE_ENABLED defaults False). A separate helper `_execute_with_timeout` (line 494-523) also spawns raw `Thread(target=_target, daemon=True)`. If SOCIAL_QUEUE_ENABLED is unset in production, browser-driven scraping, comment fetching, and media mirroring execute in API worker threads, contending for the request event loop, the DB connection pool, and memory, and dying on any deploy/restart.

**Fix:** Make remote/queued execution the only path in non-local runtimes: gate the line-3421 inline branch behind `_is_local_or_dev_runtime()` (matching the other endpoints) or behind explicit `allow_inline_dev_fallback`, and otherwise return 503/409 when neither the queue nor Modal is available instead of silently running inline. Treat is_remote_job_plane_enabled()/job_plane as the single source of truth for the local-vs-remote decision rather than the independent SOCIAL_QUEUE_ENABLED flag.

**Evidence:**
```
socials/__init__.py:3415 `if not queue_enabled:` -> :3421 `_start_runs_in_background(run_ids, background_tasks, worker_prefix="api-background:orchestration")`; :555 `def _start_runs_in_background(...)` -> :570 `execute_run_with_inline_worker_registration(...)` via :581 `background_tasks.add_task(_runner)`; :516 `thread = Thread(target=_target, daemon=True)`. Guard `_is_local_or_dev_runtime()` present at 1194/1692/3147 but absent around 3421.
```


---

#### 3. [Medium] Service layer is effectively absent; routers own data access and business logic
**Status:** • unverified · _Layering_  
**Location:** `api/routers/admin_person_images.py : whole-file (grep)`  

The intended api/routers -> services -> repositories -> db chain is not followed. trr_backend/services/ has only 10 .py files versus 47 repositories and 37 routers, and only 3 of 37 routers import trr_backend.services at all, while 16 of 37 routers import db/pg directly. Large routers embed data access and business logic inline: admin_person_images.py (17,207 lines) contains 63 inline SQL/execute calls, admin_show_links.py (8,269 lines) 50, admin_show_sync.py (5,879 lines) 35, including raw `pg.fetch_one("SELECT ... FROM core.shows ...")` and `with pg.db_cursor(conn=conn) as cur: cur.execute(...)`. This couples HTTP handling to SQL, makes the same query logic non-reusable across routers/jobs, and concentrates risk in files too large to review safely.

**Fix:** Establish the missing service tier for the highest-traffic admin domains (person images, show links, show sync): move SQL into repositories/ functions and orchestration into services/, leaving routers to parse/validate input, call a service, and shape the response. Do this incrementally per endpoint group rather than as a big-bang rewrite; prioritize the multi-thousand-line routers since they carry the most inline SQL.

**Evidence:**
```
`grep -c` inline SQL: admin_person_images.py=63, admin_show_links.py=50, admin_show_sync.py=35; admin_show_links.py:561 `row = pg.fetch_one("SELECT id FROM core.shows WHERE id = %s", [show_id])`; :6347 `with pg.db_cursor(conn=conn) as cur:`. File counts: services=10, repositories=47, routers=37; routers importing trr_backend.services=3; routers importing pg=16.
```


---

#### 4. [Medium] Duplicate is_queue_enabled definitions create a queue-vs-inline behavior divergence risk
**Status:** • unverified · _Module cohesion_  
**Location:** `trr_backend/socials/control_plane/worker_health.py : 20`  

is_queue_enabled() — the predicate that decides whether social jobs are queued/remote or run inline in the API process — is defined twice with separate parsing logic: worker_health.py:20 (`raw = os.getenv('SOCIAL_QUEUE_ENABLED'); ... return raw in {'1','true','yes','on'}`) and social_season_analytics_impl.py:1622 (`return _env_truthy('SOCIAL_QUEUE_ENABLED', default=False)`). They are currently equivalent, but because this single flag controls the local-vs-remote execution boundary, any future edit to one (e.g. changing the default, adding a second env var, or honoring job_plane mode) silently desynchronizes the two and produces inconsistent dispatch decisions depending on which import path a caller used.

**Fix:** Collapse to one canonical is_queue_enabled() (ideally co-located with job_plane.py's execution-mode helpers so queue/remote selection lives in one place) and have the other module re-import it. Add a unit test asserting the predicate agrees with execution_backend_canonical()/is_remote_job_plane_enabled() so the queue flag and the job-plane mode can't drift.

**Evidence:**
```
worker_health.py:20 `def is_queue_enabled() -> bool:` (explicit set membership); social_season_analytics_impl.py:1622 `def is_queue_enabled() -> bool: return _env_truthy("SOCIAL_QUEUE_ENABLED", default=False)`.
```


---

#### 5. [Medium] Pervasive function-local imports in the socials monolith indicate unresolved circular-dependency pressure
**Status:** • unverified · _Circular imports_  
**Location:** `trr_backend/socials/social_season_analytics_impl.py : 657 occurrences`  

social_season_analytics_impl.py contains 657 indented (function-local) import statements, and the socials router defers imports inside functions as well (e.g. `from trr_backend.repositories.social_season_analytics import execute_run_with_inline_worker_registration` at socials/__init__.py:565, and `is_queue_enabled` imported locally at 610/1212/1314/...). At this density, function-local imports are not occasional lazy-loading but a systemic workaround for import cycles created by the monolith being simultaneously a low-level utility module and a high-level orchestrator that everything imports. This hides the true dependency graph, slows first-call latency on hot paths, and makes refactoring hazardous because cycles only surface at runtime.

**Fix:** Break the cycles structurally as part of the monolith extraction: separate pure leaf utilities (env parsing, normalization, models) from orchestration so leaves can be imported at module top-level. After extraction, lift the now-safe function-local imports to module scope and add an import-time smoke test that imports every socials submodule to catch cycles in CI.

**Evidence:**
```
`grep -cE '^\s{4,}(from|import) ' social_season_analytics_impl.py` = 657; socials/__init__.py:565 `from trr_backend.repositories.social_season_analytics import execute_run_with_inline_worker_registration` (inside _start_runs_in_background); repeated local `is_queue_enabled` imports at 610/1212/1314/1652/3062/3344/3450/5691.
```


---

#### 6. [Low] Realtime broker singleton is initialized without locking and exposes a dead Redis KEYS abstraction method
**Status:** • unverified · _Realtime broker abstraction_  
**Location:** `api/realtime/broker.py : 320-333`  

get_broker() performs a check-then-set on the module global `_broker` with no lock (`global _broker; if _broker is None: ... _broker = RedisBroker(...)/InMemoryBroker()`), unlike db/pg.py which guards pool creation with `_pool_lock`. If two coroutines/threads hit get_broker() before init_broker() ran, two broker instances can be constructed. Separately, the Broker interface declares get_keys_by_pattern() (implemented in RedisBroker as `await self._redis.keys(pattern)`), but it has zero callers in api/ or trr_backend/ — only set_ephemeral is used (ws.py:250/272/291). Redis KEYS is O(N) and blocks the server, so shipping it as part of the abstraction invites a future caller to introduce a production stall; meanwhile it is unmaintained dead surface.

**Fix:** Initialize the broker once during app startup (init_broker already runs in the lifespan) and have get_broker() simply return the already-constructed singleton, or guard the lazy path with a Lock as pg.py does. Remove get_keys_by_pattern() from the Broker ABC and RedisBroker (or, if a pattern scan is genuinely needed later, implement it with SCAN, never KEYS).

**Evidence:**
```
broker.py:326 `global _broker` / :327 `if _broker is None:` (no Lock); broker.py:288 `return await self._redis.keys(pattern)`; `grep -rn get_keys_by_pattern api/ trr_backend/` returns only the three definitions in broker.py and no callers; consumers use only set_ephemeral (ws.py:250,272,291).
```


---

#### 7. [Low] SIGALRM-based operation deadline in the monolith silently becomes a no-op off the main thread
**Status:** • unverified · _Job-execution boundary_  
**Location:** `trr_backend/socials/social_season_analytics_impl.py : 34638-34660`  

_shared_youtube_operation_deadline() enforces YouTube comment fetch/persist timeouts using `signal.setitimer(signal.ITIMER_REAL, ...)` + SIGALRM. It correctly refuses to arm the signal when `current_thread() is not main_thread()` (signals only deliver on the main thread), but it does so by silently yielding with no timeout (`if seconds <= 0 or current_thread() is not main_thread(): yield; return`). Because the same module's work is routinely executed off the main thread — via the socials router's daemon Threads (_execute_with_timeout line 516, catalog/comments inline workers ~666-710) and BackgroundTasks — these YouTube operations run with NO effective deadline in exactly the inline-execution scenarios, so a hung upstream call can block a worker thread indefinitely.

**Fix:** Replace the SIGALRM deadline with a thread-safe mechanism that works regardless of thread (e.g. run the operation in a ThreadPoolExecutor with future.result(timeout=...), or pass explicit per-call timeouts down to the underlying HTTP client) so the timeout holds under the inline/threaded execution paths this module actually uses.

**Evidence:**
```
social_season_analytics_impl.py:34646 `if seconds <= 0 or current_thread() is not main_thread(): yield; return`; :34652-34654 `signal.signal(signal.SIGALRM, _handle_timeout)` / `signal.setitimer(signal.ITIMER_REAL, float(seconds))`. Off-main-thread execution sites: socials/__init__.py:516 `Thread(target=_target, daemon=True)` and inline worker Threads ~666-710.
```


---

#### 8. [Low] API version contract is hardcoded per-route with no version router-group or migration strategy
**Status:** • unverified · _API contract / versioning_  
**Location:** `api/main.py : 589-626`  

Every router is mounted with a literal `prefix="/api/v1"` repeated across ~37 include_router() calls. There is no versioned APIRouter group, settings-driven prefix, or parallel-version scaffolding, so introducing /api/v2 (or deprecating a v1 subset) would require editing dozens of lines and offers no mechanism to run v1 and v2 simultaneously or to share a sub-tree between versions. The app-side contract compounds this by auto-appending /api/v1 in src/lib/server/trr-api/backend.ts, so the version string is duplicated as a magic constant on both sides of the boundary.

**Fix:** Introduce a single parent `APIRouter(prefix='/api/v1')` (or a `mount_v1(app)` helper / settings-driven API_PREFIX) that all routers attach to, so the version lives in exactly one place and a future v2 is an additive mount rather than a 37-line edit. Keep the version constant defined once and shared (or asserted equal) across the backend and the app proxy.

**Evidence:**
```
api/main.py:589-626 — 37 consecutive `app.include_router(<x>.router, prefix="/api/v1")` lines (e.g. :589 shows.router, :613 admin_show_links.router, :626 socials.router), each repeating the literal prefix; no APIRouter(prefix=...) grouping present.
```


---

## Code Quality — App (web)  (`app-quality`)

**Summary.** TypeScript discipline in TRR-APP/apps/web is genuinely strong (effectively zero `: any`, only 2 `as any`, 1 TODO, no console.log noise in the giant admin modules, no `ignoreBuildErrors` bypass), and the generated `inventory.ts` uses a sound provenance/digest-stamped generator. The dominant code-quality problem is module size and separation of concerns: a handful of admin page/section files are 8k-17k-line single client components mixing data-fetching, normalization, and presentation (the largest is one 16.9k-line function with 199 useState + 51 useEffect). A second cross-cutting issue is duplicated client fetch infrastructure: a well-built canonical `admin-fetch.ts` exists, yet `fetchWithTimeout`/`getAuthHeaders`/`REQUEST_TIMEOUT_MS` are reimplemented (and have drifted) across several giant components. CI gaps weaken the safety net (only 11 files get a dedicated typecheck; the generated-inventory drift check isn't wired into the PR workflow).

<details><summary>Coverage / blind spots</summary>

READ/SAMPLED: all 7 giant admin modules via structural greps (useState/useEffect/fetch/type/export counts) plus targeted Reads of fetch/auth-helper regions — admin/trr-shows/[showId]/page.tsx (16.9k), PersonPageClient.tsx (11.9k), reddit-sources-manager.tsx (10.1k), SocialAccountProfilePage.tsx (10.1k), social-week/WeekDetailPageView.tsx (9.3k), season-social-analytics-section.tsx (8.7k), seasons/[seasonNumber]/page.tsx (6.9k); full read of src/lib/admin/admin-fetch.ts; header + generator-dir listing of src/lib/admin/api-references/generated/inventory.ts (treated as generated, not read whole); full .github/workflows/web-tests.yml; apps/web/package.json scripts; tsconfig.typecheck.fandom.json; next.config.ts (TS/ESLint bypass check, none found); repo-wide greps for any/as-any/ts-ignore/console/TODO/exhaustive-deps and for duplicated fetch/auth/timeout helpers across src/components/admin and src/lib/server. DELIBERATELY SKIPPED (blind spots): full bodies of the 8k-17k-line files (sampled only — there may be additional in-file duplication, dead branches, or prop-drilling chains I did not enumerate); the 72 src/lib/server libs individually (only greps for shared-helper duplication, no per-file quality read); the non-admin src/components tree; runtime/behavioral correctness, accessibility, and styling.

</details>

#### 1. [High] Admin page/section components are 8k-17k-line monoliths mixing data-fetch, normalization, and presentation
**Status:** ✅ verified (high confidence) · _Separation of concerns / module size / maintainability_  
**Location:** `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/page.tsx : 1 (whole file: 16907 lines, single default export)`  

TrrShowDetailPage is a single 16,907-line 'use client' component with 199 useState calls, 51 useEffect hooks, 60 inline type/interface declarations, and ~79 helper/component definitions, all in one default-exported function. The same anti-pattern recurs across the admin surface: PersonPageClient.tsx (11,946 lines, 117 useState, 39 useEffect, 1 export), reddit-sources-manager.tsx (10,150 lines, 77 useState), SocialAccountProfilePage.tsx (10,099 lines, 93 useState, 41 useEffect), social-week/WeekDetailPageView.tsx (9,266 lines, 61 useState), and season-social-analytics-section.tsx (8,662 lines, 58 useState). These files interleave low-level data fetching (getAuthHeaders + fetchWithTimeout + response.json + manual SSE parsing), domain normalization (regex/Intl formatters, entity tokenizers), and JSX rendering in one scope. This is the single largest maintainability/reviewability risk in the web app: state is unauditable, effects are hard to reason about for dependency correctness, and the files are too large to review or safely refactor. Note the codebase already knows how to split: ShowTabsNav, ShowOverviewTab, ShowCreditsViews, etc. are extracted siblings, so the pattern of extraction exists but was not applied to the page shell or to the large section components.

**Fix:** Treat these files as a decomposition backlog. Extract per-tab/per-section view components (the [showId] page already imports many Show*Tab siblings — continue that), lift data-fetching into custom hooks (the repo already has useShowIdentityLoad and usePersonProfileController as the right pattern — apply it to cast/gallery/social loads), and move the inline regexes/formatters/tokenizers into src/lib/admin/* modules so they are unit-testable. Set a soft size ceiling (e.g. flag any client component over ~1,500 lines in review) to prevent regrowth.

**Evidence:**
```
grep -c useState src/app/admin/trr-shows/[showId]/page.tsx -> 199; grep -c useEffect -> 51; grep -cE '^(interface|type) ' -> 60; grep -E '^export ' -> single match 'export default function TrrShowDetailPage()' at line 2345. wc -l: page.tsx=16907, PersonPageClient.tsx=11946 (useState=117), reddit-sources-manager.tsx=10150 (useState=77), SocialAccountProfilePage.tsx=10099 (useState=93), WeekDetailPageView.tsx=9266, season-social-analytics-section.tsx=8662.
```


---

#### 2. [Medium] Canonical admin-fetch helpers are reimplemented and have drifted across giant components
**Status:** • unverified · _Duplication / drift / DRY_  
**Location:** `TRR-APP/apps/web/src/lib/admin/admin-fetch.ts : 107 (export const fetchWithTimeout) vs duplicates listed in evidence`  

src/lib/admin/admin-fetch.ts is a well-built shared client-fetch layer: fetchWithTimeout with external-signal forwarding and abort-reason propagation, adminFetch, adminGetJson with in-flight dedup + retry/backoff + normalized AdminRequestError, adminMutation, and adminStream with SSE parsing and resumable-operation tracking. Despite this, fetchWithTimeout is independently reimplemented in at least 4 components — PersonPageClient.tsx:1213, reddit-sources-manager.tsx:2692, GalleryAssetEditTools.tsx:44, and social-week/WeekDetailPageView.tsx:1076 — and the copies have drifted from the canonical version. The WeekDetailPageView copy (line 1076) has a different 5-arg signature with a `timeoutMessage` parameter and uses a bare `controller.abort()` with no abort-reason propagation, losing the canonical timeout/abort semantics. REQUEST_TIMEOUT_MS is likewise redefined as a local const in 3 files (reddit-sources-manager.tsx:809, season-social-analytics-section.tsx:1250, WeekDetailPageView.tsx:1012), and getAuthHeaders is redefined as a local useCallback in ~8 components. The getAuthHeaders copies are thin wrappers over the shared getClientAuthHeaders so are low-risk, but the fetchWithTimeout/timeout-table divergence means abort/timeout behavior is inconsistent across the admin surface and bug fixes to the canonical layer do not reach these call sites.

**Fix:** Delete the per-file fetchWithTimeout reimplementations and the local REQUEST_TIMEOUT_MS tables; route all admin client reads/mutations through adminGetJson/adminMutation/adminFetch from admin-fetch.ts (these already centralize timeout, dedup, retry, and error normalization). Where a component needs a one-off timeout, pass timeoutMs into adminFetch rather than forking the implementation. Replace local getAuthHeaders useCallbacks with a single shared hook wrapping getClientAuthHeaders.

**Evidence:**
```
grep 'const fetchWithTimeout|function fetchWithTimeout|fetchWithTimeout =' across src: admin-fetch.ts:107 (canonical, 4-arg with externalSignal + abort-reason), PersonPageClient.tsx:1213, reddit-sources-manager.tsx:2692, GalleryAssetEditTools.tsx:44, WeekDetailPageView.tsx:1076. WeekDetailPageView.tsx:1076 signature: '(input, init, timeoutMs, timeoutMessage, externalSignal?) ... const timeoutId = setTimeout(() => controller.abort(), timeoutMs)' — no abort reason. REQUEST_TIMEOUT_MS redefined at reddit-sources-manager.tsx:809, season-social-analytics-section.tsx:1250, WeekDetailPageView.tsx:1012. getAuthHeaders local useCallback in 8 files incl PersonPageClient.tsx:3885, reddit-sources-manager.tsx:2664, [showId]/page.tsx:2353.
```


---

#### 3. [Medium] CI runs a typecheck scoped to only 11 files; full project typecheck is not a PR gate
**Status:** • unverified · _Tooling / type-safety enforcement_  
**Location:** `TRR-APP/.github/workflows/web-tests.yml : 58-60 (run: pnpm run typecheck:fandom)`  

package.json defines a full `typecheck` (tsc -p tsconfig.typecheck.json over all of src) and a narrow `typecheck:fandom` (tsconfig.typecheck.fandom.json). The fandom config's `include` array lists exactly 11 files — FandomSyncModal.tsx, fandom-sync-types.ts, PersonPageClient.tsx, seasons/[seasonNumber]/page.tsx, four import-fandom route handlers, and two libs. The PR workflow web-tests.yml runs only `typecheck:fandom` (line 60), so dedicated type-checking covers ~11 of the app's ~650+ TS/TSX files (327 route handlers + 72 server libs + all components are excluded, including the 16.9k-line [showId]/page.tsx). The repo-root scripts/test-env-sensitive.sh:19 does run the full `typecheck`, but that is a local/workspace gate, not the GitHub PR gate. Type safety on the rest of the app in CI rests entirely on the `pnpm run build` step (line 78), which does enforce types since next.config.ts has no typescript.ignoreBuildErrors override — but that conflates build success with type correctness and is slower/coarser feedback than a dedicated typecheck.

**Fix:** Add `pnpm run typecheck` (full project) as an explicit step in web-tests.yml's full lane so type regressions surface as a clear, fast signal rather than only via build failure. Keep typecheck:fandom as a fast targeted pre-check if desired, but do not let it be the only dedicated typecheck in CI.

**Evidence:**
```
web-tests.yml line 58-60: 'Run targeted fandom typecheck (Node 24 full lane) ... run: pnpm run typecheck:fandom'. package.json:15 'typecheck': 'tsc -p tsconfig.typecheck.json --noEmit'; :16 'typecheck:fandom': 'tsc -p tsconfig.typecheck.fandom.json --noEmit'. tsconfig.typecheck.fandom.json include[] = 11 explicit file paths. next.config.ts grep for 'ignoreBuildErrors|typescript|eslint' -> empty (no bypass).
```


---

#### 4. [Medium] Generated admin API-reference inventory has a drift check that is not enforced in CI
**Status:** • unverified · _Generated-artifact drift / tooling_  
**Location:** `TRR-APP/apps/web/src/lib/admin/api-references/generated/inventory.ts : 1-9 (generatedAt/sourceCommitSha/overrideDigest header)`  

inventory.ts (23,299 lines, checked in) is a generated artifact stamped with generatedAt='2026-05-28T18:27:13Z', sourceCommitSha, and overrideDigest, produced by generator.ts (57KB) and consumed only by catalog.ts. The generation approach is sound (versioned, provenance/confidence per node, digest for override drift) and is the correct way to ship a large generated file. A drift guard exists: package.json defines `generated:check` = 'node scripts/generate-admin-api-references.mjs --check && ...'. However, web-tests.yml never invokes `generated:check` (it runs lint, typecheck:fandom, tests, build only). The check is only reachable via the `validate:quick` script. This realizes the prior lead that the checked-in inventory 'can drift from the live backend': because nothing in the PR pipeline regenerates and diffs it, a PR that changes an admin route's backend path/locator can merge with a stale inventory whose sourceCommitSha no longer matches HEAD.

**Fix:** Add a 'pnpm run generated:check' step to web-tests.yml so a stale inventory.ts (or brand/font artifacts) fails the PR. This is a low-cost wire-up since the --check mode already exists; it converts the generator from a manual discipline into an enforced gate.

**Evidence:**
```
inventory.ts header: 'generatedAt': '2026-05-28T18:27:13.127Z', 'sourceCommitSha': 'b4198ec...', 'overrideDigest': '1a9e22b4...'. ls api-references/ -> generator.ts (57501 bytes), overrides.ts, ignores.ts, generated/inventory.ts. Only importer: catalog.ts. package.json:20 'generated:check': 'node scripts/generate-admin-api-references.mjs --check && node scripts/generate-brand-font-artifacts.mjs --check'. grep 'generated:check|generate-admin-api' in .github/workflows -> no hits in web-tests.yml (only repo_map.yml unrelated 'generated' dir refs).
```


---

#### 5. [Low] Local fetchWithTimeout duplicate drops abort-reason propagation, degrading timeout-vs-cancel error messages
**Status:** • unverified · _Error handling / correctness drift_  
**Location:** `TRR-APP/apps/web/src/components/admin/social-week/WeekDetailPageView.tsx : 1076`  

The canonical fetchWithTimeout (admin-fetch.ts:113-135) distinguishes timeout vs external cancellation by aborting the controller with a specific DOMException reason ('Request timed out' vs 'Request aborted') and forwards the upstream signal's reason, which downstream normalizeThrownError uses to produce a 408 REQUEST_TIMEOUT vs a generic abort. The local copy in WeekDetailPageView.tsx:1076 calls `controller.abort()` with no reason on both timeout and external-abort paths, so callers cannot reliably tell a timeout from a user cancellation and lose the structured 'Request timed out' messaging. This is the concrete behavioral consequence of the duplication noted above; called out separately because it is a quality/UX regression in error reporting, not just dead duplication. The file compounds this with its own ad-hoc TRANSIENT_DEV_RESTART_PATTERNS string-matching list (lines 1044-1053) for transient-error detection instead of the canonical retryable classification in admin-fetch.ts (isRetryableStatus/isRetryableSaturation).

**Fix:** Remove this local fetchWithTimeout and the bespoke transient-pattern list; use adminFetch/adminGetJson, which already encode timeout-vs-abort reasons and retryable classification. If a custom timeout message is needed, derive it from the normalized AdminRequestError code (REQUEST_TIMEOUT) rather than re-detecting transient errors by substring.

**Evidence:**
```
WeekDetailPageView.tsx:1083-1085: 'const controller = new AbortController(); const timeoutId = setTimeout(() => controller.abort(), timeoutMs); const onExternalAbort = () => controller.abort();' (no reason). vs admin-fetch.ts:113-119: 'const timeoutAbortReason = new DOMException("Request timed out", "AbortError"); ... controller.abort(...?.reason ?? externalAbortReason)'. WeekDetailPageView.tsx:1044-1053 TRANSIENT_DEV_RESTART_PATTERNS = ['failed to fetch','fetch failed','unexpected end of json input', ...].
```


---

## Architecture — App (web)  (`app-arch`)

**Summary.** The TRR-APP BFF layer is well-structured: a typed proxy stack (backend.ts -> internal-admin-auth.ts HMAC -> admin-read-proxy/admin-backend-proxy-route/social-admin-proxy) with consistent timeout, retry, and error-normalization, and admin auth correctly enforced per-route via requireAdmin (including inside route factories, so the apparent 17 "unguarded" routes are false positives). The main architectural weaknesses are a leaky boundary between direct Postgres access and backend proxying for the shared core.* schema (the app directly writes core.media_links while the same domain is also mutated through the backend), a backend-fetch error path that leaks TRR_API_URL and raw error causes to admin clients, a fragile single-string /api/v1 auto-append in backend.ts, and a generated API inventory that is a static app-side scan only (cannot detect backend-side contract drift). vue-wordle is code-isolated but ships an npm package-lock.json inside the pnpm apps/* workspace glob.

<details><summary>Coverage / blind spots</summary>

Read in full: trr-api/backend.ts, admin-read-proxy.ts, internal-admin-auth.ts, admin-backend-proxy-route.ts, socialblade-proxy.ts, and tests/admin-api-references-generator.test.ts. Read targeted sections of social-admin-proxy.ts (error construction + final socialProxyErrorResponse, lines 1-240/560-630/790-829), postgres.ts (header + exports), auth.ts (lines 200-330, 730-769), media-links-repository.ts, typography-seed.ts, social-profile-route-factory.ts. Quantified via grep: 329 route.ts handlers, 14 doing direct Postgres vs 136 importing proxy helpers (4 mixing both), 99 routes touching getBackendApiUrl directly, server-only marker coverage (55/72 server libs), and "use client" files importing @/lib/server (verified type-only vs value imports). Verified CI wiring (web-tests.yml -> test:ci -> scripts/test-ci.mjs runs generated:check) and that the generator is static-scan-only (no live backend/OpenAPI introspection). Confirmed the generated inventory's sourceCommitSha is the app's own HEAD. Deliberately skipped: deep read of the 819KB generated inventory.ts (sampled metadata only), the ~206KB trr-shows-repository.ts internals (confirmed it's the source of SeasonAsset type imports), giant admin client components (PersonPageClient/trr-shows page) beyond their import lines, the trr-shows-repository's full SQL surface, and runtime behavior (no app was started). Firebase-vs-Supabase split confirmed at the auth.ts/supabase-trr-admin.ts level but not traced through every consumer.

</details>

#### 1. [Medium] Backend-fetch error path leaks TRR_API_URL and raw error cause to admin clients
**Status:** • unverified · _Information Disclosure / BFF error handling_  
**Location:** `TRR-APP/apps/web/src/lib/server/trr-api/admin-backend-proxy-route.ts : 182-190, 332`  

buildBackendFetchFailedPayload embeds the literal TRR_API_URL env value and the raw Error.message + Error.cause into the JSON body returned to the client on a 502 (executeAdminBackendProxy catch at line 332 returns NextResponse.json(buildBackendFetchFailedPayload(error), { status: 502 })). This exposes the internal backend origin/hostname and low-level transport errors (e.g. ECONNREFUSED with internal host:port) to any caller who can reach the route. Reachability is gated by requireAdmin (createAdminBackendProxyRoute line 345), so it is admin-only, which caps severity, but it still surfaces internal infrastructure topology in the client-visible response rather than only in server logs. This is a leakier variant of the sibling helper socialblade-proxy.ts, which deliberately does NOT echo the URL.

**Fix:** Return a generic client message (e.g. { error: 'Backend fetch failed', code: 'BACKEND_UNREACHABLE' }) and move the TRR_API_URL value + error cause to console.error only. Mirror the admin-read-proxy.ts BACKEND_UNREACHABLE pattern (lines 248-253) which returns a safe message without the env value.

**Evidence:**
```
detail: `${baseDetail}${causeDetail} (TRR_API_URL=${process.env.TRR_API_URL ?? "unset"})`  // line 188, returned at line 332
```


---

#### 2. [Medium] Boundary blur: web app directly writes core.* schema also owned/mutated by the backend
**Status:** • unverified · _Data-access boundary / dual ownership_  
**Location:** `TRR-APP/apps/web/src/lib/server/trr-api/media-links-repository.ts : 92, 103, 117, 195, 249`  

The app's own Postgres pool performs INSERT/UPDATE directly against core.media_links (and reads core.media_assets in media-links/route.ts line 47-49), while the SAME core media domain is simultaneously mutated through the backend proxy (the generator test asserts edges like backend:POST:/api/v1/admin/media-assets/[assetId]/variants). This creates two independent writers to the shared core.* schema across two repositories with no shared data-access contract: schema changes, invariants, triggers, or RLS assumptions enforced on the backend side can be silently bypassed by the app's direct SQL. Of 329 route handlers, 14 use direct Postgres and 136 use the backend proxy, with 4 routes mixing both in a single handler (admin/covered-shows, admin/surveys/[surveyKey], admin/covered-shows/[showId], admin/health/app-db-pressure) — confirming the boundary is decided per-route rather than by a clear domain-ownership rule.

**Fix:** Define and document which schemas/tables are app-owned (e.g. firebase_surveys, app reddit tables) vs backend-owned (core.media_*, core domain). Route all backend-owned-table mutations through the backend API so invariants live in one place; restrict the app's direct pg pool to app-owned tables. At minimum, add a comment/lint rule flagging direct core.media_* writes from the app.

**Evidence:**
```
media-links-repository.ts:92  `INSERT INTO core.media_links (entity_type, entity_id, media_asset_id, kind, position, context)` ; media-links/route.ts:47 `await query<{ id: string }>(... FROM core.media_assets`
```


---

#### 3. [Medium] Fragile single-string /api/v1 auto-append in backend URL contract
**Status:** • unverified · _Cross-repo contract robustness_  
**Location:** `TRR-APP/apps/web/src/lib/server/trr-api/backend.ts : 35`  

normalizeBackendBase decides whether to append the API version by a single substring check: `normalized.endsWith('/api/v1') ? normalized : `${normalized}/api/v1``. This is brittle to plausible misconfigurations of TRR_API_URL: a value ending in /api (no version) yields /api/api/v1; a value already including a deeper path such as https://host/api/v1/admin fails the endsWith check and becomes https://host/api/v1/admin/api/v1; a value with /api/v1/ trailing slash works only because of the earlier trailing-slash strip. The contract is implicit and silent — there is no validation/throw on a malformed base, so a bad env var produces 404s against a doubled path that are hard to diagnose (and the only signal is a dev-mode console.warn for remote hosts, which is unrelated). 99 route files resolve URLs through getBackendApiUrl, so every admin route inherits this fragility.

**Fix:** Parse TRR_API_URL with the URL API, normalize/validate the path explicitly (reject or strip an existing version segment, reject deeper paths), and throw a clear configuration error on malformed input instead of silently concatenating. Add a unit test covering /api, /api/v1, /api/v1/, and a path-bearing base.

**Evidence:**
```
return normalized.endsWith("/api/v1") ? normalized : `${normalized}/api/v1`;  // backend.ts:35
```


---

#### 4. [Low] Generated admin API inventory is app-side static scan only and cannot detect backend contract drift
**Status:** • unverified · _Contract observability / generated artifact_  
**Location:** `TRR-APP/apps/web/scripts/generate-admin-api-references.mjs : 1 (whole generator); generator.ts:288,667-708`  

The 819KB checked-in inventory.ts (src/lib/admin/api-references/generated/) is produced purely by statically scanning the app's own route files and proxy-helper call sites (KNOWN_PROXY_HELPERS, createAdminBackendProxyRoute basis 'static_scan'); it never fetches the live backend or its OpenAPI schema. Backend edges are either inferred from app call sites or hard-coded as verificationStatus 'unverified_manual'. Consequently the artifact records what the APP believes it calls, not what the BACKEND actually exposes — if the backend renames/removes /api/v1/admin/* endpoints, the inventory and its in-sync test (tests/admin-api-references-generator.test.ts) still pass. The KNOWN LEAD that the inventory 'can drift from the live backend' is therefore partly REFUTED for app-side staleness (CI does guard self-consistency: scripts/test-ci.mjs line 69 runs generated:check) but CONFIRMED for backend-side drift (no introspection exists to catch it). sourceCommitSha is the app's own HEAD, reinforcing that it is self-referential.

**Fix:** If the inventory is meant to assert a live cross-repo contract, add a verification step that diffs the manual/inferred backend edges against the backend's actual OpenAPI/route list (e.g. fetch the backend openapi.json in a scheduled CI job) and downgrade 'unverified_manual' edges that no longer exist. Otherwise, document in the generator header that it is app-side only and does not validate backend existence.

**Evidence:**
```
grep of generate-admin-api-references.mjs for fetch/http/TRR_API_URL/openapi returned no matches; generator.ts:288 `return `backend:${method.toUpperCase()}:${pathPattern}`` built from app source; verificationStatus 'unverified_manual' used for backend edges
```


---

#### 5. [Low] Server-named module shipped into a client bundle via value import (TypographyRuntimeClient)
**Status:** • unverified · _Server/client boundary hygiene_  
**Location:** `TRR-APP/apps/web/src/components/typography/TypographyRuntimeClient.tsx : 1,4`  

A 'use client' component performs a runtime VALUE import of buildSeededTypographyRuntimeState from @/lib/server/admin/typography-seed. This only compiles because typography-seed.ts is one of 17 of 72 src/lib/server files that omit the import 'server-only' guard, and it happens to be a pure data/config module (only `import type` deps, no process.env/DB), so there is no secret leak. But it is an architectural smell: a module under src/lib/server (the server-only namespace) is bundled into client JS, and the absence of the server-only marker removes the compile-time tripwire that would catch a future maintainer adding a DB/secret dependency to that file. All other client files importing @/lib/server were verified to use erased `import type` only (e.g. SeasonAsset from trr-shows-repository), so this is the single genuine value-import crossing.

**Fix:** Move pure shared data like typography-seed out of src/lib/server (e.g. to src/lib/typography/seed.ts) so the server namespace stays server-only, then add 'server-only' to the remaining server libs that genuinely run server-side. This restores the guarantee that anything under src/lib/server fails the build if pulled client-side.

**Evidence:**
```
TypographyRuntimeClient.tsx:1 `"use client";` and :4 `import { buildSeededTypographyRuntimeState } from "@/lib/server/admin/typography-seed";`  (typography-seed.ts has no `import "server-only"`)
```


---

#### 6. [Low] vue-wordle ships an npm package-lock.json inside the pnpm apps/* workspace glob
**Status:** • unverified · _Monorepo packaging / workspace isolation_  
**Location:** `TRR-APP/apps/vue-wordle/package-lock.json : 1 (presence); pnpm-workspace.yaml:2`  

pnpm-workspace.yaml declares `packages: - "apps/*"`, so apps/vue-wordle is a member of the pnpm workspace, yet vue-wordle carries its own npm package-lock.json and a separate node_modules. The web CI explicitly bans an npm lockfile for the main app ('apps/web/package-lock.json detected. Use pnpm…' in web-tests.yml lines 33-39) but that guard is path-specific and does not cover apps/vue-wordle, leaving a mixed npm/pnpm package-manager state inside one pnpm workspace. This is benign as long as vue-wordle is never installed via the workspace root, but it is an inconsistency that can produce divergent dependency resolution and confuses tooling. Code isolation itself is clean: no apps/web source imports from vue-wordle.

**Fix:** Either exclude apps/vue-wordle from the pnpm workspace glob explicitly (e.g. narrow to `apps/web` or add an ignore) and document it as an independently-managed npm app, or migrate vue-wordle to pnpm and remove its package-lock.json. Extend the CI lockfile guard to fail on any npm lockfile under apps/* that is inside the pnpm workspace.

**Evidence:**
```
pnpm-workspace.yaml: `packages:\n  - "apps/*"` ; `ls apps/vue-wordle` shows package-lock.json + node_modules; web-tests.yml guard matches only apps/web/package-lock.json
```


---

#### 7. [Low] Internal-admin propagated context bypasses the admin host allowlist in requireAdmin
**Status:** • unverified · _Auth defense-in-depth_  
**Location:** `TRR-APP/apps/web/src/lib/server/auth.ts : 731-738, 763-768`  

requireAdmin checks isRequestHostAllowedForAdmin first (line 731), but a request carrying a valid HMAC-signed internal-admin context short-circuits at lines 735-738 AFTER the host check, while requireAdminContext (line 763-768) returns the propagated context BEFORE any host enforcement. Forgery is not possible without TRR_INTERNAL_ADMIN_SHARED_SECRET (internal-admin-auth.ts verifies HS256 with timingSafeEqual and full iss/aud/sub/scope/exp checks), so this is not an external bypass. The note is that the host-allowlist defense-in-depth layer is skipped for any internally-propagated call path, meaning the secret becomes the sole control for that path; if the shared secret were ever leaked, the host restriction would provide no secondary containment.

**Fix:** Apply isRequestHostAllowedForAdmin (or an explicit internal-network assertion) before honoring a propagated admin context in both requireAdmin and requireAdminContext, so host enforcement and signature verification are independent layers. Keep the shared secret rotation policy documented given it is the single control on the propagated path.

**Evidence:**
```
auth.ts:735 `const propagatedContext = resolveVerifiedAdminContext(request.headers); if (propagatedContext) { return buildPropagatedAuthenticatedUser(propagatedContext); }` placed after host check; requireAdminContext:764 returns propagatedContext with no host check
```


---

## Quality & Architecture — Workspace tooling  (`tooling-qa`)

**Summary.** The workspace tooling is generally robust: new shell scripts use `set -euo pipefail`, guard empty-array expansion (safe on macOS bash 3.2), and the new Python checkers (env_hygiene.py, modal-billing-guardrail.sh, instagram_auth_freshness.py) are well-structured with 23 passing contract tests. The two material issues are (1) the new `make dev-hybrid-bg` daemon launcher records a PID that dies within milliseconds, making its `.pid` file useless and untracked by `make stop`, and (2) the committed-modified test/preflight/contract scripts hard-depend on several files that are still untracked in git, so committing the tracked changes without `git add`-ing the new files would break `make test`/`make preflight`/`make workspace-contract-check` for every other checkout.

<details><summary>Coverage / blind spots</summary>

Read in full: scripts/test.sh, test-fast.sh, test-changed.sh, app-check.sh, modal-billing-guardrail.sh, instagram_auth_freshness.py, scripts/workspace/{env_hygiene.py, hygiene_clean.sh, hygiene_report.sh}, scripts/lib/workspace-test-contracts.sh, test_env_hygiene.py, test_modal_billing_guardrail.py, stop-workspace.sh (tail), and the run_preflight_phase function. Read git diffs for Makefile, check-workspace-contract.sh, preflight.sh, codex-chrome-devtools-mcp.sh, dev-workspace.sh, status-workspace.sh, workspace-env-contract.sh, env_contract_report.py. Ran the 4 new pytest suites (23 passed) and env_hygiene.py --check (exit 0). Empirically tested the dev-hybrid-bg fork one-liner PID divergence, bash 3.2 empty-array set -u behavior, and non-exported-var visibility to python children. Verified git-tracking status of new files and CI workflow scope. Sampled but did not exhaustively read: the ~1685-line dev-workspace.sh body (only diffed regions + WORKSPACE_MANAGER_PID/PIDFILE plumbing), the 46k-line codex-chrome-devtools-mcp.sh (only the PATH diff), env-contract.md / dev-commands.md prose beyond the changed rows, and the older unchanged lib/*.sh helpers (python-venv.sh, node-baseline.sh). Did not run the full `make test` end-to-end (would build the Next.js app).

</details>

#### 1. [High] make dev-hybrid-bg records a launcher PID that exits immediately; .pid file is dead-on-arrival and not wired into make stop
**Status:** ✅ verified (high confidence) · **verifier-adjusted severity: Medium** · _Shell robustness / PID & lifecycle management_  
**Location:** `Makefile : 75-81`  

The detached launcher runs `nohup /usr/bin/python3 -c '... pid = os.fork(); os._exit(0) if pid else None; os.setsid(); os.execvp(...)' make ... dev-hybrid` and then captures `bg_pid="$!"` (the shell's background job = the python launcher process) and writes it to .logs/workspace/dev-hybrid-background.pid. But the python launcher immediately double-forks: the PARENT half calls os._exit(0) within milliseconds, and the real long-lived `make dev-hybrid` runs in the CHILD under a new session with a DIFFERENT pid. I verified this empirically: launcher pid 23411 vs daemonized child pid 23413. So the recorded .pid is dead almost immediately and points to nothing useful. Compounding this, scripts/stop-workspace.sh (line 187) only honors WORKSPACE_MANAGER_PID from .logs/workspace/pids.env (written by dev-workspace.sh's own $$), and never reads dev-hybrid-background.pid — so the file the launcher advertises ('Stop: make stop') has no path that consumes it. The only reason `make stop` works is the separate pids.env written later by the daemon itself, which races with a freshly-started background run.

**Fix:** Capture the real daemon PID, not the launcher's. Simplest fix: have the python one-liner write its post-setsid os.getpid() to the pid file itself (e.g. pass the path and `open(path,'w').write(str(os.getpid()))` after setsid, before execvp), or drop the .pid file entirely and rely solely on pids.env/WORKSPACE_MANAGER_PID (which is what `make stop` actually uses). Either way, stop scripts should reconcile the background launcher with the eventual manager pid.

**Evidence:**
```
Makefile:75 `nohup /usr/bin/python3 -c 'import os, sys; pid = os.fork(); os._exit(0) if pid else None; os.setsid(); os.execvp(sys.argv[1], sys.argv[1:])' make --no-print-directory dev-hybrid > "$$log_file" 2>&1 &` then line 76 `bg_pid="$$!"`. Empirical: `python launcher pid would be 23411` / `daemon child pid is 23413 session 23413`. stop-workspace.sh:187 `if stop_manager "${WORKSPACE_MANAGER_PID:-}"; then` (consumes pids.env, never dev-hybrid-background.pid).
```


---

#### 2. [High] Committed-modified test/preflight/contract scripts hard-depend on files that are still untracked in git
**Status:** ✅ verified (high confidence) · _Config/contract drift / release coupling_  
**Location:** `scripts/check-workspace-contract.sh : 14-16, 148-264`  

The modified-and-staged-for-commit scripts reference new files that `git ls-files` reports as UNTRACKED (status '??'): scripts/workspace/{hygiene_report.sh,hygiene_clean.sh,env_hygiene.py}, scripts/lib/workspace-test-contracts.sh, scripts/modal-billing-guardrail.sh, scripts/instagram_auth_freshness.py, and the test_*.py files. check-workspace-contract.sh's new assert_workspace_hygiene_contract()/assert_env_hygiene_contract() `exit 1` if those paths are missing; test.sh/test-fast.sh/test-changed.sh `source scripts/lib/workspace-test-contracts.sh` (untracked) at load time; preflight.sh runs scripts/modal-billing-guardrail.sh and scripts/instagram_auth_freshness.py as new phases; Makefile adds env-hygiene/workspace-hygiene-report/workspace-hygiene-clean-dry-run targets calling untracked scripts. If the tracked modifications are committed without `git add`-ing the new files, `make test`, `make test-fast`, `make test-changed`, `make preflight`, and `make workspace-contract-check` all break for every other checkout (source error or exit 1). This is a working-tree state risk, not a code defect, but it is a release-blocking coupling.

**Fix:** Ensure all new dependency files are staged and committed in the SAME commit as the scripts that reference them (git add scripts/workspace/, scripts/lib/workspace-test-contracts.sh, scripts/modal-billing-guardrail.sh, scripts/instagram_auth_freshness.py, scripts/test_*.py, docs/workspace/{workspace-hygiene.md,test-skip-inventory.md}). Consider a pre-commit/CI guard that runs `make workspace-contract-check` against a clean checkout to catch this class of drift.

**Evidence:**
```
`git ls-files scripts/workspace/` -> (empty); `git ls-files scripts/lib/workspace-test-contracts.sh scripts/modal-billing-guardrail.sh scripts/instagram_auth_freshness.py` -> (empty). check-workspace-contract.sh:152 `if [[ ! -f "$path" ]]; then echo ... missing workspace hygiene contract file ... missing=1` then `exit 1`. test.sh:7 `source "$ROOT/scripts/lib/workspace-test-contracts.sh"`. preflight.sh:288 `run_preflight_phase "modal-billing-guardrail" ... bash "$ROOT/scripts/modal-billing-guardrail.sh"`.
```


---

#### 3. [Low] New preflight phase does not forward WORKSPACE_PREFLIGHT_STRICT to instagram_auth_freshness.py
**Status:** • unverified · _Shell robustness / env propagation consistency_  
**Location:** `scripts/preflight.sh : 274, 289`  

WORKSPACE_PREFLIGHT_STRICT is assigned as a plain (non-exported) shell variable at line 274. The existing `doctor` phase explicitly re-injects it via `env WORKSPACE_PREFLIGHT_STRICT="$WORKSPACE_PREFLIGHT_STRICT" bash ...`, but the new instagram-auth-freshness phase (line 289) runs `python3 .../instagram_auth_freshness.py` with no `env` prefix. instagram_auth_freshness.py reads WORKSPACE_PREFLIGHT_STRICT (line 243) to decide whether an advisory state should fail preflight. Because a non-exported shell var is NOT inherited by child processes (verified: `FOO=1; python3 -c '...getenv(FOO)...'` -> None), the strict gate only reaches the python child when the var was exported by the CALLER. `make preflight-strict` uses inline `WORKSPACE_PREFLIGHT_STRICT=1 bash scripts/preflight.sh`, which DOES export it, so the supported path happens to work — but the in-script default at line 274 would not propagate, making the strict behavior inconsistent and fragile.

**Fix:** Either `export WORKSPACE_PREFLIGHT_STRICT` once near line 274, or prefix the new phase with `env WORKSPACE_PREFLIGHT_STRICT="$WORKSPACE_PREFLIGHT_STRICT"` to match the doctor phase pattern.

**Evidence:**
```
preflight.sh:274 `WORKSPACE_PREFLIGHT_STRICT="${WORKSPACE_PREFLIGHT_STRICT:-0}"` (no export). preflight.sh:291 doctor uses `env WORKSPACE_DEV_MODE=... WORKSPACE_PREFLIGHT_STRICT=...`. preflight.sh:289 `run_preflight_phase "instagram-auth-freshness" ... python3 "$ROOT/scripts/instagram_auth_freshness.py"` (no env prefix). instagram_auth_freshness.py:243 `strict = str(os.getenv("WORKSPACE_PREFLIGHT_STRICT") or "0").strip() == "1"`.
```


---

#### 4. [Low] Dead function _collect_local_cleanup_actions in env_hygiene.py
**Status:** • unverified · _Duplication / dead code_  
**Location:** `scripts/workspace/env_hygiene.py : 256-262`  

_collect_local_cleanup_actions() is defined but never called anywhere in the codebase (single grep hit = the definition itself). It duplicates a subset of _collect_cleanup_actions() (only LOCAL_SECRET_KEY and RETIRED_ENV_KEY surfaces). It is not referenced by main(), the renderers, or the test suite. This is harmless but adds maintenance surface and can mislead future readers into thinking local-only collection is wired up.

**Fix:** Remove the function, or call it if a local-only cleanup view was intended (none of main(), _render_text, _render_markdown, or test_env_hygiene.py use it).

**Evidence:**
```
`grep -rn _collect_local_cleanup_actions scripts/` -> only `scripts/workspace/env_hygiene.py:256:def _collect_local_cleanup_actions(...)`. main() (line 484) calls `_collect_cleanup_actions(manifest)` instead.
```


---

#### 5. [Low] make dev-hybrid-bg is not documented in dev-commands.md and not enforced by the workspace contract
**Status:** • unverified · _Config/contract drift_  
**Location:** `docs/workspace/dev-commands.md : 15-16`  

The new `make dev-hybrid-bg` target is added to the Makefile (PHONY + recipe + help text) but is absent from docs/workspace/dev-commands.md, which enumerates dev-hybrid and dev-hybrid-social-safe as the documented command contract (grep count for dev-hybrid-bg = 0). check-workspace-contract.sh does not assert Makefile<->dev-commands.md target parity, so this drift is silent. Given CLAUDE.md designates dev-commands.md as a shared contract surface, a Modal-billing-capable detached launcher should be documented (it implicitly allows always-on Modal usage).

**Fix:** Add a dev-hybrid-bg entry to docs/workspace/dev-commands.md describing the detached/Modal-capable semantics and the log/pid file locations, consistent with the help text already in the Makefile.

**Evidence:**
```
`grep -c dev-hybrid-bg docs/workspace/dev-commands.md` -> 0; `grep -c dev-hybrid-bg Makefile` -> 3. dev-commands.md:15 documents only `make dev-hybrid` (comments 8) and :16 `make dev-hybrid-social-safe`.
```


---

#### 6. [Low] env-hygiene adjacent-surface scope differs between make target and contract check
**Status:** • unverified · _Config/contract drift_  
**Location:** `Makefile : 129`  

`make env-hygiene` runs env_hygiene.py with WORKSPACE_ENV_HYGIENE_INCLUDE_ADJACENT=1 (includes retired screenalytics/.env* surfaces), but check-workspace-contract.sh's assert_env_hygiene_contract() runs `python3 .../env_hygiene.py --check` WITHOUT that var (adjacent surfaces excluded). The two 'authoritative' invocations therefore evaluate different surface sets. In practice this is benign today because (a) screenalytics/ and its .env files no longer exist post-retirement (verified: `ls screenalytics/.env` -> No such file), and (b) error-severity findings do not depend on adjacent surfaces. But the divergence is undocumented and could surface inconsistent results if a retired env file reappeared.

**Fix:** Make the two invocations consistent (either both set INCLUDE_ADJACENT or neither for --check), or add a one-line comment in both the Makefile target and the contract assertion explaining why the scopes intentionally differ.

**Evidence:**
```
Makefile:129 `@WORKSPACE_ENV_HYGIENE_INCLUDE_ADJACENT=1 python3 scripts/workspace/env_hygiene.py --check`. check-workspace-contract.sh (diff) `python3 "$WORKSPACE_ENV_HYGIENE_SCRIPT" --check` (no INCLUDE_ADJACENT). env_hygiene.py:95 `if authority_key == RETIRED_ENV_KEY and not _include_adjacent_env_surfaces(): return []`.
```


---

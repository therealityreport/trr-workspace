# Social architecture, media, and schema acceptance follow-up

<!-- continuation-prune:2026-10-01 -->
## Continuation review — 2026-10-01

Status: PARTIAL — active. Original source: 2026-05-14; age basis: 2026-09-11 (20 days).

Current social/control-plane and media modules retain these requirements; September main changes and affected App WeekDetailPageView edits prevent stale rejection. Superseded runtime scaffolds remain excluded.

Evidence: `TRR-Backend/trr_backend/socials/instagram/catalog_ingest.py:2291` @ `3bcdc3925339`; `TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx:497` @ `f8f7f87662ea`

Status: UNVERIFIED — historical source matches exist; full acceptance is not established.
Reviewed: 2026-10-01.

## Evidence

Backend main `3bcdc39253392f94134c93b846927fbbc84e6133` contains the social compatibility core at `trr_backend/socials/social_season_analytics_impl.py:108` and import-ownership tests at `tests/repositories/test_social_control_plane_imports.py:419`. App main `f8f7f87662eab4787b1beb9cedb5614d8b7ec494` contains thumbnail selection at `apps/web/src/components/admin/social-week/social-media-thumbnails.ts:54`. These are investigation anchors, not full-plan completion evidence.

The local ignored archive `plans/archive/codex-2026-05/` retains originals and individual disposition/source records. Reconcile these requirements with the current architecture contracts and existing plans before proposing edits.

## Retained requirement groups

- Gallery/assets: bounded deterministic pagination instead of broad reads and Python slicing; smaller first pages, preserved partial results and retryable errors. Preserve fields, filters, actions, cursors, and explicit full-fetch mode. Verify the original cold/warm first-page budgets and absence of new advisor regressions with fresh evidence.
- Scraper separation: canonical control-plane, pipelines, read models, persistence, and platform handlers; thin route/CLI adapters; unchanged route/stage/job contracts; explicit compatibility-bridge owners and removal conditions. Preserve launch/auth metadata and existing import, registry, route-shape, and operator-smoke coverage. Old claimed completion does not authorize deleting wrappers.
- TikTok coverage: distinguish intentional caps, incomplete fetches, and persisted counts; target under-covered posts without replaying whole accounts; preserve comments contract gates and posts/media/analytics compatibility. Historical counts are not current repair targets.
- Platform modules: preserve platform-local ownership for TikTok, Twitter/X, Facebook, Threads, and YouTube; stable direct/catalog HTTP contracts; thin scripts and import boundaries. Retained wrappers need deletion criteria and ledger entries.
- Repost metadata: consistent aliases across extraction/merge/write, no poorer-header overwrite of richer data, canonical catalog/detail/week values and sorting, no duplicate column, and bounded diagnosis of old polluted data. Resolve engagement inclusion under the current product contract.
- Schema posture: revalidate current RLS/grants, curated reads, canonical parity, and consumer blockers. Preserve rollback/rerun guidance and legacy-table compatibility; historical tables/counts are not a current migration list. No DDL or backfill is authorized here.
- Media: preserve full originals and playable videos; separate covers/derived display variants from video URLs. Keep additive API compatibility, original-versus-variant coverage, freshness/audit/repair evidence, CDN checks, and cleanup of partial variants. Reconcile current safe-storage policies before implementation.
- Deferred SocialBlade/following/shared-source work: preserve raw immutable observations separately from merged histories; explicit freshness/auth/short-history classification; matching local/Modal payloads; incomplete following scrapes must not inactivate missing relationships. Verify pagination/source scope, stable shared identities/network sets, platform support, and separate UI/tooling test debt.
- Broader architecture: reconcile common admin proxy behavior, safe problem responses, schema security ledgers, deployment guards, social control-plane, and direct-SQL boundaries against current owning docs. Security posture changes require role probes and rollback evidence; do not reopen finished architecture work solely because old plans exist.

## Acceptance

For each group, record current-main file/line evidence and distinguish implemented behavior from missing runtime acceptance. Deduplicate current numbered plans and architecture contracts before allocating changes. Backend/shared-contract work precedes app follow-through; release order remains owned by workspace deployment guidance. No product or provider changes occur during retirement.

## Backend dated plans and grading-run reconciliation

Provenance: Backend `plans/archive/codex-2026-05/INDEX.md` (three May architecture plans) and `plans/archive/plan-grader-2026/INDEX.md` (six historical grading runs). Backend had no active `plans/` at triage, so unresolved work is deduplicated here in the workspace. Historical dispatch payloads, branch prescriptions and execution wrappers are archival evidence only. No old plan or grade authorizes execution.

All four dated plans remain unverified as whole plans on Backend main `3bcdc39253392f94134c93b846927fbbc84e6133`. Existing platform catalog modules and cancellation helpers are implementation anchors, not proof of all acceptance criteria. Recheck against current main before executing.

- Instagram hardening: preserve transport retry/backoff and Retry-After, warmup failure metadata, shared cookie adapters, connection-aware cancellation, and degraded summaries. Main `trr_backend/socials/instagram/posts_scrapling/job_runner.py:397` and `instagram/scrapling_session.py:22` show existing surfaces. The old unsupported-runtime scaffold proposal is superseded: `instagram/runtimes/scrapling_runtime.py:35,43,58` implements an opt-in runtime. Verify its default-disabled/dispatcher contract; do not restore the historical scaffold. Outstanding readiness is deduplicated into 049/050/048.
- TikTok/YouTube: main `tiktok/posts_scrapling/job_runner.py:165` and `youtube/posts_catalog/catalog.py:30` contain cancellation/catalog surfaces; `social_season_analytics_impl.py:3351` supports TikTok probing. Reconcile retry decisions, error classes, progress/skip/persistence counters, bounded page-size configuration, degraded finalization, source identity, continuation/empty-page diagnostics, and local/remote parity. Batch persistence remains conditional on payload, optional-column, conflict, assignment, job-id and return-shape equivalence. Preserve route/schema/comment-lane contracts.
- Threads/Twitter/Facebook: main `threads/posts_scrapling/job_runner.py:197` and the three `posts_catalog/catalog.py` files (Twitter:32, Facebook:27, Threads:24) are existing anchors. Reconcile safe auth structure, readiness CLI flags, cancellation, degraded finalization, progress/skip metadata, and separate shared catalog versus claimed-job ownership. Preserve comments/schema/route/stage contracts and existing lane boundaries.
- Platform fallback acceptance remains unverified: recheck TikTok's historical yt-dlp production default and fallback eligibility against current main; `trr_backend/socials/tiktok/scraper.py:42` explicitly limits yt-dlp-to-API fallback to `ytdlp_unavailable`, `ytdlp_timeout`, and `ytdlp_nonzero_exit`. Verify direct API auth/challenge failures (`challenge_or_blocked`, `non_json_response`, `http_401`, `http_403`) remain terminal and are reported once unless a current explicit configuration authorizes otherwise. Verify Threads legacy fallback only follows a fetch failure with no posts and an allowed retry policy, with no noisy auth/warmup fallback chains. These are reconciliation criteria, not permission to broaden fallbacks or retry authentication.
- Broader architecture: main `api/routers/socials/__init__.py:2,25` already registers route surfaces; `control_plane/worker_health.py:18` still accesses the compatibility core. Reconcile lifecycle/health/catalog/ingest/read-model ownership, handler/schema/cache boundaries, person-image refresh source stages, show-link discovery, and show-refresh pipeline/retry/progress ownership. Existing facade/module work must not be repeated. No full acceptance receipts were found for the five original candidates.

The latest graded suggestions remain a verification checklist, with originals retained byte-for-byte. Grade approval is not implementation acceptance:

- Instagram (latest estimated score 96): lane diagram and glossary; secret-safe metadata scanner; deterministic response fixtures; retry-reason counts; stale-worker restart guidance; shared retry helper coverage; manual bounded smoke documentation; cancellation logs; future runtime evidence/rollout/rollback reconciliation (current opt-in runtime supersedes the old implementation stub).
- TikTok/YouTube (latest estimated score 93.04): success/failure/cancellation/degraded metadata fixtures; one-page operator runbook; error-code registry coverage; YouTube catalog golden fixture; safe TikTok runtime metadata keys; opt-in local smoke wrapper; explicit batch-upsert decision; import-cycle checks; queue-dashboard copy acceptance; 30-day follow-up query.
- Threads/Twitter/Facebook (latest score 93.4): auth smoke wrapper; fixture secret validator; wrapper-owner/deletion ledger; failure query snippet; all-platform catalog import-cycle checks; shared fake persistence adapter; metadata golden fixtures; benchmark only if a material runtime path change warrants it; batch-equivalence checklist; wrapper retirement criteria; readiness smoke docs; explicit no-new-lane review question.

For each item, record a current-main file/line and revision plus the required behavioral evidence, or mark it pending/unverified with the reason. Use existing test assets where adequate; this archival task creates no new tests or live operations.

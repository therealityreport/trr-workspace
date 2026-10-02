# Instagram catalog and auth acceptance follow-up

<!-- continuation-prune:2026-10-01 -->
## Continuation review — 2026-10-01

Status: PARTIAL — active. Original source: 2026-05-21; age basis: 2026-09-11 (20 days).

Catalog listing/enrichment/cancellation and launch contracts retain unique criteria beside048. September 11 refresh code and current backend shared-router edits prevent stale rejection.

Evidence: `TRR-Backend/trr_backend/socials/instagram/catalog_ingest.py:2291` @ `3bcdc3925339`; `TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx:497` @ `f8f7f87662ea`

Status: UNVERIFIED — reconcile historical requirements before implementing.
Reviewed: 2026-10-01.

## Evidence and deduplication

Backend main `3bcdc39253392f94134c93b846927fbbc84e6133` already has the detail freshness policy at `trr_backend/socials/instagram/catalog_ingest.py:2291`, and `scripts/modal/repair_instagram_auth.py:113` exposes local validation-only mode. App main `f8f7f87662eab4787b1beb9cedb5614d8b7ec494` contains `apps/web/src/components/admin/SocialAccountProfilePage.tsx:497`. Source existence does not prove runtime acceptance.

Use [048](048-instagram-post-details-reliability.md) for durable detail targets, field-aware refresh, request budgets, transport errors, progress reliability, and detail UI acceptance. Do not create a second implementation of those contracts. This follow-up retains the remaining listing, launch, cancellation, profile-summary, enrichment, runtime-diagnostic, and manual-auth obligations.

The May 3 speed/completeness original explicitly says its implementation failed. Preserve that as failed prior work; do not rerun its acceleration recipe as an untried solution. Originals and per-file evidence remain in git-ignored `plans/archive/codex-2026-05/`.

## Remaining requirements

- Listing/resume: persist bounded pagination checkpoints, classify partial/stale/auth-blocked termination, preserve rich listing fields and sample-versus-full-comment distinctions, and separate listing from enrichment. Any cursor-direction optimization requires fresh evidence; old proxy/pacing recipes are not defaults.
- Stage graph: allow saved-target comment work independently of expensive details; expose comments, media, and crosspost enrichment separately. Bound persistence/enqueueing and keep worker concurrency distinct from database read capacity. Preserve explicitly configured transport behavior without copying private configuration.
- Execution contract: selected and effective tasks, backend requirements, launch groups, child jobs, cancellation, and summaries must agree. Ordinary Modal-required runs must not fall into an unauthorized local executor. Zero-work media lanes need an explicit skipped/waiting reason.
- Progress/profile recovery: retain account summaries when progress-only snapshots omit them; never resurrect terminal runs through timeout fallback. Recover failed comment follow-ups without deleting data or replaying the entire catalog; verify grouped-query compatibility.
- Runtime diagnostics: compare current local, worker, and deployed package/browser readiness and expose actionable redacted diagnostics. The May Scrapling version pin is historical, not an instruction to downgrade. Preserve dynamic document discovery, explicit overrides, bounded launch checks, and resumable partial outcomes.
- Manual auth: validation-only checks must not write cookies, sync secrets, deploy, or create repair cooldowns. Keep operator login, local sync, remote secret sync, deployment, and remote verification as distinguishable stages under current authority. Do not reuse historical browser-profile identifiers.

## Acceptance

Resolve each original requirement against current main and existing tests, then retain API/worker/browser evidence for any unfinished behavior. A source match or old local-pass note does not establish completion. No auth, network, provider, database, or deployment operation is authorized by this archive promotion.

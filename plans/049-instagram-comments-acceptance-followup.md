# Instagram comments acceptance follow-up

<!-- continuation-prune:2026-10-01 -->
## Continuation review — 2026-10-01

Status: PARTIAL — active. Original source: 2026-05-06; age basis: 2026-09-11 (20 days).

Comments fetch/reply-completeness and session-lane contracts remain relevant; affected backend comments/repair source is modified on the current branch and main social readers changed September 11. No full criteria proof.

Evidence: `TRR-Backend/trr_backend/socials/instagram/catalog_ingest.py:2291` @ `3bcdc3925339`; `TRR-APP/apps/web/src/components/admin/SocialAccountProfilePage.tsx:497` @ `f8f7f87662ea`

Status: UNVERIFIED — historical requirements retained, not a new implementation authorization.
Reviewed: 2026-10-01.

## Evidence and scope

The May comments plans have source counterparts on Backend main `3bcdc39253392f94134c93b846927fbbc84e6133` and App main `f8f7f87662eab4787b1beb9cedb5614d8b7ec494`. For example, the backend comments fetcher checks expected versus observed replies at `trr_backend/socials/instagram/comments_scrapling/fetcher.py:4193`, and `api/routers/socials/_shared.py:429` names the single-session strategy. These anchors prove implementation surfaces exist, not that the complete acceptance criteria passed. No full-plan completion is asserted.

Originals and individual source anchors are preserved locally in the git-ignored `plans/archive/codex-2026-05/` archive and its `DISPOSITION.json`. Do not copy operational examples or authentication details into public issues. Revalidate all old defaults before implementation.

## Remaining acceptance requirements

- Comments authentication: validate the comments lane against its own endpoint; preserve operator-controlled login, bounded failure handling, sticky sessions, and distinct authentication/transport/completeness diagnostics. No third-party scraper service dependency is required. This does not authorize authentication changes or retries.
- Post modal and week reads: bounded paginated post-scoped reads, direct shareable modal URLs, preserved headers and safe retry context on errors; staged secondary week-page work must not block the first page. Recheck the original cold-load/time-budget criteria with a current baseline.
- Crosspost accounting: retain known external counts when responses omit them; distinguish reported totals from fetchable Instagram coverage. Show external counts when available without logging authentication material. Detail transport work is owned by [048](048-instagram-post-details-reliability.md); this follow-up owns comment completeness and display acceptance.
- Complete threads: reconcile parent comments, child replies, external comments, and classified residual gaps; nest replies under parents and never mark known missing replies complete. Account totals must not treat external comments as newly saved Instagram rows.
- Progress: distinguish fetched, written, inserted, refreshed, changed, reactivated, and total saved rows; distinguish retryable incomplete work from failed work without hiding profile coverage.
- Collaborator recovery: use author/collaborator context for empty successful responses; retain bounded, explained external-limit states and prove ordinary posts remain compatible. Reproduce old zero-save findings only against current evidence, not historical account counts.
- Reply accounting: preserve retryable tail failures and rate-limit protection through stored-total reconciliation; expose complete, retryable incomplete, and unavailable states consistently.
- Single-session strategy: retain one continuous session per post, internal resumable pagination, per-post persistence, explicit shard override, and load/stop metadata. Stop on challenge/login responses without rotating identities to evade them; preserve the default strategy.
- Target selection: verify largest-gap-first ordering and the historical one-missing exclusion against the current product contract; preserve collaborator diagnostics and prove fallback classification with existing coverage.

## Acceptance and execution boundary

First map each requirement to current main source and existing tests; execute only the missing work requested in a subsequent task. Completion requires current main file/line evidence and applicable API, worker, and browser receipts. Browser checks use the friendly TRR identity and `make dev-hybrid`; provider/database writes need task-specific authority. No historical live run or account total is current evidence.

## Backend dated-plan readiness reconciliation

Provenance: Backend `plans/archive/codex-2026-05/2026-05-03-instagram-social-scraper-readiness.md` and its INDEX. Backend main `3bcdc39253392f94134c93b846927fbbc84e6133`, `docs/ai/local-status/instagram-social-scraper-readiness-20260503.md:7,18` records completed code gates and a historical operational blocker; it does not establish current session readiness. No operational identifiers or authentication material are promoted.

Retain catalog/direct-comments/deferred-comments launch guards, structured repair metadata, absence of background-read repair, fail-before-queue behavior, usable worker lanes, and fresh queue-health response acceptance. Deduplicate catalog listing/diagnostic work with [050](050-instagram-catalog-acceptance-followup.md), and detail processing with [048](048-instagram-post-details-reliability.md). Recheck current-main code and obtain fresh authorized receipts before calling the scraper operationally ready.

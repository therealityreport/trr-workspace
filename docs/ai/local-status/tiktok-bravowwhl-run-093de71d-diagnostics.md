# TikTok `@bravowwhl` Run `093de71d` Diagnostics

Last updated: 2026-04-09

## Summary

- Full run id: `093de71d-4ab4-4116-a7b2-1fc2855c6940`
- Platform/account: `tiktok` / `bravowwhl`
- Executor observed in job row: `modal:social:modal:2:165498c0`
- First broken hop: discovery produced zero partitions, so no `shared_account_posts` jobs were ever created.

## Evidence

- `social.scrape_runs` shows the run stored as `completed` with summary stage counts containing exactly one completed `shared_account_discovery` job and no posts-stage jobs.
- `social.scrape_jobs` for the run/account returns exactly one row:
  - stage: `shared_account_discovery`
  - status: `completed`
  - worker_id: `modal:social:modal:2:165498c0`
  - `retrieval_meta.total_posts = 3277`
  - `retrieval_meta.posts_checked = 0`
  - `metadata.discovered_partition_count = 0`
- `social.shared_account_run_partitions` has no rows for the run/account.
- `social.shared_account_run_frontiers` has no rows for the run/account.

## Interpretation

- This was not a dispatch-capacity problem and not a posts-stage scraper failure.
- Modal successfully claimed the discovery job.
- Discovery returned a TikTok profile snapshot with `total_posts=3277` and a valid `sec_uid`, but the first `fetch_posts` page yielded no usable items.
- Because discovery found zero partitions, the run never created any `shared_account_posts` jobs, which is why the admin page later rendered `0 / 3277`.
- The stored discovery metadata looked like the generic `discovery_empty_first_page` branch rather than a TikTok-specific failure, which suggests the remote Modal runtime was missing the latest clearer error/reporting behavior even though the local repo already expects `tiktok_discovery_empty_first_page`.

## Chosen Fix Branch

- Ship the always-fix backend changes:
  - TikTok scraper writes canonical `posts_checked` while preserving `videos_scanned`.
  - TikTok discovery path forwards `partition_callback`, matching Instagram eager-dispatch behavior.
- Improve TikTok empty-first-page diagnostics:
  - record successful `fetch_posts` response metadata even on empty JSON payloads
  - log structured TikTok discovery completion and discovery reconciliation counts
  - preserve richer discovery metadata for future empty-first-page failures

## Follow-Up

- Fresh rerun `c7239268-a371-4173-83d4-e903b1161b60` was started from the local admin proxy on 2026-04-09.
- The rerun failed in the same shape:
  - one completed `shared_account_discovery` job
  - zero partitions
  - zero `shared_account_posts` jobs
  - `post_progress.total_posts = 3277`
  - no richer `endpoint_responses` telemetry persisted in the job retrieval metadata
- That result confirms the checked-out backend fixes are not yet what the remote Modal worker is executing.
- Modal readiness is healthy (`scripts/modal/verify_modal_readiness.py --json` returned `ok: true`), so the remaining gap is rollout, not function resolution.
- I did not deploy `trr-backend-jobs` from this workspace because `TRR-Backend` already contains unrelated uncommitted changes; deploying from the dirty repo would risk shipping unrelated work along with this fix set.

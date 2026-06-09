# Markdown Review Topics

These `.md` surfaces were encountered during the review. Items marked `action needed` have fixes in `consolidated-findings.md` and `fixes-and-patches.md`.

## Current Review Package

- `reviews/agent-teams-2026-05-28/README.md` - action needed before this update: stale highest-risk list included fixed issues.
- `reviews/agent-teams-2026-05-28/consolidated-findings.md` - action needed before this update: stale findings included fixed env-report, build-command, and workspace-contract issues.
- `reviews/agent-teams-2026-05-28/fixes-and-patches.md` - refreshed with current patch directions.
- `reviews/agent-teams-2026-05-28/validation-evidence.md` - refreshed with current validation/tool evidence.
- `reviews/agent-teams-2026-05-28/agent-lane-reports.md` - new lane summary.

## Governance And Workspace Policy

- `AGENTS.md` - review honored saved-notes boundary and project plugin routing.
- `.codex/rules/trr-project.md` - current build-safety examples use the correct `TRR-APP/apps/web` path.
- `docs/ai/HANDOFF_WORKFLOW.md` - current stale-note boundary context; no blocker in this review.
- `plan.md` - action needed: app validation command is wrong after `cd TRR-APP`.

## Modal And Cloud Runtime

- `TRR-Backend/docs/runbooks/social_worker_queue_ops.md` - action needed: states Modal singleton maintenance is default owner, but current code disables Modal schedules by default.
- `docs/workspace/modal-safe-backend-deploy-set.md` - relevant for any follow-up implementation because backend is broadly dirty and Modal deploys need isolation.
- `docs/workspace/dev-commands.md` - action needed: `dev-hybrid` social caps are stale versus `Makefile`.
- `docs/workspace/instagram-scrapling-runtime-canary.md` - action needed: documents env cookie paths that `scripts/instagram_auth_freshness.py` does not honor.

## Supabase And Database

- `docs/workspace/supabase-rls-grants-review.md` - residual security context; not all items are new regressions.
- `docs/workspace/supabase-advisor-snapshot-2026-04-27.md` and later advisor docs - older snapshots are useful history, but live Supabase advisors were used for current findings.
- `docs/database-schema.md` and `TRR-Backend/docs/db/schema.md` - survey RPC context.
- `docs/workspace/unused-index-*` docs - relevant to performance advisor follow-up, but unused-index removals need owner decisions.

## Env And Workspace Hygiene

- `docs/workspace/env-contract.md` - action needed: debug-log kill-switch wording overstates current host-trust behavior.
- `docs/workspace/env-contract-inventory.md` - current contract inventory context.
- `docs/workspace/env-deprecations.md` - prior leakage concern is superseded; current generator writes `path:line` without raw matched text.
- `docs/workspace/redacted-env-inventory.md` - redaction boundary context.
- `docs/workspace/shared-env-manifest.json` - action needed: default local-secret adapters include `screenalytics/.env`.
- `docs/workspace/workspace-hygiene.md` - action needed: adjacent workspace policy conflicts with default `screenalytics/.env` scan.
- `docs/workspace/test-skip-inventory.md` - test/governance context.

## Backend And API Cleanup

- `docs/workspace/backend-social-route-cleanup-slice.md` - Instagram auth-repair notes were checked against live code.
- `docs/workspace/backend-codebase-cleanup-inventory.md` - backend cleanup context.
- `docs/workspace/codebase-cleanup-inventory.md` and `docs/workspace/codebase-cleanup-validation-matrix.md` - validation lane context.
- `docs/workspace/app-direct-sql-inventory.md` - app/backend direct SQL context.
- `docs/workspace/api-migration-ledger.md` - backend/app contract migration context.

## Frontend Route Inventory

- `docs/workspace/web-app-route-feature-inventory.md` - used to identify large app/admin route surfaces and proxy ownership.
- `docs/workspace/shows-admin-contract.md` - route contract context for admin proxy migration style.

## Planning Maps

- `.planning/codebase/workspace-map.md` - workspace orientation only.
- `.planning/codebase/backend-map.md` - backend/runtime orientation only.
- `.planning/codebase/app-map.md` - app/frontend orientation only.

## Adjacent Workspace Markdown

The nested `screenalytics` repo contains many docs and archived plans. This review treated those as adjacent context only, not TRR implementation authority, except where TRR env hygiene currently scans `screenalytics/.env` by default.

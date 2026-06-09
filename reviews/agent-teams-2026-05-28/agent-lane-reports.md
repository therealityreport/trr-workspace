# Agent Lane Reports

This file preserves the consolidated signal from each Agent Teams lane. See `consolidated-findings.md` for deduped severity and final wording.

## API / Backend

Primary findings:

- Modal maintenance has duplicate-or-zero owner risk.
- Comments progress GET mutates live shard state.
- Bravo social conflict still writes approved entity link.
- Explicit Instagram cookie refresh defaults to no refresh.
- Auth-repair cooldowns can block the next real repair attempt.

Relevant markdown:

- `TRR-Backend/docs/runbooks/social_worker_queue_ops.md`
- `docs/workspace/backend-social-route-cleanup-slice.md`
- `docs/workspace/backend-codebase-cleanup-inventory.md`

## Cloud Infra / Modal / Supabase

Primary findings:

- Modal maintenance default owner is inconsistent between docs and code.
- Modal billing guardrail misses the `.env` source used by named-secret rendering.
- Modal billing guardrail has mixed-case truthy bypass.
- Auth cooldowns can be written for infrastructure failures.
- Live Supabase advisors still report survey RPC, mutable search path, extension, FK index, and unused-index residuals.

Relevant markdown:

- `TRR-Backend/docs/runbooks/social_worker_queue_ops.md`
- `docs/workspace/modal-safe-backend-deploy-set.md`
- `docs/workspace/supabase-rls-grants-review.md`

## Frontend / Admin / API Client

Primary findings:

- SocialBlade proxy routes can hide structured backend failure reasons.
- SocialBlade proxy routes lack upstream timeouts.
- `build:turbo` bypasses the safe build guard.
- Draft `plan.md` has a bad app-validation command after `cd TRR-APP`.

Relevant markdown:

- `docs/workspace/web-app-route-feature-inventory.md`
- `plan.md`

## Security / Auth / Secrets

Primary findings:

- Admin host enforcement and dev bypass trust request host data.
- Debug-log remote kill switch trusts request hostnames.
- Bravo proxy routes forward machine identity instead of verified admin context.

Relevant markdown:

- `docs/workspace/env-contract.md`
- `reviews/agent-teams-2026-05-28/validation-evidence.md`

## Testing / Docs / Governance

Primary findings:

- `scripts/test-changed.sh` can false-green root-only changes.
- Standard root script test lanes are too narrow.
- Env hygiene scans adjacent `screenalytics/.env` by default.
- Instagram auth freshness ignores env-configured cookie paths.
- Existing review package had stale resolved findings before this update.
- `docs/workspace/dev-commands.md` has stale `dev-hybrid` caps.

Relevant markdown:

- `docs/workspace/shared-env-manifest.json`
- `docs/workspace/workspace-hygiene.md`
- `docs/workspace/instagram-scrapling-runtime-canary.md`
- `docs/workspace/dev-commands.md`

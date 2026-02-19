# Rollback Playbook: Stack Audit Remediation

Date: February 17, 2026
Scope: TRR-Backend, screenalytics, TRR-APP

## Rollback Triggers

- New 5xx spikes on TRR-APP admin proxy paths to TRR-Backend.
- screenalytics pipeline failures after dependency/runtime updates.
- Auth-shadow parity divergence crossing cutover thresholds.

## Immediate Containment

1. Freeze deploys in all repos.
2. Set `TRR_AUTH_PROVIDER=firebase` and disable shadow mode if auth instability is suspected:
- `TRR_AUTH_SHADOW_MODE=false`
3. Revert feature toggles for Gemini route specialization if needed:
- Unset `GEMINI_MODEL_FAST`/`GEMINI_MODEL_PRO` to fall back to canonical `GEMINI_MODEL`.

## Repo-Specific Rollback Commands

### TRR-Backend

- Revert merge commit:
  - `git revert -m 1 4293290520dfc8736c3e0194e7bc5e6cdd5451cd`
- Validate:
  - `pytest -q`

### screenalytics

- Revert remediation + hotfix merge commits if required:
  - `git revert -m 1 3e476722ea936770b2aafe64a2b1211d0fc58d3b`
  - `git revert -m 1 aeb0b807ae8167dbd524a0c8d99ca25b70e011f0`
- Validate:
  - `pytest -q tests/api/test_celery_jobs_api.py tests/api/test_celery_jobs_local.py`

### TRR-APP

- Revert merge commit:
  - `git revert -m 1 68bccdfe4a52fd2c9717668f57397fdeb213c912`
- Validate:
  - `pnpm -C apps/web run lint`
  - `pnpm -C apps/web run build`

## Recovery Exit Criteria

- Main branch CI green in all repos.
- Cross-collab STATUS files updated with rollback decision timestamp.
- Handoff notes include incident summary, rollback scope, and forward fix owner.

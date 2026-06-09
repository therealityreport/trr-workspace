# Backend Model and Modal Lock Runtime Slice

Status: active Modal deploy handoff only. Do not deploy from the current shared
checkout.

This slice isolates the approved backend model/runtime and Modal lockfile
changes. The current workspace is dirty with unrelated changes, so sending Modal
from this checkout would risk deploying work outside this slice.

## Deploy Decision

- Decision: do not deploy from this dirty shared checkout.
- Safe path: deploy from a clean checkout, clean worktree, or patch application
  that contains only the files listed below.
- Branch policy for this handoff: current `main` checkout only; no branch or
  worktree was created here.
- SQL status: no SQL changes, no direct-SQL changes, and no Supabase migration
  changes are part of this deploy slice.

## Approved File Set

Include exactly these backend files:

- `TRR-Backend/.env.example`
- `TRR-Backend/requirements.modal.lean.lock.txt`
- `TRR-Backend/requirements.modal.vision.lock.txt`
- `TRR-Backend/tests/clients/test_computer_use.py`
- `TRR-Backend/tests/repositories/test_social_season_analytics.py`
- `TRR-Backend/trr_backend/clients/computer_use.py`
- `TRR-Backend/trr_backend/socials/instagram/runtimes/browser_use_runtime.py`
- `TRR-Backend/trr_backend/socials/social_season_analytics_impl.py`

Do not include any other dirty backend, app, docs, profile, script, generated,
or workspace files without separate approval.

## Slice Summary

- Modal lean and vision lockfiles were refreshed for the backend runtime.
- Backend env example was updated for runtime defaults and observability/proxy
  settings.
- Computer-use defaults now reference `claude-opus-4-8`.
- Instagram browser-use runtime documentation now references the same model
  default.
- Social season analytics implementation and repository tests were updated for
  the current model/runtime behavior in this slice.

## Patch Generator

Use the workspace patch generator to list, manifest, or export only the approved
eight-file diff:

```bash
scripts/modal-deploy-patch.sh --help
scripts/modal-deploy-patch.sh --list
scripts/modal-deploy-patch.sh --manifest
scripts/modal-deploy-patch.sh --patch /tmp/trr-modal-backend-model-lock-runtime.patch
```

The generator does not create branches or worktrees. It filters the diff to the
approved file set and reports any unrelated dirty files as a deploy blocker for
the shared checkout.

## Validation

Run from `/Users/thomashulihan/Projects/TRR` or the equivalent clean deploy
tree:

```bash
git -C TRR-Backend diff --check -- \
  .env.example \
  requirements.modal.lean.lock.txt \
  requirements.modal.vision.lock.txt \
  tests/clients/test_computer_use.py \
  tests/repositories/test_social_season_analytics.py \
  trr_backend/clients/computer_use.py \
  trr_backend/socials/instagram/runtimes/browser_use_runtime.py \
  trr_backend/socials/social_season_analytics_impl.py
```

Recorded result for this handoff: passed with no whitespace errors.

Run from `TRR-Backend` for the focused runtime/test slice:

```bash
.venv/bin/python -m pytest \
  tests/clients/test_computer_use.py \
  tests/repositories/test_social_season_analytics.py \
  -q
```

Recorded result from the current dirty checkout:

- `5 failed, 911 passed in 93.46s`
- Failed tests:
  - `tests/repositories/test_social_season_analytics.py::test_cached_live_profile_snapshot_uses_twitter_graphql_user_totals`
  - `tests/repositories/test_social_season_analytics.py::test_social_account_profile_post_item_includes_catalog_media_fields`
  - `tests/repositories/test_social_season_analytics.py::test_set_job_running_clears_stale_error_fields`
  - `tests/repositories/test_social_season_analytics.py::test_build_modal_executor_health_payload_targets_platform_specific_auth_readiness`
  - `tests/repositories/test_social_season_analytics.py::test_social_account_comments_scrape_run_progress_recomputes_stale_summary_and_clamps_posts`

Do not treat this dirty-checkout pytest result as deploy-ready evidence. Re-run
the focused test command from the clean deploy tree before deploying.

## Clean Deploy Procedure

From a clean checkout or patch tree containing only the approved file set:

```bash
cd /Users/thomashulihan/Projects/TRR
git status --short
git -C TRR-Backend diff --name-only
```

Confirm the backend diff contains only the approved eight files, then run the
repo guardrail:

```bash
scripts/modal-billing-guardrail.sh
```

If the deploy uses a source env other than `TRR-Backend/.env`, set it
explicitly:

```bash
TRR_MODAL_SOURCE_ENV=/path/to/deploy.env scripts/modal-billing-guardrail.sh
```

If Modal named secrets need to be refreshed from the deploy env, run from
`TRR-Backend`:

```bash
.venv/bin/python scripts/modal/prepare_named_secrets.py --apply
```

Deploy with the TRR Modal profile wrapper from the workspace root:

```bash
scripts/modal-trr.sh deploy -m trr_backend.modal_jobs
```

Equivalent direct command from `TRR-Backend`, only when the Modal profile/env is
already correct:

```bash
.venv/bin/python -m modal deploy -m trr_backend.modal_jobs
```

## Post-Deploy Readiness

Run from `TRR-Backend`:

```bash
.venv/bin/python scripts/modal/verify_modal_readiness.py --json --probe-remote-auth instagram
```

Recommended optional probes when this runtime slice is meant to cover broader
worker readiness:

```bash
.venv/bin/python scripts/modal/verify_modal_readiness.py --json --probe-core-workers
```

Expected readiness gate:

- Modal app `trr-backend-jobs` resolves.
- Named secrets resolve.
- Required functions resolve.
- API web endpoint resolves.
- Instagram remote auth probe is recorded; if it reports a checkpoint/session
  issue, treat that as an auth repair item, not proof that unrelated dirty code
  should be deployed.

## Rollback Notes

- If Modal deploy fails before readiness passes, redeploy the previous
  known-good backend tree with the same Modal command.
- If runtime behavior regresses after deploy, revert only the approved
  eight-file patch in a clean deploy tree and redeploy `trr_backend.modal_jobs`.
- If the failure is secret-related, re-run
  `scripts/modal/prepare_named_secrets.py --apply` from the known-good env
  before redeploying.
- Do not use the dirty shared checkout for rollback; it has the same unrelated
  change risk as the forward deploy.

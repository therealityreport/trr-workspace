# Preserved Stash Cleanup Ledger

Date: 2026-06-10

This ledger records the preserved stash review after the Node 24 and PR-orchestration cleanup run.
It keeps intentionally skipped work visible without mixing generated artifacts or unrelated plugin work into TRR PRs.

## Recovered

### TRR-Backend: Modal deploy guardrails

- Stash: `preserve-TRR-Backend-modal-maintenance-owner-before-worktree-cleanup`
- Decision: recover selected missing files into a focused backend PR.
- Kept:
  - `docs/observability/modal-v439-v440-serve-backend-api-crash-loop-2026-05-28.md`
  - `scripts/modal/api_canary.py`
  - `scripts/modal/cleanup_wrong_workspace_deploy.py`
  - `scripts/modal/deploy_backend.py`
  - `tests/scripts/test_cleanup_wrong_workspace_modal.py`
  - `tests/scripts/test_deploy_backend_modal.py`
  - `tests/scripts/test_modal_auth_recovery_profile_pinning.py`
  - `tests/utils/test_lazy_imports.py`
  - `trr_backend/utils/lazy_imports.py`
- Adjustment before PR: `modal app stop` must run with `--yes` so wrong-workspace cleanup is non-interactive.

## Left Stashed

### TRR workspace `.full-review` artifacts

- Stashes:
  - `preserve-full-review-artifacts-before-main-cleanup`
  - `preserve-untracked-full-review-artifacts-before-main-cleanup`
- Decision: do not merge.
- Reason: generated review output, raw findings, and archived review payloads are not product or runtime changes.

### TRR-Backend old auth and proxy worktree deltas

- Stashes:
  - `preserve-TRR-BACKEND-comments-proxy-deploy-20260608-before-worktree-cleanup`
  - `preserve-TRR-Backend-auth-profile-deploy-before-worktree-cleanup`
  - `preserve-TRR-Backend-a5-clean-deploy-before-worktree-cleanup`
- Decision: do not merge as full patches.
- Reason: current `main` already contains the useful auth cooldown, Chrome profile, Modal image packaging, and proxy-default changes; remaining patch areas overlap heavily with current social runtime code.

### Penny-stocks plugin work

- Stash: `exclude-penny-stocks-before-trr-orchestration`
- Decision: exclude from TRR workspace PRs.
- Reason: unrelated plugin package work should not be published through the TRR PR run.

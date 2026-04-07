# Phase 7 Research

## Summary

Phase 6 already froze the policy. The remaining Phase 7 work is not discovery-heavy; it is alignment work. The repo already defaults `make dev` to cloud mode, so the main risk is residual wording and compatibility-profile drift that still frames Docker-backed local infra as a normal default lane.

## Observed Repo State

- Root `Makefile` already routes `make dev` through `WORKSPACE_DEV_MODE=cloud`.
- `profiles/default.env` already encodes the canonical no-Docker path.
- `profiles/local-cloud.env`, `profiles/local-lite.env`, and `profiles/local-full.env` remain as compatibility-oriented variants and should be labeled accordingly.
- `scripts/dev-workspace.sh` still has a few summary lines and fallback warnings that can be tightened.
- `scripts/down-screenalytics-infra.sh` still describes `dev-local` infra generically instead of as explicit fallback infra.

## Recommendation

Make Phase 7 a narrow execution slice:

1. Align root help and target comments with the preferred/fallback contract.
2. Tighten profile headers and any shared profile-facing wording so the default profile is unmistakably canonical.
3. Reword the last Screenalytics local-infra messages so unrelated backend/app work is obviously not Docker-gated.

## Risks

- Over-correcting by removing fallback modes would violate the milestone boundary.
- Leaving compatibility profile names undocumented would preserve ambiguity.

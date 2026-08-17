# Stage 3 Exact-Cohort Candidate Evidence

Candidate cohort: workspace `38515ecbd55821e724d7fdf9714671357a454068`, backend `44e2402def63bb4d7e2f37d26e5d7f0626b2fd73`, and app `c9b842d958c2d46623c4bf112d251df99d364012`.

| Checkpoint | Result | Evidence |
| --- | --- | --- |
| 1. Source changes | Pass | No product source changed. The nine base release packets were regenerated once, with repository candidate revisions and deterministic owned-path/diff digests recomputed from the exact cohort. Only these base packets changed: `local-foundation-runtime-guards`, `local-identity-canonical-routes`, `local-covered-shows`, `local-networks-streaming`, `local-recent-people-external-ids`, `local-person-media`, `local-season-survey-roles`, `local-social-freshness`, and `local-show-presentation-extractions`. The 18 immutable PREVIEW/GATE4 successor JSONs and their 18 matching preview-data approval evidence JSONs were preserved byte-for-byte through tracked moves to `docs/workspace/superseded-release-packets/` and `docs/workspace/superseded-architecture-evidence/`. They remain repository history but are outside active candidate discovery. The active inventory is exactly nine packets and 15 evidence records. The parked-work manifest remains unchanged. |
| 2. Terminal tests | Pass | **New Stage 3 E9 app recertification:** the exact remote-main parent pages measure 12,034 lines (`[showId]/page.tsx`) and 6,864 lines (`[showId]/seasons/[seasonNumber]/page.tsx`). All 16 extracted show-page components/helpers recorded by `local-show-presentation-extractions` are present. Independent T6 freshly ran the packet-owned focused show-presentation suite: 31 files and 128 tests passed. `make app-validate-quick` ran exactly `apps/web/tests/validation.test.ts`, `apps/web/tests/shared-env-contract.test.ts`, and `apps/web/tests/safe-next-build.test.ts`: 3 files, 14 tests passed; no production build was invoked. `python3 scripts/architecture/check-import-graph.py --check-zero`: backend 539 modules/1,464 edges and app 1,136 modules/2,982 edges, with zero prohibited cycles. `make openapi-v2-contract-check` passed: backend OpenAPI, the app snapshot, and generated v2 app types are in parity. `python3 scripts/app-direct-sql-inventory.py --check --fail-expired` passed. `make architecture-hotspots-check`: 148 tracked. `make architecture-guard-tests`: 156 passed. The standard clean-candidate target passed with 9 packets and 15 evidence records. `make architecture-durable-candidate-check`: `required=46 tracked=46 untracked=0`. |
| 3. Merged commits | Pass | The candidate contains the exact three merged remote-main source commits above. All three clean copies were rechecked against `origin/main` before packet regeneration and after validation. The Stage 3 evidence-only PR branch is based directly on workspace `38515ecb`; backend and app remain clean at their recorded commits. No provider, deployment, preview, production, or merge action was performed. |
| 4. Preview result | Placeholder | Not run. A preview remains separately cost-approval-gated; no preview resources, provider state, browser session, or teardown action was created. |
| 5. Production result | Placeholder | Not run. Production deployment, observation, database/provider mutation, and rollback authority remain separate user decisions. |

The ordinary clean-candidate target discovers the same Stage 3 candidate inventory and passes without a special packet-selection override. The explicit command below independently documents the exact nine-packet/15-evidence membership and produces the same result:

```text
TRR-Backend/.venv/bin/python scripts/architecture/check-release-manifests.py --clean-candidate \
  --packet docs/workspace/release-packets/local-foundation-runtime-guards.json \
  --packet docs/workspace/release-packets/local-identity-canonical-routes.json \
  --packet docs/workspace/release-packets/local-covered-shows.json \
  --packet docs/workspace/release-packets/local-networks-streaming.json \
  --packet docs/workspace/release-packets/local-recent-people-external-ids.json \
  --packet docs/workspace/release-packets/local-person-media.json \
  --packet docs/workspace/release-packets/local-season-survey-roles.json \
  --packet docs/workspace/release-packets/local-social-freshness.json \
  --packet docs/workspace/release-packets/local-show-presentation-extractions.json \
  --evidence docs/workspace/architecture-evidence/local-foundation-runtime-guards.workspace-focused.json \
  --evidence docs/workspace/architecture-evidence/local-identity-canonical-routes.app-focused.json \
  --evidence docs/workspace/architecture-evidence/local-identity-canonical-routes.backend-focused.json \
  --evidence docs/workspace/architecture-evidence/local-covered-shows.app-focused.json \
  --evidence docs/workspace/architecture-evidence/local-covered-shows.backend-focused.json \
  --evidence docs/workspace/architecture-evidence/local-networks-streaming.app-focused.json \
  --evidence docs/workspace/architecture-evidence/local-networks-streaming.backend-focused.json \
  --evidence docs/workspace/architecture-evidence/local-recent-people-external-ids.app-focused.json \
  --evidence docs/workspace/architecture-evidence/local-recent-people-external-ids.backend-focused.json \
  --evidence docs/workspace/architecture-evidence/local-person-media.app-focused.json \
  --evidence docs/workspace/architecture-evidence/local-person-media.backend-focused.json \
  --evidence docs/workspace/architecture-evidence/local-season-survey-roles.app-focused.json \
  --evidence docs/workspace/architecture-evidence/local-season-survey-roles.backend-focused.json \
  --evidence docs/workspace/architecture-evidence/local-social-freshness.backend-focused.json \
  --evidence docs/workspace/architecture-evidence/local-show-presentation-extractions.app-focused.json
```

Result: `architecture-release-manifests: OK clean-candidate packets=9 evidence=15`.

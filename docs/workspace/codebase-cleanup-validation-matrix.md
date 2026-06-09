# TRR Codebase Cleanup Validation Matrix

Use this matrix for cleanup slices from
`.plan-work/plan-architect/trr-codebase-cleanup-20260519/REVISED_PLAN.md`.
That `.plan-work` artifact is context only; revalidate it against the current
branch, dirty tree, and active user request before using it as implementation
authority.
The goal is small but adequate validation for each task. Do not run broad
workspace validation unless the slice crosses ownership boundaries or the
targeted checks leave behavior uncertain.

## Current Validation Status: 2026-05-21

The current active cleanup slice is backend social route Interface deepening.
Use this status before claiming completion:

- The original inventory/hygiene docs-only slice is complete.
- Backend social route cleanup now includes route-local cache/helper Modules and
  a hosted-media SQL escaping fix.
- Focused backend Ruff passed for the active social route scope.
- Focused route-shape, season-analytics route, repository behavior, and
  hosted-media SQL tests passed: 1,139 tests in the focused backend social set.
- `TRR-Backend/tests/repositories/test_social_season_analytics.py` no longer
  blocks the focused backend pytest command.
- `make test-fast` and `make app-check` pass after the workspace
  package-manager helper fix and backend repository test cleanup.
- Browser route/API verification through `make dev-hybrid` reached
  `http://admin.localhost:3000/southern-charm/s11/social`. The page route,
  slug resolution, season lookup, social analytics, season episodes
  `limit=500`, and week-detail requests returned HTTP 200.
- Playwright visual verification through the same `make dev-hybrid` stack
  captured `/tmp/trr-admin-social-visual-after-timeout.png` and confirmed the
  admin social page no longer shows timeout/degraded analytics copy.
- The earlier `x-trr-social-analytics-source: backend-timeout-degraded`
  response is not acceptable as the normal admin page state. Normal analytics
  now uses the default proxy timeout tier, and the client snapshot timeout now
  allows the bounded backend request window to complete.
- The season episodes proxy 500 was fixed by aligning the backend route limit
  with the app's `limit=500` request.
- The social week-detail timeout mismatch was fixed by giving the backend
  week-detail route a route-specific 45s cap, keeping server work bounded
  while the app proxy's 40s timeout tier owns the operator-facing timeout.
- SocialBlade migration drift is resolved for the inspected RLS chain:
  migration ownership lint passes, runtime reconcile reports no pending local or
  remote-only migrations, and the live DB has applied `20260517191631`,
  `20260518005750`, and `20260518124500`.
- Static backend dirty-diff review found blocking Instagram repair regressions
  outside the route cleanup extraction. Treat those auth/ops changes as
  blockers before promoting the broader backend dirty diff.

## Selection Rules

1. Identify every touched surface before choosing commands.
2. Run the smallest check that proves the changed surface still works.
3. Add browser smoke only when a route, page, component, visible status, or
   runtime startup behavior changes.
4. Add DB, migration, Modal, or generated-artifact checks only when that
   surface is touched.
5. Escalate to `make test-full` only when a cross-repo contract changes, a
   targeted check fails without a narrow explanation, or multiple high-risk
   surfaces change in one slice.

For TRR browser verification, start the workspace with `make dev-hybrid`
unless the user explicitly asks for another target. `make dev-hybrid` keeps
the app and backend local while using the safe hybrid social-worker caps.

## Validation Matrix

| Cleanup work type | Examples | Minimum validation target | Add when relevant | Evidence to capture |
|---|---|---|---|---|
| Backend route or domain extraction | Moving route-local parsing, response shaping, social orchestration, repository calls, or media helpers inside `TRR-Backend/api` or `TRR-Backend/trr_backend` | Focused Ruff plus the narrowest pytest target that proves the touched Interface. For the active social route slice: `cd TRR-Backend && ./.venv/bin/ruff check api/routers/socials trr_backend/socials/social_season_analytics_impl.py tests/api/routers tests/repositories` and `cd TRR-Backend && ./.venv/bin/python -m pytest tests/api/routers/test_socials_route_shape.py tests/api/routers/test_socials_season_analytics.py tests/repositories/test_social_season_analytics.py` | Add `tests/repositories/test_social_hosted_media_sql.py` when present; add `cd TRR-Backend && make repo-map-check` after backend file moves or package ownership changes; escalate to `make test-fast` before completing a broad route cleanup slice | Touched Interface, pytest target, pass/fail, and whether route shapes stayed unchanged |
| Backend repository or DB-lane cleanup | Repository module cleanup, SQL call path cleanup, direct/session DB lane handling, env-sensitive backend behavior | `make test-env-sensitive` when runtime DB lane behavior is touched; otherwise run the focused backend pytest target for the repository area | `make preflight-strict` if workspace startup/runtime env contracts changed | DB lane involved, env contract impact, target database class if any, and command result |
| Web-app route or feature extraction | Splitting large admin pages, route handlers, feature components, or server proxy modules under `TRR-APP/apps/web` | `make app-check` | `pnpm -C TRR-APP/apps/web run test -- <focused test>` when touched code has matching Vitest coverage; `pnpm -C TRR-APP/apps/web run test` when several web feature areas changed | Visible URL preserved, focused test target if used, app-check result |
| Route or browser-visible behavior | Admin/public route folders, route aliases, page shell, component state visible in browser, status text, browser smoke scripts | Start with `make dev-hybrid`, then run `make browser-smoke-admin-details` for covered admin detail routes | Add a manual Browser smoke for routes not covered by `make browser-smoke-admin-details`; add `make app-check` if web code changed | Startup target, route URLs checked, visible result, smoke command result |
| Workspace runtime or startup cleanup | Root `Makefile`, `scripts/dev-workspace.sh`, preflight scripts, profiles, env contract docs, workspace health scripts | `make workspace-contract-check` | `make preflight-strict` for startup or env-contract changes; `make status` when process health reporting changed | Runtime mode affected, command result, any warnings kept intentionally |
| Generated artifact policy or generator changes | Admin API references, repository maps, brand font artifacts, schema docs, generated inventories | Run the generator's check command, not hand edits to generated output: `pnpm -C TRR-APP/apps/web run generated:check` for web generated artifacts; `cd TRR-Backend && make repo-map-check` for backend repo maps | `cd TRR-Backend && make schema-docs-check` only when schema-doc generation or schema docs are intentionally touched against an approved validation database | Generator source touched, generated check result, whether generated files changed intentionally |
| DB migration or schema cleanup | Supabase migrations, schema docs, migration ownership, app migration wrappers | `make migration-ownership-lint` | For migration replay, use an isolated Supabase branch or disposable DB and run `supabase db push --db-url "$TRR_DB_URL" --include-all && cd TRR-Backend && make schema-docs-check`; do not use a shared persistent database for destructive replay | Migration IDs, validation database class, lint/check result, docs updated |
| Modal-affecting cleanup | Social worker dispatch, scraper jobs, Modal readiness, Modal secret-preparation, remote social-worker caps | Run the focused backend or workspace test first, then verify readiness with `cd TRR-Backend && ./.venv/bin/python scripts/modal/verify_modal_readiness.py --json --probe-remote-auth instagram` before completion | Send/deploy Modal-affecting changes on completion unless the user explicitly scoped the task local-only; add `--probe-getty-remote-access` only for Getty transport work | Modal surface touched, readiness/deploy command, remote auth or worker probe result |
| Cross-repo contract cleanup | Backend route shape plus web proxy/client shape, auth/session contracts, shared admin API behavior | Backend focused pytest plus `make app-check` plus `make test-changed` | Browser smoke with `make dev-hybrid` when the contract is route-visible; DB checks when persistence shape changed | Backend and web owners, route/API shape, all command results |
| Docs-only cleanup | Cleanup inventory, acceptance tracking, ownership notes, policy docs without runtime/source changes | No code validation required | `make workspace-contract-check` only if docs are referenced by workspace contract checks or generated status | File path, reason code validation was not needed, reviewed source plan |

## First Follow-Up Acceptance Tracker

These are the four handoff lanes from the approved plan. Each cleanup task
should record its acceptance evidence in the task or PR description before
claiming completion.

| Follow-up lane | Acceptance check | Required validation evidence |
|---|---|---|
| Backend ownership inventory and first Module-deepening slices | Inventory names current route/domain owners before code moves, and the first social route slice finishes before another backend route slice starts | Focused backend Ruff/pytest for `api/routers/socials`, hosted-media SQL test when present, `make test-fast`, `make app-check`, and `cd TRR-Backend && make repo-map-check` if files move |
| Web-app route-to-feature inventory and first extraction slices | Inventory maps routes to feature owners, preserves all visible URLs, and the first two slices split behavior without route renames | `make app-check`; focused `pnpm -C TRR-APP/apps/web run test` target when coverage exists; browser smoke through `make dev-hybrid` when visible behavior changes |
| Workspace hygiene follow-up | Top-level `apps/web` fragment reference check is recorded, `.DS_Store` cleanup is limited to proven stray files, backend `.locks/` are protected, and generated/runtime artifact policy says what not to hand-edit | `rg "apps/web/src/lib/fonts/brand-fonts/glyph-comparison" .`; `make codex-check`; `make workspace-contract-check` |
| Validation matrix follow-up | Matrix maps cleanup work types to small validation targets and names escalation rules | Documentation review only; no code validation required for this doc-only slice |

## Active Backend Social Slice Evidence Checklist

Record these before marking the current social route cleanup complete:

- Focused Ruff result for `api/routers/socials`,
  `trr_backend/socials/social_season_analytics_impl.py`, and focused tests.
- Focused pytest result for social route shape, season analytics route behavior,
  social analytics repository behavior, and hosted-media SQL escaping when the
  test file exists.
- Resolution or explicit split of the
  `tests/repositories/test_social_season_analytics.py` failure cluster.
  Status: resolved for the focused backend social route acceptance gate.
- `make test-fast` final result after the repository blocker is resolved or
  split.
  Status: passed.
- `make app-check` final result after the latest backend/app contract changes.
  Status: passed.
- Browser result for the admin social page with startup target `make dev-hybrid`.
  Status: passed with Playwright screenshot-backed verification.
- Explicit disposition for the episodes proxy HTTP 500 and week-detail timeout:
  fixed, split into a runtime bug slice, or documented as unrelated data/runtime
  state. Status: both fixed in the active cleanup slice and verified as HTTP
  200 in the Browser route/API pass.

## Escalation Triggers

Run broader validation only when one of these is true:

- A slice touches both backend route shape and web-app client/proxy behavior.
- A route alias, typo-like route, or public/admin URL is renamed or removed.
- SQL, migration order, DB lane selection, or env projection changes.
- Modal worker dispatch, scraper behavior, or Modal secret-preparation changes.
- A generator source changes and generated output must be refreshed.
- A targeted check fails and the failure is not clearly unrelated to the slice.

Preferred escalation order:

1. Add the next nearest focused test for the touched surface.
2. Run `make test-changed` for cross-repo or mixed-surface slices.
3. Run `make test-full` only for broad behavior uncertainty or release-grade
   cleanup milestones.

## Completion Notes

- Modal updates are not needed for docs-only, inventory-only, or local web-only
  cleanup unless Modal-affecting backend, worker, scraper, job, runtime, or
  secret-preparation code changes.
- Browser verification must report the startup target used. For normal TRR
  browser smoke, that target is `make dev-hybrid`.
- Generated artifacts should be regenerated from their source generator or
  explicitly documented as intentionally checked in; do not hand-edit generated
  output as the cleanup fix.

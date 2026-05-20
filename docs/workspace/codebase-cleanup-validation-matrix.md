# TRR Codebase Cleanup Validation Matrix

Use this matrix for cleanup slices from
`.plan-work/plan-architect/trr-codebase-cleanup-20260519/REVISED_PLAN.md`.
The goal is small but adequate validation for each task. Do not run broad
workspace validation unless the slice crosses ownership boundaries or the
targeted checks leave behavior uncertain.

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
| Backend route or domain extraction | Moving route-local parsing, response shaping, social orchestration, repository calls, or media helpers inside `TRR-Backend/api` or `TRR-Backend/trr_backend` | `cd TRR-Backend && ./.venv/bin/python -m pytest tests/api tests/repositories tests/socials -q` scoped further when a narrower test file proves the touched Interface | `cd TRR-Backend && make repo-map-check` after backend file moves or package ownership changes | Touched Interface, pytest target, pass/fail, and whether route shapes stayed unchanged |
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
| Backend ownership inventory and first Module-deepening slices | Inventory names current route/domain owners before code moves, and the first two slices identify the Interface under test | Focused backend pytest target chosen from `tests/api`, `tests/repositories`, or `tests/socials`; `cd TRR-Backend && make repo-map-check` if files move |
| Web-app route-to-feature inventory and first extraction slices | Inventory maps routes to feature owners, preserves all visible URLs, and the first two slices split behavior without route renames | `make app-check`; focused `pnpm -C TRR-APP/apps/web run test` target when coverage exists; browser smoke through `make dev-hybrid` when visible behavior changes |
| Workspace hygiene follow-up | Top-level `apps/web` fragment reference check is recorded, `.DS_Store` cleanup is limited to proven stray files, and generated/runtime artifact policy says what not to hand-edit | `rg "apps/web/src/lib/fonts/brand-fonts/glyph-comparison" .`; `make codex-check`; `make workspace-contract-check` |
| Validation matrix follow-up | Matrix maps cleanup work types to small validation targets and names escalation rules | Documentation review only; no code validation required for this doc-only slice |

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

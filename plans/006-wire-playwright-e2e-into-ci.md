# Plan 006: Run the Playwright e2e smoke suite in CI (it is installed but never executed)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the next
> step. If anything in the "STOP conditions" section occurs, stop and report — do
> not improvise. When done, update the status row for this plan in
> `plans/README.md` — unless a reviewer dispatched you and told you they maintain
> the index.
>
> **Drift check (run first)**: from `TRR-APP/`, run
> `git diff --stat 83778e5c..HEAD -- .github/workflows/web-tests.yml apps/web/playwright.config.ts apps/web/package.json`
> If any changed, compare the "Current state" excerpts against live code before
> proceeding; on a mismatch treat it as a STOP condition. If SHA `83778e5c` does
> not resolve, compare excerpts by hand and note it.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: tests
- **Planned at**: commit `83778e5c` (TRR-APP), 2026-07-06

## Why this matters

The web CI installs the Playwright Chromium binary on every full-lane run but
never actually runs the e2e suite — it only runs vitest unit tests. There are 8
committed e2e specs (admin breadcrumbs, cast tabs, modal keyboard nav, global
header menu, show-tab deep-links, homepage visual smoke) that are effectively
dead in CI: a broken admin deep-link or a keyboard trap ships uncaught, and the
Chromium install step is wasted setup. Wiring the suite in — following the repo's
own "add as non-blocking, then flip to blocking once green" convention — turns
existing test assets into real regression coverage at near-zero cost.

## Current state

- `.github/workflows/web-tests.yml` — single matrix lane (`node-version: 24`,
  `lane: full`). Relevant steps (line numbers as of planned-at SHA):
  - line 66-68: installs Chromium only on the full lane:
    ```yaml
    - name: Install Playwright Chromium (Node 24 full lane)
      if: matrix.lane == 'full'
      run: pnpm exec playwright install chromium
    ```
  - line 69-71: runs unit tests (vitest), NOT e2e:
    ```yaml
    - name: Run unit tests (Node 24 full lane)
      if: matrix.lane == 'full'
      run: pnpm run test:ci
    ```
  - There is **no** step invoking `pnpm run test:e2e` or `playwright test`
    anywhere in the file. The workflow already sets a precedent for non-blocking
    checks (the "Run full typecheck (non-blocking)" step uses
    `continue-on-error: true`).

- `apps/web/package.json` scripts (verified):
  - `test:e2e` = `playwright test -c playwright.config.ts`
  - `test:e2e:cast:live` = `E2E_CAST_LIVE=1 playwright test ...` (a live variant —
    do NOT run this in CI; it hits live services).

- `apps/web/playwright.config.ts` — `testDir: "./tests/e2e"`; in non-live mode it
  starts its own dev server via a `webServer` block
  (`command: ... pnpm exec next dev --webpack -p ${PORT}` with
  `NEXT_PUBLIC_DEV_ADMIN_BYPASS=true` and `reuseExistingServer: false`). So
  `pnpm run test:e2e` is self-contained — it boots the app itself; CI does not
  need a separate server step.

- e2e specs in `apps/web/tests/e2e/`: `admin-breadcrumbs.spec.ts`,
  `admin-cast-tabs-smoke.spec.ts`, `admin-cast-tabs-live-smoke.spec.ts` (live —
  guarded by `E2E_CAST_LIVE`), `admin-dashboard-utility-copy.spec.ts`,
  `admin-global-header-menu.spec.ts`, `admin-modal-keyboard.spec.ts`,
  `admin-show-tabs-deeplink.spec.ts`, `homepage-visual-smoke.spec.ts`, plus
  `admin-fixtures.ts` (shared helper, not a spec).

- **Convention**: this workflow gates only proven-green checks and lands newer
  checks as `continue-on-error: true` first (see the full-typecheck step's
  comment: "surfaces the remaining errors without blocking merges. Flip to
  blocking once green.").

## Commands you will need

Run from `TRR-APP/`.

| Purpose | Command | Expected on success |
|---|---|---|
| Install browser (once, local) | `pnpm -C apps/web exec playwright install chromium` | exit 0 |
| Run e2e locally | `pnpm -C apps/web run test:e2e` | suite runs; report pass/fail per spec |
| YAML sanity | `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/web-tests.yml'))"` | exit 0 (valid YAML) |

## Scope

**In scope**:
- `.github/workflows/web-tests.yml` (add one e2e step)

**Out of scope**:
- The Playwright config, the specs themselves, and `package.json` scripts — do
  not modify them. If a spec is flaky or broken, record it in your report; do not
  edit specs in this plan.
- The live cast spec / `E2E_CAST_LIVE` path — never enable it in CI.
- Any other CI job or the backend workflow.

## Git workflow

- Branch: `advisor/006-wire-playwright-e2e-into-ci`
- Conventional-commit messages (e.g. `ci(web): run playwright e2e smoke (non-blocking)`).
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Establish local baseline — do the specs pass without a backend?

Install the browser and run the suite locally first. **Run it from a checkout
that does NOT have a populated `.env`** (or temporarily unset `TRR_API_URL`), so
your baseline reflects what CI actually has — CI supplies no running backend. The
webServer sets `NEXT_PUBLIC_DEV_ADMIN_BYPASS=true`, so admin auth is bypassed;
the open question this step answers is whether the admin specs pass when their
backend/Firebase calls have no real target.

```
pnpm -C apps/web exec playwright install chromium
pnpm -C apps/web run test:e2e
```

Record which specs pass and which fail. The `E2E_CAST_LIVE`-gated live spec
skips automatically (`admin-cast-tabs-live-smoke.spec.ts` does
`test.skip(!LIVE_ENABLED)` in `beforeEach`), so it will not fail for missing
creds — confirm it shows as skipped.

**Verify**: capture the per-spec result and note explicitly **which specs need a
backend/Firebase to pass**. If a meaningful set of non-live specs cannot pass
without a backend, that is the key finding: the CI step (Step 2) will report them
as failures under `continue-on-error`, and the "flip to blocking" follow-up is
not reachable until either those specs are made backend-independent or CI gets a
stubbed backend. Do not treat that as a plan failure — record it. STOP and report
only if the suite cannot even boot its own dev server locally.

### Step 2: Add a non-blocking e2e step to the full lane

Insert a new step in `.github/workflows/web-tests.yml` immediately after the
"Run unit tests (Node 24 full lane)" step, mirroring the repo's non-blocking
pattern **and** the placeholder env the existing Build step already injects
(`web-tests.yml` ~72-83 sets placeholder Firebase/`TRR_API_URL` values — copy the
same `env:` block so the dev server the specs boot has the config it expects):

```yaml
      - name: Run Playwright e2e smoke (Node 24 full lane, non-blocking)
        if: matrix.lane == 'full'
        continue-on-error: true
        run: pnpm run test:e2e
        env:
          # Mirror the placeholder env the Build step uses (~web-tests.yml:72-83)
          # so the self-started next-dev server has the config it expects. Copy
          # the actual keys/values from that Build step — do not invent new ones.
          TRR_API_URL: http://127.0.0.1:8000
          # ...plus the NEXT_PUBLIC_FIREBASE_* placeholders from the Build step.
```

Read the real Build step and copy its exact `env:` keys rather than guessing.
Keep `continue-on-error: true` — this matches the workflow's convention for
newly-added checks and avoids blocking merges on residual flake or on specs that
need a backend CI doesn't have. (The Chromium install step at ~line 66 already
satisfies the browser dependency; do not duplicate it.)

**Verify**: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/web-tests.yml'))"` → exit 0. Confirm via `git diff` that the only change is the
added step (6-space indentation matching surrounding steps; the step inherits
`defaults.run.working-directory: apps/web`, so `pnpm run test:e2e` needs no
`-C`).

### Step 3: Confirm the step's command resolves

The workflow's `defaults.run.working-directory` is `apps/web`, so `pnpm run test:e2e`
runs there. Double-check the script exists:

```
node -e "const s=require('./apps/web/package.json').scripts; if(!s['test:e2e']) throw new Error('missing test:e2e'); console.log(s['test:e2e'])"
```

**Verify**: prints `playwright test -c playwright.config.ts`.

## Test plan

- No new tests are written; this plan activates the existing e2e suite in CI.
- Verification is the local run in Step 1 plus the YAML validity check in Step 2.
- The step is intentionally non-blocking on first landing (repo convention); a
  follow-up flips it to blocking once it is green across several CI runs.

## Done criteria

ALL must hold:

- [ ] `.github/workflows/web-tests.yml` contains a step running `pnpm run test:e2e`
      gated on `matrix.lane == 'full'` with `continue-on-error: true`
- [ ] `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/web-tests.yml'))"` → exit 0
- [ ] Local `pnpm -C apps/web run test:e2e` baseline captured in the report,
      including which specs (if any) need a backend to pass
- [ ] `git status` in the `TRR-APP` tree shows only
      `.github/workflows/web-tests.yml` modified (note: `plans/README.md` lives
      in the separate `trr-workspace` root tree, not this one)
- [ ] `plans/README.md` status row updated
- [ ] **Acknowledged, not verifiable in-scope**: the workflow triggers only on
      `pull_request` (no `push` trigger), and this plan does not open a PR, so
      you cannot observe the new step actually run in CI. The done criteria above
      are the achievable proof; the CI run is confirmed by whoever opens the PR.

## STOP conditions

Stop and report back if:

- The workflow steps differ from the "Current state" excerpts (drift) — e.g. an
  e2e step already exists, or the Chromium install step is gone.
- The local e2e run in Step 1 cannot boot the dev server at all (config-level
  problem outside this plan's scope).
- The suite requires secrets/live services to run the non-live specs — report
  what it needs instead of adding secrets to CI.

## Maintenance notes

- Follow-up: after the step is green across a handful of CI runs, flip
  `continue-on-error` to `false` (or remove it) to make e2e blocking — same
  lifecycle the repo used for the full-typecheck step.
- If any single spec proves flaky in CI, quarantine just that spec (`test.skip`
  or a `.fixme`) rather than reverting the whole step. Note:
  `homepage-visual-smoke.spec.ts` does NOT use `toHaveScreenshot`/snapshot
  baselines (it asserts DOM/visibility), so it is not a pixel-diff flake risk —
  the more likely flake source is any admin spec that depends on a backend CI
  doesn't provide (see Step 1).
- A reviewer should confirm the live cast spec is not enabled (no
  `E2E_CAST_LIVE=1` in the workflow) and that the step honors the
  `apps/web` working directory.

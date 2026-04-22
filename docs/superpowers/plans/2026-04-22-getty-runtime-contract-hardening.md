# Getty Runtime Contract Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Getty transport diagnostics truthful and non-blocking across workspace startup, backend readiness checks, and admin image-launch flows, while preserving the repo’s real production contract: local Getty prefetch is the canonical path, and remote Getty availability is only a transport capability, not a prerequisite for `make dev`.

**Current proven state:** The immediate startup blocker has already been narrowed and patched locally: `make dev` was failing because `TRR-Backend/scripts/modal/reconcile_modal_runtime.py` folded `probe_getty_remote_access` into blocking Modal readiness. Direct evidence showed:

- `scripts/modal/verify_modal_readiness.py --json --probe-remote-auth instagram` returned `ok: true`
- adding `--probe-getty-remote-access` flipped the result to `ok: false`
- the failure reason was specifically `getty_remote_probe.reason = "challenge_page"`
- the existing Getty local-status doc already says live Modal Getty is not the normal viable path, and app-launched Getty work should use local prefetch

**Architecture:** Fix this in three layers that currently disagree with each other. First, split backend Modal readiness into core blocking readiness versus optional Getty transport diagnostics. Second, surface Getty transport health in `make status` and related status artifacts without making startup fail or regress back into noisy startup attention. Third, remove the app-side launcher shortcut that currently skips the canonical local-prefetch path when a lossy remote-readiness check reports healthy, and instead always run the existing local Getty prefetch flow in `auto` transport mode so the runtime itself chooses `decodo_remote` or `local_browser`.

**Tech Stack:** Python CLI scripts, Modal SDK, Bash workspace scripts, FastAPI-adjacent backend tooling, Next.js App Router admin launchers, Vitest, pytest

---

## Working Rules

- Do not treat a Getty `challenge_page` as proof that the Modal app is undeployed or that shared-account/social Modal readiness is broken.
- Preserve the existing meaning of "Modal readiness" for social/admin rollout work:
  - deployed app exists
  - named secrets exist
  - required functions resolve
  - Instagram remote auth probe can still succeed when requested
- Keep Getty transport health visible. The fix is not to hide it; the fix is to stop misclassifying it.
- Preserve the repo’s documented Getty execution contract:
  - app-launched Getty/NBCUMV work should use local prefetch
  - local prefetch may use remote Getty transport when healthy
  - local prefetch must fall back to `local_browser` when remote Getty is blocked
- Prefer additive contract changes. Existing consumers of `verify_modal_readiness.py --json` that only care about Modal core readiness should remain valid.

---

## Problem Statement

There are three separate contract mismatches to fix:

1. `TRR-Backend/scripts/modal/verify_modal_readiness.py` currently lets optional Getty probing collapse the whole readiness result into `ok: false`, even though the same repo treats live Modal Getty as non-canonical for app-launched Getty work.
2. `TRR-APP/apps/web/src/lib/server/admin/getty-local-scrape.ts` shells out to `verify_modal_readiness.py --json --probe-getty-remote-access` using `execFile(...)`. When the script exits non-zero, the app catches that as a generic error and rewrites the real Getty state into `reason: "probe_unavailable"`, losing the actual `challenge_page` result.
3. The admin image launchers in `TRR-APP` currently branch on that remote-readiness call. If the remote probe looks healthy they skip local prefetch entirely, even though the repo’s documented normal path is local prefetch with runtime-selected transport.

The result is a bad operator story:

- startup can fail for the wrong reason
- the app diagnostics lose the true Getty failure reason
- launchers can bypass the canonical local-prefetch path based on a separate pre-check instead of letting the real prefetch runtime choose transport

---

## File Map

- Modify: `TRR-Backend/scripts/modal/verify_modal_readiness.py`
  Purpose: split core blocking readiness from optional Getty transport diagnostics.
- Modify: `TRR-Backend/tests/scripts/test_verify_modal_readiness.py`
  Purpose: lock the new readiness/probe contract and exit semantics.
- Modify: `TRR-Backend/scripts/modal/reconcile_modal_runtime.py`
  Purpose: consume the new backend contract instead of relying on an implicit Getty probe side effect.
- Modify: `TRR-Backend/tests/scripts/test_reconcile_modal_runtime.py`
  Purpose: keep startup gating pinned to core Modal readiness only.
- Modify: `scripts/workspace_runtime_reconcile.py`
  Purpose: persist non-blocking Getty transport diagnostics in the runtime-reconcile artifact without turning the whole workspace state into blocked.
- Modify: `scripts/status-workspace.sh`
  Purpose: show Getty transport health explicitly in `make status`.
- Modify: `scripts/test_workspace_runtime_reconcile.py`
  Purpose: prove advisory Getty diagnostics do not flip overall startup status to blocked.
- Modify: `TRR-APP/apps/web/src/lib/server/admin/getty-local-scrape.ts`
  Purpose: stop collapsing real Getty probe failures into `probe_unavailable` and narrow remote-readiness usage to diagnostics instead of launch gating.
- Modify: `TRR-APP/apps/web/src/app/admin/trr-shows/people/[personId]/PersonPageClient.tsx`
  Purpose: always use the canonical local Getty prefetch path for person refreshes.
- Modify: `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/page.tsx`
  Purpose: always use the canonical local Getty prefetch path for show-level cast refreshes.
- Modify: `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/seasons/[seasonNumber]/page.tsx`
  Purpose: always use the canonical local Getty prefetch path for season-level cast refreshes.
- Modify: `TRR-APP/apps/web/tests/getty-local-scrape-route.test.ts`
  Purpose: cover the server-side remote-readiness payload shape if route behavior changes.
- Modify: `TRR-APP/apps/web/tests/show-person-refresh-getty-prefetch-wiring.test.ts`
  Purpose: update the static contract assertions so they no longer require launchers to branch on `getGettyRemoteReadiness()`.
- Modify: `TRR-APP/apps/web/tests/person-refresh-request-id-wiring.test.ts`
  Purpose: same as above for person refresh request wiring.
- Modify: `TRR-APP/apps/web/tests/season-cast-tab-quality-wiring.test.ts`
  Purpose: same as above for season cast refresh wiring.
- Modify: `docs/workspace/dev-commands.md`
  Purpose: document the new separation between core Modal readiness and Getty transport diagnostics.
- Modify: `TRR-Backend/docs/runbooks/social_worker_queue_ops.md`
  Purpose: keep operator guidance honest about what "Modal readiness" proves.
- Modify: `docs/ai/local-status/getty-person-pipeline-and-event-subcategories.md`
  Purpose: append the new contract and note that workspace startup no longer treats Getty challenge pages as Modal outage evidence.

---

## Acceptance Targets

- `./.venv/bin/python scripts/modal/verify_modal_readiness.py --json` still reports core Modal readiness in a backward-compatible way for existing rollout docs.
- `./.venv/bin/python scripts/modal/verify_modal_readiness.py --json --probe-getty-remote-access` returns a parseable Getty probe payload without forcing generic CLI consumers to treat the whole result as a core-readiness failure.
- If Getty is blocked but Modal core is healthy:
  - startup runtime reconcile does not block `make preflight` or `make dev`
  - `make status` still shows the Getty probe reason, including `challenge_page`
- App-side Getty launchers no longer skip local prefetch solely because a separate remote-readiness probe looked healthy.
- The actual launcher path becomes:
  - local prefetch helper always runs for Getty-backed refreshes
  - transport mode `auto` decides between `decodo_remote` and `local_browser`
  - runtime probe status and fallback metadata come from the real prefetch result, not a separate pre-gate
- User-facing/operator copy no longer claims "Starting backend refresh without local prefetch" as the normal path.

---

## Phase 1: Split Core Modal Readiness From Getty Transport Diagnostics

### Task 1: Add an additive core-versus-probe contract to `verify_modal_readiness.py`

**Files:**
- Modify: `TRR-Backend/scripts/modal/verify_modal_readiness.py`
- Modify: `TRR-Backend/tests/scripts/test_verify_modal_readiness.py`

- [ ] **Step 1: Add failing backend tests that prove probe failures must not automatically equal core-readiness failure**

Add focused tests that cover:

- core resources healthy, Getty probe returns `{"ready": false, "reason": "challenge_page"}`:
  - default result keeps core readiness truthy
  - Getty probe payload remains present and truthful
- optional strict mode can still force a non-zero exit when the operator explicitly wants probes to count as failures
- Instagram auth probe remains core-significant when requested by startup/runtime reconcile

Suggested test cases:

```python
def test_verify_modal_readiness_keeps_core_ready_when_only_getty_probe_is_blocked(...):
    ...

def test_verify_modal_readiness_can_fail_strict_probe_mode_when_getty_probe_is_blocked(...):
    ...

def test_main_returns_zero_for_advisory_probe_failure_without_strict_mode(...):
    ...
```

- [ ] **Step 2: Implement additive JSON fields instead of overloading `ok` with optional-probe results**

Refactor `verify_modal_readiness(...)` so it computes at least these concepts separately:

- `core_ok`
- `core_failure_reasons`
- `probe_results`
- `blocking_probe_failures`
- `advisory_probe_failures`

Recommended contract:

- `ok` means core Modal readiness for the current command
- optional probes such as Getty stay in the payload under `getty_remote_probe`
- a new CLI flag such as `--strict-probes` or `--probe-failures-blocking` can request non-zero exit if advisory probes fail

Do not make every current consumer chase renamed fields just to preserve existing `ok=true` checks in docs and scripts.

- [ ] **Step 3: Keep the text summary honest**

Update `_print_text_summary(...)` so the operator can tell the difference between:

- core Modal readiness
- probe diagnostics
- advisory Getty transport failures

The summary should not imply that `challenge_page` means the app is undeployed or missing secrets/functions.

- [ ] **Step 4: Run the focused backend test slice**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
./.venv/bin/pytest -q tests/scripts/test_verify_modal_readiness.py
```

Expected:

- existing core readiness tests still pass
- new additive probe-policy tests pass

---

## Phase 2: Make Workspace Runtime Reconcile Preserve Getty Diagnostics Without Blocking Startup

### Task 2: Formalize Getty probe output as non-blocking runtime metadata

**Files:**
- Modify: `TRR-Backend/scripts/modal/reconcile_modal_runtime.py`
- Modify: `TRR-Backend/tests/scripts/test_reconcile_modal_runtime.py`
- Modify: `scripts/workspace_runtime_reconcile.py`
- Modify: `scripts/test_workspace_runtime_reconcile.py`
- Modify: `scripts/status-workspace.sh`

- [ ] **Step 1: Lock the desired reconcile contract in tests**

Add focused tests for this exact case:

- Modal core healthy
- Getty remote probe blocked with `challenge_page`
- reconcile result is not `blocked`
- runtime artifact still preserves the Getty probe payload for later inspection

Suggested repository test shape:

```python
def test_reconcile_modal_runtime_keeps_getty_probe_as_advisory_metadata(...):
    ...
```

Suggested workspace test shape:

```python
def test_compute_overall_state_keeps_modal_getty_probe_metadata_non_blocking(...):
    ...
```

- [ ] **Step 2: Refactor `reconcile_modal_runtime.py` to request and store Getty diagnostics intentionally**

Do not rely on "probe disabled" as the final design.

Instead:

- use the new additive readiness contract from Phase 1
- keep core readiness as the gating signal
- still capture Getty transport diagnostics into the reconcile payload

Recommended payload shape inside `artifact["modal"]`:

```json
{
  "state": "ok",
  "reason": null,
  "readiness": { ...core modal readiness... },
  "advisories": [
    {
      "kind": "getty_remote_probe",
      "reason": "challenge_page"
    }
  ],
  "getty_remote_probe": { ...full probe payload... }
}
```

- [ ] **Step 3: Surface Getty diagnostics in `make status`, not in blocking startup**

Extend `scripts/status-workspace.sh` so the `Runtime reconcile` section prints the nested Getty probe when present:

- status
- reason
- transport mode
- proxy fingerprint
- first relevant query failure if available

This keeps `make dev` minimal while still giving the operator the real failure reason in `make status`.

- [ ] **Step 4: Keep preflight/startup output slim**

Do not regress startup back into multi-line Getty diagnostics. The startup contract should remain:

- `Runtime reconcile OK` or real blocking failure
- detailed Getty transport evidence lives in `make status` and the JSON artifact

- [ ] **Step 5: Run the focused validation slice**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
./.venv/bin/pytest -q tests/scripts/test_reconcile_modal_runtime.py

cd /Users/thomashulihan/Projects/TRR
python3 -m pytest -q scripts/test_workspace_runtime_reconcile.py
make preflight
make status
```

Expected:

- `make preflight` stays green when Getty alone is blocked
- `make status` shows Getty probe details explicitly

---

## Phase 3: Remove the App-Side Getty Pre-Gate and Always Use Canonical Local Prefetch

### Task 3: Stop skipping local prefetch based on a separate remote-readiness call

**Files:**
- Modify: `TRR-APP/apps/web/src/lib/server/admin/getty-local-scrape.ts`
- Modify: `TRR-APP/apps/web/src/app/admin/trr-shows/people/[personId]/PersonPageClient.tsx`
- Modify: `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/page.tsx`
- Modify: `TRR-APP/apps/web/src/app/admin/trr-shows/[showId]/seasons/[seasonNumber]/page.tsx`
- Modify: `TRR-APP/apps/web/tests/show-person-refresh-getty-prefetch-wiring.test.ts`
- Modify: `TRR-APP/apps/web/tests/person-refresh-request-id-wiring.test.ts`
- Modify: `TRR-APP/apps/web/tests/season-cast-tab-quality-wiring.test.ts`
- Modify: `TRR-APP/apps/web/tests/getty-local-scrape-route.test.ts`

- [ ] **Step 1: Write failing app tests that prove the launcher should always use local prefetch**

Cover all three launcher surfaces:

- person page
- show page
- season page

Required assertions:

- no launcher treats `getGettyRemoteReadiness().ready === true` as permission to skip prefetch
- launchers still pass Getty transport metadata through from the prefetch result
- operator log/copy no longer says "Starting backend refresh without local prefetch"

Because there are already static wiring tests that assert `getGettyRemoteReadiness()` usage, these tests should be updated to assert the new canonical behavior instead.

- [ ] **Step 2: Narrow `getGettyRemoteReadiness()` to diagnostics-only behavior**

`TRR-APP/apps/web/src/lib/server/admin/getty-local-scrape.ts` currently does this:

- executes `verify_modal_readiness.py --json --probe-getty-remote-access`
- throws away real probe payload when the subprocess exits non-zero
- rewrites the outcome to `probe_unavailable`

Refactor it so:

- it can still parse the real Getty probe payload even when the transport is blocked
- it is no longer required for the launch path
- if retained, it becomes a diagnostics helper/route only

Do not leave the app with a diagnostics helper that loses `challenge_page` and only reports `probe_unavailable`.

- [ ] **Step 3: Make all Getty-backed launchers call the existing local prefetch helper directly**

Refactor the three admin launchers so the sequence becomes:

1. determine whether Getty prefetch is needed
2. call `prefetchGettyLocallyForPerson(...)` or the relevant local prefetch helper with the default `transportMode: "auto"`
3. merge the returned `bodyPatch` into the backend request
4. log the actual selected transport from the prefetch result

This preserves:

- remote transport when it is truly healthy
- automatic fallback to `local_browser` when remote is blocked
- one canonical code path instead of two competing readiness gates

- [ ] **Step 4: Keep user-facing copy aligned with the canonical path**

Update progress/log copy to describe:

- "Starting Getty prefetch..."
- "Getty prefetch is using remote transport..."
- "Getty prefetch fell back to local browser..."

Do not claim the healthy path is "without local prefetch" when the repo’s intended path is still local prefetch with auto-selected transport.

- [ ] **Step 5: Run the focused app validation**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web
pnpm exec vitest run \
  tests/getty-local-scrape-route.test.ts \
  tests/show-person-refresh-getty-prefetch-wiring.test.ts \
  tests/person-refresh-request-id-wiring.test.ts \
  tests/season-cast-tab-quality-wiring.test.ts
```

Expected:

- no launcher requires `getGettyRemoteReadiness()` as a hard branch
- the tests assert canonical local-prefetch wiring instead

---

## Phase 4: Docs And Operator Truth

### Task 4: Update docs so "Modal readiness" and "Getty transport health" are no longer conflated

**Files:**
- Modify: `docs/workspace/dev-commands.md`
- Modify: `TRR-Backend/docs/runbooks/social_worker_queue_ops.md`
- Modify: `docs/ai/local-status/getty-person-pipeline-and-event-subcategories.md`

- [ ] **Step 1: Update startup docs**

`docs/workspace/dev-commands.md` should explain:

- core Modal readiness and Getty transport diagnostics are different checks
- `make dev` blocks only on core readiness failures
- `make status` is where Getty transport diagnostics are surfaced

- [ ] **Step 2: Update backend operator docs**

`TRR-Backend/docs/runbooks/social_worker_queue_ops.md` should keep saying `verify_modal_readiness.py --json` proves Modal core health, but it must stop implying Getty remote accessibility is part of that same truth contract.

- [ ] **Step 3: Update the Getty local-status doc**

Append a dated note to `docs/ai/local-status/getty-person-pipeline-and-event-subcategories.md` that records:

- the workspace startup misclassification that was found
- the new contract: Getty challenge pages are transport diagnostics, not Modal outage proof
- the canonical launch path remains local prefetch with runtime-selected transport

---

## Final Validation

- [ ] `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && ./.venv/bin/pytest -q tests/scripts/test_verify_modal_readiness.py tests/scripts/test_reconcile_modal_runtime.py`
- [ ] `cd /Users/thomashulihan/Projects/TRR && python3 -m pytest -q scripts/test_workspace_runtime_reconcile.py`
- [ ] `cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && pnpm exec vitest run tests/getty-local-scrape-route.test.ts tests/show-person-refresh-getty-prefetch-wiring.test.ts tests/person-refresh-request-id-wiring.test.ts tests/season-cast-tab-quality-wiring.test.ts`
- [ ] `cd /Users/thomashulihan/Projects/TRR && make preflight`
- [ ] `cd /Users/thomashulihan/Projects/TRR && make status`
- [ ] Manual smoke after implementation:
  - start a Getty-backed person refresh from the admin UI
  - confirm local prefetch always runs
  - confirm the prefetch result chooses `decodo_remote` only when truly healthy
  - confirm blocked Getty still shows the true `challenge_page` reason instead of generic `probe_unavailable`

---

## Out Of Scope

- Solving Getty’s bot wall inside Modal so that live remote Getty becomes the default product path again.
- Replacing the existing local Getty prefetch runtime or browser/session strategy.
- Reworking the broader person-image pipeline beyond the Getty transport/readiness boundary.
- Changing unrelated social Modal readiness contracts for Instagram, TikTok, Reddit, or Google News.

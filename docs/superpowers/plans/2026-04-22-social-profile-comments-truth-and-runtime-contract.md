# Social Profile Comments Truth And Runtime Contract Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the comments coverage card truthful when saved data exists but the latest historical run failed, and replace the ad hoc low-pressure verification env tweaks with a tracked, reusable workspace runtime contract.

**Architecture:** Split the work into two narrow tracks. First, keep the raw comments-run history intact in `TRR-Backend`, but add an additive effective-status layer so the admin UI stops treating a stale failed run as the current state of the page. Second, restore `PROFILE=default` to the documented baseline and move the low-pressure scraper-debug settings into a dedicated tracked profile that `scripts/dev-workspace.sh` can project into both backend and app runtime env without requiring ignored `.env.local` edits.

**Tech Stack:** FastAPI repository layer, psycopg2 `ThreadedConnectionPool`, Next.js admin UI, Vitest, pytest, Bash workspace launch scripts, generated env-contract docs.

---

## File Map

- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`
  Purpose: compute additive comments-coverage operator truth from coverage counts plus recent run history.
- Modify: `TRR-Backend/tests/repositories/test_social_season_analytics.py`
  Purpose: lock the new effective-status semantics so stale failed runs stop poisoning the summary payload.
- Modify: `TRR-APP/apps/web/src/lib/admin/social-account-profile.ts`
  Purpose: extend the typed comments-coverage contract with additive effective-status and historical-attempt fields.
- Modify: `TRR-APP/apps/web/src/components/admin/instagram/InstagramCommentsPanel.tsx`
  Purpose: render the effective status as the headline state and move raw failed historical attempts into secondary copy.
- Modify: `TRR-APP/apps/web/tests/social-account-profile-page.runtime.test.tsx`
  Purpose: prove the card shows truthful coverage state instead of a stale `Failed` badge.
- Modify: `profiles/default.env`
  Purpose: restore the canonical default profile to the documented baseline instead of leaving verification-only throttles in the everyday profile.
- Create: `profiles/social-debug.env`
  Purpose: hold the tracked low-pressure scraper-debug runtime values used during validation.
- Modify: `scripts/dev-workspace.sh`
  Purpose: project tracked app-side Postgres sizing into the managed `TRR-APP` process so ignored `.env.local` edits are no longer required.
- Modify: `scripts/check-workspace-contract.sh`
  Purpose: assert the new default-profile and `social-debug` profile runtime contract.
- Modify: `docs/workspace/env-contract.md`
  Purpose: document the new tracked workspace vars and regenerate the generated contract after the launcher changes.
- Modify: `docs/workspace/dev-commands.md`
  Purpose: document when to use `PROFILE=social-debug make dev`.
- Modify: `docs/workspace/supabase-capacity-budget.md`
  Purpose: explain why the low-pressure profile exists and which knobs it owns.
- Modify: `docs/ai/local-status/instagram-social-profile-cold-path-gap-closure-2026-04-21.md`
  Purpose: append the caveat closeout, new status semantics, and the runtime-profile follow-up commands used for validation.

## Acceptance Targets

- The comments coverage card no longer shows `Failed` as the primary state when saved data is present and the failure is only historical.
- The backend summary payload preserves raw last-run data but also exposes additive effective-state fields the UI can trust.
- The comments card can still show `running`, `queued`, `completed`, and real current `failed` states when those are actually current.
- `PROFILE=default make dev` goes back to the documented baseline contract.
- A tracked `PROFILE=social-debug make dev` reproduces the low-pressure validation runtime without any ignored app-local env edits.
- `scripts/check-workspace-contract.sh`, `scripts/workspace-env-contract.sh --check`, targeted `pytest`, and targeted `vitest` all pass.

### Task 1: Add Backend-Derived Effective Comments Coverage Status

**Files:**
- Modify: `TRR-Backend/tests/repositories/test_social_season_analytics.py`
- Modify: `TRR-Backend/trr_backend/repositories/social_season_analytics.py`

- [ ] **Step 1: Write the failing repository regression for stale failed-run truth**

Append these tests to `TRR-Backend/tests/repositories/test_social_season_analytics.py`:

```python
def test_resolve_comments_coverage_status_demotes_historical_failed_run() -> None:
    coverage = {
        "eligible_posts": 427,
        "missing_posts": 364,
        "stale_posts": 37,
        "last_comments_run_at": "2026-04-21T23:50:01+00:00",
        "last_comments_run_status": "failed",
    }
    recent_runs = [
        {
            "run_id": "run-failed",
            "status": "failed",
            "created_at": "2026-04-21T23:50:01+00:00",
            "started_at": "2026-04-21T23:50:10+00:00",
            "completed_at": "2026-04-21T23:58:10+00:00",
            "error_message": "proxy timeout",
        }
    ]
    comments_saved_summary = {
        "saved_comments": 9912,
        "retrieved_comments": 106098,
        "saved_comment_posts": 427,
        "retrieved_comment_posts": 427,
    }

    resolved = social_repo._resolve_social_account_comments_coverage_status(
        coverage,
        recent_runs=recent_runs,
        comments_saved_summary=comments_saved_summary,
        active_run=None,
    )

    assert resolved["effective_status"] == "needs_refresh"
    assert resolved["effective_label"] == "Needs refresh"
    assert resolved["historical_failure"] is True
    assert resolved["last_attempt_status"] == "failed"


def test_resolve_comments_coverage_status_prefers_active_run() -> None:
    coverage = {
        "eligible_posts": 427,
        "missing_posts": 10,
        "stale_posts": 5,
        "last_comments_run_at": "2026-04-21T23:50:01+00:00",
        "last_comments_run_status": "failed",
    }
    active_run = {
        "run_id": "run-active",
        "status": "running",
        "created_at": "2026-04-22T00:10:00+00:00",
        "started_at": "2026-04-22T00:10:05+00:00",
        "completed_at": None,
        "error_message": None,
    }

    resolved = social_repo._resolve_social_account_comments_coverage_status(
        coverage,
        recent_runs=[active_run],
        comments_saved_summary={"saved_comments": 100, "retrieved_comments": 200, "saved_comment_posts": 2},
        active_run=active_run,
    )

    assert resolved["effective_status"] == "running"
    assert resolved["effective_label"] == "Running"
    assert resolved["historical_failure"] is False


def test_get_social_account_profile_summary_includes_effective_comments_coverage_fields(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        social_repo,
        "_resolve_social_account_comments_coverage_status",
        lambda coverage, **_kwargs: {
            **dict(coverage or {}),
            "effective_status": "needs_refresh",
            "effective_label": "Needs refresh",
            "historical_failure": True,
            "last_attempt_status": "failed",
            "last_attempt_at": "2026-04-21T23:50:01+00:00",
        },
    )
```

- [ ] **Step 2: Run the focused repository slice and verify it fails**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
./.venv/bin/python -m pytest -q tests/repositories/test_social_season_analytics.py -k "comments_coverage_status or effective_comments_coverage_fields"
```

Expected: `FAIL` because `_resolve_social_account_comments_coverage_status(...)` does not exist and the summary payload does not expose the additive effective-state fields.

- [ ] **Step 3: Implement the minimal backend truth helper and wire it into the summary payload**

Add this helper to `TRR-Backend/trr_backend/repositories/social_season_analytics.py` near `_social_account_comments_recent_runs(...)`:

```python
def _resolve_social_account_comments_coverage_status(
    coverage: Mapping[str, Any] | None,
    *,
    recent_runs: Sequence[Mapping[str, Any]] | None,
    comments_saved_summary: Mapping[str, Any] | None,
    active_run: Mapping[str, Any] | None,
) -> dict[str, Any] | None:
    if not isinstance(coverage, Mapping):
        return None

    payload = dict(coverage)
    recent_runs = list(recent_runs or [])
    active_run = dict(active_run or {}) if isinstance(active_run, Mapping) else None
    latest_run = dict(recent_runs[0]) if recent_runs else None

    missing_posts = _normalize_non_negative_int(payload.get("missing_posts"))
    stale_posts = _normalize_non_negative_int(payload.get("stale_posts"))
    eligible_posts = _normalize_non_negative_int(payload.get("eligible_posts"))
    saved_comment_posts = _normalize_non_negative_int((comments_saved_summary or {}).get("saved_comment_posts"))
    saved_comments = _normalize_non_negative_int((comments_saved_summary or {}).get("saved_comments"))

    if active_run and _status_is_active(str(active_run.get("status") or "").strip().lower() or None):
        effective_status = str(active_run.get("status") or "").strip().lower()
        effective_label = effective_status.capitalize()
        historical_failure = False
    elif missing_posts == 0 and stale_posts == 0 and eligible_posts > 0:
        effective_status = "covered"
        effective_label = "Covered"
        historical_failure = False
    elif saved_comment_posts > 0 or saved_comments > 0:
        effective_status = "needs_refresh"
        effective_label = "Needs refresh"
        historical_failure = str((latest_run or {}).get("status") or "").strip().lower() == "failed"
    elif str((latest_run or {}).get("status") or "").strip().lower() == "failed":
        effective_status = "failed"
        effective_label = "Failed"
        historical_failure = False
    else:
        effective_status = "idle"
        effective_label = "Idle"
        historical_failure = False

    payload.update(
        {
            "effective_status": effective_status,
            "effective_label": effective_label,
            "historical_failure": historical_failure,
            "last_attempt_status": str((latest_run or {}).get("status") or "").strip().lower() or None,
            "last_attempt_at": (latest_run or {}).get("completed_at") or (latest_run or {}).get("created_at"),
            "active_run_id": str((active_run or {}).get("run_id") or "").strip() or None,
        }
    )
    return payload
```

Then update the comments coverage loader block in `get_social_account_profile_summary(...)` to keep both raw and effective data:

```python
recent_comments_runs = _social_account_comments_recent_runs(
    normalized_platform,
    normalized_account,
    limit=3,
    conn=summary_conn,
)
active_comments_run = next(
    (
        row
        for row in recent_comments_runs
        if _status_is_active(str(row.get("status") or "").strip().lower() or None)
    ),
    None,
)
raw_comments_coverage = query_results.get("comments_coverage")
comments_coverage = _resolve_social_account_comments_coverage_status(
    raw_comments_coverage,
    recent_runs=recent_comments_runs,
    comments_saved_summary=comments_saved_summary,
    active_run=active_comments_run,
)
```

- [ ] **Step 4: Re-run the repository slice and verify it passes**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
./.venv/bin/python -m pytest -q tests/repositories/test_social_season_analytics.py -k "comments_coverage_status or effective_comments_coverage_fields"
```

Expected: `PASS`.

- [ ] **Step 5: Commit the backend truth slice**

```bash
cd /Users/thomashulihan/Projects/TRR
git add TRR-Backend/trr_backend/repositories/social_season_analytics.py TRR-Backend/tests/repositories/test_social_season_analytics.py
git commit -m "fix: derive effective social profile comments coverage state"
```

### Task 2: Render Effective Coverage State In The Admin Card

**Files:**
- Modify: `TRR-APP/apps/web/src/lib/admin/social-account-profile.ts`
- Modify: `TRR-APP/apps/web/src/components/admin/instagram/InstagramCommentsPanel.tsx`
- Modify: `TRR-APP/apps/web/tests/social-account-profile-page.runtime.test.tsx`

- [ ] **Step 1: Write the failing runtime test for historical failed-run rendering**

Append this test to `TRR-APP/apps/web/tests/social-account-profile-page.runtime.test.tsx`:

```tsx
it("shows needs refresh instead of failed when the latest failed run is historical", async () => {
  const summary = {
    ...baseSummary,
    comments_coverage: {
      eligible_posts: 427,
      missing_posts: 364,
      stale_posts: 37,
      last_comments_run_at: "2026-04-21T23:50:01.000Z",
      last_comments_run_status: "failed",
      effective_status: "needs_refresh",
      effective_label: "Needs refresh",
      historical_failure: true,
      last_attempt_status: "failed",
      last_attempt_at: "2026-04-21T23:50:01.000Z",
    },
    comments_saved_summary: {
      saved_comments: 9912,
      retrieved_comments: 106098,
      saved_comment_posts: 427,
      retrieved_comment_posts: 427,
      saved_comment_media_files: 0,
    },
    media_coverage: {
      saved_files: 858,
      total_files: 858,
    },
  };

  fetchMock.mockImplementation((input) => {
    const url = String(input);
    if (url.includes("/summary?detail=full")) {
      return Promise.resolve(jsonResponse(summary));
    }
    if (url.includes("/posts?page=1&page_size=25&comments_only=true")) {
      return Promise.resolve(jsonResponse({ items: [], pagination: { page: 1, page_size: 25, total: 0, total_pages: 0 } }));
    }
    return Promise.resolve(jsonResponse({}));
  });

  render(<SocialAccountProfilePage platform="instagram" handle="thetraitorsus" activeTab="comments" />);

  expect(await screen.findByText("Needs refresh")).toBeInTheDocument();
  expect(screen.getByText(/Last attempt failed/i)).toBeInTheDocument();
  expect(screen.queryByText(/^Failed$/)).not.toBeInTheDocument();
});
```

- [ ] **Step 2: Run the runtime test slice and verify it fails**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP
pnpm -C apps/web exec vitest run tests/social-account-profile-page.runtime.test.tsx -t "historical failed run"
```

Expected: `FAIL` because the panel still renders `coverage.last_comments_run_status` as the headline status.

- [ ] **Step 3: Extend the typed contract and render the additive status fields**

Update `TRR-APP/apps/web/src/lib/admin/social-account-profile.ts`:

```ts
export type SocialAccountCommentsCoverage = {
  available_posts?: number | null;
  eligible_posts: number;
  stale_posts: number;
  missing_posts: number;
  last_comments_run_at?: string | null;
  last_comments_run_status?: string | null;
  effective_status?: "idle" | "running" | "queued" | "covered" | "needs_refresh" | "failed" | string | null;
  effective_label?: string | null;
  historical_failure?: boolean | null;
  last_attempt_status?: string | null;
  last_attempt_at?: string | null;
  active_run_id?: string | null;
};
```

Update `TRR-APP/apps/web/src/components/admin/instagram/InstagramCommentsPanel.tsx`:

```tsx
const effectiveCoverageLabel = String(coverage?.effective_label || coverage?.last_comments_run_status || "idle").trim() || "idle";
const effectiveCoverageStatus = String(coverage?.effective_status || coverage?.last_comments_run_status || "idle").trim().toLowerCase();
const historicalFailure = Boolean(coverage?.historical_failure);
const lastAttemptStatus = String(coverage?.last_attempt_status || "").trim().toLowerCase();
const lastAttemptAt = coverage?.last_attempt_at ?? coverage?.last_comments_run_at;
```

Replace the current status card body with:

```tsx
<div className="rounded-2xl border border-zinc-200 bg-zinc-50 p-4">
  <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-zinc-500">Status</p>
  <p className="mt-2 text-sm font-semibold text-zinc-900">{effectiveCoverageLabel}</p>
  {historicalFailure && lastAttemptStatus === "failed" ? (
    <p className="mt-1 text-xs text-amber-700">
      Last attempt failed at {formatDateTime(lastAttemptAt)}. Saved discussion remains available.
    </p>
  ) : null}
</div>
```

- [ ] **Step 4: Re-run the runtime slice and the existing comments-page runtime suite**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-APP
pnpm -C apps/web exec vitest run tests/social-account-profile-page.runtime.test.tsx -t "historical failed run"
pnpm -C apps/web exec vitest run tests/social-account-profile-page.runtime.test.tsx
```

Expected: both commands `PASS`.

- [ ] **Step 5: Commit the UI truth slice**

```bash
cd /Users/thomashulihan/Projects/TRR
git add TRR-APP/apps/web/src/lib/admin/social-account-profile.ts TRR-APP/apps/web/src/components/admin/instagram/InstagramCommentsPanel.tsx TRR-APP/apps/web/tests/social-account-profile-page.runtime.test.tsx
git commit -m "fix: render effective comments coverage state in admin"
```

### Task 3: Replace Ad Hoc Low-Pressure Env Tweaks With A Tracked Workspace Profile

**Files:**
- Modify: `profiles/default.env`
- Create: `profiles/social-debug.env`
- Modify: `scripts/dev-workspace.sh`
- Modify: `scripts/check-workspace-contract.sh`
- Modify: `docs/workspace/dev-commands.md`
- Modify: `docs/workspace/supabase-capacity-budget.md`
- Modify: `docs/workspace/env-contract.md`

- [ ] **Step 1: Add the failing contract assertions for the tracked runtime profile**

Append these assertions to `scripts/check-workspace-contract.sh`:

```bash
extract_profile_value_from_file() {
  local file="$1"
  local key="$2"
  sed -nE "s/^${key}=(.*)$/\\1/p" "$file" | head -n 1
}

SOCIAL_DEBUG_PROFILE_FILE="$ROOT/profiles/social-debug.env"

social_debug_pool_max="$(extract_profile_value_from_file "$SOCIAL_DEBUG_PROFILE_FILE" "WORKSPACE_TRR_APP_POSTGRES_POOL_MAX")"
social_debug_max_ops="$(extract_profile_value_from_file "$SOCIAL_DEBUG_PROFILE_FILE" "WORKSPACE_TRR_APP_POSTGRES_MAX_CONCURRENT_OPERATIONS")"
default_profile_posts="$(extract_profile_value "WORKSPACE_TRR_REMOTE_SOCIAL_POSTS")"
default_profile_comments="$(extract_profile_value "WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS")"

assert_equals "profiles/default.env remote social posts" "2" "$default_profile_posts"
assert_equals "profiles/default.env remote social comments" "2" "$default_profile_comments"
assert_equals "profiles/social-debug.env app postgres pool max" "2" "$social_debug_pool_max"
assert_equals "profiles/social-debug.env app postgres max concurrent operations" "2" "$social_debug_max_ops"
```

- [ ] **Step 2: Run the contract script and verify it fails**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
bash scripts/check-workspace-contract.sh
```

Expected: `FAIL` because `profiles/social-debug.env` does not exist yet and `profiles/default.env` still reflects the temporary verification edits.

- [ ] **Step 3: Restore `PROFILE=default` and create the tracked `social-debug` profile**

Set `profiles/default.env` back to the documented baseline values used by the generated env contract:

```dotenv
WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT=25
WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT=64
WORKSPACE_TRR_REMOTE_SOCIAL_POSTS=2
WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS=2
WORKSPACE_TRR_REMOTE_SOCIAL_MEDIA_MIRROR=1
WORKSPACE_TRR_REMOTE_SOCIAL_COMMENT_MEDIA_MIRROR=1
WORKSPACE_SOCIAL_WORKER_ENABLED=0
WORKSPACE_SOCIAL_WORKER_FORCE_LOCAL=0
WORKSPACE_SOCIAL_WORKER_POSTS=1
WORKSPACE_SOCIAL_WORKER_COMMENTS=1
WORKSPACE_SOCIAL_WORKER_MEDIA_MIRROR=0
WORKSPACE_SOCIAL_WORKER_COMMENT_MEDIA_MIRROR=0
TRR_SOCIAL_PROFILE_DB_POOL_MINCONN=1
TRR_SOCIAL_PROFILE_DB_POOL_MAXCONN=2
TRR_DB_POOL_MINCONN=1
TRR_DB_POOL_MAXCONN=2
```

Create `profiles/social-debug.env` with the tracked low-pressure validation settings:

```dotenv
# TRR workspace social-debug profile
# Use when validating heavy social-profile pages without mutating ignored app-local env files.
APP_ENV=development
WORKSPACE_OPEN_BROWSER=0
WORKSPACE_BACKEND_AUTO_RESTART=1
WORKSPACE_TRR_APP_DEV_BUNDLER=webpack
WORKSPACE_TRR_JOB_PLANE_MODE=remote
WORKSPACE_TRR_LONG_JOB_ENFORCE_REMOTE=1
WORKSPACE_TRR_REMOTE_EXECUTOR=modal
WORKSPACE_TRR_MODAL_ENABLED=1
WORKSPACE_TRR_REMOTE_WORKERS_ENABLED=1
WORKSPACE_TRR_REMOTE_SOCIAL_WORKERS=0
WORKSPACE_TRR_REMOTE_SOCIAL_DISPATCH_LIMIT=12
WORKSPACE_TRR_MODAL_SOCIAL_JOB_CONCURRENCY_LIMIT=16
WORKSPACE_TRR_REMOTE_SOCIAL_POSTS=1
WORKSPACE_TRR_REMOTE_SOCIAL_COMMENTS=1
WORKSPACE_TRR_REMOTE_SOCIAL_MEDIA_MIRROR=0
WORKSPACE_TRR_REMOTE_SOCIAL_COMMENT_MEDIA_MIRROR=0
WORKSPACE_SOCIAL_WORKER_ENABLED=0
TRR_API_URL=http://127.0.0.1:8000
TRR_BACKEND_RELOAD=0
TRR_ADMIN_ROUTE_CACHE_DISABLED=0
TRR_SOCIAL_PROFILE_PERF_DEBUG=0
TRR_SOCIAL_PROFILE_DB_POOL_MINCONN=1
TRR_SOCIAL_PROFILE_DB_POOL_MAXCONN=2
TRR_DB_POOL_MINCONN=1
TRR_DB_POOL_MAXCONN=2
WORKSPACE_TRR_APP_POSTGRES_POOL_MAX=2
WORKSPACE_TRR_APP_POSTGRES_MAX_CONCURRENT_OPERATIONS=2
```

- [ ] **Step 4: Wire the tracked app pool env through `scripts/dev-workspace.sh` and refresh docs**

Inside the `TRR-APP` launch block in `scripts/dev-workspace.sh`, export the tracked app env if present:

```bash
POSTGRES_POOL_MAX="${WORKSPACE_TRR_APP_POSTGRES_POOL_MAX:-${POSTGRES_POOL_MAX:-}}" \
POSTGRES_MAX_CONCURRENT_OPERATIONS="${WORKSPACE_TRR_APP_POSTGRES_MAX_CONCURRENT_OPERATIONS:-${POSTGRES_MAX_CONCURRENT_OPERATIONS:-}}" \
```

Then document the new profile in `docs/workspace/dev-commands.md`:

```md
- `PROFILE=social-debug make dev` runs the tracked low-pressure social-profile validation profile. Use it for scraper/card verification when you want app and backend pool limits reduced without editing ignored local env files.
```

Document the ownership in `docs/workspace/supabase-capacity-budget.md`:

```md
- `PROFILE=social-debug` is the tracked low-pressure validation lane for social-profile debugging.
- It owns `WORKSPACE_TRR_APP_POSTGRES_POOL_MAX=2`, `WORKSPACE_TRR_APP_POSTGRES_MAX_CONCURRENT_OPERATIONS=2`, and reduced social dispatch caps.
- Do not bake those values into `PROFILE=default`; the default profile remains the everyday cloud-first baseline.
```

Regenerate the generated env contract:

```bash
cd /Users/thomashulihan/Projects/TRR
make env-contract
```

- [ ] **Step 5: Re-run contract validation and commit the runtime-profile slice**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
bash scripts/check-workspace-contract.sh
bash scripts/workspace-env-contract.sh --check
python3 scripts/env_contract_report.py validate
```

Expected: all three commands `PASS`.

Commit:

```bash
cd /Users/thomashulihan/Projects/TRR
git add profiles/default.env profiles/social-debug.env scripts/dev-workspace.sh scripts/check-workspace-contract.sh docs/workspace/dev-commands.md docs/workspace/supabase-capacity-budget.md docs/workspace/env-contract.md
git commit -m "chore: codify tracked social debug runtime profile"
```

### Task 4: Validate End-To-End And Update Local Status

**Files:**
- Modify: `docs/ai/local-status/instagram-social-profile-cold-path-gap-closure-2026-04-21.md`

- [ ] **Step 1: Start the tracked low-pressure workspace and verify the runtime summary**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR
PROFILE=social-debug WORKSPACE_DEV_MODE=cloud bash scripts/dev-workspace.sh
```

Expected workspace summary:

```text
Summary: backend=non-reload, bundler=webpack, remote=modal dispatch active
```

and the `TRR-APP` child process inherits:

```text
POSTGRES_POOL_MAX=2
POSTGRES_MAX_CONCURRENT_OPERATIONS=2
```

- [ ] **Step 2: Re-run the targeted backend and app tests**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
./.venv/bin/python -m pytest -q tests/repositories/test_social_season_analytics.py -k "comments_coverage_status or effective_comments_coverage_fields"

cd /Users/thomashulihan/Projects/TRR/TRR-APP
pnpm -C apps/web exec vitest run tests/social-account-profile-page.runtime.test.tsx -t "historical failed run"
```

Expected: both commands `PASS`.

- [ ] **Step 3: Verify the live page and API truth**

Run:

```bash
curl -s "http://admin.localhost:3000/api/admin/trr-api/social/profiles/instagram/thetraitorsus/summary?detail=full" | jq '.comments_coverage'
curl -s "http://admin.localhost:3000/api/admin/trr-api/social/profiles/instagram/thetraitorsus/posts?page=1&page_size=5&comments_only=true" | jq '.pagination'
```

Expected summary shape:

```json
{
  "eligible_posts": 427,
  "missing_posts": 364,
  "stale_posts": 37,
  "last_comments_run_status": "failed",
  "effective_status": "needs_refresh",
  "effective_label": "Needs refresh",
  "historical_failure": true,
  "last_attempt_status": "failed"
}
```

- [ ] **Step 4: Use Computer Use to verify the admin card copy**

Expected UI outcome on `http://admin.localhost:3000/social/instagram/thetraitorsus/comments`:

```text
Status: Needs refresh
Last attempt failed at ...
Saved comments and table rows still render normally
```

The page must not show a primary standalone `Failed` label for this stale historical failure case.

- [ ] **Step 5: Append the local-status note and commit the validation closeout**

Append this evidence block to `docs/ai/local-status/instagram-social-profile-cold-path-gap-closure-2026-04-21.md`:

```md
## Caveat Closeout
- The comments coverage payload now separates raw last-run history from effective operator state.
- Historical failed runs no longer render as the primary page status when saved discussion already exists.
- The low-pressure validation runtime is now tracked under `PROFILE=social-debug`; ignored app-local env edits are no longer required for this validation lane.
```

Commit:

```bash
cd /Users/thomashulihan/Projects/TRR
git add docs/ai/local-status/instagram-social-profile-cold-path-gap-closure-2026-04-21.md
git commit -m "docs: record comments truth and runtime-profile caveat closeout"
```

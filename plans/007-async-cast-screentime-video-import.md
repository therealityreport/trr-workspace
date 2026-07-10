# Plan 007: Queue cast-screentime remote video imports instead of blocking the admin request

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report -- do not improvise. When done, update the status row for this plan
> in `plans/README.md` -- unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: from the workspace root, run
> `git -C TRR-Backend diff --stat 8ea7aa1a..HEAD -- api/routers/admin_cast_screentime.py tests/api/test_admin_cast_screentime.py trr_backend/repositories/cast_screentime.py`
> and
> `git -C TRR-APP diff --stat 83778e5c..HEAD -- apps/web/src/app/admin/cast-screentime/CastScreentimePageClient.tsx apps/web/tests/cast-screentime-page.test.tsx`.
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against live code before proceeding; on a mismatch,
> treat it as a STOP condition. If either planned-at SHA does not resolve,
> compare every excerpt against live code by hand and note that in your report.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: perf
- **Planned at**: workspace `fb76b5b`, TRR-Backend `8ea7aa1a`, TRR-APP `83778e5c`, 2026-07-07

## Why this matters

The remote import button currently keeps the admin POST open while the backend
does every slow external operation: YouTube metadata lookup, official-channel
resolution, media URL resolution, remote video mirroring, `ffprobe`, object
promotion, and video-asset creation. That can hold a FastAPI worker for minutes
and makes the browser look frozen or failed even when the work is simply slow.
This plan keeps the existing storage and validation behavior, but turns the
remote import into a quick queued request with status polling.

## Current state

- `TRR-Backend/api/routers/admin_cast_screentime.py` owns all cast-screentime
  upload and import routes. It currently imports FastAPI like this:

  ```python
  # api/routers/admin_cast_screentime.py:16
  from fastapi import APIRouter, Depends, HTTPException, Query
  ```

- `ImportVideoAssetRequest` already captures all data needed to run the import
  later. The request body includes `source_mode`, `source_url`,
  `social_youtube_video_id`, owner fields, and media classification:

  ```python
  # api/routers/admin_cast_screentime.py:61
  class ImportVideoAssetRequest(BaseModel):
      source_mode: Literal["youtube_url", "external_url", "social_youtube_row"]
      source_url: str | None = None
      social_youtube_video_id: UUID | None = None
      owner_scope: Literal["show", "season", "episode"] = "season"
      owner_id: UUID
      media_type: Literal["episode", "trailer", "extras"] | None = None
      media_kind: str | None = None
  ```

- The import endpoint is synchronous. It creates an upload session, performs the
  external work, promotes the session to a video asset, then returns the asset:

  ```python
  # api/routers/admin_cast_screentime.py:1290
  @router.post("/admin/cast-screentime/video-assets/import")
  def import_video_asset(
      request: ImportVideoAssetRequest,
      admin_user: CastScreentimeAdminUser,
  ) -> dict[str, Any]:
      ...
      metadata = _youtube_fetch_video_metadata(video_id)
      expected_owners = _resolve_official_youtube_owners(owner_context)
      ...
      mirror_meta = _mirror_remote_video_to_temp_object(...)
      ...
      video_asset = _promote_session_to_video_asset(...)
      return {"upload_session_id": str(upload_session_id), "video_asset": video_asset}
  ```

- The expensive operations are all in the same request path:
  - `_youtube_fetch_video_metadata()` runs `yt-dlp` with a 60 second timeout at
    `api/routers/admin_cast_screentime.py:565`.
  - `_resolve_official_youtube_owners()` creates `YouTubeScraper()` and resolves
    each handle with `delay=0.25` at `api/routers/admin_cast_screentime.py:818`.
  - `_mirror_remote_video_to_temp_object()` streams the remote video into object
    storage with a `(10, 180)` timeout at `api/routers/admin_cast_screentime.py:863`.
  - `_ffprobe_video()` runs `ffprobe` with a 30 second timeout at
    `api/routers/admin_cast_screentime.py:743`.

- No new queue table is needed for this slice. `ml.analysis_media_upload_sessions`
  already has the fields the import job needs: `status`, `verification_json`,
  `failed_at`, `promoted_video_asset_id`, and `error_text`. The repository has:

  ```python
  # trr_backend/repositories/cast_screentime.py:43
  def create_media_upload_session(payload: dict[str, Any]) -> dict[str, Any]:
      ...

  # trr_backend/repositories/cast_screentime.py:81
  def get_media_upload_session(upload_session_id: str) -> dict[str, Any] | None:
      return pg.fetch_one("SELECT * FROM ml.analysis_media_upload_sessions WHERE id = %s", [upload_session_id])

  # trr_backend/repositories/cast_screentime.py:85
  def update_media_upload_session(upload_session_id: str, payload: dict[str, Any]) -> dict[str, Any] | None:
      ...
  ```

- Use the existing Google News async route as the local pattern: it creates a
  durable row, schedules a background task when remote dispatch is unavailable,
  and returns a queued response immediately:

  ```python
  # api/routers/admin_show_news.py:1704
  def sync_google_news(..., background_tasks: BackgroundTasks, ...):
      ...
      if payload.async_mode:
          job_id = _create_google_news_sync_job(...)
          ...
          background_tasks.add_task(_run_google_news_sync_job, job_id=job_id, ...)
          return {"queued": True, "job_id": job_id, "status": "queued", ...}
  ```

- The admin page expects the import POST to return a completed asset. It sets
  `videoAsset` immediately from `payload.video_asset`:

  ```tsx
  // CastScreentimePageClient.tsx:853
  const payload = await parseResponse<{ upload_session_id: string; video_asset: VideoAssetPayload }>(
    await fetchAdminWithAuth("/api/admin/trr-api/cast-screentime/video-assets/import", ...)
  );
  setLatestUpload({ upload_session_id: payload.upload_session_id, ... });
  setVideoAsset(payload.video_asset);
  ```

## Commands you will need

Backend commands run from `TRR-Backend/` with `.venv` present. App commands run
from `TRR-APP/`.

| Purpose | Command | Expected on success |
|---|---|---|
| Backend import gate | `.venv/bin/python -c "import api.main"` | exit 0, prints nothing |
| Backend route tests | `.venv/bin/python -m pytest tests/api/test_admin_cast_screentime.py -q` | all pass |
| Backend lint | `ruff check api/routers/admin_cast_screentime.py tests/api/test_admin_cast_screentime.py trr_backend/repositories/cast_screentime.py` | exit 0 |
| App focused test | `pnpm -C apps/web exec vitest run tests/cast-screentime-page.test.tsx` | all pass |
| App typecheck | `pnpm -C apps/web run typecheck` | exit 0 |
| App lint | `pnpm -C apps/web run lint` | exit 0, existing unrelated warnings allowed |

## Scope

**In scope**:
- `TRR-Backend/api/routers/admin_cast_screentime.py`
- `TRR-Backend/tests/api/test_admin_cast_screentime.py`
- `TRR-Backend/trr_backend/repositories/cast_screentime.py` only if a tiny
  helper is needed to return an upload session with its promoted video asset
- `TRR-APP/apps/web/src/app/admin/cast-screentime/CastScreentimePageClient.tsx`
- `TRR-APP/apps/web/tests/cast-screentime-page.test.tsx`

**Out of scope**:
- New database tables or migrations. Use `ml.analysis_media_upload_sessions` as
  the import job row for this slice.
- Modal dispatch. This plan may leave a `ponytail:` comment that the current
  background task is local-only and Modal can own it later if import volume
  grows.
- Changing direct upload behavior. `/upload-sessions` and
  `/upload-sessions/{id}/complete` should keep their current response shape.
- Changing media validation, official-channel checks, object keys, or the
  promoted `video_asset` shape.

## Git workflow

- Work on the current branch unless the operator explicitly asks for a new one.
- Preserve unrelated dirty-tree changes in the workspace root, TRR-Backend, and
  TRR-APP.
- Commit message style, if asked to commit later: plain imperative, e.g.
  `queue cast screentime video imports`.

## Steps

### Step 1: Extract the current import body into a worker function

In `api/routers/admin_cast_screentime.py`, move the slow branch body from
`import_video_asset()` into a private helper, for example:

```python
def _run_import_video_asset_job(
    *,
    upload_session_id: UUID,
    request: ImportVideoAssetRequest,
    owner_context: dict[str, Any],
    session: dict[str, Any],
) -> dict[str, Any] | None:
    ...
```

Keep the existing behavior inside that helper:
- It updates the session to `uploaded` after mirroring.
- It marks the session `failed` with `error_text="remote import failed"` on
  unexpected failures.
- It calls `_promote_session_to_video_asset(...)`.
- It returns the annotated promoted asset.

Do not swallow `HTTPException`; keep the session failure update, then re-raise
so tests can still assert validation errors when the helper is called directly.

**Verify**:
`.venv/bin/python -m pytest tests/api/test_admin_cast_screentime.py -q` passes
with the endpoint still synchronous.

### Step 2: Make the POST queue the helper and return quickly

Change `import_video_asset()` to accept `background_tasks: BackgroundTasks`.
Import `BackgroundTasks` from FastAPI.

The route should still do cheap validation before enqueueing:
- Resolve owner context.
- Normalize and validate media classification.
- Create the `analysis_media_upload_sessions` row.
- Put enough metadata into `verification_json` to rerun the job later:
  `source_mode`, `source_url` or `social_youtube_video_id`, owner scope/id, and
  media fields.

Set the created session status to `queued` for remote imports, then schedule:

```python
background_tasks.add_task(
    _run_import_video_asset_job,
    upload_session_id=upload_session_id,
    request=request,
    owner_context=owner_context,
    session=session,
)
```

Return HTTP 202 semantics in the JSON body while preserving easy compatibility:

```python
return {
    "upload_session_id": str(upload_session_id),
    "queued": True,
    "status": "queued",
    "video_asset": None,
}
```

The exact FastAPI decorator can remain plain `@router.post(...)`; using
`status_code=202` is preferred if existing tests can be updated cleanly.

Add a short comment only if helpful:

```python
# ponytail: local background task is enough for low import volume; move this to Modal if operators batch imports.
```

**Verify**:
Add or update a backend test so posting to `/video-assets/import` returns
quickly with `queued: true`, an `upload_session_id`, `status: "queued"`, and no
completed `video_asset`.

### Step 3: Add a status endpoint for the admin page

Add:

```python
@router.get("/admin/cast-screentime/upload-sessions/{upload_session_id}")
def get_upload_session(upload_session_id: UUID, _: CastScreentimeAdminUser) -> dict[str, Any]:
    ...
```

Return:
- `upload_session_id`
- `status`
- `error_text`
- `promoted_video_asset_id`
- `video_asset` when `promoted_video_asset_id` exists and resolves

Use `cast_screentime.get_media_upload_session()` and
`cast_screentime.resolve_video_asset()` or `_resolve_video_asset_or_404()` for
the asset. Return 404 if the session is missing.

**Verify**:
Add backend tests for:
- missing upload session returns 404
- queued session returns no `video_asset`
- promoted session returns the promoted asset
- failed session returns `status: "failed"` and `error_text`

### Step 4: Update the admin UI to handle queued imports

In `CastScreentimePageClient.tsx`, change the import response type to allow:

```ts
{
  upload_session_id: string;
  queued?: boolean;
  status?: string;
  video_asset?: VideoAssetPayload | null;
}
```

After import:
- Always set `latestUpload` from `upload_session_id`.
- If `video_asset` is present, keep the existing immediate-success path.
- If `queued` is true or `video_asset` is missing, show a plain progress state
  such as `Import queued...` / `Importing remote video...`.
- Poll `/api/admin/trr-api/cast-screentime/upload-sessions/${upload_session_id}`
  until the session is `promoted` or `failed`.
- On `promoted`, set `videoAsset`, sync show context, reset run outputs, and
  refresh recent runs exactly like the old success path.
- On `failed`, surface `error_text` or `Import failed`.

Keep the polling small and boring: `setInterval` or an async loop in the click
handler is enough. Clear the interval on completion and component unmount.

**Verify**:
Update `tests/cast-screentime-page.test.tsx` with one focused test that:
- clicks import
- sees the queued status text
- mocks the status endpoint returning promoted
- confirms the promoted asset becomes available in the UI

### Step 5: Final checks

Run:

```bash
cd TRR-Backend
.venv/bin/python -c "import api.main"
.venv/bin/python -m pytest tests/api/test_admin_cast_screentime.py -q
ruff check api/routers/admin_cast_screentime.py tests/api/test_admin_cast_screentime.py trr_backend/repositories/cast_screentime.py

cd ../TRR-APP
pnpm -C apps/web exec vitest run tests/cast-screentime-page.test.tsx
pnpm -C apps/web run typecheck
pnpm -C apps/web run lint
```

Do not run a full TRR-APP production build unless the operator explicitly
approves it in the current chat.

## Test plan

- Backend route tests in `tests/api/test_admin_cast_screentime.py`:
  - import POST queues work instead of returning a completed asset
  - worker helper still promotes a successful external import
  - status endpoint reports queued, promoted, failed, and missing sessions
- App component test in `apps/web/tests/cast-screentime-page.test.tsx`:
  - queued import progresses to promoted asset via status polling

## Done criteria

- [ ] The import POST returns quickly with `queued: true`, `status: "queued"`,
      and an `upload_session_id`.
- [ ] The slow operations are only inside `_run_import_video_asset_job()` or an
      equivalently named worker helper.
- [ ] A GET status endpoint exposes queued/promoted/failed upload-session state.
- [ ] The admin page no longer assumes the import POST always returns a
      completed `video_asset`.
- [ ] Backend import gate, focused backend tests, backend lint, app focused test,
      app typecheck, and app lint pass.
- [ ] No new migration or queue table was added.

## STOP conditions

Stop and report back if:

- `analysis_media_upload_sessions` no longer has `status`, `error_text`, or
  `promoted_video_asset_id` in the live schema/repository.
- Existing callers require `/video-assets/import` to stay synchronous outside
  `CastScreentimePageClient.tsx`.
- The fix appears to require Modal dispatch or a new persistent worker table to
  be correct.
- A verification command fails twice with the same substantive error.

## Maintenance notes

- This is the low-volume async slice. If operators start batch-importing many
  videos, move `_run_import_video_asset_job()` behind Modal or the shared admin
  operation queue rather than adding more local background work.
- Reviewers should scrutinize status transitions: `queued` -> `uploaded` ->
  `promoted` or `failed`. The user-facing page should never enable "Launch Run"
  until a promoted asset exists.
- Keep source validation and official YouTube ownership checks in the worker;
  the queued route should only do cheap request-shape validation.

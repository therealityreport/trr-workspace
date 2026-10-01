# Plan 026: Route scraped avatar/profile-pic downloads through the existing SSRF guard

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan in
> `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git -C TRR-Backend diff --stat -- trr_backend/socials/social_season_analytics_impl.py`
> The nested `TRR-Backend` working tree is authoritative and dirty. This file is
> 68k+ lines; do NOT read it whole. Use the `grep` commands in each step to jump
> to the exact functions and confirm the "Current state" excerpts match before
> editing. On any mismatch, STOP.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: security
- **Planned at**: commit `8ea7aa1a` (TRR-Backend), 2026-07-08 — working tree authoritative
- **Repo**: TRR-Backend

## Why this matters

The backend mirrors scraped social avatars/profile pictures to S3 by fetching
each `source_url` server-side from a Modal worker. Those URLs come from hostile
scraped content (a profile can advertise any `profile_pic_url`). The avatar
download does a raw `requests.get(source_url, stream=True)` with **default
redirect following** and only a `source_url.startswith(("http://","https://"))`
check — no host allowlist, no private/loopback/link-local IP block, no
per-redirect re-validation. That is a server-side request forgery (SSRF) sink: a
crafted avatar URL (or a redirect to one) can make the worker fetch cloud
metadata (169.254.169.254), loopback, or internal services.

The project already has the correct guard — `media_url_safety.py` with
`validate_media_url` (blocks reserved/private/loopback IPs, enforces a
per-platform host-suffix allowlist, resolves DNS and blocks addresses that
resolve into blocked ranges) and `safe_requests_get` (re-validates **every
redirect hop**). The **post-media** mirror path already uses it; the avatar path
is the unguarded sibling. This plan makes the avatar downloader use the same
guard. It reuses existing, tested code, so it is small and low-risk.

## Current state

- `trr_backend/socials/media_url_safety.py` — the SSRF guard. Key API:
  - `allowed_hosts_for_platform(platform) -> tuple[str, ...]` — e.g. instagram →
    `("instagram.com","cdninstagram.com","fbcdn.net","fbsbx.com")`.
  - `MediaUrlSafetyPolicy(allowed_host_suffixes: tuple[str,...])`.
  - `validate_media_url(url, *, policy=...) -> str` — raises `UnsafeMediaUrlError`
    on blocked IP / disallowed host / DNS-resolves-to-blocked-IP.
  - `safe_requests_get(client, url, *, policy=..., **kwargs) -> Response` —
    validates the URL and each redirect hop; `client` is the `requests` module.
  - Even when `allowed_hosts_for_platform` returns `()` (unknown platform), the
    literal-IP and DNS-resolution blocks in `validate_media_url` still run, so
    private-range SSRF is blocked regardless of platform.

- `trr_backend/socials/social_season_analytics_impl.py` — the god module holding
  the avatar mirror. Three relevant functions:

  1. `_download_avatar_to_tempfile` (around line 18570) — **the vulnerable
     downloader**. Current shape:

     ```python
     def _download_avatar_to_tempfile(
         source_url: str,
         *,
         headers: Mapping[str, str],
         progress_cb: Callable[[], None] | None = None,
     ) -> tuple[str, str, str]:
         temp_path: str | None = None
         content_type = "application/octet-stream"
         total_bytes = 0
         sha256 = hashlib.sha256()
         try:
             with requests.get(
                 source_url,
                 timeout=(10, 30),
                 headers=dict(headers),
                 stream=True,
             ) as response:
                 response.raise_for_status()
                 ...
     ```

  2. `_mirror_instagram_profile_pics_for_post` (around line 18617) — caller #1.
     Calls `_download_avatar_to_tempfile(source_url, headers={...}, progress_cb=progress_cb)`
     around line 18882, inside a `try/except Exception as exc:` that records a
     registry failure via `_upsert_avatar_registry_entry(..., status=_avatar_registry_failure_status(reason), failure_reason=reason[:240])`
     (around line 18933). Platform here is always `"instagram"`.

  3. `_mirror_post_author_avatar_to_s3(*, platform, username, source_avatar_url, ...)`
     (around line 19047) — caller #2. Calls `_download_avatar_to_tempfile(source_url, headers={...}, progress_cb=progress_cb)`
     around line 19103, inside a `try/except Exception as exc:` that records a
     registry failure (around line 19149). Platform is the `platform` parameter.

  The reference (correct) pattern is in the **post-media** mirror in the same
  file, which imports the guard locally and calls
  `safe_requests_get(requests, source_url, policy=media_url_policy, ...)` (around
  lines 17844–17939). Match that local-import style.

Repo conventions: ruff py311, line length 120, double quotes. Tests live under
`TRR-Backend/tests/socials/`; the media-safety exemplar is
`tests/socials/test_media_url_safety.py` (imports the guard, uses a fake client,
asserts redirect re-validation).

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Locate downloader | `grep -n "_download_avatar_to_tempfile" TRR-Backend/trr_backend/socials/social_season_analytics_impl.py` | 3 hits: def + 2 callers |
| Import gate | `cd TRR-Backend && .venv/bin/python -c "import trr_backend.socials.social_season_analytics_impl"` | exit 0 |
| Focused tests | `cd TRR-Backend && .venv/bin/python -m pytest tests/socials/test_media_url_safety.py tests/socials/test_avatar_ssrf_guard.py -q` | all pass |
| Lint | `cd TRR-Backend && ruff check trr_backend/socials/social_season_analytics_impl.py tests/socials/test_avatar_ssrf_guard.py` | exit 0 |

## Scope

**In scope**:
- `TRR-Backend/trr_backend/socials/social_season_analytics_impl.py` — only the
  three functions named above.
- `TRR-Backend/tests/socials/test_avatar_ssrf_guard.py` (create).

**Out of scope** (do NOT touch):
- `media_url_safety.py` — the guard is correct; only start *using* it.
- The post-media mirror path (already guarded).
- Any change to the avatar registry schema or `_upsert_avatar_registry_entry`.
- The rest of the god module.

## Git workflow

- Branch: `advisor/026-avatar-mirror-ssrf-guard`
- One commit; imperative subject (e.g. "guard scraped avatar downloads against SSRF").
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Add a `platform` parameter and validate inside the downloader

Change `_download_avatar_to_tempfile` to require a keyword `platform: str` and
fetch through the guard. Inside the function, add a local import matching the
post-media path's style and replace the raw `requests.get(...)` with
`safe_requests_get(...)`:

```python
def _download_avatar_to_tempfile(
    source_url: str,
    *,
    platform: str,
    headers: Mapping[str, str],
    progress_cb: Callable[[], None] | None = None,
) -> tuple[str, str, str]:
    from trr_backend.socials.media_url_safety import (
        MediaUrlSafetyPolicy,
        allowed_hosts_for_platform,
        safe_requests_get,
    )

    media_url_policy = MediaUrlSafetyPolicy(allowed_hosts_for_platform(platform))
    temp_path: str | None = None
    content_type = "application/octet-stream"
    total_bytes = 0
    sha256 = hashlib.sha256()
    try:
        with safe_requests_get(
            requests,
            source_url,
            policy=media_url_policy,
            timeout=(10, 30),
            headers=dict(headers),
            stream=True,
        ) as response:
            response.raise_for_status()
            ...  # keep the rest of the body byte-for-byte unchanged
```

Keep everything after the `with` line (content-type read, tempfile write, size
cap, sha256) exactly as it is today.

**Verify**: `cd TRR-Backend && .venv/bin/python -c "import trr_backend.socials.social_season_analytics_impl"` → exit 0.

### Step 2: Pass `platform` from both callers

- In `_mirror_instagram_profile_pics_for_post` (~line 18882), change the call to
  pass `platform="instagram"`.
- In `_mirror_post_author_avatar_to_s3` (~line 19103), change the call to pass
  `platform=platform`.

Do not change anything else in those functions — their existing
`except Exception` blocks already convert a raised `UnsafeMediaUrlError` into a
recorded avatar-registry failure and continue, which is the desired behavior for
a blocked URL.

**Verify**: `grep -n "_download_avatar_to_tempfile(" TRR-Backend/trr_backend/socials/social_season_analytics_impl.py` → the two call sites now include `platform=`.

### Step 3: Add the regression test

Create `tests/socials/test_avatar_ssrf_guard.py`, modeled on
`tests/socials/test_media_url_safety.py`. Cover:

1. `_download_avatar_to_tempfile("http://169.254.169.254/latest/meta-data", platform="instagram", headers={})`
   raises `UnsafeMediaUrlError` (cloud-metadata literal IP is blocked *before*
   any socket call — no network needed).
2. `_download_avatar_to_tempfile("http://127.0.0.1/a.jpg", platform="instagram", headers={})`
   raises `UnsafeMediaUrlError` (loopback blocked).
3. A disallowed public host is rejected: patch `socket.getaddrinfo` to return a
   public IP and call with `platform="instagram"` and host `http://evil.example.org/a.jpg`
   — assert `UnsafeMediaUrlError` with `media_url_host_not_allowed` (mirror the
   monkeypatch style in the exemplar; note `.example` is a reserved test suffix,
   so use a non-reserved host like `evil-cdn.org`).

Import the target with
`from trr_backend.socials.social_season_analytics_impl import _download_avatar_to_tempfile`.

**Verify**: `cd TRR-Backend && .venv/bin/python -m pytest tests/socials/test_avatar_ssrf_guard.py -q` → all pass.

## Test plan

- New file `tests/socials/test_avatar_ssrf_guard.py`, 3 cases above, structured
  after `tests/socials/test_media_url_safety.py`.
- Verification: `cd TRR-Backend && .venv/bin/python -m pytest tests/socials/test_media_url_safety.py tests/socials/test_avatar_ssrf_guard.py -q` → all pass.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `cd TRR-Backend && .venv/bin/python -c "import trr_backend.socials.social_season_analytics_impl"` exits 0
- [ ] `grep -n "requests.get(" TRR-Backend/trr_backend/socials/social_season_analytics_impl.py` does NOT match inside `_download_avatar_to_tempfile` (raw get removed)
- [ ] `grep -n "safe_requests_get" TRR-Backend/trr_backend/socials/social_season_analytics_impl.py` shows the new avatar use
- [ ] Both `_download_avatar_to_tempfile(` call sites pass `platform=`
- [ ] `cd TRR-Backend && .venv/bin/python -m pytest tests/socials/test_avatar_ssrf_guard.py -q` exits 0 with 3 passing tests
- [ ] `cd TRR-Backend && ruff check trr_backend/socials/social_season_analytics_impl.py tests/socials/test_avatar_ssrf_guard.py` exits 0
- [ ] No files outside the in-scope list are modified (`git -C TRR-Backend status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- `_download_avatar_to_tempfile` or either caller does not match the "Current
  state" excerpts.
- The guard API (`safe_requests_get(client, url, *, policy=...)`,
  `allowed_hosts_for_platform`) differs from what's described in `media_url_safety.py`.
- Either caller's `except` block does NOT already record a registry failure
  (that would mean a blocked URL crashes the mirror — report it; a different fix
  shape is needed).
- A test fails twice after a reasonable fix attempt.

## Maintenance notes

- If a new platform is added, add its CDN host suffixes to
  `_PLATFORM_ALLOWED_HOST_SUFFIXES` in `media_url_safety.py`; otherwise its
  avatars will be rejected as `media_url_host_not_allowed` (private-IP SSRF is
  still blocked either way).
- A reviewer should confirm no *other* raw `requests.get`/`httpx.get` over a
  scraped URL remains in the avatar/media paths (grep the file for `requests.get(`
  and `httpx.get(` and confirm each is either guarded or over a trusted URL).
- SEC-05 (TikTok sound-URL passthrough) is a related latent sink tracked
  separately in the backlog — not fixed here.

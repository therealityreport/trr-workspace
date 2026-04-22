# Instagram Comments Sticky Proxy And Execution Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Instagram comments Scrapling lane truthful and operable by implementing the documented sticky-proxy env vars and updating operator docs to match the current hybrid local-vs-Modal execution model.

**Architecture:** Keep the existing comments runtime model intact: `start_social_account_comments_scrape(...)` already chooses Modal when queue mode and remote execution are enabled, and already falls back to the dedicated local `instagram_comments_scrapling` lane when Modal is not required. The only backend behavior change in this plan is inside `comments_scrapling/proxy.py`: when the documented sticky env is enabled for Decodo username:password auth, build the proxy username with Decodo's `session-<id>-sessionduration-<minutes>` parameters and thread a deterministic session key from the account handle so browser warmup and `httpx` stay on the same sticky upstream.

**Tech Stack:** Python 3.11, Scrapling 0.4.6, Patchright 1.58.2, Playwright 1.58.0, httpx, pytest, Markdown runbooks, Decodo residential proxies.

---

## Scope

This plan intentionally addresses the two confirmed workspace defects only:

1. `SOCIAL_INSTAGRAM_COMMENTS_USE_STICKY_PROXY` and `SOCIAL_INSTAGRAM_COMMENTS_PROXY_SESSION_TTL_SECONDS` are documented in `.env.example` and the runbook, but are not implemented in `comments_scrapling/proxy.py`.
2. The comments runbook still describes a dedicated-lane-only execution model even though the repo already supports `required_execution_backend="modal"` for queued comments runs.

Deferred follow-ups, not part of this plan:

- Automated `posts_scrapling` shadow-compare jobs.
- Browser re-warmup / re-auth inside the Scrapling fetchers after mid-run auth degradation.

## File Structure

- `TRR-Backend/trr_backend/socials/instagram/comments_scrapling/proxy.py`
  - Owns comments-lane proxy selection.
  - Add sticky-session env parsing and Decodo username shaping here.
- `TRR-Backend/trr_backend/socials/instagram/comments_scrapling/job_runner.py`
  - Already owns fetcher startup for the comments lane.
  - Thread a deterministic `session_key` into proxy selection here; do not spread sticky-session logic into the fetcher.
- `TRR-Backend/tests/socials/test_instagram_comments_scrapling.py`
  - Already owns comments-lane proxy/session tests.
  - Extend it with sticky-proxy coverage instead of creating a new test module.
- `TRR-Backend/.env.example`
  - Keep the operator-facing env contract honest.
  - Document sticky-session semantics in the same block where the vars already live.
- `TRR-Backend/docs/workspace/instagram-comments-scrapling.md`
  - Correct the execution architecture narrative.
  - Explain the sticky proxy format in the same runbook operators already use.

---

### Task 1: Implement Decodo sticky-session support for the comments lane

**Files:**
- Modify: `TRR-Backend/tests/socials/test_instagram_comments_scrapling.py`
- Modify: `TRR-Backend/trr_backend/socials/instagram/comments_scrapling/proxy.py`
- Modify: `TRR-Backend/trr_backend/socials/instagram/comments_scrapling/job_runner.py`

- [ ] **Step 1: Write the failing sticky-proxy tests**

Append these tests to `TRR-Backend/tests/socials/test_instagram_comments_scrapling.py`:

```python
from contextlib import nullcontext
import hashlib
from types import SimpleNamespace
from unittest.mock import AsyncMock

from trr_backend.socials.instagram.comments_scrapling.fetcher import InstagramCommentsFetchResult
from trr_backend.socials.instagram.comments_scrapling.job_runner import run_instagram_comments_scrapling_job


def test_select_comments_proxy_adds_decodo_sticky_session_and_duration(monkeypatch) -> None:
    monkeypatch.delenv("SOCIAL_INSTAGRAM_COMMENTS_PROXY_URLS", raising=False)
    monkeypatch.setenv("SOCIAL_INSTAGRAM_COMMENTS_PROXY_PROVIDER", "decodo")
    monkeypatch.setenv("SOCIAL_INSTAGRAM_COMMENTS_USE_STICKY_PROXY", "true")
    monkeypatch.setenv("SOCIAL_INSTAGRAM_COMMENTS_PROXY_SESSION_TTL_SECONDS", "600")
    monkeypatch.setenv("DECODO_USERNAME", "user-customer")
    monkeypatch.setenv("DECODO_PASSWORD", "secret")
    monkeypatch.setenv("DECODO_GATEWAY", "gate.decodo.com:7000")

    config = select_comments_proxy(session_key="bravotv")

    expected_token = hashlib.sha256("bravotv".encode("utf-8")).hexdigest()[:16]
    expected_suffix = f"-session-{expected_token}-sessionduration-10"

    assert config is not None
    assert isinstance(config.browser_proxy, dict)
    assert config.browser_proxy["username"] == f"user-customer{expected_suffix}"
    assert expected_suffix in config.api_proxy_url
    assert config.fingerprint == "gate.decodo.com:7000:decodo"


def test_select_comments_proxy_ignores_sticky_env_for_explicit_proxy_urls(monkeypatch) -> None:
    monkeypatch.setenv("SOCIAL_INSTAGRAM_COMMENTS_PROXY_URLS", "http://user:pass@proxy-one:8000")
    monkeypatch.setenv("SOCIAL_INSTAGRAM_COMMENTS_USE_STICKY_PROXY", "true")
    monkeypatch.setenv("SOCIAL_INSTAGRAM_COMMENTS_PROXY_SESSION_TTL_SECONDS", "1800")
    monkeypatch.setenv("DECODO_USERNAME", "user-customer")
    monkeypatch.setenv("DECODO_PASSWORD", "secret")

    config = select_comments_proxy(session_key="bravotv")

    assert config is not None
    assert config.browser_proxy == "http://user:pass@proxy-one:8000"
    assert config.api_proxy_url == "http://user:pass@proxy-one:8000"


def test_job_runner_passes_account_handle_as_proxy_session_key(monkeypatch) -> None:
    captured: dict[str, str | None] = {}

    monkeypatch.setattr(
        "trr_backend.socials.instagram.comments_scrapling.job_runner.resolve_comments_scrapling_session",
        lambda **_kwargs: SimpleNamespace(
            cookies=[],
            browser_account_id="bravotv",
            auth_session=SimpleNamespace(cookies={}, metadata={}),
        ),
    )
    monkeypatch.setattr(
        "trr_backend.socials.instagram.comments_scrapling.job_runner.select_comments_proxy",
        lambda *, session_key=None: captured.setdefault("session_key", session_key) or None,
    )
    monkeypatch.setattr(
        "trr_backend.socials.instagram.comments_scrapling.job_runner.InstagramCommentsScraplingFetcher",
        lambda **_kwargs: SimpleNamespace(
            warmup=AsyncMock(),
            aclose=AsyncMock(),
            runtime_metadata={},
            fetch_comments_for_shortcode=AsyncMock(
                return_value=InstagramCommentsFetchResult(comments=[], fetch_failed=False, auth_failed=False)
            ),
        ),
    )
    monkeypatch.setattr(
        "trr_backend.socials.instagram.comments_scrapling.job_runner.persist_instagram_comments_for_post",
        lambda **_kwargs: SimpleNamespace(
            comments_upserted=0,
            comments_marked_missing=0,
            comment_media_mirror_jobs_enqueued=0,
            comment_media_mirror_job_enqueue_errors=0,
        ),
    )
    monkeypatch.setattr("trr_backend.socials.instagram.comments_scrapling.job_runner.pg.db_connection", lambda **_kwargs: nullcontext(SimpleNamespace(commit=lambda: None)))
    monkeypatch.setattr("trr_backend.repositories.social_season_analytics._touch_job_heartbeat", lambda *_args, **_kwargs: None)
    monkeypatch.setattr("trr_backend.repositories.social_season_analytics._emit_job_progress", lambda **_kwargs: None)
    monkeypatch.setattr("trr_backend.repositories.social_season_analytics._finish_job", lambda *_args, **_kwargs: None)
    monkeypatch.setattr("trr_backend.repositories.social_season_analytics._finalize_run_status", lambda *_args, **_kwargs: None)
    monkeypatch.setattr("trr_backend.socials.instagram.comments_scrapling.job_runner.pg.fetch_one", lambda *_args, **_kwargs: {})

    run_instagram_comments_scrapling_job(
        {
            "id": "job-1",
            "run_id": "run-1",
            "status": "queued",
            "config": {
                "account": "bravotv",
                "stage": "comments_scrapling",
                "mode": "profile",
                "source_scope": "bravo",
                "target_source_ids": ["ABC12345"],
            },
        }
    )

    assert captured["session_key"] == "bravotv"
```

- [ ] **Step 2: Run the targeted tests and verify they fail**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
./.venv/bin/pytest tests/socials/test_instagram_comments_scrapling.py -k "sticky_session or session_key" -q
```

Expected: FAIL because `select_comments_proxy()` does not accept `session_key`, does not shape the Decodo username with `session-...-sessionduration-...`, and `job_runner.py` calls `select_comments_proxy()` with no session key.

- [ ] **Step 3: Implement the minimal sticky-session behavior**

Update `TRR-Backend/trr_backend/socials/instagram/comments_scrapling/proxy.py` with these helper seams and signature changes:

```python
import hashlib
import math


def _env_truthy(name: str, default: bool = False) -> bool:
    raw = str(os.getenv(name) or "").strip().lower()
    if not raw:
        return default
    return raw in {"1", "true", "yes", "on"}


def _sticky_session_duration_minutes() -> int:
    raw = str(os.getenv("SOCIAL_INSTAGRAM_COMMENTS_PROXY_SESSION_TTL_SECONDS") or "").strip()
    try:
        ttl_seconds = int(raw or "600")
    except ValueError:
        ttl_seconds = 600
    ttl_seconds = max(60, min(86400, ttl_seconds))
    return max(1, min(1440, math.ceil(ttl_seconds / 60)))


def _sticky_session_token(session_key: str | None) -> str:
    normalized = str(session_key or "").strip().lower() or "instagram-comments"
    return hashlib.sha256(normalized.encode("utf-8")).hexdigest()[:16]


def _decodo_username(username: str, *, session_key: str | None) -> str:
    normalized = str(username or "").strip()
    if not normalized or not _env_truthy("SOCIAL_INSTAGRAM_COMMENTS_USE_STICKY_PROXY", False):
        return normalized
    session_token = _sticky_session_token(session_key)
    session_minutes = _sticky_session_duration_minutes()
    return f"{normalized}-session-{session_token}-sessionduration-{session_minutes}"


def select_comments_proxy(*, session_key: str | None = None) -> CommentsProxyConfig | None:
    explicit_urls = _load_proxy_urls_from_env()
    if explicit_urls:
        first_url = explicit_urls[0]
        rotator = _build_proxy_rotator(first_url)
        return CommentsProxyConfig(
            browser_proxy=first_url,
            api_proxy_url=first_url,
            proxy_rotator=rotator,
            fingerprint=_fingerprint_from_url(first_url),
        )

    provider = str(os.getenv("SOCIAL_INSTAGRAM_COMMENTS_PROXY_PROVIDER") or "").strip().lower()
    if provider in {"", "decodo", "smartproxy"}:
        creds = _decodo_env()
        if creds:
            username, password, gateway = creds
            proxy_username = _decodo_username(username, session_key=session_key)
            browser_dict = {
                "server": f"http://{gateway}",
                "username": proxy_username,
                "password": password,
            }
            api_url = f"http://{quote(proxy_username, safe='')}:{quote(password, safe='')}@{gateway}"
            rotator = _build_proxy_rotator(browser_dict)
            return CommentsProxyConfig(
                browser_proxy=browser_dict,
                api_proxy_url=api_url,
                proxy_rotator=rotator,
                fingerprint=_fingerprint_from_gateway(gateway, "decodo"),
            )

    return None
```

Then update `TRR-Backend/trr_backend/socials/instagram/comments_scrapling/job_runner.py` so the comments lane passes the account handle into proxy selection:

```python
proxy_config = select_comments_proxy(session_key=account_handle)
```

- [ ] **Step 4: Run the targeted tests and verify they pass**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
./.venv/bin/pytest tests/socials/test_instagram_comments_scrapling.py -k "sticky_session or session_key" -q
```

Expected: PASS. The sticky-proxy tests should now prove:

- explicit proxy URLs still win;
- Decodo usernames include `session-<hash>-sessionduration-<minutes>` only when the sticky env is enabled;
- the comments job runner uses the normalized account handle as the deterministic sticky-session key.

- [ ] **Step 5: Run the broader comments-lane regression slice**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
./.venv/bin/pytest -q \
  tests/socials/test_instagram_comments_scrapling.py \
  tests/socials/test_instagram_comments_scrapling_retry.py \
  tests/scripts/test_instagram_comments_worker.py
```

Expected: PASS. No regressions in comments-lane proxy selection, retry handling, or worker bootstrapping.

- [ ] **Step 6: Commit**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
git add \
  tests/socials/test_instagram_comments_scrapling.py \
  trr_backend/socials/instagram/comments_scrapling/proxy.py \
  trr_backend/socials/instagram/comments_scrapling/job_runner.py
git commit -m "fix(instagram-comments): implement decodo sticky proxy support"
```

---

### Task 2: Align operator docs and env docs with the actual hybrid execution model

**Files:**
- Modify: `TRR-Backend/.env.example`
- Modify: `TRR-Backend/docs/workspace/instagram-comments-scrapling.md`

- [ ] **Step 1: Update the env contract text in `.env.example`**

Replace the comments proxy block in `TRR-Backend/.env.example` with this clarified version:

```bash
SOCIAL_INSTAGRAM_COMMENTS_PROXY_PROVIDER=decodo
SOCIAL_INSTAGRAM_COMMENTS_PROXY_URLS=
# Applies only to Decodo/Smartproxy username:password auth.
# When true, comments_scrapling/proxy.py appends
# "-session-<stable-id>-sessionduration-<minutes>" to the proxy username.
SOCIAL_INSTAGRAM_COMMENTS_USE_STICKY_PROXY=false
# Sticky session length in seconds. The proxy builder clamps this to 60..86400
# and converts it to Decodo's "sessionduration-<minutes>" username parameter.
SOCIAL_INSTAGRAM_COMMENTS_PROXY_SESSION_TTL_SECONDS=600
SOCIAL_INSTAGRAM_COMMENTS_MAX_POSTS_PER_RUN=50
SOCIAL_INSTAGRAM_COMMENTS_MAX_COMMENTS_PER_POST=200
SOCIAL_INSTAGRAM_COMMENTS_HEADLESS=true
```

- [ ] **Step 2: Update the runbook architecture and proxy sections**

Replace the architecture block in `TRR-Backend/docs/workspace/instagram-comments-scrapling.md` with this current-state flow:

```text
UI (/social/:platform/:handle/comments)
  └─ POST /api/v1/admin/socials/profiles/:platform/:account_handle/comments/scrape
       └─ start_social_account_comments_scrape(...)
            ├─ queue enabled + Modal remote executor enabled
            │    └─ enqueues job with config.required_execution_backend="modal"
            │         └─ Modal social dispatcher / run_social_comments_job
            └─ local dev inline bypass or Modal not required
                 └─ enqueues job with config.required_worker_lane="instagram_comments_scrapling"
                      └─ comments worker (wrapper over shared scripts/socials/worker.py)
                           └─ InstagramCommentsScraplingFetcher → StealthyFetcher (Patchright)
                                └─ persists into social.instagram_comments
```

Then replace the runbook env explanation with this sticky-proxy note:

```markdown
- `SOCIAL_INSTAGRAM_COMMENTS_USE_STICKY_PROXY=true` only affects the Decodo username:password path.
- When enabled, the proxy builder appends Decodo's `session-<id>-sessionduration-<minutes>` parameters to the username so browser warmup and `httpx` stay on one sticky upstream.
- `SOCIAL_INSTAGRAM_COMMENTS_PROXY_SESSION_TTL_SECONDS` is converted to whole minutes and clamped to Decodo's supported `1..1440` minute range.
- `SOCIAL_INSTAGRAM_COMMENTS_PROXY_URLS` still has highest precedence and bypasses all Decodo username shaping.
```

Also update the production section so it says the current Modal defaults come from `trr_backend/modal_jobs.py` (`TRR_REMOTE_EXECUTOR=modal`, `TRR_MODAL_ENABLED=1`) rather than describing the lane as dedicated-worker-only.

- [ ] **Step 3: Verify the docs now mirror the actual code**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
rg -n "SOCIAL_INSTAGRAM_COMMENTS_USE_STICKY_PROXY|SOCIAL_INSTAGRAM_COMMENTS_PROXY_SESSION_TTL_SECONDS|required_execution_backend|required_worker_lane|sessionduration" \
  .env.example \
  docs/workspace/instagram-comments-scrapling.md \
  trr_backend/socials/instagram/comments_scrapling/proxy.py \
  trr_backend/repositories/social_season_analytics.py
```

Expected:

- `.env.example` and the runbook both mention sticky-session semantics.
- `comments_scrapling/proxy.py` now reads both sticky env vars.
- `social_season_analytics.py` remains the source of truth for `required_execution_backend` and `required_worker_lane`.

- [ ] **Step 4: Re-run the existing hybrid-execution regression test**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
./.venv/bin/pytest tests/repositories/test_social_season_analytics.py -k "comments_scrape_uses_modal_execution_backend_without_dedicated_lane" -q
```

Expected: PASS. This confirms the docs now describe behavior already enforced in repo tests.

- [ ] **Step 5: Commit**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
git add \
  .env.example \
  docs/workspace/instagram-comments-scrapling.md
git commit -m "docs(instagram-comments): align sticky proxy and execution docs"
```

---

## Self-Review

### Spec coverage

- Confirmed sticky-proxy env drift: covered by Task 1 and Task 2.
- Confirmed comments execution docs drift: covered by Task 2.
- Intentionally excluded broader hardening items (`posts_scrapling` shadow compare, Scrapling re-warmup) because they are not current source-of-truth defects.

### Placeholder scan

- No `TODO`, `TBD`, or “implement later” markers remain.
- Every code-changing step includes an explicit code snippet.
- Every validation step includes an exact command and expected result.

### Type consistency

- `select_comments_proxy(*, session_key: str | None = None)` is defined once and used consistently in both tests and `job_runner.py`.
- Sticky-session formatting uses one deterministic helper path in `comments_scrapling/proxy.py`; no second proxy-formatting API is introduced.

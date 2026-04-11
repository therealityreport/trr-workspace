# TikTok YT-DLP Hardening And Browser Intercept Recovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Treat `yt-dlp` as the only known-good TikTok posts path, harden its operational visibility, and run a focused recovery triage on `browser_intercept` before any TikTok comments work is reconsidered.

**Architecture:** Keep the production posts path on `yt-dlp`, but make its single-path risk explicit in scraper diagnostics, admin/API status payloads, and operator docs. In parallel, instrument `browser_intercept` just enough to classify why it returns `0` posts on `@bravotv` so the next planning cycle can choose between repairing that surface first or keeping comments work parked.

**Tech Stack:** Python 3.11, FastAPI, pytest, Markdown planning docs, existing TikTok scraper/CLI tooling

---

## File Structure

- Modify: `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/socials/tiktok/scraper.py`
  - Add a small path-health helper for `yt-dlp` and structured triage metadata for `browser_intercept`.
- Modify: `/Users/thomashulihan/Projects/TRR/TRR-Backend/scripts/socials/tiktok/scrape.py`
  - Surface the new TikTok risk metadata in the CLI diagnostics summary.
- Modify: `/Users/thomashulihan/Projects/TRR/TRR-Backend/api/routers/socials.py`
  - Expose safer TikTok scrape diagnostics and single-path alerts in admin-facing responses.
- Modify: `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/repositories/social_season_analytics.py`
  - Fold TikTok single-path alerts into existing ingest health / readiness payloads instead of inventing a new monitoring channel.
- Create: `/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/socials/tiktok/test_scraper.py`
  - Add focused unit coverage for path-health and browser-intercept triage classification.
- Create: `/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/scripts/test_tiktok_scrape_cli.py`
  - Lock the CLI diagnostics summary so it prints the new risk metadata.
- Create: `/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/api/routers/test_socials_tiktok_scrape.py`
  - Verify the admin scrape route returns a safe TikTok diagnostics subset.
- Modify: `/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/repositories/test_social_season_analytics.py`
  - Cover TikTok single-path alert generation in queue/readiness payloads.
- Modify: `/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/api/routers/test_socials_season_analytics.py`
  - Verify admin health-dot/live-status payloads include TikTok risk alerts.
- Create: `/Users/thomashulihan/Projects/TRR/TRR-Backend/docs/runbooks/tiktok-ytdlp-degradation.md`
  - Document what breaks when `yt-dlp` degrades, how operators recognize it, and what not to do.
- Create: `/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_BROWSER_INTERCEPT_RECOVERY_TRIAGE_2026-04-10.md`
  - Capture the focused recovery triage outcome for `browser_intercept`.
- Modify: `/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_SCRAPE_RESILIENCE_BOARD.md`
  - Update the board with the triage result and a sharper comments-planning note.

### Task 1: Add A Single-Path Health Contract To The TikTok Scraper

**Files:**
- Create: `/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/socials/tiktok/test_scraper.py`
- Modify: `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/socials/tiktok/scraper.py`

- [ ] **Step 1: Write failing tests for `yt-dlp` single-path metadata and browser-intercept triage buckets**

```python
from __future__ import annotations

from datetime import datetime

import pytest

from trr_backend.socials.tiktok.scraper import TikTokScrapeConfig, TikTokScraper


def _config() -> TikTokScrapeConfig:
    return TikTokScrapeConfig(
        username="bravotv",
        hashtags=["RHOBH"],
        date_start=datetime.fromisoformat("2026-03-31T00:00:00+00:00"),
        date_end=datetime.fromisoformat("2026-04-10T00:00:00+00:00"),
        max_pages=2,
    )


def test_ytdlp_zero_posts_marks_single_path_degraded(monkeypatch: pytest.MonkeyPatch) -> None:
    scraper = TikTokScraper(cookies={"sessionid": "cookie"})
    monkeypatch.setattr(scraper, "_scrape_via_ytdlp", lambda *args, **kwargs: [])

    posts = scraper.scrape(_config())

    assert posts == []
    assert scraper.last_retrieval_meta["retrieval_mode"] == "ytdlp"
    assert scraper.last_retrieval_meta["path_role"] == "primary"
    assert scraper.last_retrieval_meta["topology_state"] == "single_path_ytdlp"
    assert scraper.last_retrieval_meta["risk_state"] == "critical"
    assert scraper.last_retrieval_meta["operator_summary"] == (
        "TikTok posts path degraded: yt-dlp returned zero posts while browser_intercept is not proven live."
    )


def test_browser_intercept_zero_posts_classifies_target_drift() -> None:
    scraper = TikTokScraper(cookies={"sessionid": "cookie"})

    bucket = scraper._classify_browser_intercept_failure(  # noqa: SLF001
        posts_found=0,
        intercepted_post_responses=0,
        intercepted_user_detail_responses=1,
        dom_cards_seen=0,
        scroll_iterations=5,
        authenticated=True,
        playwright_error=None,
    )

    assert bucket == "interception_target_drift"
```

- [ ] **Step 2: Run the tests to confirm the new contract does not exist yet**

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest tests/socials/tiktok/test_scraper.py -q`

Expected: `FAIL` because `/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/socials/tiktok/test_scraper.py` does not exist and `_classify_browser_intercept_failure()` is not implemented.

- [ ] **Step 3: Add a minimal path-health helper and a browser-intercept classifier**

```python
def _set_tiktok_path_health(
    self,
    *,
    retrieval_mode: str,
    posts_found: int,
    stop_reason: str | None = None,
) -> None:
    self.last_retrieval_meta["retrieval_mode"] = retrieval_mode
    self.last_retrieval_meta["topology_state"] = "single_path_ytdlp"
    self.last_retrieval_meta["path_role"] = "primary" if retrieval_mode == "ytdlp" else "fallback"
    if retrieval_mode == "ytdlp" and posts_found <= 0:
        self.last_retrieval_meta["risk_state"] = "critical"
        self.last_retrieval_meta["operator_summary"] = (
            "TikTok posts path degraded: yt-dlp returned zero posts while browser_intercept is not proven live."
        )
        self.last_retrieval_meta["operator_action"] = "Check yt-dlp diagnostics before retrying browser_intercept or comments work."
    elif retrieval_mode == "ytdlp":
        self.last_retrieval_meta["risk_state"] = "healthy"
        self.last_retrieval_meta["operator_summary"] = "TikTok posts path healthy on yt-dlp."
    if stop_reason:
        self.last_retrieval_meta["stop_reason"] = stop_reason


def _classify_browser_intercept_failure(
    self,
    *,
    posts_found: int,
    intercepted_post_responses: int,
    intercepted_user_detail_responses: int,
    dom_cards_seen: int,
    scroll_iterations: int,
    authenticated: bool,
    playwright_error: str | None,
) -> str:
    if playwright_error:
        return "playwright_runtime_change"
    if not authenticated:
        return "auth_or_session_state"
    if intercepted_post_responses == 0 and intercepted_user_detail_responses > 0:
        return "interception_target_drift"
    if dom_cards_seen == 0 and scroll_iterations > 0:
        return "scroll_or_pagination_drift"
    if posts_found <= 0:
        return "unclassified_zero_posts"
    return "healthy"
```

- [ ] **Step 4: Call the helper from the existing scrape-mode routing paths**

```python
if mode in {"ytdlp", "auto"}:
    posts = self._scrape_via_ytdlp(
        config,
        max_videos_hint=config.ytdlp_max_videos_hint,
        max_posts_hint=config.ytdlp_max_videos_hint,
        progress_cb=progress_cb,
    )
    self._set_tiktok_path_health(
        retrieval_mode="ytdlp",
        posts_found=len(posts),
        stop_reason=str(self.last_retrieval_meta.get("stop_reason") or "").strip() or None,
    )
    self.last_retrieval_meta["profile_enrichment_status"] = "skipped"
    return posts

if mode == "browser_intercept":
    posts = self._scrape_browser_intercept(config, progress_cb=progress_cb)
    if not posts:
        self._ensure_structured_direct_failure(mode="browser_intercept")
        self.last_retrieval_meta["triage_bucket"] = self._classify_browser_intercept_failure(
            posts_found=0,
            intercepted_post_responses=int(self.last_retrieval_meta.get("intercepted_post_responses") or 0),
            intercepted_user_detail_responses=int(
                self.last_retrieval_meta.get("intercepted_user_detail_responses") or 0
            ),
            dom_cards_seen=int(self.last_retrieval_meta.get("dom_cards_seen") or 0),
            scroll_iterations=int(self.last_retrieval_meta.get("scroll_iterations") or 0),
            authenticated=bool(self.last_retrieval_meta.get("auth_mode") == "with_cookies"),
            playwright_error=str(self.last_retrieval_meta.get("playwright_error") or "").strip() or None,
        )
    return posts
```

- [ ] **Step 5: Run the unit tests and fix any contract drift**

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest tests/socials/tiktok/test_scraper.py -q`

Expected: `2 passed`

- [ ] **Step 6: Commit the scraper contract change**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
git add tests/socials/tiktok/test_scraper.py trr_backend/socials/tiktok/scraper.py
git commit -m "feat: add tiktok single-path health metadata"
```

### Task 2: Surface TikTok Risk Metadata In CLI And Admin Scrape Responses

**Files:**
- Create: `/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/scripts/test_tiktok_scrape_cli.py`
- Create: `/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/api/routers/test_socials_tiktok_scrape.py`
- Modify: `/Users/thomashulihan/Projects/TRR/TRR-Backend/scripts/socials/tiktok/scrape.py`
- Modify: `/Users/thomashulihan/Projects/TRR/TRR-Backend/api/routers/socials.py`

- [ ] **Step 1: Add failing tests for the CLI summary and admin scrape response shape**

```python
from __future__ import annotations

from scripts.socials.tiktok.scrape import _emit_diagnostics_summary


def test_emit_diagnostics_summary_prints_risk_lines(capsys) -> None:
    _emit_diagnostics_summary(
        target_label="@bravotv",
        scrape_mode="ytdlp",
        diagnostics={
            "http_client": "yt_dlp",
            "risk_state": "critical",
            "operator_summary": "TikTok posts path degraded: yt-dlp returned zero posts while browser_intercept is not proven live.",
            "operator_action": "Check yt-dlp diagnostics before retrying browser_intercept or comments work.",
        },
    )

    output = capsys.readouterr().out
    assert "Risk state: critical" in output
    assert "Operator summary: TikTok posts path degraded" in output
```

```python
from datetime import UTC, datetime


class _FakeTikTokScraper:
    def __init__(self, cookies: dict[str, str]) -> None:
        self.last_retrieval_meta = {
            "retrieval_mode": "ytdlp",
            "risk_state": "critical",
            "operator_summary": "TikTok posts path degraded: yt-dlp returned zero posts while browser_intercept is not proven live.",
            "operator_action": "Check yt-dlp diagnostics before retrying browser_intercept or comments work.",
        }

    def scrape(self, _config) -> list[object]:
        return []


def test_tiktok_scrape_response_includes_diagnostics(client, monkeypatch) -> None:
    import api.routers.socials as socials_router

    monkeypatch.setattr(socials_router, "_load_social_auth_or_503", lambda **kwargs: {"sessionid": "cookie"})
    monkeypatch.setattr("trr_backend.socials.tiktok.TikTokScraper", _FakeTikTokScraper)

    response = client.post(
        "/api/v1/admin/socials/tiktok/scrape",
        json={
            "username": "bravotv",
            "hashtags": ["RHOBH"],
            "date_start": datetime(2026, 3, 31, tzinfo=UTC).isoformat(),
            "date_end": datetime(2026, 4, 10, tzinfo=UTC).isoformat(),
            "delay_seconds": 2.0,
            "max_pages": 2,
        },
    )
    body = response.json()

    assert body["diagnostics"]["risk_state"] == "critical"
    assert body["diagnostics"]["operator_summary"].startswith("TikTok posts path degraded")
```

- [ ] **Step 2: Run the focused tests to verify the new fields are missing**

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest tests/scripts/test_tiktok_scrape_cli.py tests/api/routers/test_socials_tiktok_scrape.py -q`

Expected: `FAIL` because the CLI does not print `risk_state` / `operator_summary`, and the TikTok scrape response model does not include diagnostics yet.

- [ ] **Step 3: Extend the CLI diagnostics summary with risk-state lines**

```python
print(f"  HTTP client: {diagnostics.get('http_client') or 'requests'}")
print(f"  Auth mode: {diagnostics.get('auth_mode') or 'without_cookies'}")
if diagnostics.get("risk_state"):
    print(f"  Risk state: {diagnostics.get('risk_state')}")
if diagnostics.get("operator_summary"):
    print(f"  Operator summary: {diagnostics.get('operator_summary')}")
if diagnostics.get("operator_action"):
    print(f"  Operator action: {diagnostics.get('operator_action')}")
if diagnostics.get("triage_bucket"):
    print(f"  Triage bucket: {diagnostics.get('triage_bucket')}")
```

- [ ] **Step 4: Extend the admin TikTok scrape response with a safe diagnostics subset**

```python
class TikTokScrapeResponse(BaseModel):
    success: bool
    username: str
    posts_found: int
    posts: list[TikTokPostResponse]
    filters_applied: dict
    error: str | None = None
    diagnostics: dict[str, Any] | None = None
```

```python
safe_diagnostics = {
    key: value
    for key, value in dict(scraper.last_retrieval_meta or {}).items()
    if key in {
        "retrieval_mode",
        "http_client",
        "fallback_chain",
        "stop_reason",
        "error_code",
        "risk_state",
        "operator_summary",
        "operator_action",
        "triage_bucket",
        "profile_enrichment_status",
    }
}
```

- [ ] **Step 5: Re-run the CLI and router tests**

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest tests/scripts/test_tiktok_scrape_cli.py tests/api/routers/test_socials_tiktok_scrape.py -q`

Expected: `PASS`

- [ ] **Step 6: Commit the failure-surfacing change**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
git add tests/scripts/test_tiktok_scrape_cli.py api/routers/socials.py scripts/socials/tiktok/scrape.py
git commit -m "feat: surface tiktok scrape risk diagnostics"
```

### Task 3: Fold TikTok Single-Path Alerts Into Existing Health And Readiness Payloads

**Files:**
- Modify: `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/repositories/social_season_analytics.py`
- Modify: `/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/repositories/test_social_season_analytics.py`
- Modify: `/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/api/routers/test_socials_season_analytics.py`
- Create: `/Users/thomashulihan/Projects/TRR/TRR-Backend/docs/runbooks/tiktok-ytdlp-degradation.md`

- [ ] **Step 1: Add failing tests for a TikTok single-path alert and its API exposure**

```python
def test_queue_status_adds_tiktok_single_path_alert(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(social_repo, "get_worker_auth_capabilities", lambda: {"tiktok_authenticated": True})
    payload = social_repo._build_tiktok_transport_alerts(  # noqa: SLF001
        {
            "platform": "tiktok",
            "posts_primary_mode": "ytdlp",
            "posts_primary_healthy": False,
            "posts_fallback_mode": "browser_intercept",
            "posts_fallback_healthy": False,
        }
    )

    assert payload[0]["code"] == "tiktok_single_path_degraded"
    assert payload[0]["severity"] == "critical"
```

```python
from unittest.mock import patch


def test_health_dot_exposes_tiktok_single_path_alert(client) -> None:
    with patch(
        "trr_backend.repositories.social_season_analytics.get_queue_status",
        return_value={
            "alerts": [
                {
                    "code": "tiktok_single_path_degraded",
                    "severity": "critical",
                    "message": "TikTok yt-dlp degraded and browser_intercept is not proven live.",
                }
            ]
        },
    ):
        response = client.get("/api/v1/admin/socials/ingest/health-dot")
        body = response.json()

    assert any(alert["code"] == "tiktok_single_path_degraded" for alert in body["alerts"])
```

- [ ] **Step 2: Run the repository/API tests to confirm the alert does not exist**

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest tests/repositories/test_social_season_analytics.py tests/api/routers/test_socials_season_analytics.py -q`

Expected: `FAIL` because there is no TikTok-specific single-path alert builder yet.

- [ ] **Step 3: Add a narrow TikTok transport alert helper and wire it into existing alerts**

```python
def _build_tiktok_transport_alerts(status_payload: dict[str, Any]) -> list[dict[str, Any]]:
    if str(status_payload.get("posts_primary_mode") or "") != "ytdlp":
        return []
    if bool(status_payload.get("posts_primary_healthy")):
        return []
    if bool(status_payload.get("posts_fallback_healthy")):
        severity = "warning"
        code = "tiktok_primary_degraded_fallback_available"
        message = "TikTok yt-dlp degraded; browser_intercept is the only remaining backup."
    else:
        severity = "critical"
        code = "tiktok_single_path_degraded"
        message = "TikTok yt-dlp degraded and browser_intercept is not proven live."
    return [
        {
            "code": code,
            "severity": severity,
            "message": message,
            "platform": "tiktok",
        }
    ]
```

- [ ] **Step 4: Document what breaks if `yt-dlp` degrades**

```md
# TikTok yt-dlp Degradation Runbook

## Signals

- `risk_state=critical` in TikTok scrape diagnostics
- `tiktok_single_path_degraded` in admin ingest health alerts
- `posts_found=0` from `scrape_mode=ytdlp` on a known-good account such as `@bravotv`

## What Breaks

- TikTok post ingestion loses its only proven live production path.
- Season/account TikTok freshness becomes stale until ingestion succeeds again.
- `browser_intercept` cannot be treated as an automatic failover until the recovery triage says it is live again.
- Task 6 comments work remains planning-only because it depends on the same fragile browser surface.

## Non-Goals

- Do not re-open request signing.
- Do not re-open `curl_cffi + proxy` in the middle of an incident without a new approved plan.
```

- [ ] **Step 5: Re-run repository and API tests**

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest tests/repositories/test_social_season_analytics.py tests/api/routers/test_socials_season_analytics.py -q`

Expected: `PASS`

- [ ] **Step 6: Commit the monitoring and runbook work**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
git add trr_backend/repositories/social_season_analytics.py tests/repositories/test_social_season_analytics.py tests/api/routers/test_socials_season_analytics.py docs/runbooks/tiktok-ytdlp-degradation.md
git commit -m "feat: add tiktok single-path health alerts"
```

### Task 4: Instrument Browser Intercept For Focused Recovery Triage

**Files:**
- Modify: `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr_backend/socials/tiktok/scraper.py`
- Modify: `/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/socials/tiktok/test_scraper.py`

- [ ] **Step 1: Add failing tests for intercept, scroll, and auth/session counters**

```python
def test_browser_intercept_records_target_drift_counters() -> None:
    scraper = TikTokScraper(cookies={"sessionid": "cookie"})
    scraper.last_retrieval_meta.update(
        {
            "intercepted_post_responses": 0,
            "intercepted_user_detail_responses": 1,
            "dom_cards_seen": 0,
            "scroll_iterations": 5,
            "auth_mode": "with_cookies",
        }
    )

    assert scraper._classify_browser_intercept_failure(  # noqa: SLF001
        posts_found=0,
        intercepted_post_responses=0,
        intercepted_user_detail_responses=1,
        dom_cards_seen=0,
        scroll_iterations=5,
        authenticated=True,
        playwright_error=None,
    ) == "interception_target_drift"
```

- [ ] **Step 2: Run the scraper test file to keep the instrumentation work red-first**

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest tests/socials/tiktok/test_scraper.py -q`

Expected: `FAIL` until `_scrape_browser_intercept()` records the counters below.

- [ ] **Step 3: Record the minimum triage fields inside `_scrape_browser_intercept()`**

```python
self.last_retrieval_meta.update(
    {
        "intercepted_post_responses": 0,
        "intercepted_user_detail_responses": 0,
        "dom_cards_seen": 0,
        "scroll_iterations": 0,
        "playwright_error": None,
    }
)

def handle_response(response):
    url = response.url
    if "item_list" in url or "post/item_list" in url:
        self.last_retrieval_meta["intercepted_post_responses"] += 1
    if "user/detail" in url or "fetch_user_detail" in url:
        self.last_retrieval_meta["intercepted_user_detail_responses"] += 1

for scroll_index in range(max_scrolls):
    self.last_retrieval_meta["scroll_iterations"] = scroll_index + 1
    await page.mouse.wheel(0, 2500)
    await page.wait_for_timeout(int(max(config.delay_seconds, 0.5) * 1000))
    cards = await page.locator("[data-e2e='user-post-item'], [data-e2e='user-post-item-list']").count()
    self.last_retrieval_meta["dom_cards_seen"] = max(
        int(self.last_retrieval_meta.get("dom_cards_seen") or 0),
        cards,
    )
```

- [ ] **Step 4: Persist the classified triage bucket into `last_retrieval_meta` before returning**

```python
if not posts:
    self.last_retrieval_meta["triage_bucket"] = self._classify_browser_intercept_failure(
        posts_found=0,
        intercepted_post_responses=int(self.last_retrieval_meta.get("intercepted_post_responses") or 0),
        intercepted_user_detail_responses=int(self.last_retrieval_meta.get("intercepted_user_detail_responses") or 0),
        dom_cards_seen=int(self.last_retrieval_meta.get("dom_cards_seen") or 0),
        scroll_iterations=int(self.last_retrieval_meta.get("scroll_iterations") or 0),
        authenticated=bool(self.last_retrieval_meta.get("auth_mode") == "with_cookies"),
        playwright_error=str(self.last_retrieval_meta.get("playwright_error") or "").strip() or None,
    )
```

- [ ] **Step 5: Re-run the focused scraper tests**

Run: `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest tests/socials/tiktok/test_scraper.py -q`

Expected: `PASS`

- [ ] **Step 6: Commit the browser-intercept instrumentation**

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
git add trr_backend/socials/tiktok/scraper.py tests/socials/tiktok/test_scraper.py
git commit -m "feat: instrument tiktok browser intercept triage"
```

### Task 5: Run A Bounded Browser Intercept Recovery Triage And Save The Result

**Files:**
- Create: `/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_BROWSER_INTERCEPT_RECOVERY_TRIAGE_2026-04-10.md`
- Modify: `/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_SCRAPE_RESILIENCE_BOARD.md`

- [ ] **Step 1: Create the triage note with a fixed structure**

```md
# TikTok Browser Intercept Recovery Triage

Date: 2026-04-10

## Question

Why does `browser_intercept` return `0` posts on `@bravotv`?

## Inputs

- `/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_BROWSER_INTERCEPT_SANITY_CHECK_2026-04-10.md`
- `/tmp/tiktok-browser-intercept-20260410.json`

## Hypotheses

1. auth/session state
2. interception target drift
3. scroll/pagination drift
4. Playwright/TikTok runtime change

## Invocation

## Diagnostics

## Conclusion
```

- [ ] **Step 2: Run one authenticated recovery-triage invocation with the new diagnostics fields**

Run:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
python -m scripts.socials.tiktok.scrape \
  --username bravotv \
  --hashtags RHOBH \
  --start 2026-03-31 \
  --end 2026-04-10 \
  --max-pages 2 \
  --scrape-mode browser_intercept \
  --diagnostics-json /tmp/tiktok-browser-intercept-recovery-20260410.json
```

Expected: command completes and writes `/tmp/tiktok-browser-intercept-recovery-20260410.json` with `triage_bucket`, intercept counters, and scroll counters.

- [ ] **Step 3: Record the classification result without expanding scope**

```md
## Conclusion

The authenticated 2026-04-10 recovery-triage run classified the failure as `interception_target_drift` because `fetch_user_detail` still responded while no post-list intercepts were captured and no DOM cards accumulated across the scroll loop. Do not broaden this into request-signing or proxy work; the next engineering decision is whether to repair the intercept target or keep TikTok fallback risk explicit.
```

- [ ] **Step 4: Update the resilience board to reference the recovery-triage note**

```md
2. `browser_intercept`
   - Status: only remaining in-repo backup path.
   - Current state: `/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_BROWSER_INTERCEPT_RECOVERY_TRIAGE_2026-04-10.md` classifies the 2026-04-10 failure as `interception_target_drift` until proven otherwise.
```

- [ ] **Step 5: Verify the note and board entries exist**

Run: `rg -n "Recovery Triage|triage_bucket|interception_target_drift|browser_intercept" /Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_BROWSER_INTERCEPT_RECOVERY_TRIAGE_2026-04-10.md /Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_SCRAPE_RESILIENCE_BOARD.md`

Expected: matches in both files.

- [ ] **Step 6: Commit the triage artifacts**

```bash
cd /Users/thomashulihan/Projects/TRR
git add .planning/research/TIKTOK_BROWSER_INTERCEPT_RECOVERY_TRIAGE_2026-04-10.md .planning/research/TIKTOK_SCRAPE_RESILIENCE_BOARD.md
git commit -m "docs: record tiktok browser intercept recovery triage"
```

### Task 6: Re-Evaluate Task 6 Comments Work As Planning Only

**Files:**
- Modify: `/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_SCRAPE_RESILIENCE_BOARD.md`
- Create: `/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_TASK6_COMMENTS_REEVALUATION_2026-04-10.md`

- [ ] **Step 1: Create a short planning-only decision memo**

```md
# TikTok Task 6 Comments Re-Evaluation

Date: 2026-04-10

## Decision

Task 6 remains parked until the `browser_intercept` recovery triage produces a repair plan or a live fallback result.

## Why

- `yt-dlp` is the only proven posts path.
- `browser_intercept` is currently the shared risk surface for both posts fallback and eventual comments collection.
- Starting comments implementation before repairing or explicitly abandoning that surface would hide the real bottleneck.

## Next Planning Trigger

Revisit immediately after the `browser_intercept` recovery-triage note is closed with either a repair plan or a formal abandonment decision.
```

- [ ] **Step 2: Update the Deferred Task 6 entry to point at the re-evaluation memo**

```md
- Updated planning note:
  - `/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_TASK6_COMMENTS_REEVALUATION_2026-04-10.md` is the source of truth for whether comments work stays parked after the browser-intercept recovery triage.
```

- [ ] **Step 3: Verify the Task 6 planning artifacts**

Run: `rg -n "Comments Re-Evaluation|browser_intercept recovery triage|remains parked" /Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_TASK6_COMMENTS_REEVALUATION_2026-04-10.md /Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_SCRAPE_RESILIENCE_BOARD.md`

Expected: the new memo and updated deferred entry both match.

- [ ] **Step 4: Commit the planning-only Task 6 update**

```bash
cd /Users/thomashulihan/Projects/TRR
git add .planning/research/TIKTOK_TASK6_COMMENTS_REEVALUATION_2026-04-10.md .planning/research/TIKTOK_SCRAPE_RESILIENCE_BOARD.md
git commit -m "docs: re-evaluate tiktok comments planning"
```

## Test Plan

1. `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && pytest tests/socials/tiktok/test_scraper.py tests/scripts/test_tiktok_scrape_cli.py tests/repositories/test_social_season_analytics.py tests/api/routers/test_socials_season_analytics.py -q`
   - expected: pass

2. `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m scripts.socials.tiktok.scrape --username bravotv --hashtags RHOBH --start 2026-03-31 --end 2026-04-10 --max-pages 2 --scrape-mode ytdlp --diagnostics-json /tmp/tiktok-ytdlp-health-20260410.json`
   - expected: known-good control run with `retrieval_mode="ytdlp"`

3. `cd /Users/thomashulihan/Projects/TRR/TRR-Backend && python -m scripts.socials.tiktok.scrape --username bravotv --hashtags RHOBH --start 2026-03-31 --end 2026-04-10 --max-pages 2 --scrape-mode browser_intercept --diagnostics-json /tmp/tiktok-browser-intercept-recovery-20260410.json`
   - expected: command completes and writes triage counters even if posts remain `0`

4. `python3 /Users/thomashulihan/Projects/TRR/scripts/sync-handoffs.py --check`
   - expected: green if local-status docs are touched during execution

5. `bash /Users/thomashulihan/Projects/TRR/scripts/handoff-lifecycle.sh post-phase`
   - expected: green if handoff sources change during execution

## Assumptions And Defaults

- This plan intentionally does **not** reopen request-signing work (`msToken`, `X-Bogus`, `_signature`) or `curl_cffi + proxy`.
- `yt-dlp` remains the production path throughout this plan; no automatic failover to `browser_intercept` is introduced here.
- The browser-intercept triage stays bounded to classification and evidence capture. If the result points at a repair, that repair gets its own follow-up plan.
- If execution updates any handoff-source docs, keep the existing repo-wide “do not touch unrelated Ruff failures” guard in place.

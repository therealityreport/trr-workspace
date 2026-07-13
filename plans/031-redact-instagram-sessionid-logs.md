# Plan 031: Stop logging raw Instagram `sessionid` prefixes (log a fingerprint instead)

> **Executor instructions**: Follow step by step. Run every verification command
> before moving on. If a "STOP conditions" item occurs, stop and report. Update
> the `plans/README.md` status row when done unless a reviewer maintains it.
>
> **Drift check (run first)**:
> `git -C TRR-Backend diff --stat -- trr_backend/socials/instagram/scraper.py`
> The nested `TRR-Backend` tree is authoritative and dirty. Confirm the "Current
> state" excerpts before editing. On mismatch, STOP.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: security
- **Planned at**: commit `8ea7aa1a` (TRR-Backend), 2026-07-08 — working tree authoritative
- **Repo**: TRR-Backend

## Why this matters

Two `logger.info` calls in the Instagram scraper emit the first 8 characters of
the live `sessionid` cookie. Root-logger output is shipped off-box to a log store
(Better Stack). A partial session-token prefix in a centralized log store is
needless token/PII exposure and diverges from the project's own hygiene
elsewhere: `chrome_cookie_model.py` sets `do_not_print_cookie_values`, and the
cookie-refresh script logs a SHA-256 fingerprint rather than the value. This plan
replaces the raw prefix with a non-reversible fingerprint that still lets an
operator correlate "same cookie across log lines" without exposing token
material.

## Current state

`trr_backend/socials/instagram/scraper.py` — two sites.

Around line 877:

```python
            logger.info(
                "[instagram] confirmed cookie repair succeeded - sessionid=%s...",
                fresh_cookies["sessionid"][:8],
            )
```

Around line 972:

```python
            logger.info("[instagram] interactive login succeeded — sessionid=%s…", fresh_cookies["sessionid"][:8])
```

Prior art (do not necessarily import — see Step 1): `auth_resolver.py:217`
`_cookie_fingerprint`, `auth_runtime.py:177` `_instagram_cookie_fingerprint`,
and `scripts/modal/refresh_instagram_cookies_from_chrome.py` all use SHA-256
fingerprints of cookie material.

Repo conventions: ruff py311, line 120, double quotes. `hashlib` is already used
across the socials tree.

## Commands you will need

| Purpose | Command | Expected |
|---------|---------|----------|
| Find the sites | `grep -n 'sessionid=%s' TRR-Backend/trr_backend/socials/instagram/scraper.py` | 2 hits |
| Import gate | `cd TRR-Backend && .venv/bin/python -c "import trr_backend.socials.instagram.scraper"` | exit 0 |
| Focused tests | `cd TRR-Backend && .venv/bin/python -m pytest tests/socials/test_instagram_sessionid_redaction.py -q` | all pass |
| Lint | `cd TRR-Backend && ruff check trr_backend/socials/instagram/scraper.py tests/socials/test_instagram_sessionid_redaction.py` | exit 0 |

## Scope

**In scope**:
- `TRR-Backend/trr_backend/socials/instagram/scraper.py` — the two log sites and
  one small helper.
- `TRR-Backend/tests/socials/test_instagram_sessionid_redaction.py` (create).

**Out of scope**:
- The other cookie-fingerprint helpers (reference only — do not refactor them).
- Any other `logger` call in the file. If you spot another raw-secret log while
  here, note it in your report; do not fix it in this plan.
- `chrome_cookie_model.py` and the refresh scripts.

## Steps

### Step 1: Add a module-local sessionid fingerprint helper

Add near the top of `scraper.py` (after imports; ensure `import hashlib` is
present):

```python
def _sessionid_fingerprint(cookies: Mapping[str, Any]) -> str:
    """Non-reversible, stable fingerprint of the sessionid for log correlation.

    Never log the raw sessionid (or a prefix of it) — this ships to a central log
    store. Same sessionid -> same fingerprint, so operators can still correlate.
    """
    raw = str((cookies or {}).get("sessionid") or "")
    if not raw:
        return "none"
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()[:12]
```

Use whatever mapping type the file already imports for annotations (`Mapping`);
if it isn't imported, use `dict[str, Any]` in the signature to avoid adding an
import.

**Verify**: `cd TRR-Backend && .venv/bin/python -c "import trr_backend.socials.instagram.scraper"` → exit 0.

### Step 2: Replace both raw-prefix logs

- Site 1 → `"[instagram] confirmed cookie repair succeeded - sessionid_fp=%s", _sessionid_fingerprint(fresh_cookies)`
- Site 2 → `"[instagram] interactive login succeeded — sessionid_fp=%s", _sessionid_fingerprint(fresh_cookies)`

Keep the log level (`info`) and the surrounding message text; only the value
changes from a raw prefix to the fingerprint, and the placeholder label from
`sessionid=` to `sessionid_fp=`.

**Verify**: `grep -n 'sessionid.*\[:8\]' TRR-Backend/trr_backend/socials/instagram/scraper.py` → no matches.

### Step 3: Test the helper

Create `tests/socials/test_instagram_sessionid_redaction.py`. Assert:
1. `_sessionid_fingerprint({"sessionid": "SECRET_VALUE"})` is deterministic
   (same input → same output) and does **not** contain `"SECRET_VALUE"` or its
   first 8 chars.
2. Different sessionids → different fingerprints.
3. Missing sessionid → `"none"` (no crash).

**Verify**: `cd TRR-Backend && .venv/bin/python -m pytest tests/socials/test_instagram_sessionid_redaction.py -q` → all pass.

## Test plan

- New test file per Step 3. Case 1 (fingerprint doesn't leak the value) is the
  mandatory security assertion.
- Verification: focused test command above → all pass.

## Done criteria

- [ ] `cd TRR-Backend && .venv/bin/python -c "import trr_backend.socials.instagram.scraper"` exits 0
- [ ] `grep -n 'sessionid.*\[:8\]' TRR-Backend/trr_backend/socials/instagram/scraper.py` → no matches
- [ ] Both log sites use `_sessionid_fingerprint(...)`
- [ ] `cd TRR-Backend && .venv/bin/python -m pytest tests/socials/test_instagram_sessionid_redaction.py -q` passes
- [ ] `ruff check ...` exits 0
- [ ] No files outside scope modified (`git -C TRR-Backend status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report if:

- Either log site does not match the "Current state" excerpt.
- `fresh_cookies` is not a mapping with a `sessionid` key at those sites (then the
  helper call shape is wrong — report it).

## Maintenance notes

- Consider a follow-up sweep (backlog): grep the socials tree for any other
  `logger.*sessionid`/`password`/`token` raw-value logs. This plan fixes only the
  two confirmed Instagram sites.
- A reviewer should confirm the fingerprint is not itself used anywhere as an
  auth value (it is log-only).

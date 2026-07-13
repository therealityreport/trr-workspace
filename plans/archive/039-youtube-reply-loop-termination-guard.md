# Plan 039: Add the non-advancing-continuation guard to the YouTube reply-fetch loop

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: from `TRR-Backend/`, run
> `git diff --stat 8ea7aa1a..HEAD -- trr_backend/socials/youtube/scraper.py`
> If the file changed since this plan was written, compare the "Current state"
> excerpts against the live code before proceeding; on a mismatch, treat it as a
> STOP condition. If the SHA does not resolve, compare by hand and note it.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `8ea7aa1a` (TRR-Backend), 2026-07-08

## Why this matters

`YouTubeScraper._fetch_comment_replies` paginates replies with
`while continuation_token:` and, at the end of each iteration, does
`continuation_token = next_continuation` with **no check that the token
advanced**, no visited-token set, and no page cap. If YouTube returns a
continuation item whose token equals the current token — which happens on schema
drift, an error/interstitial page, or an adversarial thread — the loop spins
forever, issuing rate-limited requests indefinitely and hanging the worker/CLI on
a single comment. The parent comment loop (`fetch_comments`) was already hardened
against exactly this (`if continuation_token == next_continuation: … break` plus
an empty-page break); the reply loop was not. This is the kind of latent hang
that only manifests in production against a live, drifting third-party surface.

After this plan, the reply loop terminates on a non-advancing token, an empty
page with no continuation, or a max-pages cap — matching the parent loop's
robustness.

## Current state

- `trr_backend/socials/youtube/scraper.py` — the reply loop (lines 4278-4327).
  Note the last line reassigns the token with no guard:

```python
        while continuation_token:
            self._rate_limit(delay, fast_mode=fast_mode)
            data = self._fetch_comment_continuation(continuation_token, delay)
            if not data:
                break

            next_continuation = None
            entity_index = self._build_comment_entity_index(data)
            try:
                on_response = self._comment_response_containers(data)
                for endpoint in on_response:
                    append_items = endpoint.get("appendContinuationItemsAction", {}).get("continuationItems", [])
                    reload_items = endpoint.get("reloadContinuationItemsCommand", {}).get("continuationItems", [])
                    for item in [*append_items, *reload_items]:
                        comment_renderer = item.get("commentRenderer", {})
                        if comment_renderer:
                            reply = self._parse_comment_renderer(...)
                            if reply:
                                replies.append(reply)
                        else:
                            ...
                            reply = self._parse_comment_view_model(...)
                            if reply:
                                replies.append(reply)

                        # Check for more replies
                        next_continuation = self._extract_token_from_continuation_item(item) or next_continuation
            except (KeyError, TypeError):
                break

            continuation_token = next_continuation   # <-- no advance/visited/cap guard
        return replies
```

- The parent loop pattern to mirror is `fetch_comments` (around lines
  3606-3613), which already guards with a token-equality break and an
  empty-page break. Read it before editing so your guard matches the house style.

Convention: the scraper is a class with `self._rate_limit`, `self._fetch_comment_continuation`,
etc.; use module constants for caps if the file already defines pagination caps
(grep for `MAX_PAGES`/`_MAX_`). ruff py311, line 120, double quotes.

## Commands you will need

| Purpose      | Command (run from `TRR-Backend/`)                                    | Expected on success   |
|--------------|----------------------------------------------------------------------|-----------------------|
| Import gate  | `.venv/bin/python -c "import api.main"`                               | exit 0                |
| Focused test | `.venv/bin/python -m pytest tests/socials/youtube/test_scraper.py -q`| all pass              |
| Lint         | `ruff check trr_backend/socials/youtube/scraper.py`                  | `All checks passed!`  |

## Scope

**In scope** (the only files you should modify):
- `trr_backend/socials/youtube/scraper.py` — the `_fetch_comment_replies` loop only
- `tests/socials/youtube/test_scraper.py` — add a termination test

**Out of scope** (do NOT touch):
- `fetch_comments` (the parent loop) — it is already guarded; do not refactor it.
- Any other scraper method, media resolver, or the SocialBlade lane.
- The parsing helpers (`_parse_comment_renderer`, `_parse_comment_view_model`,
  `_extract_token_from_continuation_item`) — the bug is loop control, not parsing.

## Git workflow

- Branch: `advisor/039-youtube-reply-loop-termination-guard`
- One commit. Message style (match `git log --oneline`): imperative subject,
  e.g. `guard youtube reply pagination against a non-advancing continuation token`.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Add advance-check, visited-set, and page cap to the reply loop

Mirror the parent loop's guard. Before the loop, initialize a visited set and a
page counter; at the end of each iteration, break when the token does not advance,
is already seen, or the page cap is reached:

```python
        seen_tokens: set[str] = set()
        max_reply_pages = <use the existing module cap if one exists, else 200>
        pages = 0
        while continuation_token:
            if continuation_token in seen_tokens:
                break
            seen_tokens.add(continuation_token)
            pages += 1
            if pages > max_reply_pages:
                logger.warning("[youtube_reply_pagination_capped] pages=%s parent_id=%s", pages, parent_id)
                break

            self._rate_limit(delay, fast_mode=fast_mode)
            data = self._fetch_comment_continuation(continuation_token, delay)
            if not data:
                break

            next_continuation = None
            ...  # existing body unchanged
            except (KeyError, TypeError):
                break

            if not next_continuation or next_continuation == continuation_token:
                break
            continuation_token = next_continuation
        return replies
```

Notes:
- Use whatever logger the file already uses (grep for `logger =`); if there is
  none in scope, drop the warning log and just `break`.
- If the file already defines a comment/reply page cap constant, use it instead
  of a literal — search for existing `*_PAGES`/`*_MAX_*` names first.
- Do not change what gets appended to `replies` or how tokens are extracted.

**Verify**: `.venv/bin/python -m pytest tests/socials/youtube/test_scraper.py -q` → all pass (existing reply tests unaffected).

## Test plan

Add to `tests/socials/youtube/test_scraper.py` (model after the existing scraper
tests — they already construct a `YouTubeScraper` and patch its continuation
fetcher). Add a test that:

- Patches `_fetch_comment_continuation` to always return a payload whose only
  continuation item yields the **same** token it was called with (a stuck
  token), plus one reply item.
- Calls `_fetch_comment_replies(...)` and asserts it **returns** (does not hang)
  after a bounded number of `_fetch_comment_continuation` calls (assert the call
  count is small — e.g. `<= 2` for the equality-break, or `<= max_reply_pages+1`
  for the cap), and that the collected replies are returned.

Use a call counter / `unittest.mock.Mock(side_effect=...)` so the assertion is on
call count, giving a deterministic proof the loop terminates.

Verification: `.venv/bin/python -m pytest tests/socials/youtube/test_scraper.py -q` → all pass, with the new termination test.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `.venv/bin/python -c "import api.main"` exits 0
- [ ] `.venv/bin/python -m pytest tests/socials/youtube/test_scraper.py -q` passes, with the new termination test present
- [ ] `ruff check trr_backend/socials/youtube/scraper.py` prints `All checks passed!`
- [ ] `grep -n "seen_tokens" trr_backend/socials/youtube/scraper.py` returns a match inside `_fetch_comment_replies`
- [ ] `git status --short` shows only the two in-scope files modified
- [ ] `plans/README.md` status row updated *(skip if a dispatching reviewer maintains the index)*

## STOP conditions

Stop and report back (do not improvise) if:

- The "Current state" excerpt does not match live code (drift).
- The reply loop already has a termination guard you missed (re-read it) — then
  no change is needed; report that.
- A verification fails twice after a reasonable fix attempt.

## Maintenance notes

- A reviewer should confirm the guard mirrors `fetch_comments` and that the cap
  is high enough not to truncate legitimate deep reply threads (200 pages of
  replies is already extreme for YouTube).
- If YouTube's reply continuation shape changes, this loop and `fetch_comments`
  should be updated together — they share the same pagination contract.

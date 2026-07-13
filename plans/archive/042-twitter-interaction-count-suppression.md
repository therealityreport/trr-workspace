# Plan 042: Stop Twitter interaction "duplicate" mis-counting from permanently suppressing real repair candidates

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan in
> `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: from `TRR-Backend/`, run
> `git diff --stat 8ea7aa1a..HEAD -- trr_backend/socials/twitter/posts_catalog/catalog.py trr_backend/socials/twitter/repair_planner.py trr_backend/socials/social_season_analytics_impl.py`
> If any file changed since this plan was written, compare the "Current state"
> excerpts against the live code before proceeding; on a mismatch, treat it as a
> STOP condition. If the SHA does not resolve, compare by hand and note it.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `8ea7aa1a` (TRR-Backend), 2026-07-08

## Why this matters

When the Twitter catalog persists a root tweet's replies/quotes, it records
`duplicate_count = max(0, len(replies) - reply_upserted)` and
`unique_saved_delta = reply_upserted`, where `reply_upserted` counts only
truthy returns from `deps.upsert_tweet(...)`. But `upsert_tweet` returns `None`
for a **non-duplicate** reason — a payload that fails preparation
(`_build_twitter_tweet_payload` returns `None`, e.g. a missing/invalid tweet id),
tracked as `comments_skipped_missing_id`. The underlying upsert is
`ON CONFLICT DO UPDATE ... RETURNING *`, so a genuine duplicate returns a truthy
row and is counted in `reply_upserted`. The net effect: `duplicate_count` is
actually a **skip/failure count mislabeled as duplicates**, and genuine
duplicates are hidden inside `unique_saved_delta`.

The repair planner then suppresses a root+kind as `low_unique_yield` when
`unique_saved_delta <= 3` and `duplicate_count >= 50`, and
`build_twitter_repair_plan` drops suppressed candidates unless `force`/
`include_suppressed`. So a root whose replies were fetched but systematically
skipped (a payload-prep regression, a schema drift that trips the id extractor)
records `unique≈0` + `duplicate≥50` and is **permanently removed from the repair
plan** — genuinely-missing interactions never get backfilled.

The fix distinguishes the three real outcomes — inserted, duplicate (updated),
skipped — using the insert flag `_pg_upsert` already supports, so
`duplicate_count` reflects genuine duplicates and skips no longer trip
suppression.

## Current state

- `trr_backend/socials/twitter/posts_catalog/catalog.py` — the reply persist loop
  (lines ~876–922) and the quote persist loop (~1037–1074). Replies:
```python
            row = deps.upsert_tweet(
                None, job_id=job_id, run_id=run_id, account=account_handle, tweet=reply, persist_stats=None,
            )
            stats["comments_fetched"] += 1
            if row:
                stats["comments_upserted"] += 1
                reply_upserted += 1
            ...
            _record_interaction_fetch_state(
                ...
                unique_saved_delta=reply_upserted,
                duplicate_count=max(0, len(replies) - reply_upserted),
                ...
            )
```
  Quotes mirror this at ~1037–1074:
  `unique_saved_delta=quote_upserted`,
  `duplicate_count=max(0, quote_saved_total - quote_upserted)`.

- `trr_backend/socials/social_season_analytics_impl.py` — `_upsert_tweet`
  (starts line 29171). It returns `dict | None`; returns `None` when the payload
  can't be prepared (non-duplicate skip), else returns the row from `_pg_upsert`:
```python
    prepared = _build_twitter_tweet_payload(...)
    if prepared is None:
        if persist_stats is not None:
            persist_stats["comments_skipped_missing_id"] = int(persist_stats.get("comments_skipped_missing_id") or 0) + 1
        return None
    _tweet_id, payload = prepared
    row = _pg_upsert("twitter_tweets", payload, conflict_col="tweet_id", conn=conn)
    ...
    return row
```

- `trr_backend/socials/social_season_analytics_impl.py` — `_pg_upsert`
  (starts line 21179) already supports an insert flag:
```python
    returning_sql = "*, (xmax = 0) as __trr_inserted" if include_inserted_flag else "*"
    ...  ON CONFLICT ({conflict_list}) DO UPDATE SET {updates} ... RETURNING {returning_sql}
```
  With `include_inserted_flag=True`, the returned row carries a boolean
  `__trr_inserted` (`True` = fresh insert, `False` = updated duplicate). This key
  is **additive** — callers that don't read it are unaffected.

- `trr_backend/socials/twitter/repair_planner.py` — the suppression it feeds:
```python
LOW_YIELD_UNIQUE_THRESHOLD = 3
LOW_YIELD_DUPLICATE_THRESHOLD = 50
def _low_yield_suppression_reason(state, raw_missing):
    ...
    if state.unique_saved_delta > LOW_YIELD_UNIQUE_THRESHOLD:
        return None
    if state.duplicate_count < LOW_YIELD_DUPLICATE_THRESHOLD:
        return None
    return "low_unique_yield"
```
  Do NOT change the planner — it is correct **once** `duplicate_count` means
  genuine duplicates and `unique_saved_delta` means genuine inserts.

Convention: this repo uses `_pg_upsert` for upserts and passes structured
`persist_stats` dicts; match the existing `stats[...]` counting idiom in
catalog.py. ruff py311, line 120, double quotes.

## Commands you will need

| Purpose      | Command (run from `TRR-Backend/`)                                                                 | Expected on success   |
|--------------|---------------------------------------------------------------------------------------------------|-----------------------|
| Import gate  | `.venv/bin/python -c "import api.main"`                                                            | exit 0                |
| Focused test | `.venv/bin/python -m pytest tests/socials/twitter/test_twitter_posts_catalog.py tests/socials/twitter/test_twitter_repair_planner.py -q` | all pass |
| Lint         | `ruff check trr_backend/socials/twitter/posts_catalog/catalog.py trr_backend/socials/social_season_analytics_impl.py` | `All checks passed!` |

## Scope

**In scope**:
- `trr_backend/socials/social_season_analytics_impl.py` — **only** the single
  `_pg_upsert(...)` call inside `_upsert_tweet` (add `include_inserted_flag=True`).
  Do not touch anything else in this 68.7K-line file.
- `trr_backend/socials/twitter/posts_catalog/catalog.py` — the reply and quote
  persist loops + their `_record_interaction_fetch_state` calls.
- `tests/socials/twitter/test_twitter_posts_catalog.py` (add/extend a test).

**Out of scope**:
- `trr_backend/socials/twitter/repair_planner.py` — leave the suppression logic
  and thresholds unchanged; the fix is upstream in what feeds them.
- `_build_twitter_tweet_payload`, `_pg_upsert`'s own body, and every other
  `_upsert_tweet` caller — do not change `_upsert_tweet`'s signature or the
  meaning of its return value beyond the additive `__trr_inserted` key on the row.
- The `stats["comments_upserted"]`/`stats["quotes_upserted"]` aggregate counters
  — keep counting any saved row (insert or update) there; only the
  `_record_interaction_fetch_state` fields change.

## Git workflow

- Branch: `advisor/042-twitter-interaction-count-suppression`
- One commit. Message style (match `git log --oneline`): imperative subject,
  e.g. `count twitter interaction inserts vs duplicates vs skips correctly`.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Surface the insert flag from `_upsert_tweet`

In `_upsert_tweet` (`social_season_analytics_impl.py`), change the single upsert
call to request the insert flag:
```python
    row = _pg_upsert("twitter_tweets", payload, conflict_col="tweet_id", conn=conn, include_inserted_flag=True)
```
The returned `row` now carries `row["__trr_inserted"]` (`True`=insert,
`False`=duplicate/update). The return value is still the row dict (or `None` on
prep-skip) — no signature or None-path change.

**Verify**: `.venv/bin/python -c "import api.main"` → exit 0.

### Step 2: Count inserted / duplicate / skipped in the catalog loops

In `catalog.py`, in the **reply** loop, replace the single `reply_upserted`
counter with three counters:
```python
        reply_inserted = 0
        reply_duplicate = 0
        reply_skipped = 0
        for reply_index, reply in enumerate(replies, start=1):
            ...
            row = deps.upsert_tweet(None, job_id=job_id, run_id=run_id, account=account_handle, tweet=reply, persist_stats=None)
            stats["comments_fetched"] += 1
            if row:
                stats["comments_upserted"] += 1
                if row.get("__trr_inserted"):
                    reply_inserted += 1
                else:
                    reply_duplicate += 1
            else:
                reply_skipped += 1
            ...
```
Then in the `_record_interaction_fetch_state(...)` call use:
```python
                saved_count_after=reply_inserted + reply_duplicate,
                unique_saved_delta=reply_inserted,
                duplicate_count=reply_duplicate,
```
Keep `pages_scanned`, `status`, etc. unchanged. Apply the **identical** pattern to
the quote loop (`quote_inserted`/`quote_duplicate`/`quote_skipped`;
`unique_saved_delta=quote_inserted`, `duplicate_count=quote_duplicate`). If the
quote loop currently computes `quote_saved_total` for `saved_count_after`, set
`saved_count_after=quote_inserted + quote_duplicate` and leave any
`quote_off_root_count` accounting as-is.

If a `saved_count_after` or a metadata field elsewhere in these calls references
the old `reply_upserted`/`quote_upserted` names, update it to
`reply_inserted + reply_duplicate` (saved rows) — grep the function for the old
names and replace every use.

**Verify**: `grep -n "reply_upserted\|quote_upserted" trr_backend/socials/twitter/posts_catalog/catalog.py` returns no matches.

### Step 3: Confirm the planner now suppresses only on genuine duplicates

No code change here — read `repair_planner._low_yield_suppression_reason` and
confirm it now receives genuine `duplicate_count` (updates) and genuine
`unique_saved_delta` (inserts), so a skip-heavy run no longer trips
`low_unique_yield`.

**Verify**: `.venv/bin/python -m pytest tests/socials/twitter/test_twitter_posts_catalog.py tests/socials/twitter/test_twitter_repair_planner.py -q` → all pass.

## Test plan

Add to `tests/socials/twitter/test_twitter_posts_catalog.py` (model after the
existing catalog persist tests — they inject a fake `upsert_tweet` via the
`deps`). Add a test where the injected `upsert_tweet`:
- returns a row with `{"__trr_inserted": True}` for N fresh replies,
- returns a row with `{"__trr_inserted": False}` for M duplicate replies,
- returns `None` for K skipped replies (prep failure),
and asserts the recorded interaction state has `unique_saved_delta == N`,
`duplicate_count == M`, and that K skips do **not** inflate `duplicate_count`
(the regression: with K≥50 and N≤3 the old code would have produced
`duplicate_count≥50` → suppression; assert it does not now).

Capture what `_record_interaction_fetch_state` received (patch/spy it, mirroring
how the existing tests capture recorded state).

Verification: `.venv/bin/python -m pytest tests/socials/twitter/test_twitter_posts_catalog.py tests/socials/twitter/test_twitter_repair_planner.py -q` → all pass, with the new test.

## Done criteria

- [ ] `.venv/bin/python -c "import api.main"` exits 0
- [ ] `.venv/bin/python -m pytest tests/socials/twitter/test_twitter_posts_catalog.py tests/socials/twitter/test_twitter_repair_planner.py -q` passes, with the new test
- [ ] `ruff check trr_backend/socials/twitter/posts_catalog/catalog.py trr_backend/socials/social_season_analytics_impl.py` prints `All checks passed!`
- [ ] `grep -n "include_inserted_flag=True" trr_backend/socials/social_season_analytics_impl.py` shows the `_upsert_tweet` call updated
- [ ] `grep -n "reply_upserted\|quote_upserted" trr_backend/socials/twitter/posts_catalog/catalog.py` returns no matches
- [ ] `git status --short` shows only in-scope files modified
- [ ] `plans/README.md` status row updated *(skip if a dispatching reviewer maintains the index)*

## STOP conditions

Stop and report back (do not improvise) if:

- The "Current state" excerpts do not match live code (drift).
- Another caller of `_upsert_tweet` inspects the returned row in a way that a new
  `__trr_inserted` key would break (grep callers; the key is additive so this is
  unlikely, but verify) — if so, report before proceeding.
- `_pg_upsert` does not accept `include_inserted_flag` at the live head (the
  excerpt says it does) — report rather than adding the flag another way.
- A verification fails twice after a reasonable fix attempt.

## Maintenance notes

- A reviewer should confirm `stats["comments_upserted"]`/`quotes_upserted`
  aggregate counters still count any saved row (insert+update) — only the
  per-interaction `unique_saved_delta`/`duplicate_count` semantics changed.
- If a future change makes `_upsert_tweet` batch its writes, the per-row
  `__trr_inserted` flag must be preserved per row or this accounting breaks.
- The planner thresholds (3 / 50) are now measured against correct signals; if
  suppression still looks wrong after this lands, tune the thresholds — but the
  mis-counting was the root cause.

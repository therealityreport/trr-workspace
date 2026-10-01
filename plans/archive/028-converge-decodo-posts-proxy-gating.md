# Plan 028: Require explicit opt-in for Decodo on TikTok/Threads posts proxies (match Instagram's safety gate)

> **Executor instructions**: Follow step by step. Run every verification command
> and confirm the expected result before moving on. If anything in "STOP
> conditions" occurs, stop and report. Update the `plans/README.md` status row
> when done unless a reviewer maintains the index.
>
> **Drift check (run first)**:
> `git -C TRR-Backend diff --stat -- trr_backend/socials/tiktok/posts_scrapling/proxy.py trr_backend/socials/threads/posts_scrapling/proxy.py trr_backend/modal_jobs.py`
> The nested `TRR-Backend` tree is authoritative and dirty. Confirm the "Current
> state" excerpts before editing. On mismatch, STOP.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: MED
- **Depends on**: none (touches `modal_jobs.py`; if plan 025 also lands, see Maintenance notes)
- **Category**: correctness / security
- **Planned at**: commit `8ea7aa1a` (TRR-Backend), 2026-07-08 — working tree authoritative
- **Repo**: TRR-Backend

## Why this matters

The "should this lane activate the Decodo residential proxy?" decision has
drifted three ways across platforms that copy-pasted the same proxy module:

- **Instagram** (`instagram/posts_scrapling/proxy.py:243`) requires an explicit
  provider: `if provider in {"decodo", "smartproxy"}`. A documented safety
  rationale sits right above it (lines 241–242): *"Credentials alone are not
  enough because a stale residential proxy can make healthy auth cookies look
  blocked."*
- **TikTok** (`tiktok/posts_scrapling/proxy.py:64`) uses
  `if provider in {"", "decodo", "smartproxy"}` — an **empty** provider also
  activates Decodo, i.e. credentials alone are enough: exactly what Instagram's
  comment warns against.
- **Threads** (`threads/posts_scrapling/proxy.py:44-49`) has a third variant: a
  disable-list, then `if not provider and decodo_creds: provider = "decodo"`
  (auto-enable on credentials).

A safety fix was applied to one platform only. On TikTok and Threads a stale
residential proxy can silently mask healthy auth as "blocked," corrupting the
adaptive control plane's auth-health signal. This plan converges all three gates
onto Instagram's explicit-opt-in rule while **preserving current production proxy
usage**: TikTok's posts lane routes through Decodo in production today (via the
empty-string auto-enable), so this plan adds an explicit
`SOCIAL_TIKTOK_POSTS_PROXY_PROVIDER=decodo` to the canonical Modal runtime
defaults. Threads is already pinned to `decodo` in those defaults, so aligning
its gate is behavior-preserving in production.

## Current state

TikTok gate (`trr_backend/socials/tiktok/posts_scrapling/proxy.py`, around 62-64):

```python
    # 2. DECODO credentials.
    provider = str(os.getenv("SOCIAL_TIKTOK_POSTS_PROXY_PROVIDER") or "").strip().lower()
    if provider in {"", "decodo", "smartproxy"}:
        creds = _decodo_env()
        if creds:
            ...
    # 3. No proxy — local dev mode.
    return None
```

Threads gate (`trr_backend/socials/threads/posts_scrapling/proxy.py`, around 44-51):

```python
    provider = str(os.getenv("SOCIAL_THREADS_POSTS_PROXY_PROVIDER") or "").strip().lower()
    if provider in {"0", "false", "none", "off", "disabled"}:
        return None
    decodo_creds = _decodo_env()
    if not provider and decodo_creds:
        provider = "decodo"
    if provider in {"decodo", "smartproxy"}:
        creds = decodo_creds
        if creds:
            ...
    return None
```

Instagram reference gate (`trr_backend/socials/instagram/posts_scrapling/proxy.py:241-244`) —
the target behavior:

```python
    # 2. Explicit Decodo provider. Credentials alone are not enough because a
    # stale residential proxy can make healthy auth cookies look blocked.
    provider = str(os.getenv("SOCIAL_INSTAGRAM_POSTS_PROXY_PROVIDER") or "").strip().lower()
    if provider in {"decodo", "smartproxy"}:
        creds = _decodo_env()
        ...
```

Canonical Modal runtime defaults (`trr_backend/modal_jobs.py:289` dict) already
pins Threads: `"SOCIAL_THREADS_POSTS_PROXY_PROVIDER": "decodo"` (~line 423).
There is **no** `SOCIAL_TIKTOK_POSTS_PROXY_PROVIDER` key — that is why TikTok
relies on the empty-string auto-enable.

Test files (per-platform, non-blocking lane):
`tests/socials/tiktok/posts_scrapling/test_proxy.py`,
`tests/socials/threads/posts_scrapling/test_proxy.py`, and the reference
`tests/socials/instagram/posts_scrapling/test_proxy.py`.

Repo conventions: ruff py311, line 120, double quotes.

## Commands you will need

| Purpose | Command | Expected |
|---------|---------|----------|
| Import gate | `cd TRR-Backend && TRR_MODAL_RUNTIME_SCHEDULER_ENABLED=1 .venv/bin/python -c "import trr_backend.socials.tiktok.posts_scrapling.proxy, trr_backend.socials.threads.posts_scrapling.proxy, trr_backend.modal_jobs"` | exit 0 |
| Focused tests | `cd TRR-Backend && .venv/bin/python -m pytest tests/socials/tiktok/posts_scrapling/test_proxy.py tests/socials/threads/posts_scrapling/test_proxy.py -q` | all pass |
| Lint | `cd TRR-Backend && ruff check trr_backend/socials/tiktok/posts_scrapling/proxy.py trr_backend/socials/threads/posts_scrapling/proxy.py trr_backend/modal_jobs.py` | exit 0 |

## Scope

**In scope**:
- `TRR-Backend/trr_backend/socials/tiktok/posts_scrapling/proxy.py`
- `TRR-Backend/trr_backend/socials/threads/posts_scrapling/proxy.py`
- `TRR-Backend/trr_backend/modal_jobs.py` — add ONE dict entry only
- `TRR-Backend/tests/socials/tiktok/posts_scrapling/test_proxy.py`
- `TRR-Backend/tests/socials/threads/posts_scrapling/test_proxy.py`

**Out of scope**:
- Instagram proxy (already correct — reference only).
- SocialBlade proxy and any other lane.
- `_decodo_env()` and the proxy-config construction (unchanged).
- Any broader refactor to extract a shared proxy selector (that is DEBT-03 in the
  backlog, separate).

## Steps

### Step 1: TikTok — drop the empty-string auto-enable

In `tiktok/posts_scrapling/proxy.py`, change the gate to require an explicit
provider:

```python
    if provider in {"decodo", "smartproxy"}:
```

(Remove the `""` member.) Leave everything else in the function unchanged.

**Verify**: `grep -n 'provider in {"decodo", "smartproxy"}' TRR-Backend/trr_backend/socials/tiktok/posts_scrapling/proxy.py` → 1 hit.

### Step 2: Threads — remove the credentials-alone auto-enable

In `threads/posts_scrapling/proxy.py`, delete the two lines:

```python
    decodo_creds = _decodo_env()
    if not provider and decodo_creds:
        provider = "decodo"
```

and replace with a call that keeps the explicit-provider gate. The function must
still (a) honor the disable-list, (b) activate only when provider is explicitly
`decodo`/`smartproxy`, (c) fetch `_decodo_env()` inside that branch. Target:

```python
    provider = str(os.getenv("SOCIAL_THREADS_POSTS_PROXY_PROVIDER") or "").strip().lower()
    if provider in {"0", "false", "none", "off", "disabled"}:
        return None
    if provider in {"decodo", "smartproxy"}:
        creds = _decodo_env()
        if creds:
            ...  # keep the existing sticky-session + config construction unchanged
    return None
```

**Verify**: `grep -n "if not provider and decodo_creds" TRR-Backend/trr_backend/socials/threads/posts_scrapling/proxy.py` → no matches.

### Step 3: Pin the TikTok provider so production behavior is preserved

In `trr_backend/modal_jobs.py`, in `_CANONICAL_MODAL_RUNTIME_DEFAULTS`, add next
to the existing `SOCIAL_THREADS_POSTS_PROXY_PROVIDER` entry:

```python
    "SOCIAL_TIKTOK_POSTS_PROXY_PROVIDER": "decodo",
```

This keeps TikTok's posts lane routing through Decodo in the deployed runtime —
now via explicit configuration rather than credentials-alone auto-enable.

**Verify**: `grep -n "SOCIAL_TIKTOK_POSTS_PROXY_PROVIDER" TRR-Backend/trr_backend/modal_jobs.py` → 1 hit in the dict.

### Step 4: Tests

Update the two proxy test files (model on
`tests/socials/instagram/posts_scrapling/test_proxy.py`). Add/adjust cases so:
1. **Credentials set, provider unset/empty → returns `None`** (no proxy) for both
   TikTok and Threads. (This is the behavior change; assert it explicitly.)
2. **provider=`decodo` + credentials → returns a Decodo proxy config** (unchanged
   path still works) for both.
3. **provider in the Threads disable-list → returns `None`** (Threads only).

If an existing test asserted the old credentials-alone auto-enable, update it to
the new explicit-opt-in expectation and note that in your report.

**Verify**: `cd TRR-Backend && .venv/bin/python -m pytest tests/socials/tiktok/posts_scrapling/test_proxy.py tests/socials/threads/posts_scrapling/test_proxy.py -q` → all pass.

## Test plan

- Update the two proxy test files per Step 4; the "creds-alone → None" case is
  the mandatory regression proving the gate tightened.
- Verification: focused test command above → all pass.

## Done criteria

- [ ] `cd TRR-Backend && TRR_MODAL_RUNTIME_SCHEDULER_ENABLED=1 .venv/bin/python -c "import trr_backend.socials.tiktok.posts_scrapling.proxy, trr_backend.socials.threads.posts_scrapling.proxy, trr_backend.modal_jobs"` exits 0
- [ ] TikTok gate is `provider in {"decodo", "smartproxy"}` (no `""`)
- [ ] `grep -n "if not provider and decodo_creds" TRR-Backend/trr_backend/socials/threads/posts_scrapling/proxy.py` → no matches
- [ ] `SOCIAL_TIKTOK_POSTS_PROXY_PROVIDER` is in `_CANONICAL_MODAL_RUNTIME_DEFAULTS`
- [ ] `cd TRR-Backend && .venv/bin/python -m pytest tests/socials/tiktok/posts_scrapling/test_proxy.py tests/socials/threads/posts_scrapling/test_proxy.py -q` passes, incl. the creds-alone→None cases
- [ ] `ruff check ...` exits 0
- [ ] No files outside scope modified (`git -C TRR-Backend status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report (do not improvise) if:

- Any of the three gates does not match the "Current state" excerpts.
- The injector dict already contains `SOCIAL_TIKTOK_POSTS_PROXY_PROVIDER` (then
  production behavior differs from the assumption here — report and reassess).
- A live caller of `select_tiktok_posts_proxy` relies on the empty-provider
  auto-enable outside the Modal runtime in a way that would break (grep callers).
- A test fails twice after a reasonable fix attempt.

## Maintenance notes

- **Overlap with plan 025**: both edit `modal_jobs.py`. 025 changes the injector
  *function* and adds `_OPERATOR_TUNABLE_RUNTIME_DEFAULT_KEYS`; this plan adds one
  *dict entry*. They don't conflict textually. If 025 has landed, also add
  `SOCIAL_TIKTOK_POSTS_PROXY_PROVIDER` to the tunable allowlist for symmetry with
  the other proxy-provider keys (one-line follow-up).
- The larger cleanup — a single shared `select_posts_proxy(env_prefix=...)`
  parameterized selector so this can't drift again — is DEBT-03 in the backlog.
- A reviewer should confirm no other platform (facebook, twitter) has a
  posts_scrapling proxy with a credentials-alone auto-enable.

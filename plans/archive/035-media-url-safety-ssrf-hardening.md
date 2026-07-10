# Plan 035: Close the loopback/fail-open holes in the media-URL SSRF guard

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: from `TRR-Backend/`, run
> `git diff --stat 8ea7aa1a..HEAD -- trr_backend/socials/media_url_safety.py tests/socials/test_media_url_safety.py`
> If either file changed since this plan was written, compare the "Current
> state" excerpts against the live code before proceeding; on a mismatch, treat
> it as a STOP condition. If the SHA `8ea7aa1a` does not resolve (rebased/GC'd),
> compare the excerpts against live code by hand and note the SHA was
> unresolvable in your report.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: security
- **Planned at**: commit `8ea7aa1a` (TRR-Backend), 2026-07-08

## Why this matters

`trr_backend/socials/media_url_safety.py` is the SSRF guard that scraper-lane
code calls before fetching media URLs harvested from scraped social content
(profile pictures, post media, thumbnails). Plan 026 (already landed) routed
avatar/profile-pic downloads through this exact guard, so its correctness is now
load-bearing for the fix that plan delivered. The guard has two holes that let a
hostile scraped URL reach internal services:

1. **Loopback bypass.** `localhost` and any `*.localhost` host is treated as a
   "reserved test host", which makes `validate_media_url` skip *both* the
   allowlist rejection and the DNS/blocked-IP resolution check — even when a
   non-empty platform allowlist is active. A scraped media URL of
   `http://localhost:6379/…` or `http://x.localhost/…` passes validation and is
   fetched server-side against loopback (Redis, admin ports, the metadata
   service on some hosts, etc.). This is precisely the threat the module exists
   to stop.
2. **Fail-open on empty allowlist.** `allowed_hosts_for_platform()` returns an
   empty tuple for any platform not in the 6-entry suffix map (e.g. `reddit`,
   which is a first-class supported platform). An empty allowlist causes the
   host-allowlist check to be skipped entirely, degrading the guard to "any
   public host that resolves to a non-private IP". A new platform or a typo
   silently inherits this posture.

A sibling guard, `trr_backend/media/s3_mirror.py:_public_media_url_error`, is
already stricter (it blocks `localhost`/`.local` and uses `is_global`). This
plan tightens `media_url_safety.py` so the guard scraper lanes rely on stops
loopback and fails closed on an unknown platform, without breaking the test
hosts the unit tests legitimately use (`example.com`, `*.test`, `*.invalid`).

## Current state

- `trr_backend/socials/media_url_safety.py` — the guard. Relevant lines today:

```python
# lines 20-25
    allow_test_hosts: bool = True
    resolve_dns: bool = True


_RESERVED_TEST_SUFFIXES = (".test", ".example", ".invalid", ".localhost")
_RESERVED_TEST_HOSTS = {"example.com", "example.net", "example.org", "localhost"}
```

```python
# lines 70-72
def allowed_hosts_for_platform(platform: str | None) -> tuple[str, ...]:
    normalized = str(platform or "").strip().lower()
    return _PLATFORM_ALLOWED_HOST_SUFFIXES.get(normalized, ())
```

```python
# lines 88-103
def _is_reserved_test_host(hostname: str) -> bool:
    normalized = hostname.strip(".").lower()
    return normalized in _RESERVED_TEST_HOSTS or normalized.endswith(_RESERVED_TEST_SUFFIXES)


def _is_blocked_ip(ip: ipaddress._BaseAddress) -> bool:
    return any(
        (
            ip.is_loopback,
            ip.is_private,
            ip.is_link_local,
            ip.is_multicast,
            ip.is_reserved,
            ip.is_unspecified,
        )
    )
```

```python
# lines 160-167 — the non-literal-IP host branch of validate_media_url
    active_policy = policy or MediaUrlSafetyPolicy(tuple(allowed_host_suffixes or ()))
    if active_policy.allowed_host_suffixes and not _hostname_matches(hostname, active_policy.allowed_host_suffixes):
        if not (active_policy.allow_test_hosts and _is_reserved_test_host(hostname)):
            raise UnsafeMediaUrlError("media_url_host_not_allowed")

    if active_policy.resolve_dns and not _is_reserved_test_host(hostname):
        _validate_resolved_addresses(hostname)
    return candidate
```

Why the holes exist, traced end-to-end:
- For a scraped host `localhost` under a non-empty platform allowlist:
  line 161 is true (localhost is not an instagram/tiktok/etc. suffix), so we
  enter the block; line 162 is `not (True and True)` → `False`, so **no raise**;
  then line 165 is `True and not True` → `False`, so **DNS is skipped**. The URL
  is returned as safe. Loopback is reachable.
- For `reddit` (or any unlisted platform): `allowed_hosts_for_platform("reddit")`
  returns `()`, so `active_policy.allowed_host_suffixes` is falsy and the
  allowlist check on line 161 is skipped — only the literal-IP check and DNS
  resolution remain.

Callers (do NOT modify — they already pass a per-platform policy):
- `trr_backend/socials/tiktok/media_resolver.py:52`
- `trr_backend/socials/threads/media_resolver.py:25`
- `trr_backend/socials/social_season_analytics_impl.py:17860,18583`

None of them pass `allow_test_hosts=False`; the flag exists only so the unit
tests can use `example.com`-style hosts without live DNS. Repo-wide grep
confirms zero production callers set `allow_test_hosts=False`.

Convention: this is a pure-stdlib module (`ipaddress`, `socket`, `urllib`);
match its style — no new dependencies, double quotes, ruff line-length 120.
Errors are raised as `UnsafeMediaUrlError("snake_case_code")`.

## Commands you will need

| Purpose      | Command (run from `TRR-Backend/`)                                             | Expected on success        |
|--------------|-------------------------------------------------------------------------------|----------------------------|
| Import gate  | `.venv/bin/python -c "import api.main"`                                        | exit 0, no output          |
| Focused test | `.venv/bin/python -m pytest tests/socials/test_media_url_safety.py -q` | all pass |
| Lint         | `ruff check trr_backend/socials/media_url_safety.py tests/socials/test_media_url_safety.py` | `All checks passed!` |

## Scope

**In scope** (the only files you should modify):
- `trr_backend/socials/media_url_safety.py`
- `tests/socials/test_media_url_safety.py` (add cases; keep existing ones green)

**Out of scope** (do NOT touch, even though they look related):
- `trr_backend/media/s3_mirror.py` — the second, stronger guard. Converging the
  two guards is a separate, larger task (recorded in the backlog). Do not delete
  or rewire it here.
- Any caller listed under "Current state" — they already pass a correct policy;
  changing them is out of scope.
- The literal-IP branch of `validate_media_url` (lines 148-158) — it already
  blocks private/loopback literal IPs; leave its logic intact.

## Git workflow

- Branch: `advisor/035-media-url-safety-ssrf-hardening`
- One commit for the fix + tests. Message style (match `git log --oneline`):
  a short imperative subject, e.g. `harden media-url SSRF guard against loopback and empty allowlist`.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Stop treating `localhost`/`.localhost` as a reserved test host

`localhost` and the `.localhost` TLD (RFC 6761) resolve to loopback — they are
routable, unlike `.test`/`.example`/`.invalid` (RFC 2606, guaranteed
non-resolving) and the `example.com/net/org` documentation domains. Remove the
loopback names from the reserved sets:

- Change `_RESERVED_TEST_SUFFIXES` to `(".test", ".example", ".invalid")` (drop
  `".localhost"`).
- Change `_RESERVED_TEST_HOSTS` to `{"example.com", "example.net", "example.org"}`
  (drop `"localhost"`).

After this change, a `localhost`/`*.localhost` host is no longer reserved, so on
line 162 it will not be waived from the allowlist rejection, and on line 165 it
will go through DNS resolution — where `_validate_resolved_addresses` resolves
`localhost` to `127.0.0.1`/`::1` and `_is_blocked_ip` rejects it via
`is_loopback`.

**Verify**: `.venv/bin/python -m pytest tests/socials/test_media_url_safety.py -q` → existing tests still pass (they use `example.com`/`*.test`, which remain reserved).

### Step 2: Fail closed when the platform allowlist is empty

Add an explicit `reddit` entry so the supported platform set is covered, and make
an empty allowlist reject non-test hosts rather than allowing them.

- In `_PLATFORM_ALLOWED_HOST_SUFFIXES`, add a `reddit` key with the Reddit media
  CDN suffixes:
  ```python
  "reddit": (
      "redd.it",
      "redditmedia.com",
      "redditstatic.com",
      "reddit.com",
  ),
  ```
- In `validate_media_url`, the non-literal-IP branch (lines 160-166) must reject
  a host that is neither allowlisted nor a reserved test host **even when the
  allowlist tuple is empty**. Replace the guarded check so an empty allowlist is
  fail-closed. Target shape:
  ```python
  active_policy = policy or MediaUrlSafetyPolicy(tuple(allowed_host_suffixes or ()))
  host_allowed = _hostname_matches(hostname, active_policy.allowed_host_suffixes)
  if not host_allowed:
      if not (active_policy.allow_test_hosts and _is_reserved_test_host(hostname)):
          raise UnsafeMediaUrlError("media_url_host_not_allowed")

  if active_policy.resolve_dns and not _is_reserved_test_host(hostname):
      _validate_resolved_addresses(hostname)
  return candidate
  ```
  Note `_hostname_matches` already returns `False` for an empty suffix
  iterable (its loop finds nothing), so removing the `active_policy.allowed_host_suffixes and`
  short-circuit is exactly what makes an empty allowlist reject.
- Apply the identical change to the **literal-IP** branch (lines 155-157): a
  literal IP that passes `_is_blocked_ip` but is not allowlisted must now be
  rejected when the allowlist is empty too. Change
  `if active_policy.allowed_host_suffixes and not _hostname_matches(...)` to
  `if not _hostname_matches(...)` there as well, so a bare public IP literal is
  not accepted for an unlisted platform.

**STOP and report** instead of continuing if you find a production caller that
*relies* on an empty allowlist to fetch arbitrary public hosts (grep for
`validate_media_url`, `safe_requests_get`, `safe_requests_head`,
`MediaUrlSafetyPolicy` across `trr_backend/` and confirm every call passes a
non-empty `allowed_hosts_for_platform(...)` or an explicit suffix list). If one
genuinely needs open fetching, an empty allowlist must not be the signal — that
is a design decision for the maintainer.

**Verify**: `.venv/bin/python -m pytest tests/socials/test_media_url_safety.py -q` → all pass.

### Step 3: Unwrap IPv4-mapped IPv6 and NAT64 before the blocked-IP check

`_is_blocked_ip` and `_validate_resolved_addresses` do not unwrap
IPv4-mapped IPv6 (`::ffff:169.254.169.254`) or NAT64 (`64:ff9b::/96`)
addresses, so on some runtimes those literals/resolutions evade the private-range
check. Harden `_is_blocked_ip` to unwrap before testing:

```python
def _is_blocked_ip(ip: ipaddress._BaseAddress) -> bool:
    mapped = getattr(ip, "ipv4_mapped", None)
    if mapped is not None:
        ip = mapped
    return any(
        (
            ip.is_loopback,
            ip.is_private,
            ip.is_link_local,
            ip.is_multicast,
            ip.is_reserved,
            ip.is_unspecified,
        )
    )
```

(NAT64 `64:ff9b::/96` embeds the IPv4 in the low 32 bits; if you want to also
cover it, additionally test membership in `ipaddress.ip_network("64:ff9b::/96")`
and, when matched, extract and re-test the embedded IPv4. This is optional
defense-in-depth — the ipv4_mapped unwrap is the required part.)

**Verify**: `ruff check trr_backend/socials/media_url_safety.py` → `All checks passed!`

## Test plan

Add to `tests/socials/test_media_url_safety.py` (model new cases after the
existing tests in that file — same `pytest.raises(UnsafeMediaUrlError)` /
return-value style). Cover:

- **Loopback rejected**: `validate_media_url("http://localhost:6379/x", policy=MediaUrlSafetyPolicy(("cdninstagram.com",)))` raises `UnsafeMediaUrlError` (loopback resolves to a blocked IP; monkeypatch `socket.getaddrinfo` to return `127.0.0.1` so the test does no live DNS).
- **`*.localhost` rejected**: same for host `something.localhost`.
- **Reserved non-resolving test host still allowed**: `validate_media_url("http://example.com/x", policy=MediaUrlSafetyPolicy(("cdninstagram.com",), allow_test_hosts=True))` returns the URL (regression guard for the tests that use `example.com`).
- **Empty allowlist fails closed**: `validate_media_url("http://evil.example-not-reserved.com/x", policy=MediaUrlSafetyPolicy(()))` raises `media_url_host_not_allowed` (host is not a reserved test host and the allowlist is empty).
- **Reddit platform is now non-empty**: `allowed_hosts_for_platform("reddit")` returns a non-empty tuple containing `"redd.it"`.
- **IPv4-mapped IPv6 blocked**: `_is_blocked_ip(ipaddress.ip_address("::ffff:169.254.169.254"))` is `True`.

Verification: `.venv/bin/python -m pytest tests/socials/test_media_url_safety.py -q` → all pass, including the ≥6 new cases.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `.venv/bin/python -c "import api.main"` exits 0
- [ ] `.venv/bin/python -m pytest tests/socials/test_media_url_safety.py -q` passes, with the new cases present
- [ ] `ruff check trr_backend/socials/media_url_safety.py tests/socials/test_media_url_safety.py` prints `All checks passed!`
- [ ] `grep -n '"localhost"' trr_backend/socials/media_url_safety.py` returns no match (loopback removed from the reserved host set)
- [ ] `grep -n '"reddit"' trr_backend/socials/media_url_safety.py` returns a match (reddit allowlist added)
- [ ] `git status --short` shows only the two in-scope files modified
- [ ] `plans/README.md` status row updated *(skip if a dispatching reviewer said they maintain the index)*

## STOP conditions

Stop and report back (do not improvise) if:

- The "Current state" excerpts do not match the live code (drift since planning).
- A production caller genuinely depends on an empty allowlist meaning
  "fetch any public host" (Step 2 grep) — the fail-closed change would break it,
  and the right fix is a maintainer decision.
- Removing `localhost` from the reserved set breaks a test that legitimately
  needs a loopback host to *pass* validation — that test encodes the vulnerable
  behavior; report it rather than re-adding the hole.
- A step's verification fails twice after a reasonable fix attempt.

## Maintenance notes

- The two SSRF guards (`media_url_safety.py` and `s3_mirror._public_media_url_error`)
  still exist in parallel and can drift. Converging them onto one `is_global`-based
  implementation is a recorded backlog item — this plan intentionally only
  hardens the socials-lane guard, not the merge.
- A reviewer should confirm no caller was changed and that the DNS-resolution
  test uses a monkeypatched `socket.getaddrinfo` (no live network in unit tests).
- If a future platform is added, add its media-CDN suffixes to
  `_PLATFORM_ALLOWED_HOST_SUFFIXES` — the fail-closed behavior now means a
  missing entry blocks that platform's media fetches loudly instead of silently
  allowing any host.

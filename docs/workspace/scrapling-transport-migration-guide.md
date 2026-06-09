# Scrapling Transport Migration Guide

Use this guide when adding or changing Scrapling-backed social scrapers. The
shared adapter is `trr_backend.socials.scrapling_transport`.

The adapter owns cross-platform transport glue only. Platform modules still own
scrape policy, request construction, parsing, persistence, queue behavior, and
operator-facing semantics.

## Shared Adapter Owns

Keep these concerns in `trr_backend.socials.scrapling_transport`:

- lazy Scrapling fetcher construction:
  - `build_fetcher`
  - `build_dynamic_fetcher`
  - `build_stealthy_fetcher`
- lazy `ProxyRotator` construction through `build_proxy_rotator`
- simple cookie mapping to browser cookie records through `cookies_to_scrapling`
- response-cookie merge helpers through `merge_response_cookies`
- redaction-safe cookie diagnostics through `safe_cookie_metadata`
- redaction-safe runtime package metadata through `scrapling_runtime_metadata`
- early proxy conflict checks through `assert_no_conflicting_scrapling_proxies`
- Decodo username session shaping through `apply_decodo_session_affinity`
- shared default transport constants:
  - `DEFAULT_TIMEOUT_MS`
  - `DEFAULT_MAX_TRANSIENT_RETRIES`
  - `DEFAULT_BASE_BACKOFF_SECONDS`
  - `DEFAULT_TRANSPORT`
- clear runtime errors when `scrapling[fetchers]` is missing
- a stable `scrapling_proxy_conflict` reason when callers mix session-level and
  per-request proxy modes
- helpers that can be reused by Instagram, TikTok, Threads, or future Scrapling
  lanes without importing platform modules

The adapter must stay import-light. Importing it should not import Scrapling
until a builder function is called.

## Platform Modules Own

Keep these concerns in the platform package, not in the shared adapter:

- endpoint URLs, doc ids, request params, headers, and GraphQL variables
- platform-specific session resolution and auth validation
- platform-specific proxy env names and provider policy
- browser warmup strategy and page-token extraction
- retry budgets that differ from the shared default
- pacing, backoff escalation, and rate-limit policy
- parser behavior and response-shape compatibility
- persistence into social tables
- queue stages, worker lanes, cancellation, and active-run locks
- operator routes, API payloads, and progress response fields
- platform-specific runtime metadata beyond generic safe transport metadata

Examples of platform-owned packages today:

- `trr_backend.socials.instagram.posts_scrapling`
- `trr_backend.socials.instagram.comments_scrapling`
- `trr_backend.socials.tiktok.posts_scrapling`
- `trr_backend.socials.threads.posts_scrapling`
- `trr_backend.socials.instagram.runtimes.scrapling_runtime`

## Migration Steps

1. Identify duplicated transport glue in the platform module.

   Good candidates are direct Scrapling fetcher imports, cookie conversion,
   proxy rotator construction, response-cookie merging, and cookie metadata
   redaction.

2. Move only platform-neutral behavior into the shared adapter.

   Do not move URLs, env names, parser code, job-runner decisions, or DB writes.

3. Replace platform imports with shared adapter imports.

   Prefer:

   ```python
   from trr_backend.socials.scrapling_transport import (
       apply_decodo_session_affinity,
       assert_no_conflicting_scrapling_proxies,
       build_stealthy_fetcher,
       cookies_to_scrapling,
       safe_cookie_metadata,
       scrapling_runtime_metadata,
   )
   ```

   Avoid direct platform code importing Scrapling fetcher classes unless a
   feature is not yet represented by the shared adapter.

4. Preserve the existing public platform contract.

   Stage names, worker lanes, route payloads, metadata keys, and persistence
   fields should not change during a transport-only migration.

5. Keep metadata secret-safe.

   Store cookie names and counts, never cookie values. Store proxy fingerprints,
   never proxy credentials or full credential-bearing URLs. Store package
   versions under `scrapling_runtime` so Modal/local mismatches are visible.

   For Decodo, default to rotating/no-session usernames. Only add `session`
   and `sessionduration` username suffixes when a platform-owned sticky opt-in
   env var is explicitly enabled or the operator has already provided a
   session-scoped username. Never store the raw username or full proxy URL in
   metadata.

6. Add or update focused tests for the ownership boundary.

   Adapter tests belong near `tests/socials/test_scrapling_transport.py`.
   Platform behavior tests stay with that platform's existing tests.

## Decision Checklist

Move code into `scrapling_transport` only when all answers are yes:

- Can Instagram, TikTok, Threads, or another Scrapling lane reuse it unchanged?
- Does it avoid importing platform packages?
- Does it avoid route, queue, persistence, parser, and business policy choices?
- Does it keep secrets out of metadata and logs?
- Can it be tested without reaching Instagram, TikTok, Threads, Modal, or the DB?

Keep code platform-owned when any answer is yes:

- It names a platform env var such as `SOCIAL_INSTAGRAM_POSTS_PROXY_PROVIDER`.
- It decides whether a platform should opt into sticky Decodo sessions.
- It knows a platform URL, doc id, cursor, shortcode, handle, or request body.
- It decides whether to retry, stop, downgrade, or enqueue another job.
- It writes or reads social tables.
- It emits operator progress fields for a specific surface.
- It contains auth/session policy for one platform.

## Metadata Rules

Allowed shared transport metadata:

- cookie names
- cookie counts
- selected safe proxy fingerprint
- timeout and retry defaults
- transport error class or stable reason code

Forbidden shared transport metadata:

- cookie values
- `sessionid`, `csrftoken`, bearer tokens, or auth headers as values
- proxy usernames or passwords
- full proxy URLs with credentials
- raw response bodies that may contain account or session data
- database URLs

## Anti-Patterns

Do not turn `scrapling_transport` into:

- a platform dispatcher
- an Instagram/TikTok/Threads parser
- a DB persistence layer
- a queue or worker-lane registry
- an operator runbook surface
- a place for one-off env names
- a compatibility wrapper for legacy repository helpers

If a future platform needs a new Scrapling capability, add the smallest shared
builder or redaction helper first, then keep platform decisions in that
platform's package.

# Instagram Scrapling Runtime Canary

Use this runbook when testing the opt-in Instagram `ScraplingRuntime` path behind
`INSTAGRAM_SCRAPLING_RUNTIME_ENABLED`.

This is not the same path as the existing `posts_scrapling` or
`comments_scrapling` worker lanes. Those lanes remain platform-owned production
scraper paths. This runtime is a canary inside the pluggable Instagram runtime
dispatcher.

## Safe Default

Leave the canary disabled unless an operator is explicitly running a bounded
test:

```bash
INSTAGRAM_SCRAPLING_RUNTIME_ENABLED=0
```

When disabled, `ScraplingRuntime.healthcheck()` returns unhealthy with:

```text
instagram_scrapling_runtime_enabled_not_enabled
```

The dispatcher can keep `scrapling` in `INSTAGRAM_RUNTIME_ORDER` without sending
traffic to the runtime while this flag is off.

## Environment

| Name | Safe value | Canary value | Notes |
|---|---:|---:|---|
| `INSTAGRAM_SCRAPLING_RUNTIME_ENABLED` | `0` or unset | `1` | Main rollout switch. |
| `INSTAGRAM_RUNTIME_ORDER` | current deployment default | `scrapling,crawlee,crawl4ai,browser_use` for canary only | Use only in a bounded canary shell or scoped deployment. |
| `SOCIAL_INSTAGRAM_COOKIES_JSON` or `SOCIAL_INSTAGRAM_COOKIES_FILE` | current deployment value | current deployment value | Required when the target Instagram endpoint needs authenticated cookies. |

Do not put cookie values, browser storage, bearer tokens, proxy credentials, or
database URLs in this document, shell history, issue comments, or run summaries.
Record only env names, boolean flag state, account handle, status, timings, and
redacted metadata.

## Decodo Session/IP Risk

Decodo residential proxy sessions must default to rotating/no-session usernames
for independent Scrapling requests. In Decodo's documented rotating mode, the
egress IP can change across connections, which prevents one bad or contaminated
IP state from being preserved across unrelated fetches.

Sticky sessions are an explicit operator opt-in for stateful warmup or login
flows only. The code enables stickiness by adding a `session` and
`sessionduration` suffix shape to the Decodo username; do not record the
username, password, or full proxy URL in docs or logs.

If authenticated Instagram cookies checkpoint after an egress change, stop the
canary. Classify the result as auth/checkpoint or transport-blocked before
refreshing cookies, then repair auth through the owned operator path and verify
before resuming.

## Local Preflight

Run from the backend directory:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/socials/instagram/runtimes/test_scrapling_runtime.py
```

Confirm the local Scrapling runtime before a canary:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/scrapling --version
.venv/bin/python - <<'PY'
from trr_backend.socials.scrapling_transport import scrapling_runtime_metadata

print(scrapling_runtime_metadata())
PY
```

Expected version floor for this canary slice:

```text
scrapling_version >= 0.4.9
patchright_version >= 1.60.1
playwright_version >= 1.60.0
```

Confirm the safe default is still disabled:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
INSTAGRAM_SCRAPLING_RUNTIME_ENABLED=0 .venv/bin/python - <<'PY'
from trr_backend.socials.instagram.runtimes.scrapling_runtime import ScraplingRuntime

health = ScraplingRuntime().healthcheck()
print({"healthy": health.healthy, "reason": health.reason})
PY
```

Expected output shape:

```text
{'healthy': False, 'reason': 'instagram_scrapling_runtime_enabled_not_enabled'}
```

Confirm the enabled healthcheck before any live request:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
INSTAGRAM_SCRAPLING_RUNTIME_ENABLED=1 .venv/bin/python - <<'PY'
from trr_backend.socials.instagram.runtimes.scrapling_runtime import ScraplingRuntime

health = ScraplingRuntime().healthcheck()
print({"healthy": health.healthy, "reason": health.reason})
PY
```

Expected output shape:

```text
{'healthy': True, 'reason': None}
```

## Bounded Canary Command

Use one account and a small post limit. Keep the flag scoped to this command or
to a short-lived canary process:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
INSTAGRAM_SCRAPLING_RUNTIME_ENABLED=1 \
INSTAGRAM_RUNTIME_ORDER=scrapling,crawlee,crawl4ai,browser_use \
.venv/bin/python - <<'PY'
import asyncio
import json
import os

from trr_backend.socials.instagram.runtimes.scrapling_runtime import ScraplingRuntime

async def main() -> None:
    runtime = ScraplingRuntime()
    profile = await runtime.fetch_profile("bravotv")
    posts = await runtime.fetch_posts("bravotv", limit=3)
    print(json.dumps({
        "runtime": runtime.name,
        "enabled": os.getenv("INSTAGRAM_SCRAPLING_RUNTIME_ENABLED"),
        "account": profile.username,
        "profile_user_id_present": bool(profile.user_id),
        "post_count": len(posts),
        "sample_shortcodes": [post.shortcode for post in posts[:3]],
    }, indent=2, sort_keys=True))

asyncio.run(main())
PY
```

If a deployment command is needed instead of a local shell, use the same env
shape and keep the scope bounded:

```bash
# Placeholder only: replace with the Modal or worker launch command for the
# target environment.
INSTAGRAM_SCRAPLING_RUNTIME_ENABLED=1 \
INSTAGRAM_RUNTIME_ORDER=scrapling,crawlee,crawl4ai,browser_use \
<launch-one-instagram-runtime-canary-for-one-account>
```

## Expected Metadata

Record this information in the operator note:

- `runtime`: `scrapling`
- `enabled`: `1`
- `account`: target handle without `@`
- `profile_user_id_present`: boolean, not the raw id if the note will be shared
- `post_count`: bounded count returned by the canary
- `sample_shortcodes`: okay to record; do not record cookies or headers
- healthcheck result before and after the run
- fallback behavior if the dispatcher moved to the next runtime
- any `RuntimeUnsupported` reason, HTTP status, or non-JSON payload reason

Do not record:

- cookie values
- request headers containing session or auth material
- proxy usernames, passwords, or full proxy URLs
- raw response bodies that may include account/session data
- database connection strings

## Stop Rules

Stop the canary and roll back before retrying if any of these appear:

- `401`, `403`, redirect to login, checkpoint, or challenge response
- repeated `RuntimeUnsupported` for empty profile/posts payloads
- non-JSON payloads from Instagram API endpoints
- Scrapling import/fetcher errors in the target runtime
- proxy, DNS, socket, or timeout failures that repeat after one retry
- any metadata that includes cookie values or credential-bearing strings

## Rollback

Rollback is env-only unless a separate code change was deployed:

```bash
INSTAGRAM_SCRAPLING_RUNTIME_ENABLED=0
```

If `INSTAGRAM_RUNTIME_ORDER` was changed for the canary, restore the previous
value or remove the scoped override. Restart the canary process, worker, or
deployment target so the env change is loaded.

After rollback, confirm the healthcheck is back to:

```text
{'healthy': False, 'reason': 'instagram_scrapling_runtime_enabled_not_enabled'}
```

Leave the existing `posts_scrapling` and `comments_scrapling` worker lanes
untouched during this rollback. They are separate dispatch paths.

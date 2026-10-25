# January public Instagram completion contract

This contract covers the existing January 2026 bravotv run
`2aef72ed-110c-4af9-b2b3-4a45da170a32`. It is public-only. Frozen membership,
run intent, native identities, retained source evidence and backoff remain binding.
Full-history stays disabled. No recurring schedules are part of this work.

## Recovery and preservation

The backend internal `recover_public_target` command accepts exact run/account,
generation, target, reviewed checkpoint hash, explicit lanes, source revision,
reason, operator and idempotency key. It refuses active/uncertain owners, changed
checkpoints, source backoff, unrelated blocks and non-public provenance. Prior
checkpoints and receipt IDs remain in the command journal. Timed continuation
attempts and immutable page receipts remain intact. Recovery never marks saved
comments missing. Unknown expected totals stay unknown; known totals cannot be
lowered by recovery. Two complete passes adding no IDs or stronger proof stop
further rescans and leave an explicit source gap.

`scripts/ingestion/recover_january_comments.py` defaults to a read-only ledger.
Application requires explicit target/hash/reason/revision/idempotency arguments.
This control interface does not change the public API.

## Per-post media proof

A selected post needs its own current comment target settled, a matching current
owner-generation receipt, exact persisted active comment inventory, and its
same-run detail receipt when details are selected. Other posts may remain pending.
A native-exhaustion count gap remains visible even if that known inventory can be
preserved as media. Media success never certifies comment completeness.

`instagram-media-inventory-v1` fingerprints cover post sources, comments including
text-only identities and parent links, attachments, and selected profile-image
inputs. Retained results carry original and exact attachment-projection hashes;
receipts bind the inventory after a validated refresh. Changed inventory fences
old media ownership and reopens media work, preserving receipts, stored bytes,
attempts, future retry deadlines and source/identity blocks. Lock order is media
target before post advisory/row locks. Comment writes and comment replay invoke
that invalidation before their canonical writer acquires the post lock.

The local worker gives ready media a turn in a free activity slot. A due turn
waits for one comment child to finish before reservation; up to five other comment
activities may continue. Total active activities remain at most six. Due state
survives partial batches, admission waits and partition continuation. Other phase
changes and finalization still drain all children. Existing admission and explicit
execution selections remain authoritative.

Changed post renditions use deterministic SHA-256 sibling keys when an immutable
existing key contains different bytes. Original objects remain intact. Exact
resolved keys flow through the existing result/receipt format. Prior role
provenance is retained separately with a current archival retention clock and
unchanged original clocks inside its payload. This auxiliary evidence cannot
stand in for completion proof. Comment attachments and avatars retain their
strict existing conflict rules.

Public avatar discovery and expired-URL refresh use the same bounded observation
path. A saved native ID is only a lookup hint; a fresh response must pass strict
native identity, exact handle and provenance checks. Sources allow one legacy
request or the reviewed bootstrap plus GraphQL POST, with explicit request
permits. Fresh signed download URLs stay in private memory and must match the
canonical source reference. Evidence, registry rows and replay contain canonical
references. A changed current avatar cannot silently replace a required older
asset. Partial progress is preserved under the current media owner.

Media inherits the parent process's absolute source deadline and cleanup reserve.
CDN timeouts use the remaining budget after admission. Each production R2 SDK
operation runs in a child process within the existing media activity group.
The owner enforces the absolute deadline and kills and reaps that child on
cancellation. Child deadline and parent-liveness guards cover abrupt parent loss.
Conditional writes and content-versioned keys preserve existing bytes; a lost
upload response is reconciled through the existing object check on retry.
Expected deadlines and local control/database failures remain technical outcomes,
not public-source rejection evidence.

## Completion lifecycle and certification

The local worker's optional January recovery binding is selected by
`TRR_INSTAGRAM_JANUARY_RECOVERY_RUN_ID`,
`TRR_INSTAGRAM_JANUARY_RECOVERY_INTENT_HASH` and
`TRR_INSTAGRAM_JANUARY_RECOVERY_SOURCE_REVISION`. At a drained completion boundary
it first reparses retained public responses for every settled post under the exact
checkpoint and parser fingerprint. Audits stream retained payloads without page
checkpoints. Historical observations can recover native IDs and attachments but
cannot advance current traversal proof or undo newer missing/deleted observations.
Only a complete offline audit can precede a fresh source comparison. A matched
zero-gap inventory does not trigger a root rescan.

Productive exhausted attempts receive journaled extensions of twelve attempts
when immutable page evidence proves progress in the last owner generation. Active
or uncertain owners, source blocks, backoff, checkpoints and counters remain
protected. Two complete recovery passes with no improvement still stop rescans.
The worker reopens one eligible source gap and continues durable scheduling.
A replayed completion choice cannot finish over newly unresolved work.

After ordinary work and bounded recovery settle or a stage remains blocked, the same worker can invoke the
maintained `scripts/ingestion/certify_january.py` through its explicit January
binding/storage-binding/output environment settings. Certification runs in one
owned process group; abort and timeout terminate and reap certifier/decoder
children. Existing complete private artifacts are never overwritten. Interrupted empty output is archived, and worker startup resumes missing certification under its coordinator lease.

Certification inventories all stage target keys. During unfinished traversal,
known count gaps produce an interim `final_acceptance=false` without expensive
retained-page scans or byte reads. Terminal runs proceed through the deep audits
so a source-count limitation does not hide independent media and byte results.
The complete observed media path requires exact full key coverage, passing post
proof, known counts, and verified native pages, IDs, parents, clocks, canonical
rows and attachment bindings. Only the positive public-native-exhaustion count
parity diagnostic is permitted there. Unknown or incomplete inventories still
block media/byte acceptance. Count parity and aggregate comments remain blocked
when a gap exists, so successful known-media checks cannot produce final
acceptance. Deep audits independently inspect listing, post fields, all comment
IDs/parentage, media slot order, selected profiles and canonical records in two
read-only snapshots. Source/binding/evidence fingerprints must remain unchanged. Complete
hosted bodies are streamed, hashed and decoded, including animation frames and
video/audio streams; there is no silent 50 MiB object exclusion. Public locations
must match an explicitly verified account/bucket/key/URL binding.

## Storage and consumer compatibility

The January worker can override its public media base independently through
`OBJECT_STORAGE_PUBLIC_BASE_URL`. The bucket stays `trr-media-prod` in the verified
TRR R2 account. A task canary proved that the existing public `r2.dev` endpoint
serves the same bucket bytes; the unhealthy `media.thereality.report` endpoint is
not required for this bounded run. Retain delivery backoff. Do not infer arbitrary
host aliases or rewrite URLs without object proof.

Public API shape and app contracts are unchanged. No app production build or SQL
schema migration is required. Operational progress must distinguish traversal,
source-count gaps, preserved media, and final acceptance.

## Bounded reply transport candidate

`SOCIAL_INSTAGRAM_PUBLIC_REPLY_CONCURRENCY` accepts only `1` or `2`, default `1`.
It applies to strict public reply traversal. One serialized owner runs each
parent branch's parser, evidence callback, canonical write, receipt and checkpoint
transition. HTTP tasks receive immutable request descriptors and independent
anonymous cookie jars. Each request starts from the latest owner-validated
snapshot; response cookies never carry automatically into another request.

Two slots means two total outstanding uncommitted pages, including pacing,
in-flight transport, completed responses and the current commit. A parent cannot
send its next cursor until its prior response has been processed. Completed
responses are consumed without waiting for an earlier slow parent. Existing
global and per-fetcher pacing, page sizes and retry budgets remain authoritative.
Six post workers therefore admit at most twelve outstanding reply pages.

Waiting bodies use anonymous disk files. Raw transport, bounded gzip/deflate
decompression and JSON parsing use 64 KiB raw chunks; parsed native objects,
including complete large strings, belong to the single owner. Oversized
bodies are not truncated. Trailing garbage, failed reads and malformed pagination
cannot prove exhaustion. Shutdown cancels and awaits HTTP tasks and drains
shielded pacing callbacks before closing clients or leaving ownership.

The optional `SOCIAL_INSTAGRAM_PUBLIC_REPLY_CANARY_TARGET`,
`SOCIAL_INSTAGRAM_PUBLIC_REPLY_CANARY_GENERATION`,
`SOCIAL_INSTAGRAM_PUBLIC_REPLY_CANARY_RUN_ID` and
`SOCIAL_INSTAGRAM_PUBLIC_REPLY_CANARY_RUN_GENERATION` must be supplied together. Only
that exact run, target and generation pair can use the configured concurrency;
other attempts remain serial. This makes a limited canary a normal continuation
of one existing attempt, with no duplicate traversal. The optional local
`TRR_INSTAGRAM_REPLY_TELEMETRY_DIR` stores fixed numeric timing receipts and public
target/owner-generation identity, with no credentials, headers or comment text.

Source validation and offline benchmark success do not activate the candidate.
Independent review, packaged-source verification, deployment readiness and a
bounded live canary remain prerequisites to enabling concurrency two broadly.

## Technical public reply failures

Generic failed public child requests retain their native error envelope and a
versioned top-level `public_reply_failures` entry. This technical metadata stays
outside native lane/page proof. The write requires the live run, exact owner
generation and unchanged checkpoint. It creates no successful page receipt,
canonical row, cursor advance, count or native-exhaustion proof.

Other parents and the existing supported child-document alternatives can
continue. Resume visits healthy parents before failed ones. A repeated technical
request uses 60/120/240-second scheduling delays, capped at 900 seconds, and a
technical hold after three identical failures. Stronger server waits still stop
requests globally. Auth, rate, root, parser and ownership/control failures retain
their existing stop behavior. Only a genuinely parsed and committed page clears
its own parent's failure. Any outstanding technical failure blocks settlement.

Recovery commands replay an accepted journal entry before admission. Both command
and run/account root admission use nonblocking locks. The shared limit counts
four unresolved recovery roots even after a restart marker is consumed. Busy or
full admission defers the finalizer, and abort cannot fall through to completion.

## Public storage client identity

The hosted reader declares `TRR-January-Media-Audit/1.0`. The verified managed R2
binding and original keys/bytes remain unchanged. A controlled October 25 check
found Cloudflare 403/1010 for urllib's library-default user agent while the same
object passed S3/public equality and full decode with explicit TRR identification.
The maintained requests client also passed before the identification change.

The reader records only bounded safe HTTP status, provider code and CF-Ray
diagnostics on failure. A 1010 client-signature denial is distinct from missing
bytes, source unavailability and rate limiting; it is not blindly retried. The
existing 429 shared stop and Retry-After behavior remain authoritative. This
object-level delivery proof does not certify the complete January media inventory.

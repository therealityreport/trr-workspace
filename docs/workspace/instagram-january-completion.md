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

The local worker drains each comment batch before requesting one proved media
candidate. Existing admission and six-comment policy remain effective. Explicit
execution selections remain authoritative.

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

Certification inventories all stage target keys. Known count gaps produce
`final_acceptance=false` without expensive retained-page scans or byte reads. The
no-gap path independently audits listing, post fields, all comment IDs/parentage,
media slot order, selected profiles and canonical records in two read-only
snapshots. Source/binding/evidence fingerprints must remain unchanged. Complete
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

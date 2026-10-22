# Instagram ingestion source profiles

The durable ingestion worker freezes its source profile in each new run intent.
The profile forms part of the intent hash. Changing process configuration does
not change an existing run or convert its saved cursors to another source family.

## Profile selection

| Source mode | Additional setting | Comment family | New local placement |
| --- | --- | --- | --- |
| `public` | None | `instagram_public_relay` | Supported |
| `authenticated` | `TRR_INSTAGRAM_INGESTION_AUTH_COMMENTS_TRANSPORT=rest`, or unset | `instagram_comments_rest` | Rejected |
| `authenticated` | `TRR_INSTAGRAM_INGESTION_AUTH_COMMENTS_TRANSPORT=www_relay` | `instagram_authenticated_www_relay` | Supported as an explicit operator selection |

`SOCIAL_INSTAGRAM_SCRAPE_MODE` selects the source mode. Public runs use anonymous
source clients and do not obtain a credential snapshot or use an interactive
browser. Authenticated runs use the existing pinned credential mechanism.
Enabling a profile selects code; live source qualification remains a separate
acceptance requirement. Keep session credentials local when local execution is
selected.

Untagged older intents retain their authenticated REST interpretation and their
original serialized payload and hash. The external ingestion API response shape
does not expose the internal source-profile fields.

## Checkpoints and retained evidence

Authenticated Relay has separate initial parent, parent continuation, initial
child, and child continuation operations. Its checkpoint binds the operation,
media identity, provider flags, ordering, page size, and native cursor. The initial
container may have an unknown page size; only the documented transition to its
matching continuation operation is accepted. A checkpoint from another family
is rejected before source access.

The authenticated Relay transport retains a failed request fact for rejected,
malformed, or unsupported streamed query envelopes. These envelopes cannot
advance comment rows, page receipts, or checkpoints, including during offline
replay and interruption recovery.

`public_native_exhaustion` may settle a public count gap only after the required
native lanes are exhausted. The receipt reports the expected count, observed
count, and gap. This settlement does not apply to authenticated retrieval.
Unresolved authenticated gaps or child lanes remain incomplete.

## Local operation

Create a fresh local run through the production command service with an explicit
supported profile. Use the account policy for a bounded month; the separate
canary policy accepts only its configured calendar-year window. Keep the normal
capacity, request, cooldown, ownership, cancellation, and placement checks.

The local worker uses the same durable scheduler and activity implementation.
Modal and local consumers honor the stored execution placement. During a
coordinated maintenance window, stop the owned local worker, verify that its
lease and target owners have drained, and use fenced run control. Preserve the
intent hash and checkpoints when resuming.

The Bravo full-history and `resume_tail` gate remains enforced by
`TRR-Backend/trr_backend/ingestion/validation_gate.py`. Selecting local placement
or a different source profile does not open that gate.

Implementation owners are `domain.py`, `composition.py`, `command_service.py`,
`comments.py`, `authenticated_relay_contract.py`, and
`authenticated_comment_transport.py` under `TRR-Backend/trr_backend/ingestion/`.

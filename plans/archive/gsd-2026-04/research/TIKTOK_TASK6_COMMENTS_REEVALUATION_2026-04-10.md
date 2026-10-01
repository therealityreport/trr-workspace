# TikTok Task 6 Comments Re-Evaluation

Date: 2026-04-10

## Decision

Task 6 remains parked until the `browser_intercept` recovery triage produces either a repair plan or a formal abandonment decision.

## Why

- `yt-dlp` is the only proven posts path.
- `browser_intercept` is currently the shared risk surface for both posts fallback and eventual comments collection.
- Starting comments implementation before repairing or explicitly abandoning that surface would hide the real bottleneck.

## Next Planning Trigger

Revisit immediately after the `browser_intercept` recovery-triage note is closed with either a repair plan or a formal abandonment decision.

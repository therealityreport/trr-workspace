# COMPARISON

## Summary

The source plan had the right architectural direction but was not approval-ready because live Supabase state contradicted two platform assumptions and the raw payload/RLS model was unsafe.

## Topic Delta

| Topic | Source | Revised | Delta | Reason |
|---|---:|---:|---:|---|
| A.2 Repo awareness | 6 | 8 | +2 | Adds `twitter_tweets`, `youtube_videos`, comment tables, and bridge refs. |
| A.4 Execution specificity | 6 | 8 | +2 | Adds private observation table, normalized keys, and composite FKs. |
| B Gap coverage | 6 | 8 | +2 | Covers raw-data exposure and legacy FK bridge. |
| E Safety | 5 | 8 | +3 | Removes public raw payload from canonical table and adds integrity controls. |
| D.2 Solution fit | 1 | 2 | +1 | Corrects platform adapter design. |
| H Bonus | 3 | 4 | +1 | Adds durable provenance/observation pattern. |

## Score Change

- Source: `73/100`
- Revised estimate: `88/100`
- Net improvement: `+15`

## Why The Revision Matters

Executing the source plan literally would build the right broad idea on an inaccurate platform matrix and expose raw scraper payloads in a new public-readable canonical table. The revised plan keeps the canonical model but adds the Supabase safety and integrity structure needed for execution.


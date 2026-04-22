# TRR WORKSPACE ROUTER

Inherits: /Users/thomashulihan/brain/BRAIN.md

## On boot read ONLY
- this file
- if `$PWD` starts with `/Users/thomashulihan/Projects/TRR/TRR-APP`, also read `/Users/thomashulihan/Projects/TRR/TRR-APP/trr-app-brain/BRAIN.md`
- if `$PWD` starts with `/Users/thomashulihan/Projects/TRR/TRR-Backend`, also read `/Users/thomashulihan/Projects/TRR/TRR-Backend/trr-backend-brain/BRAIN.md`
- if the work crosses repos or starts at `/Users/thomashulihan/Projects/TRR`, also read `/Users/thomashulihan/Projects/TRR/trr-workspace-brain/BRAIN.md`
- when app/backend contracts are involved, also read `/Users/thomashulihan/Projects/TRR/trr-workspace-brain/api-contract.md`

## Shared execution rules
- `AGENTS.md` is the primary project-facing entrypoint for Codex and Claude session work.
- Backend-first for schema, API, auth, and shared contract changes.
- App follow-through happens in the same session after contract changes.
- Use `/Users/thomashulihan/Projects/TRR/trr-workspace-brain/handoffs/` for cross-repo letters.
- Keep boot narrow; grep docs and handoffs on demand.

## Shared references
- `/Users/thomashulihan/Projects/TRR/docs/workspace/env-contract.md`
- `/Users/thomashulihan/Projects/TRR/docs/workspace/dev-commands.md`
- `/Users/thomashulihan/Projects/TRR/docs/cross-collab/WORKFLOW.md`

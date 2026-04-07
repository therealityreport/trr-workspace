# Phase 8 Research

## Summary

Phase 8 is an adoption-and-proof phase. Most of the work is already encoded in the repo: the canonical path exists, the help surfaces are aligned, and the handoff lifecycle is available. The missing piece is trustworthy evidence that a real milestone verification path runs without Docker and a concise inventory of the remaining fallback-only Docker cases.

## Recommended Proof Strategy

Use a real no-Docker milestone verification lane that exercises multiple workspace surfaces without invoking local Docker fallback:

1. `make preflight`
2. `bash scripts/check-workspace-contract.sh`
3. `python3 scripts/env_contract_report.py validate`
4. `bash scripts/handoff-lifecycle.sh post-phase`
5. `bash scripts/handoff-lifecycle.sh closeout`

This is stronger than a single grep or help-text check because it validates the same cross-repo guardrails the milestone depends on.

## Remaining Documentation Gap

The repo still needs one clear fallback inventory for Docker-only cases. The likely items are:

- `make dev-local`
- `make down`
- local Screenalytics Redis + MinIO via Docker
- Docker-backed local replay or reset checks when a remote isolated target cannot answer the question

## Recommendation

Treat Phase 8 as:

1. real no-Docker verification evidence
2. one explicit fallback-boundary section in workspace-facing docs
3. continuity and milestone-closeout artifacts that reference the same story

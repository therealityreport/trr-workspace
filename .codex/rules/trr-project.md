# TRR Codex Project Rules

These rules apply to Codex work in `/Users/thomashulihan/Projects/TRR`.

## Completion
- When a completed change affects Modal-deployed TRR backend, worker, scraper, job, runtime, or Modal secret-preparation code, update or send the change to Modal before calling the task complete.
- Treat the Modal update as required completion work unless the user explicitly asks for local-only work.
- If the change is outside Modal's deploy surface, state that no Modal update was needed and why.
- If Modal cannot be updated, report the exact blocker and the command or handoff needed to finish it.

## Browser Testing
- When using `[@Browser](plugin://browser-use@openai-bundled)` or browser inspection/testing for TRR, use `make dev-hybrid` as the default startup/build command.
- Use a different target only when the user explicitly specifies one or the task requires local-only or cloud-only behavior.
- In the final handoff, state which startup target was used for browser verification.

## Build Safety
- Codex must not run a full TRR-APP production build (`pnpm -C TRR-APP/apps/web run build`, `cd TRR-APP && pnpm run web:build`, `cd TRR-APP/apps/web && next build`, or equivalent) without explicit user approval in the current chat.
- Before asking to run a full production build, Codex should run the lightweight app validation command first: `make app-validate-quick`.
- If lightweight validation fails, fix or report that failure before proposing a production build.
- Do not bypass the local build safety wrapper with `TRR_FORCE_BUILD=1` unless the user explicitly approves that override in the current chat.
- Short final-response note: `TRR-APP build: <passed | skipped, no current-chat approval | blocked: reason>.`

## Full App Build Required
- Run a full TRR-APP production build after current-chat approval when changes touch Next.js build behavior, app routing or middleware, server/client component boundaries, generated app contracts, production env projection, or app/API contracts that may fail only during `next build`.
- A full build is also required when the user explicitly approves or requests production-build evidence for the current change.

## Final Response Checklist
- State backend/API validation status and any blockers.
- State app validation/build status using the short build-safety note.
- State direct-SQL ledger/inventory status when SQL ownership changed.
- State Modal follow-through status when backend, worker, scraper, job, runtime, or Modal secret-preparation code changed.
- State browser verification target if a browser was used; otherwise omit browser proof.

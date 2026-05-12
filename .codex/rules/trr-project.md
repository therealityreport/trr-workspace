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

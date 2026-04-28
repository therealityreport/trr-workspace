# Suggestions

These are optional follow-ups. They are not required fixes for the revised plan.

1. **Title:** Add `make runtime-db-identity`
   **Type:** Small
   **Why:** Operators need a quick no-secret way to confirm the active DB target.
   **Where it would apply:** `Makefile`, `TRR-Backend/scripts/dev/`.
   **How it could improve the plan:** Makes identity verification reusable outside startup.

2. **Title:** Add `make runtime-db-redaction-check`
   **Type:** Small
   **Why:** Secret leakage is easy to regress in env tooling.
   **Where it would apply:** `Makefile`, `scripts/`.
   **How it could improve the plan:** Gives operators a targeted check before commits.

3. **Title:** Add structured startup mode JSON
   **Type:** Medium
   **Why:** Shell output is useful to humans, but status tooling benefits from stable keys.
   **Where it would apply:** `.logs/workspace/runtime-reconcile.json`, `scripts/status-workspace.sh`.
   **How it could improve the plan:** Makes `make status` and future monitors less fragile.

4. **Title:** Add a cloud-mode direct-env guard
   **Type:** Small
   **Why:** Ignored local env files may contain direct URLs.
   **Where it would apply:** `scripts/preflight.sh`, `scripts/dev-workspace.sh`.
   **How it could improve the plan:** Fails early if cloud mode would accidentally see local direct config.

5. **Title:** Add migration action dry-run output
   **Type:** Medium
   **Why:** Manual migration decisions are easier to review before live changes.
   **Where it would apply:** `TRR-Backend/scripts/dev/reconcile_runtime_db.py`.
   **How it could improve the plan:** Shows the proposed per-migration action without applying or repairing.

6. **Title:** Add direct-URI derivation unit tests for malformed usernames
   **Type:** Small
   **Why:** Supabase pooler usernames encode the project ref.
   **Where it would apply:** `scripts/test_runtime_db_env.py`, backend `_db_url` tests.
   **How it could improve the plan:** Prevents deriving a wrong direct host from nonstandard pooler strings.

7. **Title:** Record local mode in pidfile metadata
   **Type:** Small
   **Why:** Runtime debugging often starts from `.logs/workspace/pids.env`.
   **Where it would apply:** `scripts/dev-workspace.sh`.
   **How it could improve the plan:** Makes it obvious which mode started the current process set.

8. **Title:** Add docs for the session escape hatch
   **Type:** Small
   **Why:** Explicit session fallback is intentionally exceptional.
   **Where it would apply:** `docs/workspace/dev-commands.md`.
   **How it could improve the plan:** Prevents operators from treating the escape hatch as the normal path.

9. **Title:** Add a rollback checklist for launcher mode split
   **Type:** Medium
   **Why:** Startup contract changes affect daily workflow.
   **Where it would apply:** `docs/workspace/dev-commands.md` or a runbook.
   **How it could improve the plan:** Gives a fast path back to cloud mode if direct local connectivity fails.

10. **Title:** Add a migration verdict JSON companion
    **Type:** Medium
    **Why:** Markdown is good for review, JSON is easier for tooling.
    **Where it would apply:** `docs/workspace/runtime-reconcile-migration-decisions-2026-04-28.json`.
    **How it could improve the plan:** Enables future reconcile tooling to read prior decisions.

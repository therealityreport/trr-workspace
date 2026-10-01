# Cross-repo coordination

This note owns only the cross-repo rules below; follow the linked documents for their procedures.

- **Release order:** follow the canonical release sequence in [development and deployment commands](../workspace/dev-commands.md).
- **View bridge:** before dropping a table used across repos, deploy a compatibility view over the replacement schema, switch and verify every consumer, then drop the old table.
- **Vercel env gate:** before a survey or app cutover that depends on runtime env contracts, compare `vercel env ls` with `vercel env pull` for the verified active project.
  Classify unexplained or pull-only entries as `canonical`, `deprecated-removable`, `integration-managed-retained`, or `unknown-blocking`.
  Block cutover while any `unknown-blocking` entry remains; record reviewed retained variables in [the env review](../workspace/vercel-env-review.md).
- **PR coordination:** use one PR per affected repo and merge in dependency order.

## Owning references

- [Handoff workflow](../ai/HANDOFF_WORKFLOW.md) owns snapshots, freshness, generated indexes, and lifecycle commands.
- [Plans](../../plans/) owns active implementation plans and their archive.
- [Deployment commands](../workspace/dev-commands.md) and [Modal release guidance](../workspace/modal-safe-backend-deploy-set.md), and [API deployment guidance](../../TRR-Backend/docs/deploy/render.md) own release procedures.
- [Workspace completion rules](../../AGENTS.md#completion) and [app build gates](../../.codex/rules/trr-project.md) govern completion.
- [Backend instructions](../../TRR-Backend/AGENTS.md) and [app instructions](../../TRR-APP/AGENTS.md) own repo-specific work.

The TASK-folder workflow is retired. Existing TASK files remain historical sources; create new continuity records under `docs/ai/local-status/`.

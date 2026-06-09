# Agent Teams Code Review - 2026-05-28

Target: `/Users/thomashulihan/Projects/TRR`

Snapshot:

- Commit: `ff76d01`
- Review time: `2026-05-28T17:38:52Z`
- Tree state: dirty before review; review artifacts are documentation only.

Implementation update:

- Non-admin-auth remediation was implemented after this review using
  `REVISED_PLANv2.MD`.
- Admin auth and debug-log host-trust findings remain intentionally deferred by
  user scope.
- Modal deploy remains blocked by the safe deploy manifest because the backend
  checkout is heavily dirty and this orchestration run was not allowed to create
  an isolated worktree.

Review lanes:

- API/backend correctness and data integrity
- Cloud infra, Modal, Supabase, env, secrets, and deploy contracts
- Frontend/admin/API client correctness
- Security, auth, trust boundaries, and secrets
- Testing, validation, docs/governance, and markdown-topic inventory

## Package

- [consolidated-findings.md](consolidated-findings.md) - severity-ranked findings, impact, and fixes.
- [fixes-and-patches.md](fixes-and-patches.md) - concrete patch directions for each finding.
- [markdown-topics.md](markdown-topics.md) - markdown files and topic surfaces encountered.
- [validation-evidence.md](validation-evidence.md) - commands, tool checks, and coverage gaps.
- [agent-lane-reports.md](agent-lane-reports.md) - source-lane summary from each review agent.

## Highest-Risk Items

1. Admin auth and debug-log locality checks trust request host data.
2. Modal maintenance can have zero default owner, or duplicate owners when fallback is enabled in multiple API replicas.
3. Modal billing guardrail does not validate the actual `.env` source used to render named secrets.
4. Comments progress `GET` mutates live shard state by auto-rebalancing.
5. Supabase still exposes `surveys.submit_response(uuid, jsonb)` as a `SECURITY DEFINER` RPC to `anon` and `authenticated`.

This review package now records both the original findings and the 2026-05-28
implementation status for the non-admin-auth remediation pass.

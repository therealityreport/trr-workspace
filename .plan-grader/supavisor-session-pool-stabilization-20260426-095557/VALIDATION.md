# Validation Notes

## Files Inspected

- `/Users/thomashulihan/.codex/plugins/plan-grader/SKILL.md`
- `/Users/thomashulihan/.codex/plugins/plan-grader/skills/plan-grader/SKILL.md`
- `/Users/thomashulihan/Documents/Codex/2026-04-21-create-a-rubric-for-scoring-an/implementation-plan-rubric.md`
- `/Users/thomashulihan/Projects/TRR/docs/superpowers/plans/2026-04-26-supavisor-session-pool-stabilization.md`
- `/Users/thomashulihan/.codex/memories/MEMORY.md`
- `/Users/thomashulihan/Projects/TRR/.plan-grader/supavisor-session-pool-stabilization-20260426-095557/REVISED_PLAN.md`

## Commands Run

```bash
sed -n '1,260p' /Users/thomashulihan/.codex/plugins/plan-grader/SKILL.md
sed -n '1,260p' /Users/thomashulihan/.codex/plugins/plan-grader/skills/plan-grader/SKILL.md
sed -n '1,620p' /Users/thomashulihan/Documents/Codex/2026-04-21-create-a-rubric-for-scoring-an/implementation-plan-rubric.md
wc -l docs/superpowers/plans/2026-04-26-supavisor-session-pool-stabilization.md
sed -n '1,900p' docs/superpowers/plans/2026-04-26-supavisor-session-pool-stabilization.md
nl -ba /Users/thomashulihan/.codex/memories/MEMORY.md | sed -n '497,505p'
nl -ba /Users/thomashulihan/.codex/memories/MEMORY.md | sed -n '997,1050p'
nl -ba /Users/thomashulihan/.codex/memories/MEMORY.md | sed -n '2197,2255p'
nl -ba /Users/thomashulihan/.codex/memories/MEMORY.md | sed -n '2868,2908p'
nl -ba /Users/thomashulihan/.codex/memories/MEMORY.md | sed -n '3092,3099p'
mkdir -p .plan-grader/supavisor-session-pool-stabilization-20260426-095557
sed -n '1,760p' .plan-grader/supavisor-session-pool-stabilization-20260426-095557/REVISED_PLAN.md
```

## Not Run

No source-code tests were run. This was a plan grading and revision pass only.

## Evidence Gaps

1. The actual backend router target for `GET /admin/socials/landing-summary` still needs live repo discovery immediately before implementation.
2. The actual workspace runtime DB env helper file still needs live repo discovery before the env-lane phase.
3. Supavisor pool size and active session counts are external runtime state and must be captured from Supabase or a safe database view during Phase 0.
4. Screenalytics git ownership should be checked before staging any changes.
5. Production app instance caps, backend replica counts, Screenalytics instance counts, and Postgres `max_connections` need live environment confirmation before production rollout.

## Assumptions

- The currently saved source plan is the plan the user intended to grade.
- The current failure is session-mode saturation, not a broken landing route contract.
- TRR should continue using a small, cloud-first local `make dev` profile rather than hiding problems with larger local pools.
- Backend APIs should own durable app/backend data contracts for admin reads.

## Recommended Next Validation

Before implementing:

```bash
cd /Users/thomashulihan/Projects/TRR
git status --short
git -C TRR-APP status --short
git -C TRR-Backend status --short
git -C screenalytics status --short || true
rg -n "trr_runtime_db_resolve_local_app_url|runtime.*db|TRR_DB_SESSION_URL|TRR_DB_URL" scripts TRR-APP/apps/web/src TRR-Backend
rg -n "APIRouter|include_router|admin.*social|socials" TRR-Backend/api TRR-Backend/trr_backend
rg -n "safeLoadCastSocialBladeRows|pipeline.socialblade_growth_data|@/lib/server/postgres" TRR-APP/apps/web/src/lib/server/admin/social-landing-repository.ts
```

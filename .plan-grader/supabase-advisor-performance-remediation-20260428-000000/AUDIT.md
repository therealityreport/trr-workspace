# AUDIT

Source plan: `/Users/thomashulihan/Projects/TRR/docs/codex/plans/2026-04-28-supabase-advisor-performance-remediation-plan.md`
Rubric: `/Users/thomashulihan/Documents/Codex/2026-04-21-create-a-rubric-for-scoring-an/implementation-plan-rubric.md`
Verdict: **Phase 1 local staging approved; live DDL and Phase 2+ gated**
Original score: **88.5 / 100**
Revised score estimate: **96.6 / 100**
Approval decision: **Phase 0 evidence collection is approved; Phase 1+ is blocked pending review of the amended gates**

## current-state fit

**PASS for local staging.** The plan still matches the TRR workspace direction: backend-owned shared-schema migrations, app migration quarantine, query-plan evidence before index changes, and no bulk index drops from `idx_scan = 0`.

The revision changes the approval posture: urgent Security Advisor exposure can no longer wait behind the whole performance sequence, and RLS DDL now requires stronger access-semantics proof before implementation.

## benefit score

**High.** The first performance target remains correct: seven `auth_rls_initplan` findings and overlapping duplicate permissive policies on hot catalog/public/survey tables. The index posture also remains correct: evidence-gated, owner-reviewed, reversible batches rather than bulk-dropping 415 "unused" indexes.

## biggest risks fixed by this revision

1. **Security ordering.** Added a parallel hotfix gate for `public.__migrations` and exposed `SECURITY DEFINER` RPC execution.
2. **RLS access drift.** Added per-table permission matrix tests and GRANT/table-owner/FORCE RLS inventory.
3. **Command-specific policy mistakes.** Added exact `INSERT`, `UPDATE`, and `DELETE` policy DDL templates.
4. **Firebase survey data leaks.** Added null-safe UUID casts, old/new row checks, and a stop rule for moving answers to another user's response.
5. **Rollback gap.** Added rollback SQL requirement to restore exact Phase 0 policies by name.
6. **Stale execution source.** Marked `docs/codex/plans/` as canonical and `.plan-grader` as evidence only.
7. **Subagent ambiguity.** Added an explicit `orchestrate-subagents` execution model with disjoint ownership scopes, parallel waves, stop rules, report format, and main-session integration duties.

## approval decision

Post-approval note: Phase 1 safety and RLS artifacts may be staged locally, but live deployment and Phase 2+ index work remain blocked until owner-controlled DB rollout, post-deploy verifier, and immediate advisor recheck are complete.

Recommended next execution skill after approval remains **`orchestrate-subagents`** for independent implementation workstreams. The revised plan now specifies the exact subagent roster and orchestration gates, but live DDL and Phase 2+ remain blocked until owner-controlled rollout and advisor recheck requirements are met.

# AUDIT

Source plan: `/Users/thomashulihan/Projects/TRR/docs/codex/plans/2026-04-28-unused-index-full-decision-review-plan.md`
Rubric: `/Users/thomashulihan/Documents/Codex/2026-04-21-create-a-rubric-for-scoring-an/implementation-plan-rubric.md`
Verdict: **Revise before execution**
Original score: **88.6 / 100**
Revised score estimate: **95.0 / 100**
Approval decision: **Artifact-only planning is approved; execution is blocked until row-count drift and worktree conflicts are resolved**

## current-state fit

**Mostly fits, but execution must stop at preflight today.** The source plan has the right safety posture: no index drops, live inventory checks, stats-window checks, `TRR_SUPABASE_ACCESS_TOKEN`, rollback SQL from `pg_get_indexdef`, workload packets, and a hard social hashtag/search architecture block.

The current repo state adds two concrete blockers that the plan needs to make more explicit:

1. `docs/workspace/unused-index-advisor-review-2026-04-28.csv` is present, but currently parses as `1,302` rows with `777 excluded`, `267 defer:idx_scan_nonzero`, and `258 drop_review_required`. That conflicts with the owner-supplied target universe of `1,324` rows, `781 excluded`, `266 deferred`, and `277 drop_review_required`.
2. The workspace is currently detached `HEAD` with unresolved conflicts in multiple workspace files, including `docs/workspace/env-deprecations.md`, `scripts/check-workspace-contract.sh`, `scripts/status-workspace.sh`, and `scripts/test_workspace_app_env_projection.py`. The index review can be planned, but execution should not start until the owner intentionally resolves or accepts this state.

## benefit score

**High.** The plan protects production data and query performance while converting a raw Advisor report into owner-reviewed operational decisions. The biggest benefit is preventing accidental destructive index cleanup while still making future Phase 3 batches possible.

## biggest risks fixed by this revision

1. **Report-universe drift.** The revised plan makes the `1,324` vs `1,302` mismatch a mandatory preflight blocker, not a footnote.
2. **Conflicted worktree execution risk.** The revised plan blocks execution while detached `HEAD` and unresolved conflicts are present unless the owner explicitly approves proceeding.
3. **Historical approval bleed-through.** Existing `phase3-*-approved-drops.sql` and prior owner packets are now treated as evidence only, not reusable approval for the new full review.
4. **Subagent ambiguity.** The revised plan adds a concrete owner/workload subagent roster with disjoint write scopes.
5. **Canonical artifact naming.** The revised plan distinguishes existing prior packet names from required new `*-review.md` outputs.

## approval decision

Use the revised plan for execution planning. Do not execute the review until Phase 0 resolves the report-count mismatch and the current worktree conflicts. After those blockers are cleared, hand off with `orchestrate-subagents`.

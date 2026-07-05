# VALIDATION — TRR Remediation Plan

**Input:** `.full-review/REMEDIATION_PLAN.md` · **Against:** `.full-review/_raw-findings.json`, `05-final-report.md`.

## Coverage check (plan ↔ findings)
- **2 Critical** → Phase 0 (anon grants 0B; branch protection 0B). ✅ both mapped.
- **32 High** → 30 active mapped to Phase 1 workstreams; 1 **refuted** (middleware) correctly excluded; 1 **uncertain** (migration testing) routed to Gate G0. ✅
- **53 Medium / 37 Low** → Phase 2 / Phase 3 grouped by theme with `_raw-findings.json` as the exhaustive index. ✅ (not individually enumerated by design — decision-complete via grouping).
- **+4 completeness items** → Modal ingress (0A-modal), 2nd cron (0A-cron), refuted XSS excluded, unverified leads → Workstream V. ✅

## Reality grounding
- Backend-first ordering matches `CLAUDE.md` cross-repo contract. ✅
- Modal redeploy-on-completion flagged for 0A-modal + W1.S2-adjacent worker changes. ✅
- Validation commands match repo entrypoints (`ruff`/`pyright`/`pytest` in TRR-Backend; pnpm scripts in apps/web; `make preflight`/`workspace-contract-check`). ✅

## Gaps found & resolved in revision
1. Initial plan lacked an explicit **file-ownership matrix** → added (required because subagents run on `main`).
2. `api/main.py` and `api/routers/**` contention between 0A-modal/W1.3/S-streams was implicit → now explicit serialization.
3. Cross-repo credential change was a loose Phase-2 bullet → now a single coordinated slice with rollback.
4. Workstream V was a list → now a true **Gate G0** that blocks dependent scheduling.

## Residual (acceptable) gaps
- Phase 2/3 are grouped, not per-finding tasked — intentional; `orchestrate-subagents` should expand the chosen Phase-2 cluster into tasks at execution time using `_raw-findings.json`.

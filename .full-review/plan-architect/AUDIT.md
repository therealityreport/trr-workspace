# AUDIT — Plan pressure-test (risks & latent bugs)

Severity = risk to a safe, correct execution.

| # | Risk | Sev | Mitigation in revised plan |
|---|---|---|---|
| A1 | Two subagents edit the same monolith on `main` → corruption/lost work | **High** | Ownership matrix marks `social_season_analytics_impl.py`, `admin_person_images.py`, `[showId]/page.tsx`, `inventory.ts` **single-owner**; Wave 3 sequential. |
| A2 | W1.3 sanitizer touches broad `api/routers/**` while S1/S2 refactor the same routers | **High** | W1.3 = Wave 2; S-streams = Wave 3 (after W1.3). Explicit "must finish before Wave 3". |
| A3 | `api/main.py` edited by both 0A-modal (metrics) and W1.3 (global handler) | Med | 0A-modal edits `main.py` first; W1.3 rebases. |
| A4 | Auto-applying anon-grant revoke / key rotation / branch protection | **Critical** | All 🔒, Wave 0, human-only, OUT of subagent set. |
| A5 | Removing static-secret gates piecemeal → cross-repo auth lockout | **High** | Single coordinated slice (backend+app+Modal) + feature flag + rollback. |
| A6 | Acting on unverified completeness leads (some may be wrong, like the refuted XSS) | Med | Gate G0 (Workstream V) confirms before scheduling. |
| A7 | `orchestrate-subagents` on dirty/`main` with uncommitted review files | Med | Precondition: clean tree, commit at each wave boundary. |
| A8 | Modal change not redeployed → public ingress stays open | Med | 0A-modal acceptance requires redeploy + unauth `/metrics` rejection check. |
| A9 | Branch-protection enabled before CI is green → blocks all merges | Med | Sequence: W1.1 lands + passing, *then* 0B branch protection. |

**Net:** no Critical/High audit risk is left unmitigated; A4/A9 are sequencing constraints encoded in the wave order.

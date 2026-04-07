# Phase 5: Runtime Retirement & Cutover Cleanup - Research

**Researched:** 2026-04-03
**Domain:** Final screentime runtime retirement, backend-only cutover cleanup, and operator continuity after donor removal
**Confidence:** HIGH

<user_constraints>
## User Constraints (from PROJECT.md, ROADMAP.md, REQUIREMENTS.md, and prior phase decisions)

### Locked Decisions
- `TRR-Backend` is the permanent owner of screentime ingestion, identity, execution, review, publication, and admin-facing contracts.
- `TRR-APP` must preserve the working screentime admin flow while the remaining donor runtime dependency is removed.
- `screenalytics` is being retired for screentime; remaining donor seams are cleanup work, not permanent architecture.
- Phase 5 is not a UI redesign. The operator path stays in `TRR-APP` and continues to use backend-owned contracts.
- Production screentime flows must no longer require `SCREENALYTICS_API_URL` or `SCREENALYTICS_SERVICE_TOKEN`.
- The retained backend runtime, review state, and publication state from Phases 3 and 4 remain the canonical source of truth.
- At least one real-media parity sanity check is still required before claiming operational confidence, but that does not change the Phase 5 scope.

### the agent's Discretion
- Whether the donor runtime rollback flag is removed entirely or collapsed to a backend-only single mode with compatibility shims.
- Whether `screenalytics`-named backend routes are deleted, narrowed, or left in place for non-screentime legacy concerns that are explicitly out of scope.
- Exact env-doc cleanup boundaries across repo docs, README files, and examples.
- How aggressively to prune tests that mention `SCREENALYTICS_*` versus rewriting them around preserved non-screentime behaviors.

### Deferred Ideas (OUT OF SCOPE)
- Retiring every `screenalytics`-named concept everywhere in the workspace regardless of whether it is related to screentime.
- Public productization, non-admin UX work, or richer review intelligence beyond the current operator-reviewable contract.
- Re-architecting unrelated backend startup validation beyond what is necessary to remove screentime runtime dependency on `SCREENALYTICS_*`.

</user_constraints>

<research_summary>
## Summary

Phase 5 is a cleanup and retirement phase, not another feature-construction phase. The backend already owns screentime runtime execution, reviewed totals, publication lineage, and the app proxy contract. The remaining gap is that the backend still preserves a donor rollback path and still models `SCREENALYTICS_API_URL` and `SCREENALYTICS_SERVICE_TOKEN` as live operational dependencies. That leaves the migration technically incomplete even though operators can already work through `TRR-APP`.

Repo inspection shows the remaining dependency is concentrated in four places:
1. `retained_cast_screentime_dispatch.py` still supports donor runtime modes and HTTP forwarding through `screenalytics_cast_screentime.py`.
2. `api/main.py` startup validation still treats `SCREENALYTICS_SERVICE_TOKEN` as required for deployed backend operation and still reasons about `SCREENALYTICS_API_URL`.
3. Backend-internal `screenalytics` service-token routes remain mounted even though the screentime admin flow is already backend-owned.
4. Docs, examples, and tests still describe Screenalytics runtime dependency as active rather than retired for screentime.

The app side is already in good shape for retirement: the admin proxy route only targets backend `/admin/cast-screentime/...` paths and does not depend on Screenalytics auth directly. That means Phase 5 should leave `TRR-APP` pathing stable while removing the remaining donor dependency behind the backend seam.

**Primary recommendation:** Execute Phase 5 as a three-part retirement:
1. collapse screentime dispatch to backend-only runtime ownership and remove donor HTTP execution as an operational mode,
2. remove the screentime-specific startup/env/auth dependency on `SCREENALYTICS_*` and retire the now-obsolete service boundary,
3. clean docs, tests, and decommission status so the workspace clearly records backend-only operation while preserving app continuity.
</research_summary>

<standard_stack>
## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| FastAPI | Repo-pinned in `TRR-Backend` | Canonical screentime API and startup config | The backend already owns the retained screentime control plane |
| PostgreSQL + Supabase migrations | Repo-pinned | Canonical `ml.*` screentime state | Retirement should not move persistence ownership |
| Next.js App Router + React 19 | Repo-pinned in `TRR-APP` | Stable operator surface during retirement | Existing proxy and page contracts should remain intact |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Pytest + FastAPI TestClient | Repo-pinned | Backend route, dispatch, and startup verification | Required for runtime retirement confidence |
| Ruff | Repo-pinned | Scoped backend lint/format validation | Needed for touched retirement files |
| Vitest | Repo-pinned in `TRR-APP` | Proxy and operator continuity checks | Confirms the app remains stable after backend cleanup |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Removing donor screentime runtime mode | Keep donor HTTP as a permanent fallback | Fails `MIGR-04` and leaves split-runtime dependency in production |
| Updating startup config to stop requiring `SCREENALYTICS_*` for screentime | Keep the envs as "just in case" operational dependencies | Preserves unnecessary secrets and obscures the actual architecture |
| Preserving stable app proxy contract while retiring backend donor seams | Rewire the app to a new path during retirement | Adds avoidable UI risk in a cleanup phase |

</standard_stack>

<architecture_patterns>
## Architecture Patterns

### Pattern 1: Single-owner screentime dispatch
**What:** Collapse runtime dispatch so screentime execution resolves to backend-owned services only.
**When to use:** When migration is complete enough that rollback-by-external-service is no longer part of the supported production architecture.
**Example direction:**
```python
def dispatch_cast_screentime_run(...):
    return execute_retained_cast_screentime_run(...)
```

### Pattern 2: Environment contract retirement by capability, not by name sweep
**What:** Remove `SCREENALYTICS_*` only where it represents screentime runtime dependency; do not blindly delete unrelated references without evidence.
**When to use:** When a donor name still appears in code but some non-screentime or transitional uses may remain.
**Example direction:**
```python
required_runtime_envs = [
    "TRR_INTERNAL_ADMIN_SHARED_SECRET",
    "TRR_DB_URL",
]
```

### Pattern 3: Stable app path, changed backend internals
**What:** Preserve `/api/admin/trr-api/cast-screentime/[...path]` and the existing app workflow while removing donor internals behind the backend.
**When to use:** When the app already reflects the canonical operator flow and the remaining problem is backend dependency drift.
**Example direction:**
```ts
const backendPath = `/admin/cast-screentime/${path.join("/")}${request.nextUrl.search}`;
```

### Anti-Patterns to Avoid
- **Broad "delete all screenalytics files" cleanup:** Phase 5 is about screentime runtime retirement, not unrelated codebase churn.
- **Keeping donor envs as silent no-op requirements:** It creates false operational coupling and fails the requirement even if runtime no longer uses them.
- **Changing app routes during backend retirement:** It creates unnecessary operator risk in the final cleanup phase.

</architecture_patterns>

<dont_hand_roll>
## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Screentime runtime selection | New runtime registry or second feature-flag layer | Simplify existing `retained_cast_screentime_dispatch.py` | The seam already exists and only needs retirement cleanup |
| App continuity proof | Manual click-through only | Existing proxy and page tests plus targeted Vitest updates | Keeps Phase 5 regression checks fast and repeatable |
| Retirement documentation | Ad hoc chat-only explanation | Existing status docs and decommission ledger | Keeps cross-repo continuity explicit |

</dont_hand_roll>

<common_pitfalls>
## Common Pitfalls

### Pitfall 1: Retiring env references incompletely
**What goes wrong:** Production code no longer uses donor runtime, but startup validation, docs, or examples still require `SCREENALYTICS_*`.
**How to avoid:** Treat startup validation, env examples, tests, and docs as part of the retirement surface, not postscript cleanup.

### Pitfall 2: Breaking app continuity during backend cleanup
**What goes wrong:** The runtime is retired, but `TRR-APP` loses a stable proxy or operator-state assumption.
**How to avoid:** Keep the app path stable and verify existing screentime tests after backend cleanup.

### Pitfall 3: Over-scoping retirement into unrelated legacy work
**What goes wrong:** Phase 5 becomes an unbounded "rename or delete everything screenalytics" effort.
**How to avoid:** Scope retirement to screentime runtime dependency and explicitly document anything left outside this milestone.

</common_pitfalls>

<code_examples>
## Code Examples

### Current donor-capable dispatch seam
```python
runtime_mode = os.getenv("CAST_SCREENTIME_RUNTIME_MODE", "backend")
if runtime_mode in {"donor_http", "legacy", "screenalytics"}:
    return client.dispatch_run(...)
```

### Current app proxy seam to preserve
```ts
const backendPath = `/admin/cast-screentime/${path.join("/")}${request.nextUrl.search}`;
return proxyTracedRequest(request, backendUrl);
```

### Current startup validation drift to retire
```python
missing_auth.append("SCREENALYTICS_SERVICE_TOKEN")
```

</code_examples>

<open_questions>
## Open Questions

1. **Should screentime donor-mode code be deleted outright or left as unreachable compatibility code for one more cycle?**
   - Recommendation: remove operational support and tests for donor mode in this phase; leave only clearly documented non-screentime legacy surfaces if still needed.

2. **Should `api/routers/screenalytics.py` and `api/routers/screenalytics_runs_v2.py` be deleted entirely?**
   - Recommendation: retire screentime-specific uses and tests in this phase, but only delete the routes if repo inspection confirms no remaining supported non-screentime consumers.

3. **Should the real-media parity check be part of Phase 5 acceptance or recorded as a post-phase operational gate?**
   - Recommendation: keep it in Phase 5 manual verification so retirement is not declared complete without one end-to-end live sanity run.

</open_questions>

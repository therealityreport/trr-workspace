# Phase 4: Canonical Review, Publication & Admin Cutover - Research

**Researched:** 2026-04-03
**Domain:** Canonical screentime review state, publication lineage, and TRR-APP operator cutover against retained backend contracts
**Confidence:** HIGH

<user_constraints>
## User Constraints (from PROJECT.md, ROADMAP.md, REQUIREMENTS.md, and prior phase decisions)

### Locked Decisions
- `TRR-Backend` remains the permanent owner of screentime state. `screenalytics` is donor code plus temporary rollback path only.
- `TRR-APP` is the operator-facing surface for screentime. Phase 4 must make review, publication, and inspection work end-to-end there.
- Runs remain immutable execution facts. Review decisions and publication lineage must be stored separately from raw run artifacts and metrics.
- Operators need evidence-linked totals, segments, exclusions, generated clips, scene cuts, and review decisions that are inspectable and explainable.
- Episode-class assets are the only inputs that can contribute to canonical episode, season, and show rollups.
- Supplementary videos still need review and publish semantics for internal reference, but must never contaminate canonical episode rollups.
- Phase 4 builds on the retained backend runtime from Phase 3; it does not remove the donor rollback envs yet.
- The workflow stays admin-first and operator-reviewable. Human adjudication remains part of the contract.

### the agent's Discretion
- Exact backend service boundaries for reviewed totals, publication snapshots, and lineage helpers.
- Whether review overlays are stored as additional `ml.screentime_review_state` kinds, a dedicated service layer, or both.
- Exact app-level component/test split for the cast screentime page.
- Whether the legacy `/admin/screenalytics` entry point should be redirected, linked forward, or left as legacy-only with explicit cutover messaging.

### Deferred Ideas (OUT OF SCOPE)
- Final removal of `SCREENALYTICS_API_URL` and `SCREENALYTICS_SERVICE_TOKEN` belongs to Phase 5.
- Richer heuristic quality work for title cards, confessionals, flashbacks, or montage-heavy cuts is not Phase 4 work.
- Public productization of screentime metrics is still out of scope.

</user_constraints>

<research_summary>
## Summary

Phase 4 is not starting from zero. The current repo already has an early retained review and publication surface in `TRR-Backend` and a sizable admin page in `TRR-APP`. The backend exposes run detail, segments, evidence, artifact reads, excluded sections, review-status transitions, publish-history, published rollups, and decision endpoints for cast suggestions and unknown-review queues. The app already proxies the screentime admin API and renders a dedicated `/admin/cast-screentime` page with publish history, rollups, evidence, suggestions, unknown-review state, and clip generation controls.

The gap is that the current publication contract is still too thin for the Phase 4 roadmap goal. Today the publish path snapshots the run leaderboard directly and treats suggestion or unknown-review decisions as future-rerun guidance only. That means the repo does not yet have one explicit backend-owned reviewed-results layer that can regenerate approved totals and publication rollups from immutable artifacts plus mutable review state. Supplementary assets are also currently blocked from publishing entirely, which conflicts with the Phase 4 requirement that they be publishable for internal reference without affecting canonical episode rollups.

The strongest recommendation is a three-part cutover:
1. Finish the backend review-state contract so operator adjudication is explicit, separate from immutable execution facts, and able to produce reviewed totals without mutating raw run artifacts.
2. Split publication semantics into canonical episode publications versus supplementary internal publications, with rollups sourced only from eligible episode publications.
3. Harden `TRR-APP` as the sole operator surface by wiring the page to the canonical backend review/publication contract and adding targeted UI and proxy coverage.

**Primary recommendation:** Treat Phase 4 as a canonicalization phase, not a net-new UI phase. Reuse the current backend routes and app page where possible, but add the missing reviewed-results and publication lineage layer so operators are acting on canonical backend state rather than thin snapshots of raw run output.
</research_summary>

<standard_stack>
## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| FastAPI | Repo-pinned in `TRR-Backend` | Canonical admin API and review/publication routes | Existing retained control plane already owns screentime state |
| PostgreSQL + Supabase migrations | Repo-pinned | Review state, publication lineage, and rollups | `ml.*` remains the source of truth |
| Next.js App Router + React 19 | Repo-pinned in `TRR-APP` | Sole operator-facing surface | Existing `/admin/cast-screentime` page already covers most of the flow |
| Vitest + Testing Library | Repo-pinned in `TRR-APP` | Route and page behavior coverage | Current app already uses Vitest for screentime proxy and state helpers |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Pytest + FastAPI TestClient | Repo-pinned | Backend route and repository contract verification | Required for review/publication cutover coverage |
| Ruff | Repo-pinned | Lint and formatting checks | Phase-scoped backend validation |
| Existing retained screentime repositories | Current repo state | Canonical persistence helpers | Use instead of bespoke SQL in new route logic |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Reviewed totals service over immutable artifacts + review overlays | Mutate run leaderboard rows directly during review | Violates Phase 4 immutability contract |
| Supplementary publication records separated from canonical rollups | Keep blocking supplementary publish forever | Fails `REVW-04` and hides useful internal-reference lineage |
| Hardening existing `/admin/cast-screentime` page | Building a second operator page or moving work back to `/screenalytics` | Creates admin drift and fails `ADMIN-01` |

</standard_stack>

<architecture_patterns>
## Architecture Patterns

### Pattern 1: Immutable run facts plus mutable review overlays
**What:** Keep raw segments, evidence, exclusions, and person metrics as immutable run outputs while storing operator review choices in separate review-state rows and deriving reviewed totals from both layers.
**When to use:** When review must be audit-friendly and publication must not rewrite historical execution outputs.
**Example direction:**
```python
review_summary = retained_cast_screentime_review.build_review_summary(run_id)
reviewed_totals = retained_cast_screentime_review.build_reviewed_leaderboard(run_id)
```

### Pattern 2: Dual publication classes
**What:** Distinguish canonical episode publications from supplementary internal publications at the backend contract level.
**When to use:** When some reviewed assets should be publishable for reference but never enter canonical show or season rollups.
**Example direction:**
```python
publication_mode = "canonical_episode" if media_type == "episode" else "supplementary_reference"
```

### Pattern 3: App-first operator cutover with stable proxy seam
**What:** Keep the current app proxy route and admin page, but align them to one canonical backend response contract and add app tests for the whole operator workflow.
**When to use:** When the app already has a credible surface and the remaining risk is contract drift, not page absence.
**Example direction:**
```tsx
const reviewSummary = await fetchAdminWithAuth(`/api/admin/trr-api/cast-screentime/runs/${runId}/review-summary`);
```

### Anti-Patterns to Avoid
- **Using publication snapshots as the only reviewed truth:** It hides whether totals came from immutable run output or reviewed overlays.
- **Allowing supplementary assets into canonical rollups via loose filters:** It breaks one of the phase’s core guarantees.
- **Leaving the app page untested while claiming operator cutover:** Phase 4 is explicitly about the app as the sole admin surface.

</architecture_patterns>

<dont_hand_roll>
## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Review-state persistence | New ad hoc tables or JSON-only blobs | Existing `ml.screentime_review_state` contract extended intentionally | Keeps lineage unified and queryable |
| Publication rollups | UI-only aggregation from page-loaded rows | Backend-owned rollup endpoints and reviewed publication service | Keeps canonical totals deterministic |
| App data transport | New bespoke app-to-backend auth path | Existing `/api/admin/trr-api/cast-screentime/[...path]` proxy | Shared internal-admin auth is already solved |
| Run output edits | Overwriting raw segments/evidence during review | Separate review overlay plus derived reviewed leaderboard | Preserves auditability |

</dont_hand_roll>

<common_pitfalls>
## Common Pitfalls

### Pitfall 1: Treating current publish snapshots as the final reviewed contract
**What goes wrong:** The system can publish, but cannot explain how operator review changed totals or regenerate them later.
**How to avoid:** Add a backend-owned reviewed-results layer and make publications depend on it, not just raw run metrics.

### Pitfall 2: Forgetting supplementary publication semantics
**What goes wrong:** Trailers and extras remain reviewable but have no publication lineage, or worse, accidentally enter canonical rollups.
**How to avoid:** Add explicit supplementary-reference publication handling and keep rollup filters episode-only.

### Pitfall 3: Assuming the existing app page equals finished admin cutover
**What goes wrong:** The UI exists, but contract drift or missing tests make it unreliable as the sole operator surface.
**How to avoid:** Add route, state, and page-level tests tied to canonical backend review/publication behavior.

</common_pitfalls>

<code_examples>
## Code Examples

### Existing backend review/publication seam already present
```python
@router.post("/admin/cast-screentime/runs/{run_id}/review-status")
def set_review_status(...): ...

@router.post("/admin/cast-screentime/runs/{run_id}/publish")
def publish_run(...): ...

@router.get("/admin/cast-screentime/runs/{run_id}/decision-state")
def get_decision_state(...): ...
```

### Existing app operator surface already present
```tsx
const [publishHistory, setPublishHistory] = useState<PublishVersionEntry[]>([]);
const [excludedSections, setExcludedSections] = useState<ExcludedSectionEntry[]>([]);
const [suggestionDecisions, setSuggestionDecisions] = useState<SuggestionDecisionEntry[]>([]);
```

### Existing proxy seam to preserve
```ts
const backendPath = `/admin/cast-screentime/${path.join("/")}${request.nextUrl.search}`;
const backendUrl = getBackendApiUrl(backendPath);
```

</code_examples>

<open_questions>
## Open Questions

1. **Should reviewed totals be materialized at publish time only, or also exposed before publish as a review-summary preview?**
   - Recommendation: expose them before publish so operators can verify the effect of review decisions prior to publication.

2. **Should supplementary publication reuse `ml.screentime_publications` with a mode field, or use a parallel publication table?**
   - Recommendation: prefer one publication contract with an explicit publication mode unless schema constraints make that unsafe.

3. **Should `/admin/screenalytics` remain as a legacy launcher after Phase 4?**
   - Recommendation: preserve it only as a legacy entry point with forward guidance, not as the primary operator workflow.

</open_questions>

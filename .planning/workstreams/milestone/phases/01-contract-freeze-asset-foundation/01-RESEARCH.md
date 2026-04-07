# Phase 1: Contract Freeze & Asset Foundation - Research

**Researched:** 2026-04-02
**Domain:** Backend-owned screentime intake contract freeze and legacy asset migration
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- `ml.analysis_media_upload_sessions` and `ml.analysis_media_assets` are the source of truth for Phase 1 screentime intake and asset identity across direct upload, `youtube_url`, `external_url`, and `social_youtube_row`.
- Admin intake route paths stay stable in Phase 1. The contract is additive and non-breaking.
- Every intake path must return the same canonical asset shape with `media_type`, `media_kind`, `video_class`, `promo_subtype`, `source_import_type`, `source_json`, `metadata`, and `duration_seconds`.
- Episode versus supplementary behavior stays exactly as it works now: episode assets remain publishable candidates, while trailers, clips, teasers, and other supplementary assets remain reviewable analysis inputs but do not enter canonical episode rollups.
- Classification normalization should remain backward-compatible with the existing `video_class` and `promo_subtype` fields while making `media_type` and `media_kind` explicit.
- Legacy `screenalytics.video_assets` rows must remain addressable through an explicit nullable bridge column on `ml.analysis_media_assets`: `legacy_screenalytics_video_asset_id`.
- Phase 1 includes an idempotent asset-only backfill or bridge now, not a "new assets only" cut. Owner linkage, classification, provenance, and object metadata are in scope; legacy runs, review state, publications, and unknown queues are not.
- Canonical backend flows should resolve either the canonical `ml` asset ID or the legacy Screenalytics asset ID to the same retained asset row.
- Phase 1 freezes a backend-owned retained artifact registry for review and publication dependencies, including `shots.json`, `segments.json`, `scenes.json`, `excluded_sections.json`, `person_metrics.json`, `reference_fingerprints.json`, `cast_suggestions.json`, `unknown_review_queues.json`, `title_card_candidates.json`, `title_card_reference_signatures.json`, and `confessional_candidates.json`.
- Artifact key and schema-version ownership should live in backend code rather than scattered string literals.
- Keep the existing dispatch seam untouched in Phase 1. `retained_cast_screentime_dispatch`, `SCREENALYTICS_API_URL`, and `SCREENALYTICS_SERVICE_TOKEN` remain transitional until the runtime port phase.
- `TRR-APP` should remain unchanged unless a backend contract mismatch forces additive typing or payload support. No admin redesign belongs in this phase.

### the agent's Discretion
- Exact repository module layout for the artifact registry.
- Exact backfill SQL structure as long as it remains rerunnable and preserves the canonical bridge semantics.
- Whether app work is skipped entirely if backend parity is already satisfied.

### Deferred Ideas (OUT OF SCOPE)
- DeepFace-backed face-reference registration, search, and verification flows belong to Phase 2.
- Replacing the runtime executor behind `retained_cast_screentime_dispatch` belongs to Phase 3.
- Full review/publication cutover and any TRR-APP workflow redesign belong to Phase 4.
- Final removal of `SCREENALYTICS_API_URL`, `SCREENALYTICS_SERVICE_TOKEN`, and the split runtime belongs to Phase 5.

</user_constraints>

<research_summary>
## Summary

The current repo state already points to the right Phase 1 architecture: the retained backend control plane in `TRR-Backend` owns upload sessions, promoted assets, run records, review state, and publication under `ml.*`, while `screenalytics` is now clearly a transition runtime and donor source. The main remaining Phase 1 job is to make that ownership explicit and stable rather than implicit.

The standard approach for this kind of migration is additive and bridge-first: keep public/admin route shapes stable, add a canonical bridge column for legacy identities, normalize responses at the boundary layer, and freeze artifact keys in one backend-owned registry before larger runtime moves begin. This reduces downstream churn and lets later phases port execution and identity systems without re-breaking intake and review surfaces.

The key recommendation is to treat Phase 1 as a backend contract hardening and validation phase, not a rewrite. That means one migration for legacy asset bridge semantics, one backend registry for retained artifacts, one canonical resolution path in the repository/router layer, and only additive TRR-APP changes if parity checks prove they are necessary.

**Primary recommendation:** Finish Phase 1 by formalizing the existing retained backend work into one validated contract slice, then carry all runtime replacement and DeepFace behavior changes into later phases.
</research_summary>

<standard_stack>
## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| FastAPI | Repo-pinned in `TRR-Backend` | Stable admin route surface and response normalization | Already owns the retained control plane and admin contracts |
| PostgreSQL + Supabase migrations | Repo-pinned | Additive schema evolution and bridge/backfill logic | Canonical schema source already lives in `TRR-Backend/supabase/migrations` |
| Pytest + TestClient | Repo-pinned | Route and repository contract verification | Existing screentime backend tests already exercise upload/import/review/publication flows |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Ruff | Repo-pinned | Python lint and formatting checks | Phase-scoped file validation before broader repo cleanup |
| Next.js admin surface | Repo-pinned in `TRR-APP` | App parity verification for cast-screentime intake and review flows | Only if backend response/type changes force app updates |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Additive bridge migration | Full replacement/cutover now | Too risky because runtime replacement and identity reset are separate later phases |
| Backend-owned artifact registry | Leave literals in routers/tests | Faster short term, but guarantees artifact drift during runtime porting |
| Canonical route normalization | App-side normalization only | Pushes migration complexity downstream and makes backend contracts ambiguous |

**Installation:**
```bash
# No new stack required for Phase 1
cd TRR-Backend
ruff check .
pytest -q
```
</standard_stack>

<architecture_patterns>
## Architecture Patterns

### Recommended Project Structure
```text
TRR-Backend/
├── api/routers/admin_cast_screentime.py
├── trr_backend/repositories/cast_screentime.py
├── trr_backend/services/cast_screentime_artifacts.py
├── supabase/migrations/
└── docs/ai/local-status/
```

### Pattern 1: Canonical boundary normalization
**What:** Normalize legacy and canonical classification fields at the backend route boundary so every intake path emits one stable asset shape.
**When to use:** When old `video_class`/`promo_subtype` semantics still exist but later phases need `media_type`/`media_kind` to be authoritative.
**Example:**
```python
media = _normalize_media_classification(
    media_type=str(payload.get("media_type") or "").strip() or None,
    media_kind=str(payload.get("media_kind") or "").strip() or None,
    video_class=str(payload.get("video_class") or "").strip() or None,
    promo_subtype=str(payload.get("promo_subtype") or "").strip() or None,
)
```

### Pattern 2: Additive bridge migration
**What:** Add a nullable bridge column and backfill legacy rows into the new canonical table without mutating unrelated review or runtime state.
**When to use:** When identity continuity matters across a multi-phase migration and later systems still need legacy references to resolve.
**Example:**
```sql
alter table if exists ml.analysis_media_assets
  add column if not exists legacy_screenalytics_video_asset_id uuid null;

create unique index if not exists ml_analysis_media_assets_legacy_screenalytics_video_asset_uidx
  on ml.analysis_media_assets (legacy_screenalytics_video_asset_id)
  where legacy_screenalytics_video_asset_id is not null;
```

### Anti-Patterns to Avoid
- **Big-bang runtime replacement in Phase 1:** It collapses contract freeze, execution port, and DeepFace reset into one cutover and hides regressions.
- **JSON-only legacy provenance with no explicit bridge field:** It makes canonical lookup ambiguous and forces ad hoc parsing in later phases.
- **Artifact literals spread across routers/tests/services:** It guarantees contract drift when later phases port executor behavior.
</architecture_patterns>

<dont_hand_roll>
## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Legacy asset continuity | Custom JSON-only remapping logic in each route | One bridge column plus repository resolver | Keeps canonical resolution in one place and avoids route drift |
| Artifact contract discovery | Manual recollection of filenames | A backend-owned artifact registry | Artifact lists are already finite and need central ownership |
| App contract compatibility | New parallel admin API just for Phase 1 | Existing stable admin routes | Route churn adds no value during contract freeze |

**Key insight:** Phase 1 should harden the existing retained path, not invent new migration machinery.
</dont_hand_roll>

<common_pitfalls>
## Common Pitfalls

### Pitfall 1: Treating route stability and canonical storage as separate concerns
**What goes wrong:** The backend writes `ml.*`, but routes still leak legacy shapes or path-specific field differences.
**Why it happens:** Teams freeze the database first and postpone response normalization.
**How to avoid:** Normalize returned asset rows in one boundary helper and test each intake source mode against the same expected shape.
**Warning signs:** Upload and import tests assert different response keys for the same asset concept.

### Pitfall 2: Backfilling too much legacy state
**What goes wrong:** The bridge migration starts pulling in runs, reviews, or publication semantics that belong to later phases.
**Why it happens:** It is tempting to make the backfill “complete” in one pass.
**How to avoid:** Keep Phase 1 asset-only. Legacy runs and mutable review/publication state stay untouched.
**Warning signs:** Migration starts writing to `ml.screentime_runs` or review/publication tables.

### Pitfall 3: Letting repo-wide noise block a phase-specific contract freeze
**What goes wrong:** The contract work is correct, but unrelated dirty-tree lint/schema drift obscures phase validation.
**Why it happens:** Large active repos rarely have perfectly clean broad checks during cross-stream work.
**How to avoid:** Keep phase-scoped validation explicit, document repo-wide blockers separately, and do not claim broad green status without evidence.
**Warning signs:** `ruff check .` or schema-doc checks fail in untouched files unrelated to screentime.
</common_pitfalls>

<code_examples>
## Code Examples

Verified patterns from current repo sources:

### Canonical-or-legacy asset resolution
```python
def resolve_video_asset(video_asset_id: str) -> dict[str, Any] | None:
    return get_video_asset(video_asset_id) or get_video_asset_by_legacy_screenalytics_id(video_asset_id)
```

### Artifact registry ownership
```python
ARTIFACT_REGISTRY: dict[str, CastScreentimeArtifact] = {
    artifact.key: artifact
    for artifact in (
        SHOTS,
        SEGMENTS,
        SCENES,
        EXCLUDED_SECTIONS,
        PERSON_METRICS,
        TITLE_CARD_CANDIDATES,
        TITLE_CARD_REFERENCE_SIGNATURES,
        CONFESSIONAL_CANDIDATES,
        CAST_SUGGESTIONS,
        UNKNOWN_REVIEW_QUEUES,
        REFERENCE_FINGERPRINTS,
    )
}
```

### Route-level canonical run launch
```python
video_asset = _resolve_video_asset_or_404(str(video_asset_id))
canonical_video_asset_id = str(video_asset["id"])

snapshot_bundle = cast_screentime.build_candidate_cast_snapshot(
    video_asset_id=canonical_video_asset_id,
    show_id=str(video_asset.get("show_id") or "") or None,
    season_id=str(video_asset.get("season_id") or "") or None,
    episode_id=str(video_asset.get("episode_id") or "") or None,
)
```
</code_examples>

<sota_updates>
## State of the Art (2024-2026)

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Split service owns both intake and execution semantics | Retained backend owns intake, review, and publication contracts first | Current repo migration direction | Lets runtime move later without re-breaking admin contracts |
| Manifest-only or JSON-only migration bookkeeping | Explicit bridge columns and canonical tables | Mature migration practice | Makes later executor/identity ports deterministic |
| Router-owned artifact strings | Registry-owned artifact contract | Standard contract hardening pattern | Enables safe runtime refactors and plan-level verification |

**New tools/patterns to consider:**
- Backend-owned compatibility layers for legacy IDs — useful during phased runtime retirement.
- Phase-scoped validation strategy docs — useful when repo-wide checks are noisy but contractual slices still need evidence.

**Deprecated/outdated:**
- Treating `screenalytics.video_assets` as an active long-term canonical asset source.
- Leaving artifact contract ownership implicit in multiple consumers.
</sota_updates>

<open_questions>
## Open Questions

1. **How much repo-wide validation debt must be burned down before Phase 1 can be marked fully complete?**
   - What we know: The screentime slice validates cleanly, but repo-wide Ruff/schema-doc state is noisy in unrelated files.
   - What's unclear: Whether Phase 1 completion should require broad repo cleanup or only scoped evidence for touched contractual surfaces.
   - Recommendation: Treat broad repo cleanup as separate validation debt unless the uncovered issues directly break the screentime contract.

2. **Should any TRR-APP typing layer be tightened in Phase 1 even if runtime parity already holds?**
   - What we know: Existing app flows already support the required intake modes.
   - What's unclear: Whether stricter canonical type definitions are worth touching now.
   - Recommendation: Leave app no-op unless backend validation proves a contract mismatch.
</open_questions>

<sources>
## Sources

### Primary (HIGH confidence)
- `.planning/PROJECT.md` — project constraints and migration intent
- `.planning/REQUIREMENTS.md` — Phase 1 requirement IDs and acceptance targets
- `.planning/ROADMAP.md` — Phase 1 goal and success criteria
- `.planning/phases/01-contract-freeze-asset-foundation/01-CONTEXT.md` — locked decisions for this phase
- `.planning/codebase/ARCHITECTURE.md` — backend/app/screenalytics ownership boundaries
- `docs/plans/2026-03-22-deepface-integration-plan.md` — overall migration direction for later phases
- `TRR-Backend/docs/cross-collab/TASK24/PLAN.md` — donor/runtime dependency inventory
- `screenalytics/docs/cross-collab/TASK13/PLAN.md` — transition runtime classification
- `TRR-APP/docs/cross-collab/TASK23/PLAN.md` — app-facing parity surface
- `TRR-Backend/api/routers/admin_cast_screentime.py` — retained backend control plane
- `TRR-Backend/trr_backend/repositories/cast_screentime.py` — retained screentime repository layer

### Secondary (MEDIUM confidence)
- `TRR-Backend/docs/ai/local-status/screenalytics-decommission-ledger.md` — retained versus retiring boundary notes
- `.planning/codebase/CONCERNS.md` — repo fragility and validation-noise context

### Tertiary (LOW confidence - needs validation)
- None
</sources>

## Validation Architecture

- **Framework:** Pytest + FastAPI `TestClient` for route contracts, Ruff for phase-scoped lint/format enforcement, additive migration review via SQL diff/read.
- **Quick verification loop:** `cd TRR-Backend && pytest -q tests/api/test_admin_cast_screentime.py`
- **Phase-scoped full verification loop:** `cd TRR-Backend && ruff check api/routers/admin_cast_screentime.py tests/api/test_admin_cast_screentime.py trr_backend/services/cast_screentime_artifacts.py && ruff format --check api/routers/admin_cast_screentime.py tests/api/test_admin_cast_screentime.py trr_backend/services/cast_screentime_artifacts.py && pytest -q tests/api/test_admin_cast_screentime.py`
- **Manual review points:** Confirm migration SQL only touches asset bridge semantics, confirm app parity is no-op unless contract mismatch appears, and keep repo-wide drift explicitly separated from phase-slice evidence.

<metadata>
## Metadata

**Research scope:**
- Core technology: retained backend screentime contract freeze
- Ecosystem: FastAPI, PostgreSQL migrations, backend/admin route contracts
- Patterns: bridge migration, canonical normalization, artifact registry ownership
- Pitfalls: scope creep, legacy over-backfill, repo-wide validation noise

**Confidence breakdown:**
- Standard stack: HIGH - already established in the workspace and active backend code
- Architecture: HIGH - phase boundary and repo ownership are explicit in current docs and code
- Pitfalls: HIGH - validated against current repo state and recent implementation work
- Code examples: HIGH - taken from repo-local code paths

**Research date:** 2026-04-02
**Valid until:** 2026-05-02
</metadata>

---

*Phase: 01-contract-freeze-asset-foundation*
*Research completed: 2026-04-02*
*Ready for planning: yes*

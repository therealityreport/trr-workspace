# Phase 1: Contract Freeze & Asset Foundation - Context

**Gathered:** 2026-04-02
**Status:** Ready for planning

<domain>
## Phase Boundary

Freeze the canonical screentime intake, asset, and retained artifact contracts in `TRR-Backend` so future migration phases can preserve stable `ml.*` ownership while the standalone `screenalytics` runtime remains temporarily in place.

</domain>

<decisions>
## Implementation Decisions

### Canonical asset ownership
- **D-01:** `ml.analysis_media_upload_sessions` and `ml.analysis_media_assets` are the source of truth for Phase 1 screentime intake and asset identity across direct upload, `youtube_url`, `external_url`, and `social_youtube_row`.
- **D-02:** Admin intake route paths stay stable in Phase 1. The contract is additive and non-breaking.
- **D-03:** Every intake path must return the same canonical asset shape with `media_type`, `media_kind`, `video_class`, `promo_subtype`, `source_import_type`, `source_json`, `metadata`, and `duration_seconds`.

### Classification and publication boundary
- **D-04:** Episode versus supplementary behavior stays exactly as it works now: episode assets remain publishable candidates, while trailers, clips, teasers, and other supplementary assets remain reviewable analysis inputs but do not enter canonical episode rollups.
- **D-05:** Classification normalization should remain backward-compatible with the existing `video_class` and `promo_subtype` fields while making `media_type` and `media_kind` explicit.

### Legacy asset bridge
- **D-06:** Legacy `screenalytics.video_assets` rows must remain addressable through an explicit nullable bridge column on `ml.analysis_media_assets`: `legacy_screenalytics_video_asset_id`.
- **D-07:** Phase 1 includes an idempotent asset-only backfill or bridge now, not a "new assets only" cut. Owner linkage, classification, provenance, and object metadata are in scope; legacy runs, review state, publications, and unknown queues are not.
- **D-08:** Canonical backend flows should resolve either the canonical `ml` asset ID or the legacy Screenalytics asset ID to the same retained asset row.

### Artifact contract freeze
- **D-09:** Phase 1 freezes a backend-owned retained artifact registry for review and publication dependencies, including `shots.json`, `segments.json`, `scenes.json`, `excluded_sections.json`, `person_metrics.json`, `reference_fingerprints.json`, `cast_suggestions.json`, `unknown_review_queues.json`, `title_card_candidates.json`, `title_card_reference_signatures.json`, and `confessional_candidates.json`.
- **D-10:** Artifact key and schema-version ownership should live in backend code rather than scattered string literals.

### Migration boundary
- **D-11:** Keep the existing dispatch seam untouched in Phase 1. `retained_cast_screentime_dispatch`, `SCREENALYTICS_API_URL`, and `SCREENALYTICS_SERVICE_TOKEN` remain transitional until the runtime port phase.
- **D-12:** `TRR-APP` should remain unchanged unless a backend contract mismatch forces additive typing or payload support. No admin redesign belongs in this phase.

### the agent's Discretion
- Exact repository module layout for the artifact registry.
- Exact backfill SQL structure as long as it remains rerunnable and preserves the canonical bridge semantics.
- Whether app work is skipped entirely if backend parity is already satisfied.

</decisions>

<specifics>
## Specific Ideas

- The system is admin-first and operator-reviewable; trust comes from scenes, cuts, segments, exclusions, evidence frames, and generated clips, not only totals.
- This is a backend-first migration, not a greenfield rewrite.
- The user explicitly wants a full DeepFace reset overall, but Phase 1 is contract and asset groundwork only.
- The user explicitly wants direct imports supported alongside uploads in v1.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Product and migration intent
- `.planning/PROJECT.md` — Project vision, migration constraints, and user-locked principles for the screentime reset.
- `.planning/REQUIREMENTS.md` — Phase 1 requirement mapping for `INTK-01` through `INTK-04` and `MIGR-01` through `MIGR-02`.
- `.planning/ROADMAP.md` — Phase 1 goal, dependency ordering, and success criteria.

### DeepFace and donor transition
- `docs/plans/2026-03-22-deepface-integration-plan.md` — Target direction for DeepFace-backed registration, search, and verification.
- `screenalytics/docs/cross-collab/TASK13/PLAN.md` — Screenalytics-side donor/runtime transition plan relevant to later phases.
- `screenalytics/docs/cross-collab/TASK13/STATUS.md` — Current donor transition status and retained runtime boundary.
- `TRR-Backend/docs/cross-collab/TASK24/PLAN.md` — Backend donor transition inventory and dependency audit.
- `TRR-APP/docs/cross-collab/TASK23/PLAN.md` — App-side dependency and admin surface transition plan.

### Existing code and contract surfaces
- `.planning/codebase/ARCHITECTURE.md` — Cross-repo ordering and ownership boundaries.
- `.planning/codebase/STRUCTURE.md` — Primary backend/app/screenalytics file locations relevant to this phase.
- `.planning/codebase/CONCERNS.md` — Known fragile screentime and donor areas to avoid destabilizing during contract freeze.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `TRR-Backend/api/routers/admin_cast_screentime.py`: Existing retained control plane for upload, import, run orchestration, review, and publication.
- `TRR-Backend/trr_backend/repositories/cast_screentime.py`: Existing `ml.*` repository layer for upload sessions, assets, runs, artifacts, and publication.
- `TRR-APP/apps/web/src/app/admin/cast-screentime/CastScreentimePageClient.tsx`: Existing admin UI already supports the required upload and import modes.

### Established Patterns
- Backend-first contract changes land before donor or app changes.
- Additive migrations and stable route paths are preferred over disruptive rewrites.
- Retained screentime data already lives under `ml.*`; Phase 1 should harden that contract rather than invent a parallel path.

### Integration Points
- `TRR-Backend/supabase/migrations/` for the bridge column and legacy asset backfill.
- `TRR-Backend/docs/ai/local-status/*.md` and `TRR-Backend/docs/cross-collab/TASK24/STATUS.md` for canonical continuity updates.
- `screenalytics.video_assets` as the temporary legacy source that must resolve into canonical `ml.analysis_media_assets`.

</code_context>

<deferred>
## Deferred Ideas

- DeepFace-backed face-reference registration, search, and verification flows belong to Phase 2.
- Replacing the runtime executor behind `retained_cast_screentime_dispatch` belongs to Phase 3.
- Full review/publication cutover and any TRR-APP workflow redesign belong to Phase 4.
- Final removal of `SCREENALYTICS_API_URL`, `SCREENALYTICS_SERVICE_TOKEN`, and the split runtime belongs to Phase 5.

</deferred>

---

*Phase: 01-contract-freeze-asset-foundation*
*Context gathered: 2026-04-02*

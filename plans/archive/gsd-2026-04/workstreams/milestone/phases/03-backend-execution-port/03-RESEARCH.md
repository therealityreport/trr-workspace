# Phase 3: Backend Execution Port - Research

**Researched:** 2026-04-03
**Domain:** Backend-owned screentime execution port, retained run orchestration, and reversible cutover from donor `screenalytics` runtime
**Confidence:** HIGH

<user_constraints>
## User Constraints (from PROJECT.md, ROADMAP.md, prior phase decisions, and implementation direction)

### Locked Decisions
- `TRR-Backend` is the permanent runtime owner. `screenalytics` is donor code and a temporary execution dependency only.
- Phase 1 already froze `ml.analysis_media_assets` plus the retained artifact registry as the canonical asset and artifact contract.
- Phase 2 already froze the face-reference and embedding contract in `TRR-Backend`, with DeepFace-backed ArcFace-class identity governance under one explicit contract key.
- Phase 3 must replace the standalone execution dependency behind the existing retained dispatch seam. Public admin route paths remain stable.
- The system remains admin-first and operator-reviewable. Accuracy does not need to be fully autonomous; outputs must be inspectable and reproducible.
- A completed run must persist totals plus reviewable scenes, shots, segments, exclusions, evidence frames, unknown or unassigned detections, and generated clips.
- Run configuration must stay auditable. Thresholds, embedding contract, candidate cast snapshot, and execution backend must remain versioned per run.
- Cutover must be reversible. Phase 3 should support parity validation and controlled rollback instead of a one-way runtime swap.
- `TRR-APP` should remain unchanged in this phase unless a backend contract mismatch forces additive proxy or typing work.

### the agent's Discretion
- Exact backend module layout for the executor, orchestration helpers, and clip-generation logic.
- Whether the backend-owned executor writes results directly through repository functions or through an internal service layer shared with callback routes.
- Whether parity validation is implemented as dedicated comparison helpers, golden-run fixtures, or both.
- Exact env/flag names used to choose the donor HTTP adapter versus backend-owned executor.

### Deferred Ideas (OUT OF SCOPE)
- Full review/publication cutover and admin workflow redesign belong to Phase 4.
- Final removal of `SCREENALYTICS_API_URL` and `SCREENALYTICS_SERVICE_TOKEN` belongs to Phase 5.
- Broad non-screentime image-analysis fallback removal is not part of this phase except where screentime execution code directly depends on it.

</user_constraints>

<research_summary>
## Summary

The repo state is favorable for Phase 3 because the retained backend control plane already exists. `TRR-Backend` owns run creation, run state, artifact persistence, segments, evidence, excluded sections, person metrics, publish flows, and internal callback endpoints. The remaining split is the executor itself: `retained_cast_screentime_dispatch.py` still delegates to `screenalytics_cast_screentime.py`, which calls the separate `screenalytics` HTTP runtime guarded by `SCREENALYTICS_API_URL` and `SCREENALYTICS_SERVICE_TOKEN`.

That means Phase 3 does not need to invent a new admin surface or new retained storage model. The main job is to port the donor execution lane from `screenalytics/apps/api/services/cast_screentime.py` into backend-owned runtime services, then switch the existing dispatch seam from donor HTTP to backend-owned execution behind reversible flags. The safest path is to preserve the current backend route and repository contracts, keep the internal callback routes as compatibility shims while donor runtime still exists, and move the actual run orchestration, artifact production, and clip generation into backend-owned modules that operate directly on the retained `ml.*` state and Phase 2 face-reference contract.

The strongest recommendation is a three-part port:
1. Replace the dispatch internals with a flag-controlled executor selection layer.
2. Port run execution and clip generation into backend-owned services that read canonical retained assets and face references, write retained artifacts and metrics, and version run config explicitly.
3. Add parity and failure-state validation so the executor can switch between donor and backend lanes without losing reproducibility or rollback safety.

**Primary recommendation:** Treat Phase 3 as a runtime-port phase, not a control-plane rewrite. Reuse the retained admin routes, retained repositories, and retained callback schema already in `TRR-Backend`, while moving the execution engine and clip generation off the standalone `screenalytics` service.
</research_summary>

<standard_stack>
## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| FastAPI | Repo-pinned in `TRR-Backend` | Existing admin control plane and internal callback routes | Stable retained surface already owns runs and artifacts |
| PostgreSQL + Supabase migrations | Repo-pinned | Canonical run, asset, artifact, and face-reference state | Retained `ml.*` schema already exists and should remain canonical |
| DeepFace + ArcFace-class embeddings | Added in Phase 2 | Runtime identity lookup against backend-owned face references | Phase 3 depends on the frozen Phase 2 contract rather than donor facebank state |
| Object storage + ffmpeg/ffprobe tooling | Existing runtime pattern | Video localization, evidence extraction, and clip generation | Donor runtime already depends on this execution model; backend should reuse it |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Pytest + FastAPI TestClient | Repo-pinned | Route, dispatch, and runtime contract verification | Existing backend testing infrastructure already covers screentime admin surfaces |
| Ruff | Repo-pinned | Lint and formatting checks | Phase-scoped validation for runtime port files |
| Existing donor `screenalytics` runtime code | Current repo state | Port source and parity reference | Use as donor reference, not long-term ownership |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Flag-controlled dispatch seam | Immediate hard switch to backend executor | Too risky because Phase 3 explicitly needs reversible cutover |
| Backend-owned runtime modules using retained repositories | Continue writing through donor HTTP callbacks permanently | Preserves the dependency the migration is trying to eliminate |
| Shared retained service layer for finalization and artifact writes | Duplicate persistence logic inside executor and callback routes | Increases drift risk between donor and backend execution lanes |

**Installation note:** No new product surface is required for planning. Execution will likely need only backend-owned Python modules plus targeted tests because the retained database and DeepFace lane already exist.
</standard_stack>

<architecture_patterns>
## Architecture Patterns

### Recommended Project Structure
```text
TRR-Backend/
├── api/routers/admin_cast_screentime.py
├── trr_backend/services/retained_cast_screentime_dispatch.py
├── trr_backend/services/retained_cast_screentime_runtime.py
├── trr_backend/repositories/cast_screentime.py
├── tests/api/test_admin_cast_screentime.py
├── tests/services/test_retained_cast_screentime_dispatch.py
├── tests/services/test_retained_cast_screentime_runtime.py
└── docs/ai/local-status/
```

### Pattern 1: Stable dispatch seam with executor selection
**What:** Keep `retained_cast_screentime_dispatch` as the single runtime entry point, but make it choose between donor HTTP and backend-owned execution based on explicit config.
**When to use:** When the admin control plane is already stable and the migration needs reversible cutover.
**Example direction:**
```python
def start_run(run_id: str) -> None:
    if _runtime_mode() == "backend":
        retained_cast_screentime_runtime.enqueue_run(run_id)
        return
    screenalytics_cast_screentime.start_run(run_id)
```

### Pattern 2: Shared retained persistence/finalization contract
**What:** Move run finalization, artifact persistence, segment writes, evidence writes, and excluded-section writes behind backend-owned service helpers so both donor callbacks and backend executor can use the same retained write path.
**When to use:** When an existing callback surface already exists and the new executor should preserve identical retained outputs.
**Example direction:**
```python
runtime_payload = retained_cast_screentime_runtime.build_runtime_payload(run_id)
retained_cast_screentime_runtime.persist_completed_run(
    run_id=run_id,
    artifacts=artifacts,
    segments=segments,
    evidence=evidence,
    excluded_sections=excluded_sections,
    person_metrics=person_metrics,
)
```

### Pattern 3: Versioned run manifest snapshots
**What:** Persist a single run manifest or config snapshot that includes candidate cast snapshot, thresholds, artifact schema version, embedding contract key, execution backend, and source asset metadata.
**When to use:** When reproducibility and parity comparison matter as much as successful execution.
**Example direction:**
```python
config_snapshot = {
    "execution_backend": execution_backend,
    "artifact_schema_version": cast_screentime_artifacts.ARTIFACT_SCHEMA_VERSION,
    "embedding_contract_key": ACTIVE_FACE_REFERENCE_CONTRACT,
    "candidate_cast_snapshot": snapshot_bundle,
    "thresholds": runtime_thresholds,
}
```

### Anti-Patterns to Avoid
- **Rebuilding the admin routes during executor porting:** The retained control plane already exists and should remain stable.
- **Writing backend executor outputs through ad hoc SQL not shared with retained repositories:** It creates parity drift between donor and backend lanes.
- **Cutting over clip generation separately from run execution without shared config/versioning:** Operators would see mixed-output semantics inside one run family.
</architecture_patterns>

<dont_hand_roll>
## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Run orchestration API | New public admin endpoints for executor launch | Existing `admin_cast_screentime.py` create-run and dispatch path | The route surface is already correct and tested |
| Result persistence | Fresh bespoke write path inside executor | Existing retained repository functions and internal callback semantics | Keeps donor and backend outputs aligned during cutover |
| Candidate cast and config continuity | Ad hoc runtime-only variables | Existing run snapshot and retained config payload fields | Run reproducibility depends on explicit stored snapshots |
| Parity comparison | Manual eyeballing of runs | Dedicated parity helper/tests against artifact and metric payloads | Phase 3 needs reversible cutover evidence, not only anecdotal confidence |

**Key insight:** The hard part of Phase 3 is not route design. It is controlled ownership transfer of the runtime lane while preserving the retained contracts already frozen in Phases 1 and 2.
</dont_hand_roll>

<common_pitfalls>
## Common Pitfalls

### Pitfall 1: Porting executor logic without preserving retained write semantics
**What goes wrong:** The backend executor “works,” but it writes artifacts, metrics, or status transitions differently from the donor lane.
**Why it happens:** Teams port core analysis code but skip the exact retained persistence path.
**How to avoid:** Route both donor and backend execution lanes through one backend-owned persistence/finalization contract or keep callback compatibility while the donor lane still exists.
**Warning signs:** Artifact payloads differ by key presence, schema version, or run status order between the two runtimes.

### Pitfall 2: Collapsing runtime cutover and runtime retirement into one phase
**What goes wrong:** The backend executor replaces donor runtime abruptly, but rollback is unclear and `SCREENALYTICS_*` dependencies disappear too early.
**Why it happens:** Once local execution works, it is tempting to remove the donor lane immediately.
**How to avoid:** Keep reversible flags and donor adapter support in Phase 3; remove the env dependencies only in Phase 5.
**Warning signs:** The plan deletes `screenalytics_cast_screentime.py` or the env contract before parity evidence exists.

### Pitfall 3: Forgetting clip generation is part of the runtime contract
**What goes wrong:** Main run execution ports successfully, but operators cannot regenerate segment clips or the clip output no longer matches retained segment windows.
**Why it happens:** Clip generation is often treated as an auxiliary feature rather than part of the reviewable artifact contract.
**How to avoid:** Port clip generation as part of the same runtime service family and version the clip-generation inputs with the rest of the run config.
**Warning signs:** `generate_segment_clip` still depends on donor HTTP after the main executor flips to backend mode.
</common_pitfalls>

<code_examples>
## Code Examples

Verified patterns from current repo sources:

### Existing dispatch seam to preserve
```python
def start_run(run_id: str) -> None:
    screenalytics_cast_screentime.start_run(run_id)


def generate_segment_clip(
    run_id: str,
    *,
    segment_id: str | None = None,
    start_seconds: float | None = None,
    end_seconds: float | None = None,
) -> dict[str, Any]:
    return screenalytics_cast_screentime.generate_segment_clip(
        run_id,
        segment_id=segment_id,
        start_seconds=start_seconds,
        end_seconds=end_seconds,
    )
```

### Existing retained callback contract already in backend
```python
@router.post("/internal/screenalytics/cast-screentime/runs/{run_id}:artifacts:upsert")
def internal_upsert_run_artifacts(...): ...


@router.post("/internal/screenalytics/cast-screentime/runs/{run_id}:segments:replace")
def internal_replace_run_segments(...): ...


@router.post("/internal/screenalytics/cast-screentime/runs/{run_id}:finalize")
def internal_finalize_run(...): ...
```

### Existing retained run creation already snapshots backend ownership
```python
run = cast_screentime.create_run(
    video_asset_id=canonical_video_asset_id,
    execution_backend="trr_backend_retained_dispatch",
    candidate_cast_scope=snapshot_bundle["candidate_cast_scope"],
    candidate_cast_json=snapshot_bundle["candidate_cast"],
    run_config_json=run_config_json,
)
retained_cast_screentime_dispatch.start_run(run_id)
```
</code_examples>

<sota_updates>
## State of the Art (2024-2026)

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Standalone CV worker owns control plane plus execution | Control plane freezes first, then execution is ported behind a stable seam | Current migration sequence | Reduces admin churn and makes parity measurable |
| Runtime-specific ephemeral config | Stored run manifests and versioned thresholds/contracts | Modern ML operations practice | Makes historical runs auditable after model/config changes |
| One-way runtime cutovers | Flagged dual-lane or compatibility windows | Mature service migration practice | Improves rollback safety and parity measurement |

**New tools/patterns to consider:**
- Backend-owned parity helpers comparing donor/backend artifact payloads and totals for the same source clip.
- Shared finalization services so internal callbacks remain usable while the backend executor comes online.
- Explicit runtime mode flags so the control plane can change executor ownership without API churn.

**Deprecated/outdated:**
- Treating `screenalytics` HTTP as the permanent runtime dependency for cast-screentime.
- Maintaining clip generation as a donor-only feature after the executor itself moves.
</sota_updates>

<open_questions>
## Open Questions

1. **Should the backend-owned executor run inline, through an existing worker fabric, or through a new backend-managed background queue primitive?**
   - What we know: The admin route must remain asynchronous, and the donor runtime currently uses Celery queue `visual_v2`.
   - What's unclear: Which backend execution primitive best fits existing deployment and operational constraints.
   - Recommendation: Preserve the dispatch seam and design the runtime module so enqueue and execute are separated; choose the backend-native execution primitive during implementation without changing the retained contracts.

2. **Should the internal callback routes remain active after backend executor cutover?**
   - What we know: They already match the retained write contract and are useful while donor HTTP remains a rollback path.
   - What's unclear: Whether backend executor code should call them internally or bypass them for direct repository/service writes.
   - Recommendation: Keep the routes and callback payload contract intact for compatibility, but prefer shared backend services or repositories for in-process writes to avoid unnecessary HTTP indirection.
</open_questions>

<sources>
## Sources

### Primary (HIGH confidence)
- `.planning/PROJECT.md`
- `.planning/REQUIREMENTS.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/research/SUMMARY.md`
- `.planning/phases/01-contract-freeze-asset-foundation/01-01-SUMMARY.md`
- `.planning/phases/01-contract-freeze-asset-foundation/01-VERIFICATION.md`
- `.planning/phases/02-identity-reset-embedding-governance/02-01-SUMMARY.md`
- `.planning/phases/02-identity-reset-embedding-governance/02-VERIFICATION.md`
- `docs/plans/2026-03-22-deepface-integration-plan.md`
- `TRR-Backend/docs/cross-collab/TASK24/PLAN.md`
- `screenalytics/docs/cross-collab/TASK13/PLAN.md`
- `screenalytics/docs/cross-collab/TASK13/STATUS.md`
- `TRR-APP/docs/cross-collab/TASK23/PLAN.md`
- `TRR-Backend/api/routers/admin_cast_screentime.py`
- `TRR-Backend/trr_backend/repositories/cast_screentime.py`
- `TRR-Backend/trr_backend/services/retained_cast_screentime_dispatch.py`
- `TRR-Backend/trr_backend/clients/screenalytics_cast_screentime.py`
- `screenalytics/apps/api/routers/cast_screentime.py`
- `screenalytics/apps/api/tasks_cast_screentime.py`
- `screenalytics/apps/api/services/cast_screentime.py`

### Secondary (MEDIUM confidence)
- `.planning/codebase/ARCHITECTURE.md`
- `.planning/codebase/INTEGRATIONS.md`
- `TRR-Backend/docs/ai/local-status/screenalytics-decommission-ledger.md`
</sources>

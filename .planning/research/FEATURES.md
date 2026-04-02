# Feature Landscape

**Domain:** Internal admin-first cast screentime analysis and DeepFace reset
**Researched:** 2026-04-02

This project is not a generic video AI product. It is an internal operator system replacing an existing transitional runtime, so "table stakes" means two things at once:

1. features operators already rely on in the current TRR flow, and
2. capabilities that modern video-analysis/review systems expose as the normal baseline for reviewable video understanding: timestamped detections, timeline navigation, human review, and job-state visibility.

## Table Stakes

Features operators should expect in v1. Missing any of these means the reset is not actually a trustworthy replacement.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Asset intake for both uploaded and imported video | Brownfield parity already requires direct upload plus remote import, and modern video systems assume ingestion from multiple sources rather than only local files. | Med | Must support full episodes and supplementary assets like trailers, clips, and extras. Internal-only is fine; consumer-facing intake is not needed. |
| Explicit asset typing and ownership metadata | Operators need to know whether a run is for an episode, trailer, or extras asset, and whether it is publishable or standalone. | Med | Required to keep episode metrics canonical while allowing supplementary-video analysis without contaminating official rollups. |
| Run launch, status, progress, history, and stale-run recovery | Long-running video analysis is normally asynchronous and must be inspectable. Official cloud video APIs expose job IDs, progress, and later retrieval rather than synchronous results. | Med | Minimum controls: launch, refresh, load prior run, see stage/progress detail, reconcile stale runs, surface errors. |
| Cast/identity preflight before dispatch | Internal operators need to know whether the facebank and candidate cast are sufficient before spending compute on a run. | Med | This is especially important during the DeepFace reset because facebank quality directly controls review load. |
| Per-person screentime totals at run level | This is the core product output. Without totals by person, the system is not a screentime analyzer. | Med | Include screen time, frame count, confidence summary, and named/unassigned separation. |
| Reviewable segments with timestamps and counted/not-counted state | Current TRR parity already exposes segments, and mainstream video review tools revolve around timestamped timeline units with keyframes/interpolation. | High | Segment rows must show person assignment, assignment source, start/end, and whether the segment contributes to totals. |
| Persisted shot and scene artifacts | Shot and scene boundaries are a standard baseline in video indexing systems and are required to make screentime totals explainable. | High | Scenes should show time range, composition summary, dominant people, and unknown density; shots should remain available as lower-level evidence. |
| Excluded sections with type and provenance | Operators need to see and trust what was removed from analysis and why. | Med | Must persist section type, time range, and detection source. "Hidden exclusion logic" is not acceptable for an admin-first system. |
| Evidence frames and evidence clips tied to run artifacts | Reviewable video systems expose frame previews, keyframes, and evidence media because raw totals alone are not auditable. | Med | Each evidence object should stay linked to segment/scene/run context and retain stable object keys/URLs. |
| Generated clips on demand from segments | For internal review, operators need a fast way to inspect exact or padded context around a segment instead of scrubbing the full asset every time. | Med | Exact clip plus a few fixed contextual durations is enough for v1. |
| Review-state controls on runs | Internal systems need an explicit path from draft output to approved output. | Med | Minimum states: draft/in-review/approved or equivalent. Review state must be separate from execution state. |
| Canonical publish controls for episode-class runs | Operators need one approved episode result to become the canonical version while trailer/extras runs remain standalone. | High | This is a table stake for TRR specifically, not for generic video annotation products. |
| Show/season rollups from approved episode runs | Internal analysis becomes materially more useful once approved episode runs aggregate into show- and season-level leaderboards. | High | Rollups should only consume canonical published episode runs, not trailers/extras. |

## Differentiators

These features materially improve operator throughput and trust, but the system can still exist without them on day one.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Conservative cast suggestions with accept/reject/defer actions | Reduces manual review burden by surfacing likely cast additions without silently rewriting metrics. | High | Strong fit for TRR because cast rosters drift and supplementary videos often feature people outside the approved facebank. |
| Unknown review queues grouped by similarity and escalation level | Gives operators a structured way to resolve unidentified people instead of inspecting isolated misses one by one. | High | This is the clearest admin-first differentiator versus a raw "face search" system. |
| Decision persistence that affects future reruns but not historical run facts | Preserves auditability while still letting the system learn from operator corrections. | High | Operators should be able to say "this decision changes the next canonical rerun, not the already-persisted evidence of the old run." |
| Facebank-guided DeepFace reset workflow | Makes the identity system operationally manageable during migration by centering seeded registration, search, verification, and quality scoring. | High | The differentiator is not "DeepFace" itself; it is making the facebank a reviewable admin workflow instead of a hidden backend index. |
| Specialized review surfaces for flashbacks, title cards, and confessional candidates | Helps operators remove or explain common reality-TV distortions that otherwise corrupt totals. | High | Valuable, but should follow core parity. The current TRR surface already points in this direction. |
| Unified admin surface for publishable episodes and standalone supplementary videos | Most off-the-shelf tools analyze a single asset class. TRR benefits from one control plane that handles episodes and supplementary media with different publishing semantics. | Med | Keep one surface, but preserve clear differences in review and publishing behavior. |
| Exportable review bundle per person or per segment | Makes handoff to researchers/editors easier by packaging totals, linked evidence frames, and generated clips together. | Med | Not required for v1 parity, but useful once operators trust the core outputs. |

## Anti-Features

Features to deliberately exclude from v1.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Public-facing screentime pages or consumer product surfaces | The milestone is explicitly internal admin-first and already has a risky runtime migration underneath it. | Keep all workflows in admin surfaces and publish only internal canonical versions. |
| Fully autonomous "official" metrics with no human review gate | Official docs and current TRR parity both point the other way: modern video systems expose timestamps and evidence, and the project requirement is operator-reviewable output. | Require review status and explicit publish approval for canonical episode outputs. |
| A full generic annotation workforce platform | Labelbox/CVAT-class queue management, benchmarks, consensus, and labeler productivity analytics are overkill for an internal operator tool. | Build a focused admin review queue for screentime-specific decisions only. |
| Frame-perfect manual editing of every detection/track in v1 | That turns the project into a full annotation studio and will derail parity delivery. | Allow run-level decisions, exclusions, seed management, unknown grouping, and reruns instead of universal per-frame editing. |
| Hard dependency on managed cloud face-identification products | Current vendor offerings have policy and lifecycle risk: Azure face-identification features are gated, and AWS people pathing is already deprecated. | Keep identity/search inside the backend-owned DeepFace reset with ArcFace-class compatibility. |
| Real-time/live-stream screentime analysis | Different latency, orchestration, and review constraints; not required by the current admin workflow. | Focus on stored-video batch analysis with strong rerun and review support. |
| Audio/talk-time, transcript QA, or multimodal editorial analytics in v1 | Valuable later, but it expands scope away from the screentime reset and complicates the migration boundary. | Keep v1 on visual screentime artifacts and operator review. |

## Feature Dependencies

```text
Asset intake + asset typing
  -> canonical video asset record
  -> run launch/history/progress

Facebank seed management + cast preflight
  -> reliable identity assignment
  -> cast suggestions / unknown review queues

Shot detection
  -> scene boundaries
  -> segment generation

Segment generation
  -> per-person totals
  -> exclusions
  -> evidence frames
  -> generated clips

Per-run totals + persisted artifacts
  -> review-state transitions
  -> publish canonical version (episodes only)

Approved canonical episode runs
  -> show rollup
  -> season rollup

Operator decisions on suggestions / unknown queues
  -> rerun required
  -> improved future runs without mutating prior run facts
```

## MVP Recommendation

Prioritize:
1. Asset intake, asset typing, and run orchestration for both episodes and supplementary videos.
2. Reviewable screentime output: per-person totals plus persisted scenes, shots, segments, exclusions, evidence, and generated clips.
3. One decision-driven differentiator: unknown review queues plus rerun-required decision persistence.

Defer: flashback/title-card/confessional-specific intelligence. It is high value for trust, but it should follow once core parity, reviewability, and rerun semantics are stable.

## Sources

- Internal project context: `.planning/PROJECT.md` [HIGH]
- Internal structure and parity surface: `.planning/codebase/STRUCTURE.md` [HIGH]
- DeepFace migration direction: `docs/plans/2026-03-22-deepface-integration-plan.md` [HIGH]
- Transitional-runtime and parity references: `screenalytics/docs/cross-collab/TASK13/STATUS.md`, `TRR-APP/docs/cross-collab/TASK23/PLAN.md` [HIGH]
- Current admin UI parity surface: `TRR-APP/apps/web/src/app/admin/cast-screentime/CastScreentimePageClient.tsx` [HIGH]
- Google Cloud Video Intelligence shot change detection: https://cloud.google.com/video-intelligence/docs/feature-shot-change [HIGH]
- Google Cloud Video Intelligence person detection: https://cloud.google.com/video-intelligence/docs/feature-person-detection [HIGH]
- Azure AI Video Indexer scene/shot/keyframe insights: https://learn.microsoft.com/en-us/azure/azure-video-indexer/scene-shot-keyframe-detection-insight [HIGH]
- Azure AI Video Indexer observed people and matched faces: https://learn.microsoft.com/en-us/azure/azure-video-indexer/observed-matched-people-insight [HIGH]
- Azure AI Video Indexer global face grouping: https://learn.microsoft.com/en-us/azure/azure-video-indexer/face-grouping-how-to [HIGH]
- Azure AI Video Indexer limited-access facial features: https://learn.microsoft.com/en-us/azure/azure-video-indexer/limited-access-features [HIGH]
- Amazon Rekognition stored-video face search: https://docs.aws.amazon.com/rekognition/latest/dg/procedure-person-search-videos.html [HIGH]
- Amazon Rekognition stored-video face detection: https://docs.aws.amazon.com/rekognition/latest/dg/faces-sqs-video.html [HIGH]
- Amazon Rekognition people pathing deprecation notice: https://docs.aws.amazon.com/rekognition/latest/dg/persons.html [HIGH]
- Labelbox video editor: https://docs.labelbox.com/docs/video-editor [HIGH]
- Labelbox workflows and review queues: https://docs.labelbox.com/docs/workflows [HIGH]
- Labelbox issues/comments for reviewer feedback: https://docs.labelbox.com/docs/issues-comments [HIGH]
- CVAT track mode basics: https://docs.cvat.ai/docs/annotation/manual-annotation/modes/track-mode-basics/ [HIGH]

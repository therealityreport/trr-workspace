# Phase 7: Workspace Defaults And Script Alignment - Context

**Gathered:** 2026-04-03
**Status:** Ready for planning
**Mode:** Auto-generated (infrastructure phase)

<domain>
## Phase Boundary

Shared workspace scripts, profiles, and diagnostics must match the cloud-first contract frozen in Phase 6. The root default remains `make dev`; Docker-backed local infra stays available only as an explicit opt-in fallback for narrow Screenalytics cases.

</domain>

<decisions>
## Implementation Decisions

### Locked from prior phases

- `make dev` is the preferred no-Docker path for normal workspace development.
- Remote-first validation and cloud-backed development are the baseline contract.
- Docker-backed Screenalytics infra remains available only as explicit fallback.

### Phase 7 discretion

- Align wording, summaries, profile annotations, and help surfaces to the frozen contract.
- Isolate any remaining Screenalytics local-infra assumptions behind explicit fallback language.
- Avoid inventing a new workflow or removing the fallback path entirely.

</decisions>

<code_context>
## Existing Code Insights

- Root `Makefile` already defaults `make dev` to `WORKSPACE_DEV_MODE=cloud`.
- `scripts/dev-workspace.sh`, `scripts/doctor.sh`, `scripts/preflight.sh`, and `scripts/status-workspace.sh` already distinguish `cloud` from `local_docker`, but some remaining output still implies Docker-heavy local infra as a normal peer mode.
- `profiles/default.env` is already cloud-first; compatibility profiles still need clearer labeling so one canonical preferred path is obvious.

</code_context>

<specifics>
## Specific Ideas

- Tighten `make help`, `make down`, and fallback target comments.
- Reword remaining startup/shutdown messages so Docker-only infra is clearly a special case.
- Make profile headers and shared profile intent consistent with one preferred no-Docker path.

</specifics>

<deferred>
## Deferred Ideas

- Do not remove Docker-backed paths in this phase.
- Do not automate remote branch provisioning yet; that belongs to future work.

</deferred>

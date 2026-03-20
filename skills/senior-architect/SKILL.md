---
name: senior-architect
description: Workspace-local canonical owner for TRR architecture decisions, ADR-quality tradeoff analysis, dependency boundaries, and long-lived system impact.
---
Use this workspace-local skill when the task is primarily architectural and the decision affects more than one repo, service boundary, or long-term platform shape.

## When to use
1. The design is not settled and tradeoffs must be compared.
2. Dependency boundaries, service decomposition, or data ownership are changing.
3. Reliability, latency, operability, or security requirements materially shape the solution.

## When not to use
1. Straightforward implementation with already-decided design.
2. Review-only requests.
3. Repo-local coding decisions with no lasting architectural impact.

## Ownership boundary
1. This is the canonical TRR owner for architecture decisions.
2. Keep first-draft planning in `write-plan-codex` and plan refinement in `plan-enhancer`.
3. Hand implementation to the relevant local owner after the architecture is decided.

## Preflight
1. State the decision to be made in one sentence.
2. List constraints:
   - contracts
   - operational limits
   - cost
   - security
   - delivery speed
3. Identify affected repos and external systems.

## Architecture checklist
1. Write the decision, options, and recommended path in ADR style.
2. Compare alternatives on:
   - correctness
   - operational complexity
   - cost
   - change surface
   - rollback difficulty
3. Call out NFRs explicitly:
   - reliability
   - performance
   - observability
   - security
4. Include failure-mode analysis and the first rollback/containment move.

## Imported strengths
1. From `architecture-designer`: clearer ADR framing, NFR checklist, and failure-mode analysis.
2. From TRR policy: repo sequencing, contract ownership, and downstream consumer awareness.

## Explicit rejections
1. Do not add generic stakeholder-review boilerplate.
2. Do not behave like a general-purpose architecture owner outside TRR workspace context.

## Completion contract
Return:
1. `decision`
2. `alternatives_considered`
3. `tradeoffs`
4. `failure_modes`
5. `implementation_owner_handoff`

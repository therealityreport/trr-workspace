# Phase 6: Cloud-First Validation Contract - Research

**Researched:** 2026-04-03
**Domain:** Workspace-level cloud-first validation policy, remote Supabase branch safety, and explicit no-Docker defaults
**Confidence:** HIGH

<user_constraints>
## User Constraints (from PROJECT.md, ROADMAP.md, REQUIREMENTS.md, planted seed, and workspace policy)

### Locked Decisions
- This milestone exists specifically to avoid Docker as the default assumption in this workspace.
- The preferred path must be cloud-first and usable for normal backend and app development without machine-specific container setup.
- Docker is still allowed for narrow fallback cases, but it must be explicit and documented as such.
- Remote database validation must use isolated Supabase branches or disposable targets, not shared persistent environments.
- Phase 6 is a contract-setting phase. It should freeze the recommended workflow and verification boundaries before Phase 7 changes shared scripts and defaults.

### the agent's Discretion
- Which docs become the canonical cloud-first contract surface versus supporting references.
- How much existing Docker language is relabeled now versus deferred to the script/defaults phase.
- Whether the contract note should live primarily in workspace docs, backend docs, or both.
- Which existing examples best demonstrate remote branch validation without implying production blast radius.

### Deferred Ideas (OUT OF SCOPE)
- Removing every Docker-related script or target in the workspace.
- Rewriting all workspace bootstrap and doctor flows in this phase.
- Replacing the Supabase CLI with custom tooling.
- Reopening completed screentime migration work except where it serves as a proof point for no-Docker validation.

</user_constraints>

<research_summary>
## Summary

The workspace already contains the raw ingredients for a no-Docker default, but the contract is not frozen. The planted seed, milestone requirements, and prior screentime work all point in the same direction: use remote Supabase branches or disposable environments when they answer the same validation question as local Docker-backed resets, and reserve Docker for explicitly narrow fallback cases.

Repo inspection shows the current drift is mostly contractual rather than architectural:
1. Workspace docs still advertise `make dev` and `make dev-local` without one clear statement that cloud-first is the preferred path.
2. `TRR-Backend/Makefile` and related docs still steer schema validation toward `supabase db reset --yes`, which implies local Docker-backed Supabase for fresh replay checks.
3. Root scripts and status tooling still expose `local_docker` and Screenalytics-local infra modes prominently, even though many normal workflows no longer need them.
4. The workspace already has evidence that remote branch validation works, including existing notes that use `supabase db push --db-url <branch-db-url> --include-all`.

Phase 6 should therefore define one canonical contract before any script rewrites:
- `make dev` and normal day-to-day development are cloud-first and should not require Docker.
- Migration and schema validation should prefer isolated remote Supabase branches or disposable DB targets.
- Shared production or long-lived databases are never acceptable substitutes for isolated validation.
- Docker-backed flows remain documented only as opt-in fallback for special local-infra cases.

**Primary recommendation:** execute Phase 6 as a docs-and-contract phase with three outcomes:
1. freeze one preferred no-Docker workflow in shared docs,
2. rewrite schema-validation guidance around isolated remote targets,
3. document explicit fallback boundaries so Phase 7 can safely align scripts and defaults to that contract.
</research_summary>

<standard_stack>
## Standard Stack

### Core
| Tool | Purpose | Why Standard Here |
|------|---------|-------------------|
| Supabase branches / disposable DB targets | Isolated remote schema validation | Matches the milestone goal and avoids shared-data blast radius |
| Supabase CLI | Push migrations and inspect branch URLs | Already used in the repo; no need to invent replacement tooling |
| Workspace docs + Makefile help text | Canonical operator/developer contract | Phase 6 is about freezing the contract before changing defaults |

### Supporting
| Tool | Purpose | When to Use |
|------|---------|-------------|
| `scripts/check-workspace-contract.sh` | Catch contract drift in workspace docs/scripts | Use when touching cross-repo workflow docs or script-facing defaults |
| `scripts/env_contract_report.py validate` | Validate env contract documentation stays coherent | Use when env-contract docs or related help text change |
| Existing local-status docs | Continuity and adoption evidence | Use to show remote-first validation is already a real pattern, not a theory |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Freezing remote-first validation now | Change scripts first and explain later | Creates policy drift and makes Phase 7 riskier |
| Remote Supabase branches | Local Docker-backed `supabase db reset` as default | Conflicts with the stated milestone goal and workspace seed |
| Explicit Docker fallback language | Keep Docker references ambiguous | Leaves developers guessing which path is preferred |

</standard_stack>

<architecture_patterns>
## Architecture Patterns

### Pattern 1: Contract first, defaults second
**What:** Define the canonical workflow before rewriting scripts or bootstrap behavior.
**When to use:** When the current problem is ambiguity about the preferred path rather than missing technical capability.
**Example direction:**
```md
Recommended validation path:
1. create isolated remote branch
2. push migrations to branch DB URL
3. run scoped verification against that isolated target
```

### Pattern 2: Capability-based fallback boundaries
**What:** Keep Docker only where it answers a different question than remote validation, such as narrow local infra or legacy sidecar debugging.
**When to use:** When "no Docker" is a preference, not an absolute ban.
**Example direction:**
```md
Use Docker only when you specifically need local Screenalytics-side infra or a fresh local replay that cannot be answered safely by an isolated remote target.
```

### Pattern 3: Shared-database blast-radius guardrails
**What:** State clearly that remote-first validation must never point at production or long-lived shared databases.
**When to use:** Whenever remote validation becomes the preferred path.
**Example direction:**
```md
Only use branch or disposable DB URLs for migration validation. Never run replay or destructive checks against shared persistent environments.
```

### Anti-Patterns to Avoid
- **Treating Docker avoidance as a hidden preference:** it needs to be stated explicitly in the milestone contract.
- **Equating remote-first with production-first:** isolated remote targets are required; shared databases are out of bounds.
- **Changing scripts before freezing the wording:** Phase 7 should implement against a settled contract, not infer it.

</architecture_patterns>

<dont_hand_roll>
## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Remote validation workflow | Custom DB wrapper toolchain | Supabase branches + `supabase db push --db-url ... --include-all` | Existing CLI and prior repo usage already cover the need |
| Workspace contract note | Ad hoc chat guidance only | Shared workspace docs and milestone artifacts | Keeps the preference durable and reviewable |
| Docker fallback policy | Blanket ban or blanket approval | Narrow, capability-based fallback language | Matches user intent and avoids false absolutes |

</dont_hand_roll>

<common_pitfalls>
## Common Pitfalls

### Pitfall 1: Calling remote validation "safe" without naming isolation rules
**What goes wrong:** Developers point destructive validation at the wrong remote database.
**How to avoid:** Every canonical example must say "branch or disposable DB only" and explicitly exclude production/shared persistent DBs.

### Pitfall 2: Freezing too much implementation in the contract phase
**What goes wrong:** Phase 6 starts rewriting scripts and defaults before the team agrees on the preferred wording and fallback boundaries.
**How to avoid:** Keep this phase focused on docs, contract notes, and verification expectations; defer default behavior changes to Phase 7.

### Pitfall 3: Leaving Docker language half-prominent
**What goes wrong:** Even with a no-Docker preference, docs still present Docker-heavy flows as equal defaults.
**How to avoid:** Rewrite the ordering and wording so cloud-first is primary and Docker is explicitly fallback.

</common_pitfalls>

<code_examples>
## Code / Command Examples

### Preferred branch-validation shape
```bash
supabase db push --db-url "$BRANCH_DB_URL" --include-all
```

### Current ambiguous workspace command surface
```md
- make dev
- make dev-local
```

### Desired contract tone
```md
Use `make dev` for the normal cloud-first path.
Use Docker-backed modes only when you intentionally need local infra that remote validation cannot answer.
```

</code_examples>

<open_questions>
## Open Questions

1. **Should Phase 6 update only docs, or also small Makefile/help text wording if that is part of freezing the contract?**
   - Recommendation: allow light wording updates where needed to reflect the contract, but defer behavioral default changes to Phase 7.

2. **Should disposable remote DB guidance live in shared workspace docs or backend docs?**
   - Recommendation: put the canonical contract in shared workspace docs and mirror any backend-specific migration details in `TRR-Backend` docs.

3. **Should Docker fallback examples stay visible in daily-command docs?**
   - Recommendation: yes, but only in an "Additional Commands" or "Fallback" section, never as peer defaults.

</open_questions>

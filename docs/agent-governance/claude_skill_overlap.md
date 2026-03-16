# TRR Skill Overlap and Absorption Map

This report records which overlapping global skills were reviewed, what was absorbed into TRR-local canonical skills, what was explicitly rejected, and the final governance state.

| overlap_skill | absorbed_strengths | rejected_parts | new_canonical_owner | final_status |
|---|---|---|---|---|
| `architecture-designer` | ADR framing, NFR checklist, failure-mode analysis | generic stakeholder-review boilerplate, non-TRR architecture ownership language | `/Users/thomashulihan/Projects/TRR/skills/senior-architect/SKILL.md` | demoted to generic specialist |
| `cloud-architect` | HA/DR prompts, cost/governance/security-by-design prompts | multi-cloud defaulting, broad generic cloud-platform ownership | `/Users/thomashulihan/Projects/TRR/skills/senior-devops/SKILL.md` | demoted to generic specialist |
| `devops-engineer` | deploy gates, rollback/runbook expectations, artifact/release discipline | broad Kubernetes/GitOps assumptions unless task-specific | `/Users/thomashulihan/Projects/TRR/skills/senior-devops/SKILL.md` | demoted to generic specialist |
| `fullstack-guardian` | end-to-end dataflow reasoning, integration failure thinking, security-aware implementation prompts | mandatory generic technical-design step before coding | `/Users/thomashulihan/Projects/TRR/skills/senior-fullstack/SKILL.md` | demoted to generic specialist |
| `monitoring-expert` | observability gaps, alerting prompts, release-readiness checks | broad generic observability ownership outside the actual TRR problem surface | `/Users/thomashulihan/Projects/TRR/skills/senior-devops/SKILL.md`, `/Users/thomashulihan/Projects/TRR/skills/senior-qa/SKILL.md`, `/Users/thomashulihan/Projects/TRR/skills/social-ingestion-reliability/SKILL.md` | demoted to generic specialist |
| `security-reviewer` | auth/input/secrets/infra review checklist | default pentest/SAST workflow ownership | `/Users/thomashulihan/Projects/TRR/skills/code-reviewer/SKILL.md` | demoted to generic specialist |
| `secure-code-guardian` | auth/authz, input-validation, secret-handling, and client-side security prompts | broad parallel security ownership over implementation | `/Users/thomashulihan/Projects/TRR/TRR-Backend/skills/senior-backend/SKILL.md` and `/Users/thomashulihan/Projects/TRR/TRR-APP/skills/senior-frontend/SKILL.md` | demoted to generic specialist |
| `fastapi-expert` | FastAPI/Pydantic/async implementation checks | generic tutorial content and non-TRR API conventions | `/Users/thomashulihan/Projects/TRR/TRR-Backend/skills/senior-backend/SKILL.md` | demoted to generic specialist |
| `nextjs-developer` | App Router, server-component, metadata, loading/error boundary prompts | Vercel-specific deployment assumptions unless task-specific | `/Users/thomashulihan/Projects/TRR/TRR-APP/skills/senior-frontend/SKILL.md` | demoted to generic specialist |
| `test-master` | broader coverage taxonomy, defect/risk reporting, manual verification framing | generic security/performance testing owner sprawl | `/Users/thomashulihan/Projects/TRR/skills/senior-qa/SKILL.md` | demoted to generic specialist |
| `chromedevtools-expert` | deterministic browser-debug and validation cues | top-level ownership for TRR tasks instead of supporting technique usage | `/Users/thomashulihan/Projects/TRR/TRR-APP/skills/senior-frontend/SKILL.md`, `/Users/thomashulihan/Projects/TRR/TRR-APP/skills/figma-frontend-design-engineer/SKILL.md`, `/Users/thomashulihan/Projects/TRR/skills/senior-qa/SKILL.md` | demoted to generic specialist |
| vendored `code-reviewer` | stronger PR-audit vocabulary and refactor-risk prompts | duplicate canonical ownership inside TRR | `/Users/thomashulihan/Projects/TRR/skills/code-reviewer/SKILL.md` | demoted to generic specialist |

## Resulting Routing Rules

1. TRR-coupled ownership belongs to local canonical skills first.
2. Global overlap skills remain installed as specialist references, not canonical owners.
3. Compatibility shims keep legacy prompt names working without preserving duplicate ownership.

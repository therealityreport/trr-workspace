# Codex Skills Governance Matrix

This file records TRR skill ownership after localization.

## Planning Workflow

Before producing any plan in this workspace:
1. Review the skills available for the current scope using this matrix.
2. Choose the minimum skill set needed for:
   - plan writing
   - implementation
3. State the selected skills briefly before the plan.
4. Prefer canonical owners in this order:
   - repo-local
   - workspace-local
   - globally canonical
   - alias or specialist only when no canonical owner fits cleanly
5. Follow the selected skills during plan creation and implementation routing.

## Canonical Workspace-Local Skills

| name | canonical_path | scope | status | shim_path | derived_from | notes |
|---|---|---|---|---|---|---|
| `senior-fullstack` | `/Users/thomashulihan/Projects/TRR/skills/senior-fullstack/SKILL.md` | workspace | canonical | `/Users/thomashulihan/.codex/skills/senior-fullstack/SKILL.md` | `fullstack-guardian` | Canonical owner for TRR cross-repo contract-coupled implementation. |
| `senior-architect` | `/Users/thomashulihan/Projects/TRR/skills/senior-architect/SKILL.md` | workspace | canonical | `/Users/thomashulihan/.codex/skills/senior-architect/SKILL.md` | `architecture-designer` | Canonical owner for TRR architecture, ADR framing, NFRs, and failure-mode analysis. |
| `senior-devops` | `/Users/thomashulihan/Projects/TRR/skills/senior-devops/SKILL.md` | workspace | canonical | `/Users/thomashulihan/.codex/skills/senior-devops/SKILL.md` | `devops-engineer`, `cloud-architect`, `monitoring-expert` | Canonical owner for TRR release hardening, rollback discipline, and observability gates. |
| `senior-qa` | `/Users/thomashulihan/Projects/TRR/skills/senior-qa/SKILL.md` | workspace | canonical | `/Users/thomashulihan/.codex/skills/senior-qa/SKILL.md` | `test-master`, `chromedevtools-expert` | Canonical owner for TRR regression prevention and release verification. |
| `code-reviewer` | `/Users/thomashulihan/Projects/TRR/skills/code-reviewer/SKILL.md` | workspace | canonical | `/Users/thomashulihan/.codex/skills/code-reviewer/SKILL.md` | vendored `code-reviewer`, `security-reviewer` | Canonical owner for TRR review output and post-implementation risk auditing. |
| `skillcreator` | `/Users/thomashulihan/Projects/TRR/skills/skillcreator/SKILL.md` | workspace | canonical | `/Users/thomashulihan/.codex/skills/skillcreator/SKILL.md` | `skillcreator-codex` | Canonical owner for TRR-local skill authoring, dedupe, and governance alignment. |
| `social-ingestion-reliability` | `/Users/thomashulihan/Projects/TRR/skills/social-ingestion-reliability/SKILL.md` | workspace | canonical | `/Users/thomashulihan/.codex/skills/social-ingestion-reliability/SKILL.md` | `monitoring-expert`, `security-reviewer`, `devops-engineer` | Canonical owner for TRR social-ingestion auth, retries, worker, and persistence reliability. |

## Canonical Repo-Local Skills

| name | canonical_path | scope | status | shim_path | derived_from | notes |
|---|---|---|---|---|---|---|
| `senior-backend` | `/Users/thomashulihan/Projects/TRR/TRR-Backend/skills/senior-backend/SKILL.md` | repo-local (`TRR-Backend`) | canonical | `/Users/thomashulihan/.codex/skills/senior-backend/SKILL.md` | `fastapi-expert`, `secure-code-guardian` | Canonical owner for TRR-Backend FastAPI contracts, schema, persistence, and security-sensitive behavior. |
| `database-designer` | `/Users/thomashulihan/Projects/TRR/TRR-Backend/skills/database-designer/SKILL.md` | repo-local (`TRR-Backend`) | specialist | `` | existing repo-local skill | Keep as backend DB design specialist under repo-local governance. |
| `senior-frontend` | `/Users/thomashulihan/Projects/TRR/TRR-APP/skills/senior-frontend/SKILL.md` | repo-local (`TRR-APP`) | canonical | `/Users/thomashulihan/.codex/skills/senior-frontend/SKILL.md` | `nextjs-developer`, `chromedevtools-expert`, `secure-code-guardian` | Canonical owner for TRR-APP Next.js App Router implementation with stable backend contracts. |
| `figma-frontend-design-engineer` | `/Users/thomashulihan/Projects/TRR/TRR-APP/skills/figma-frontend-design-engineer/SKILL.md` | repo-local (`TRR-APP`) | canonical | `/Users/thomashulihan/.codex/skills/figma-frontend-design-engineer/SKILL.md` | `figma-implement-design`, `chromedevtools-expert` | Canonical owner for TRR-APP Figma-driven implementation and parity work. |
| `pipeline-debug` | `/Users/thomashulihan/Projects/TRR/screenalytics/.claude/skills/pipeline-debug/SKILL.md` | repo-local (`screenalytics`) | specialist | `` | existing repo-local skill | screenalytics-specific canonical specialist remains in `.claude/skills/`. |
| `faces-review-ux` | `/Users/thomashulihan/Projects/TRR/screenalytics/.claude/skills/faces-review-ux/SKILL.md` | repo-local (`screenalytics`) | specialist | `` | existing repo-local skill | screenalytics-specific UI specialist remains repo-local. |
| `cluster-quality` | `/Users/thomashulihan/Projects/TRR/screenalytics/.claude/skills/cluster-quality/SKILL.md` | repo-local (`screenalytics`) | specialist | `` | existing repo-local skill | screenalytics-specific ML/data-quality specialist remains repo-local. |
| `storage-health` | `/Users/thomashulihan/Projects/TRR/screenalytics/.claude/skills/storage-health/SKILL.md` | repo-local (`screenalytics`) | specialist | `` | existing repo-local skill | screenalytics-specific storage/runtime specialist remains repo-local. |
| `skillcreator-codex` | `/Users/thomashulihan/Projects/TRR/screenalytics/.claude/skills/skillcreator-codex/SKILL.md` | repo-local (`screenalytics`) | specialist | `` | existing repo-local skill | Keep as screenalytics-local methodology reference; not a TRR workspace canonical owner. |

## Canonical Global Skills Kept In `~/.codex/skills`

| name | canonical_path | scope | status | shim_path | derived_from | notes |
|---|---|---|---|---|---|---|
| `orchestrate-plan-execution` | `/Users/thomashulihan/.codex/skills/orchestrate-plan-execution/SKILL.md` | global | canonical | `` | existing global skill | Mutation-session entrypoint. Explicitly defers planning-only work to `write-plan-codex`. |
| `write-plan-codex` | `/Users/thomashulihan/.codex/skills/write-plan-codex/SKILL.md` | global | canonical | `` | existing global skill | Planning-only owner. Explicitly defers file mutation to `orchestrate-plan-execution`. |
| `tdd-guide` | `/Users/thomashulihan/.codex/skills/tdd-guide/SKILL.md` | global | canonical | `` | existing global skill | Test-first implementation flow remains global. |
| `tech-stack-evaluator` | `/Users/thomashulihan/.codex/skills/tech-stack-evaluator/SKILL.md` | global | canonical | `` | existing global skill | Stack/tool comparison remains global. |
| `chatgpt-apps` | `/Users/thomashulihan/.codex/skills/chatgpt-apps/SKILL.md` | global | canonical | `` | existing global skill | ChatGPT Apps SDK specialist remains global. |
| `figma` | `/Users/thomashulihan/.codex/skills/figma/SKILL.md` | global | canonical | `` | existing global skill | Figma MCP/context/tool workflow owner. |
| `git-feature-implementer` | `/Users/thomashulihan/.codex/skills/git-feature-implementer/SKILL.md` | global | canonical | `/Users/thomashulihan/.codex/skills/git-feature-installer/SKILL.md` | existing global skill | Canonical GitHub-repo feature implementation owner. |
| `.system/skill-creator` | `/Users/thomashulihan/.codex/skills/.system/skill-creator/SKILL.md` | global | canonical | `` | existing system skill | Generic non-TRR skill-authoring owner. |
| `.system/skill-installer` | `/Users/thomashulihan/.codex/skills/.system/skill-installer/SKILL.md` | global | canonical | `` | existing system skill | Generic skill installation owner. |

## Compatibility Shims

| name | canonical_path | scope | status | shim_path | derived_from | notes |
|---|---|---|---|---|---|---|
| `git-feature-installer` | `/Users/thomashulihan/.codex/skills/git-feature-implementer/SKILL.md` | global | alias | `/Users/thomashulihan/.codex/skills/git-feature-installer/SKILL.md` | existing alias | Legacy naming compatibility only. |
| `figma-implement-design` | `/Users/thomashulihan/.codex/skills/figma/SKILL.md` + `/Users/thomashulihan/Projects/TRR/TRR-APP/skills/figma-frontend-design-engineer/SKILL.md` | hybrid | alias | `/Users/thomashulihan/.codex/skills/figma-implement-design/SKILL.md` | existing global skill | Legacy Figma implementation prompt routes to global MCP workflow plus repo-local design owner. |

## Overlap Specialists Demoted From TRR Ownership

| name | canonical_path | scope | status | shim_path | derived_from | notes |
|---|---|---|---|---|---|---|
| vendored `code-reviewer` | `/Users/thomashulihan/.codex/skills/fullstack-dev-skills/fullstack-dev-skills/0.4.9/skills/code-reviewer/SKILL.md` | global | specialist | `` | vendor | No longer canonical for TRR; supporting reference only. |
| `architecture-designer` | `/Users/thomashulihan/.codex/skills/fullstack-dev-skills/fullstack-dev-skills/0.4.9/skills/architecture-designer/SKILL.md` | global | specialist | `` | vendor | Strengths absorbed into workspace-local `senior-architect`. |
| `cloud-architect` | `/Users/thomashulihan/.codex/skills/fullstack-dev-skills/fullstack-dev-skills/0.4.9/skills/cloud-architect/SKILL.md` | global | specialist | `` | vendor | Strengths absorbed into workspace-local `senior-devops`. |
| `devops-engineer` | `/Users/thomashulihan/.codex/skills/fullstack-dev-skills/fullstack-dev-skills/0.4.9/skills/devops-engineer/SKILL.md` | global | specialist | `` | vendor | Strengths absorbed into workspace-local `senior-devops`. |
| `fullstack-guardian` | `/Users/thomashulihan/.codex/skills/fullstack-dev-skills/fullstack-dev-skills/0.4.9/skills/fullstack-guardian/SKILL.md` | global | specialist | `` | vendor | Strengths absorbed into workspace-local `senior-fullstack`. |
| `monitoring-expert` | `/Users/thomashulihan/.codex/skills/fullstack-dev-skills/fullstack-dev-skills/0.4.9/skills/monitoring-expert/SKILL.md` | global | specialist | `` | vendor | Strengths absorbed into `senior-devops`, `senior-qa`, and `social-ingestion-reliability`. |
| `security-reviewer` | `/Users/thomashulihan/.codex/skills/fullstack-dev-skills/fullstack-dev-skills/0.4.9/skills/security-reviewer/SKILL.md` | global | specialist | `` | vendor | Strengths absorbed into workspace-local `code-reviewer`. |
| `secure-code-guardian` | `/Users/thomashulihan/.codex/skills/fullstack-dev-skills/fullstack-dev-skills/0.4.9/skills/secure-code-guardian/SKILL.md` | global | specialist | `` | vendor | Strengths absorbed into repo-local `senior-backend` and `senior-frontend`. |
| `fastapi-expert` | `/Users/thomashulihan/.codex/skills/fullstack-dev-skills/fullstack-dev-skills/0.4.9/skills/fastapi-expert/SKILL.md` | global | specialist | `` | vendor | Strengths absorbed into repo-local `senior-backend`. |
| `nextjs-developer` | `/Users/thomashulihan/.codex/skills/fullstack-dev-skills/fullstack-dev-skills/0.4.9/skills/nextjs-developer/SKILL.md` | global | specialist | `` | vendor | Strengths absorbed into repo-local `senior-frontend`. |
| `test-master` | `/Users/thomashulihan/.codex/skills/fullstack-dev-skills/fullstack-dev-skills/0.4.9/skills/test-master/SKILL.md` | global | specialist | `` | vendor | Strengths absorbed into workspace-local `senior-qa`. |
| `chromedevtools-expert` | `/Users/thomashulihan/.codex/skills/fullstack-dev-skills/fullstack-dev-skills/0.4.9/skills/chromedevtools-expert/SKILL.md` | global | specialist | `` | vendor | Strengths absorbed into repo-local `senior-frontend`, repo-local `figma-frontend-design-engineer`, and workspace-local `senior-qa`. |

## Other Installed Vendored Skills

Other vendored framework, language, and domain skills under `/Users/thomashulihan/.codex/skills/fullstack-dev-skills/fullstack-dev-skills/0.4.9/skills/` remain installed as generic specialists. They are not canonical TRR owners unless explicitly promoted in this matrix.

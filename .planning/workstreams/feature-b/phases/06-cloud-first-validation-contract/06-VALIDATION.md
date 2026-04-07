---
phase: 06
slug: cloud-first-validation-contract
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-04-03
---

# Phase 06 — Validation Strategy

> Per-phase validation contract for freezing the cloud-first, no-Docker-preferred workspace and remote database validation policy.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Primary validation type** | doc/contract consistency + targeted script/doc checks |
| **Workspace contract check** | `bash /Users/thomashulihan/Projects/TRR/scripts/check-workspace-contract.sh` |
| **Env contract check** | `python3 /Users/thomashulihan/Projects/TRR/scripts/env_contract_report.py validate` |
| **Shell syntax check** | `bash -n` on any touched shell scripts |
| **Targeted docs review** | manual consistency pass across workspace and backend docs |
| **Estimated runtime** | ~1-5 minutes depending on touched files |

---

## Sampling Rate

- **After every docs/contract slice:** run the workspace contract check if shared docs or command surfaces changed.
- **After any env-doc or backend validation-guidance change:** run the env contract validator.
- **After any shell-script wording change:** run `bash -n` on the touched scripts.
- **Before `$gsd-verify-work`:** all touched validation commands must pass and the contract wording must consistently present cloud-first as the preferred path.
- **Max feedback latency:** 5 minutes

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 06-01-01 | 01 | 1 | WSDF-01, WSDF-02, WSDF-03 | workspace contract docs | `bash /Users/thomashulihan/Projects/TRR/scripts/check-workspace-contract.sh` | ✅ partial | ⬜ pending |
| 06-01-02 | 01 | 1 | DBVL-01, DBVL-02, DBVL-03 | env and validation-doc consistency | `python3 /Users/thomashulihan/Projects/TRR/scripts/env_contract_report.py validate` | ✅ partial | ⬜ pending |
| 06-01-03 | 01 | 1 | WSDF-02, DBVL-03 | shell/help text integrity | `bash -n /Users/thomashulihan/Projects/TRR/scripts/dev-workspace.sh /Users/thomashulihan/Projects/TRR/scripts/doctor.sh /Users/thomashulihan/Projects/TRR/scripts/preflight.sh /Users/thomashulihan/Projects/TRR/scripts/status-workspace.sh` | ✅ partial | ⬜ pending |
| 06-01-04 | 01 | 1 | WSDF-01, DBVL-01, DBVL-03 | full phase closeout | `bash /Users/thomashulihan/Projects/TRR/scripts/check-workspace-contract.sh && python3 /Users/thomashulihan/Projects/TRR/scripts/env_contract_report.py validate` | ✅ partial | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] A milestone-level requirement set already exists for cloud-first / no-Docker workspace tooling.
- [x] A planted seed already records the user's preference to avoid Docker as the default workspace assumption.
- [x] The repo already contains examples of remote branch validation using `supabase db push --db-url ... --include-all`.
- [ ] Shared docs and command surfaces still need one canonical statement that cloud-first is the preferred path.
- [ ] Backend schema validation guidance still needs to make isolated remote targets the default recommendation rather than local Docker-backed reset.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Shared docs present one preferred workflow | WSDF-01, WSDF-03 | Automation cannot fully judge wording clarity | Read the touched workspace docs in order and confirm cloud-first is primary while Docker is fallback |
| Remote validation guidance protects shared environments | DBVL-01, DBVL-03 | Safety language needs human review | Confirm every canonical example says branch/disposable DB only and excludes production/shared persistent DBs |
| Contract phase did not overreach into Phase 7 behavior changes | WSDF-02 | Automated checks cannot infer milestone boundary discipline | Confirm Phase 6 changes freeze the contract and guidance without silently rewriting all default script behavior |

---

## Validation Sign-Off

- [x] All planned tasks have automated or explicit manual verification coverage
- [x] Validation covers both shared workspace docs and backend validation guidance
- [x] Sampling continuity avoids long unverified stretches
- [x] No watch-mode commands
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

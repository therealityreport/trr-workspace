# Phase 7 Validation

## Must Prove

1. Root help surfaces and defaults describe `make dev` as the canonical cloud-first path.
2. Docker-backed local infra is framed as explicit fallback rather than a normal assumed baseline.
3. Shared profiles and script output reinforce one canonical preferred path without removing fallback behavior.

## Verification Commands

- `bash /Users/thomashulihan/Projects/TRR/scripts/check-workspace-contract.sh`
- `python3 /Users/thomashulihan/Projects/TRR/scripts/env_contract_report.py validate`
- `bash -n /Users/thomashulihan/Projects/TRR/scripts/dev-workspace.sh /Users/thomashulihan/Projects/TRR/scripts/down-screenalytics-infra.sh /Users/thomashulihan/Projects/TRR/scripts/preflight.sh /Users/thomashulihan/Projects/TRR/scripts/doctor.sh /Users/thomashulihan/Projects/TRR/scripts/status-workspace.sh`

## Manual Review

- Confirm `make help` wording clearly separates preferred path from fallback path.
- Confirm profile comments point at one canonical no-Docker workflow.
- Confirm Screenalytics fallback wording does not imply Docker is needed for ordinary backend/app work.

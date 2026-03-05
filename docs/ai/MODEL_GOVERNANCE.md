# TRR Workspace Model Governance

This document tracks workspace-level model governance policy across:
- `TRR-Backend`
- `screenalytics`
- `TRR-APP`

## Wave Policy

1. Keep current production defaults pinned during runtime/toolchain modernization.
2. Evaluate candidate model upgrades in separate, test-backed promotion changes.
3. Keep deprecated alias compatibility (`GEMINI-MODEL`) during this wave with documented removal target (`2026-06-30`).

## Source-of-Truth Docs

- Backend defaults and promotion rules:
  - `/Users/thomashulihan/Projects/TRR/TRR-Backend/docs/ai/MODEL_GOVERNANCE.md`
- screenalytics defaults and promotion rules:
  - `/Users/thomashulihan/Projects/TRR/screenalytics/docs/ai/MODEL_GOVERNANCE.md`
- TRR-APP integration policy:
  - `/Users/thomashulihan/Projects/TRR/TRR-APP/docs/ai/MODEL_GOVERNANCE.md`

## Cross-Repo Promotion Gate

Before changing any default model:
1. Run targeted eval and regression evidence in the owning repo.
2. Verify downstream contract behavior in dependent repos.
3. Document promotion/rollback evidence in each touched repo handoff.

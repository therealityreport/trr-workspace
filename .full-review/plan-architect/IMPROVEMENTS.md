# IMPROVEMENTS applied (maps to refinement asks #1–6)

1. **File-ownership boundaries** → added the Execution Waves & Ownership Matrix; marked single-owner monoliths + the broad-touch W1.3 sanitizer; explicit serialization (A1, A2, A3).
2. **Backend-first + cross-repo credential slice** → static-shared-secret-gate removal is now ONE coordinated slice (backend verify + app/Modal minting) with feature flag + rollback, instead of a loose Phase-2 bullet.
3. **🔒 items strictly human-gated** → Phase 0-B isolated into "Wave 0 (human)", explicitly OUT of the subagent auto-execution set, with prepare-artifact-then-human-applies handoff.
4. **Workstream V as a true gate** → promoted to Gate G0; dependent fixes (notably TRR-APP secret-scan → W1.1) are scheduled only after confirmation.
5. **Per-workstream validation + acceptance + commit boundary** → added concrete commands, acceptance, commit messages, and Modal redeploy flags.
6. **Execution wave plan** → Wave 0 (human) / G0 (verify) / Wave 1 (auto parallel, DEFAULT) / Wave 2 (auto serialized) / Wave 3 (human-scheduled refactors), with the parallel-vs-serial rule (disjoint owned paths only).

**Also:** added sequencing constraint A9 (CI green before branch protection) and A7 (clean tree precondition).

# Memory relation correction and supported rejudgment

Status: **correction documented; stored relationships unresolved**. Follow-up only; no relationship writes performed.

On 2026-10-02, sixteen imported-memory relationships were marked compatible using an insufficient blanket rationale. Fifteen explicitly cite titles/summaries; the first names adjacent topics but still does not establish all body-level claims. This review read the full stored bodies and their dated corrections. It does not re-verify historical deployment, provider, performance or credential claims against current systems.

Repository namespace: `repo-bd7647ac-9b21-48fd-8d34-681437266121`. Record numbers below mean qualified IDs `repo-bd7647ac-9b21-48fd-8d34-681437266121:<number>`; relation IDs use the same namespace prefix when passed to the adapter. All sixteen remain stored as `compatible`/`judged`. The assessments are documented proposals and qualifications, not completed database repairs.

## Individual assessments

### 1. `rel-0b6e24d60fce61f5`

- Records: `repo-bd7647ac-9b21-48fd-8d34-681437266121:10` (ig-comments-deferred-followup-and-auto-auth) and `repo-bd7647ac-9b21-48fd-8d34-681437266121:8` (ig-comment-scraper-scrape-all-remediation-2026-06-29).
- Corrected assessment: **related; temporal changes need review**.
- Reason: The deferred-run note describes the old single-attempt failure and a 100-comment auth gap. The remediation note changes retry/block handling and reduces that gap to 1, while distinguishing a failed deployment from corrected source. Their shared topic does not make all configuration/state claims simultaneously compatible.

### 2. `rel-049dac8247eb4029`

- Records: `repo-bd7647ac-9b21-48fd-8d34-681437266121:13` (instagram-comments-public-pagination) and `repo-bd7647ac-9b21-48fd-8d34-681437266121:8` (ig-comment-scraper-scrape-all-remediation-2026-06-29).
- Corrected assessment: **scoped; temporal changes need review**.
- Reason: The pagination note corrects its own earlier claim that cookies are merely an accelerator, and reports bounded public tails. The remediation note changes per-attempt checkpoint budgets and explicitly retracts an unbounded implementation. Preserve dates, lane and deployment state; do not collapse these into one current guarantee.

### 3. `rel-b07e7e7e189213b0`

- Records: `repo-bd7647ac-9b21-48fd-8d34-681437266121:15` (modal-workspace-pinning-gotcha) and `repo-bd7647ac-9b21-48fd-8d34-681437266121:6` (trr-nested-git-repos).
- Corrected assessment: **compatible within the stated historical scopes**.
- Reason: Nested Git ownership and explicit Modal workspace selection address separate failure modes. Both can apply together; neither establishes the current profile, branch cleanliness or deployed contents.

### 4. `rel-2b48c169a8d3dead`

- Records: `repo-bd7647ac-9b21-48fd-8d34-681437266121:15` (modal-workspace-pinning-gotcha) and `repo-bd7647ac-9b21-48fd-8d34-681437266121:13` (instagram-comments-public-pagination).
- Corrected assessment: **related**.
- Reason: Workspace/profile selection and logged-out comment pagination are different layers. The first does not corroborate the second's throughput or authentication claims; verify each against its own dated evidence.

### 5. `rel-7d038eb27263c130`

- Records: `repo-bd7647ac-9b21-48fd-8d34-681437266121:19` (shadgpt-runtime-pressure-2026-07-02) and `repo-bd7647ac-9b21-48fd-8d34-681437266121:18` (safe-next-build-guard-unsatisfiable-on-macos).
- Corrected assessment: **not_conflict**.
- Reason: The build-guard note explicitly distinguishes its macOS measurement problem from MCP process accumulation and says reaping four MCP trees did not move the guard. These are different causes, not interchangeable remedies.

### 6. `rel-2bbf2ee03de6a381`

- Records: `repo-bd7647ac-9b21-48fd-8d34-681437266121:20` (social-pipeline-liveness-model) and `repo-bd7647ac-9b21-48fd-8d34-681437266121:10` (ig-comments-deferred-followup-and-auto-auth).
- Corrected assessment: **related; liveness chronology unresolved**.
- Reason: Queue scheduling ownership and deferred-comments status reporting are distinct mechanisms. The liveness record contains multiple owner changes/regressions, while the deferred record describes June 23/29 behavior. Compatibility of a particular runtime requires an aligned timestamp and owner.

### 7. `rel-9b6f5776ea5849d1`

- Records: `repo-bd7647ac-9b21-48fd-8d34-681437266121:20` (social-pipeline-liveness-model) and `repo-bd7647ac-9b21-48fd-8d34-681437266121:13` (instagram-comments-public-pagination).
- Corrected assessment: **related**.
- Reason: Scheduler/dispatch liveness and public-relay pagination limits can independently stop progress. Neither record validates the other's current owner, cursor behavior or completion claim; the pagination record contains an explicit later correction.

### 8. `rel-da65bc0c0d306a9f`

- Records: `repo-bd7647ac-9b21-48fd-8d34-681437266121:21` (social-scraper-audit-2026-06-10) and `repo-bd7647ac-9b21-48fd-8d34-681437266121:11` (instagram-auth-refresh-provider-and-chrome136).
- Corrected assessment: **scoped; later constraint qualifies earlier advice**.
- Reason: The June audit says cookie refresh requires closing a real Chrome profile. The August record reports Chrome 136 remote-debugging refusal and profile churn, so closing Chrome alone is not a sufficient refresh procedure. Preserve the later constraint without claiming the full earlier audit is superseded.

### 9. `rel-7b1fe0bc83123ec0`

- Records: `repo-bd7647ac-9b21-48fd-8d34-681437266121:23` (social-worker-pool-env-shadow-gotcha) and `repo-bd7647ac-9b21-48fd-8d34-681437266121:22` (social-show-pages-audit-2026-07-02).
- Corrected assessment: **related**.
- Reason: The environment-shadow record concerns effective worker caps and dispatch cadence. The July audit adds metadata clobbering, state-mutating reads and unrelated app defects. Shared social-pipeline context does not prove those findings are fixed or mutually validating.

### 10. `rel-529efc60e019a214`

- Records: `repo-bd7647ac-9b21-48fd-8d34-681437266121:23` (social-worker-pool-env-shadow-gotcha) and `repo-bd7647ac-9b21-48fd-8d34-681437266121:10` (ig-comments-deferred-followup-and-auto-auth).
- Corrected assessment: **related**.
- Reason: Both describe forced canonical Modal defaults, but deferred auto-auth also depends on a run-config gate. A forced environment value is not proof that a particular run escalated; verify effective config and lane separately.

### 11. `rel-304e3b64c0dff2c3`

- Records: `repo-bd7647ac-9b21-48fd-8d34-681437266121:23` (social-worker-pool-env-shadow-gotcha) and `repo-bd7647ac-9b21-48fd-8d34-681437266121:20` (social-pipeline-liveness-model).
- Corrected assessment: **conflicts_with for the pool-setting instructions; broader relation scoped**.
- Reason: The liveness record recommends changing the media pool setting to 2 and restoring 6. The environment-shadow record says secret values are overwritten by canonical code values and reports an effective cap of 10. Those operational instructions cannot be treated as equivalent for the same runtime; resolve code revision and injection order before using either.

### 12. `rel-d2fca7aa01d04adf`

- Records: `repo-bd7647ac-9b21-48fd-8d34-681437266121:26` (trr-backend-ci-gating-and-test-pollution) and `repo-bd7647ac-9b21-48fd-8d34-681437266121:9` (ig-comment-throughput-2026-06-29).
- Corrected assessment: **compatible for the named historical test-pollution explanation**.
- Reason: The throughput record names an isolated-passing failure caused by runtime-default environment leakage; the CI record describes that same category of cross-test contamination. This supports the specific explanation, not current CI health, rollout readiness or a blanket waiver of failing tests.

### 13. `rel-945f9a265edcb414`

- Records: `repo-bd7647ac-9b21-48fd-8d34-681437266121:26` (trr-backend-ci-gating-and-test-pollution) and `repo-bd7647ac-9b21-48fd-8d34-681437266121:17` (pyright-burndown-2026-08-06).
- Corrected assessment: **scoped by date and claim**.
- Reason: The June CI note describes which jobs block and then-current debt; the August Pyright note reports a later remediation and retained failures. A later clean type-check does not establish changed CI gating or invalidate all older test-isolation observations.

### 14. `rel-ab6857aa4e96abaa`

- Records: `repo-bd7647ac-9b21-48fd-8d34-681437266121:28` (trr-takeover-automation-git) and `repo-bd7647ac-9b21-48fd-8d34-681437266121:12` (instagram-comments-page-blocks-modal-venv).
- Corrected assessment: **compatible for the historical concurrent-edit observation**.
- Reason: Both records describe the same background automation changing comments files and restarting services. The UI record also identifies independent venv, pool and query-shape failures. The automation observation does not explain every UI failure or authorize restarting anything now.

### 15. `rel-d7c5effeb853e94b`

- Records: `repo-bd7647ac-9b21-48fd-8d34-681437266121:28` (trr-takeover-automation-git) and `repo-bd7647ac-9b21-48fd-8d34-681437266121:26` (trr-backend-ci-gating-and-test-pollution).
- Corrected assessment: **scoped by account and date**.
- Reason: The takeover note reports a denied push under hulibrands; the CI note describes use of a different GitHub identity. These are account-scoped claims, not a universal permission state. Neither historical note supplies present authority to publish or bypass checks.

### 16. `rel-628dd54dd2a00902`

- Records: `repo-bd7647ac-9b21-48fd-8d34-681437266121:28` (trr-takeover-automation-git) and `repo-bd7647ac-9b21-48fd-8d34-681437266121:25` (supabase-speed-audit-2026-06-25).
- Corrected assessment: **related**.
- Reason: The automation record concerns concurrent Git changes and publication; the Supabase audit records database/pacing changes and dated measurements. Sharing a project identifier does not verify migration application, deployment identity or current performance.

## Deferred repair

The adapter currently rejects judgment of a non-pending relation. Do not hand-edit SQLite, recreate pairs, or apply blanket compatibility judgments. Implement or adopt a supported rejudgment operation with exact endpoint IDs, expected relation state/revision, preserved audit history and individual rationale. Re-read each endpoint and source evidence before any future change; preserve historical dates and distinguish partial claim conflicts from whole-record supersession. Preview all intended changes, back up under writer exclusion, apply only accepted individual judgments, and read back exact relation state.

Leave the two older pending pairs `rel-49ad6a240ad2b7f6` and `rel-9d0e3c1bf1f9363f` untouched. The three September 5 judged pairs are outside this correction batch.

## Evidence and continuity

Body hashes, endpoint sync IDs and complete pair accounting: `/Users/thomashulihan/Documents/Codex/2026-10-02/aud/evidence/trr-relationship-assessments.json`. Source was the consistent rehearsal database copy, with live relationship state to be rechecked before the planned correction lesson is saved. The lesson and TRR handoff must state that stored relationships remain unresolved.

TRR-APP build: not applicable (documentation and local memory integration only). Backend/API, production SQL and Modal deployment were not changed by this follow-up.

## Implementation evidence — 2026-10-02

Correction lesson `repo-bd7647ac-9b21-48fd-8d34-681437266121:30` revision 2 was verified by installed Project Manager editing and full stored readback. Its three new pending relations were individually reviewed as related; the original sixteen stored judgments and two older pending pairs remain unchanged. Managed Engram 3.0.0 is accepted; this does not add supported rejudgment. Status remains **correction documented; stored relationships unresolved**. Evidence: `/Users/thomashulihan/Documents/Codex/2026-10-02/aud/evidence/live-acceptance.json`.

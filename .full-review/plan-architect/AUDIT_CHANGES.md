# Audit — Changes To Send Back To Codex

Audit target: `.full-review/plan-architect/REVISED_PLAN.md` (BravoTV Instagram Backfill Recovery Revised Plan, generated 2026-06-29).
Audit type: approval-grade, validated against current repo reality (TRR-Backend nested repo). Every verdict below carries `file:line` evidence; the two blockers were re-verified firsthand by the auditor, not only by sub-agents.

## Verdict

**REQUEST CHANGES — do not execute as written.** The plan's directional strategy is sound (recover the existing 2026 comments child run before launching new years; keep posts discovery serialized; gate year-by-year). But two execution-level errors are unsafe against production runtime:

1. **Step 3 runs a mutating recovery framed as read-only diagnosis, and it re-launches comments jobs *before* the approval blocker is cleared** — directly re-tripping the very stop-rule the plan defines.
2. **Step 4 + Step 8's premise that clearing the approval blocker is "configuration-only / no deploy" is false** — the only switch is already forced on at the Modal layer; the residual blocked posts are an intended terminal state, not a toggle.

Fix the two blockers and the high-severity items, then this is approvable.

---

## BLOCKERS (must fix before any execution)

### CHG-01 — Step 3's `recover-stalled` is MUTATING and re-launches comments jobs before Step 4 fixes the blocker
- **Location:** Step 3, lines 99–103 ("If available, also collect Modal/job evidence for only this run: … `make instagram-backfill-recover-stalled RUN_ID=… JSON=1`").
- **Problem:** The target is presented as evidence collection. It is not. By default it runs five mutating repository actions — `recover_stale_running_jobs`, `repair_instagram_canonical_metrics_for_run`, `normalize_instagram_hosted_media_mirror_status_for_run`, `recover_orphaned_instagram_frontier_leases_for_run`, and **`dispatch_due_social_jobs(run_id=…)`** — none suppressed because the plan passes no `SKIP_*` flags. Dispatch is run-scoped, has **no approval gate** (the blocker is enforced only at job *runtime*, `retryable=False`), and for a comments run it re-launches comments shards. So Step 3 relaunches approval-blocked comments work *before* Step 4 clears it — contradicting Step 3's own line 107 ("do not relaunch more comments jobs"), Step 5's "Only after Step 4 clears" gate, and the Stop Rules.
- **Evidence (verified firsthand):** `Makefile:234-251` (dispatch runs unless `SKIP_DISPATCH=1`; all steps default-on); `TRR-Backend/scripts/socials/instagram/recover_stalled_backfill.py:74-135` (each phase guarded only by `if not args.skip_*`; dispatch at the tail); `dispatch_runtime.py:439/458` and `social_season_analytics_impl.py:43129-43147` (dispatch selects `queued/pending/retrying` for the run with no approval check; calls `recover_failed_instagram_comments_capacity_jobs`); raise site `comments_scrapling/job_runner.py:5133-5134` (`retryable=False`).
- **Change:** Make Step 3 genuinely read-only. Either **drop** the recover-stalled call and use only `make instagram-backfill-progress` for evidence, **or** call it fully skipped:
  ```bash
  RUN_ID=4f4160a4-2287-42af-8f47-27345b1c018f JSON=1 \
    SKIP_RECOVER=1 SKIP_REPAIR=1 SKIP_MEDIA_NORMALIZE=1 SKIP_FRONTIER_RECOVER=1 SKIP_DISPATCH=1 \
    make instagram-backfill-recover-stalled
  ```
  Add a one-line warning: "`instagram-backfill-recover-stalled` is a MUTATING recover+dispatch target; it relaunches comments jobs and must not run with dispatch enabled while `instagram_comments_public_requires_approval` is the active blocker." Move the only dispatch-enabled pass to Step 5 (after Step 4), where it already belongs.

> **⚠ PARTIALLY SUPERSEDED by Correction C-1 (appended below).** CHG-02's claim that the residual blocked posts are *small, sub-MIN_GAP, by-design terminal* is **wrong**. Live + empirical verification (run `4f4160a4`) shows they are large posts (150–647 comments) hit by a transient zero-result public fetch, with auto-auth escalation un-armed for this run. The deploy-vs-config reasoning below still holds; the "accept as terminal" framing does not. Read C-1.

### CHG-02 — Step 4 + Step 8: clearing the approval blocker is NOT "configuration-only / no deploy"
- **Location:** Step 4 ("Clear The Approval Blocker"); Step 8 ("If Step 4 is configuration-only, no backend deploy is needed"); Current Decision framing of the blocker as approval/config only.
- **Problem:** Step 4 tells the operator to "find the smallest existing config path / approval switch." That switch is **already on, by design**, on the Modal fleet — so there is nothing to flip. The residual `instagram_comments_public_requires_approval` cases are posts with `expected_count < MIN_GAP (100)` that `_select_auto_auth_fallback_targets` deliberately refuses to auth-escalate. Clearing them is **not** a no-op config flip; it requires one of: (a) lower `SOCIAL_INSTAGRAM_COMMENTS_AUTO_AUTH_FALLBACK_MIN_GAP` (a Modal env/secret change — and changing the baked default needs a redeploy), (b) record those targets as explicitly terminal with a reason, or (c) a code/policy change at the raise site. Also: Step 4's grep terms (`…requires_approval|public_requires_approval|comments_auth_validation_mode|comments_load_strategy|public_relay`) **do not include the real gate symbols**, so the grep will not surface the switch.
- **Evidence (verified firsthand):** `trr_backend/modal_jobs.py:226` (`_CANONICAL_MODAL_RUNTIME_DEFAULTS`), `:301` (`"SOCIAL_INSTAGRAM_COMMENTS_AUTO_AUTH_FALLBACK": "1"` with comment "MIN_GAP keeps auth/proxy cost bounded to high-value posts"), `:568-570` (`os.environ[key] = value`, unconditional overwrite), `:629` (injected at import). Gate: `comments_scrapling/job_runner.py:3008` (`auto_auth_fallback` config default **False**), `:2996` (`MIN_GAP` default 100), `:3022` (`if expected_count >= min_gap`), raise at `:5133-5134`. The only in-code escape is `_enqueue_auto_auth_fallback_targets` (`:3027-3049`) which re-enqueues on the **authenticated** `instagram_comments_endpoint_cursor` lane — i.e. the auth/proxy fallback Step 4 says to avoid.
- **Change:** Rewrite Step 4 and Step 8 to drop the "config-only / no-deploy" assumption. Replace Step 4's grep with `rg -n "auto_auth_fallback|AUTO_AUTH_FALLBACK|min_gap|MIN_GAP|comments_public_mode_from_config"`. State the real decision explicitly: *"`SOCIAL_INSTAGRAM_COMMENTS_AUTO_AUTH_FALLBACK` is already `1` on the fleet (`modal_jobs.py:301`); residual `requires_approval` posts are below `MIN_GAP=100` and intended-terminal. Choose: (1) lower `SOCIAL_INSTAGRAM_COMMENTS_AUTO_AUTH_FALLBACK_MIN_GAP` (Modal env change; redeploy if the baked default must change) — note this permits auth/proxy escalation, reconcile with the public-first policy; (2) record the blocked targets as terminal with an enumerated reason; or (3) a code/policy change at `job_runner.py:5090-5154`. The no-deploy path applies only if you accept the blocked targets as terminal."* Also reconcile the internal conflict: Step 4 cannot be both "config-only" **and** "do not fall back to auth/proxy," because the only existing auto-clear path *is* auth fallback.

---

## HIGH

### CHG-03 — Step 5 expected result "No `instagram_comments_public_requires_approval`" is unachievable by recover-stalled alone
- **Location:** Step 5, "Expected result" (lines 140–146).
- **Problem:** `recover-stalled` re-dispatches with the **same stored config**; a re-dispatched public job hits the same gate and re-raises the same non-retryable error for any sub-MIN_GAP target. The pass cannot satisfy "No `…requires_approval`" unless Step 4 actually changed escalation/MIN_GAP or the targets were marked terminal.
- **Evidence:** `recover_stalled_backfill.py` has no approval handling; raise recurs at `job_runner.py:3008 + 5124-5134`.
- **Change:** Reword the expected result: "recover-stalled cannot clear `…requires_approval` by itself; after it runs, the same blocker recurs for any target below `MIN_GAP` unless Step 4 changed escalation or those targets were marked terminal. A recurring approval error here is expected, not a failed recovery — route back to the Step 4 escalate-or-accept decision."

### CHG-04 — Step 5's stale-running-job recovery is hardcoded to the POSTS stage; it will not terminalize the stuck COMMENTS shard
- **Location:** Step 3 interpretation (line 108–109) and Step 5 expected result ("No stale `running` comments jobs", line 143).
- **Problem:** `recover_stale_running_jobs` is called with `stage=SHARED_ACCOUNT_POSTS_STAGE` ("shared_account_posts"), but the blocked child run's stuck job is stage `comments_scrapling`. So the named "recover stale running job" step never touches the comments shard. The in-dispatch helpers don't cover it either (they target unclaimed / dispatch-blocked jobs, not a claimed stale-heartbeat comments shard). A single pass will likely leave `active_jobs=1` as `running`.
- **Evidence:** `recover_stalled_backfill.py:77-82` (hardcoded posts stage); `social_season_analytics_impl.py:245` (`SHARED_ACCOUNT_POSTS_STAGE='shared_account_posts'`), `:239` (comments stage); `recover_stale_running_jobs` filters on `coalesce(config->>'stage',…)=stage` (`impl.py:14147-14150`); `dispatch_runtime.py:319-320` (unclaimed-only).
- **Change:** In Step 5 add: "recover-stalled's stale-running recovery is scoped to the posts stage; the stuck `running` comments shard is NOT released by it. Recover the comments stale job by stage explicitly (e.g. `social_repo.recover_stale_running_jobs(run_id=…, stage='comments_scrapling', stale_after_seconds=900)`) or terminalize it separately before expecting the run to complete." Soften "No stale running comments jobs" to "comments running job is terminalized via a comments-stage recovery."

### CHG-05 — Step 5: the 5 approval-failed jobs will not self-heal
- **Location:** Step 5 expected result, "Failed jobs are either recovered or explicitly terminal" (line 144).
- **Problem:** `recover_failed_instagram_comments_capacity_jobs` requeues failed comments shards only for transport/SSL/pool-capacity/stale-dispatch errors — `instagram_comments_public_requires_approval` is not in that set. The 5 failed jobs stay `failed`; progress only moves if Step 4 unblocks *new* dispatches of still-pending shards.
- **Evidence:** `social_season_analytics_impl.py:5857` and WHERE clause `:5909-5953` (error-class allowlist excludes the approval code).
- **Change:** Add: "The 5 approval-failed comments jobs will NOT be auto-requeued (the capacity-recovery WHERE clause matches only transport/capacity/stale-dispatch errors). After Step 4, either explicitly re-queue them or mark them terminal with a recorded reason; do not expect the recover-stalled pass to resurrect them."

### CHG-06 — Step 8 `-k comments_public` matches ZERO tests (false-confidence selector)
- **Location:** Step 8, second pytest command (line 200): `-k "backfill_progress or deferred_comments_followup or comments_public"`.
- **Problem:** `comments_public` collects **no tests** (`--collect-only`: "no tests collected"; the token appears in neither test file). The combined selector still collects 10 tests (from `backfill_progress` + `deferred_comments_followup`), silently masking the dead token and implying public-comments approval behavior is exercised — it is not. Real approval/public-relay coverage lives in `tests/socials/instagram/test_instagram_public_mode.py`, which Step 8 never references.
- **Evidence:** `--collect-only` on `test_social_season_analytics.py -k comments_public` ⇒ 0 collected, 994 deselected; coverage exists at `test_instagram_public_mode.py:33,47`.
- **Change:** Replace line 200 with `-k "backfill_progress or deferred_comments_followup"` and **add** `pytest TRR-Backend/tests/socials/instagram/test_instagram_public_mode.py -k "public_comments_mode or public_relay"`. (Minor: in the first command, `deferred_comments_followup` is redundant with `recover_failed_deferred` — both select the same 3 tests; harmless.)

### CHG-07 — Config-only approval fix ships with ZERO automated verification
- **Location:** Step 8 gate ("pytest … only if backend code changes are required") combined with Step 4's preference for a config-only fix.
- **Problem:** If Step 4 is config-only (its stated preference), Step 8 skips all pytest, so the central approval change ships unverified.
- **Change:** Add a lightweight gate that runs even for config-only fixes: "(a) `pytest TRR-Backend/tests/socials/instagram/test_instagram_public_mode.py -k 'public_comments_mode or public_relay'`; (b) re-run `make instagram-backfill-preflight ACCOUNT_HANDLE=bravotv` and confirm comments mode is allowed. Proceed to Step 5 only after both pass."

### CHG-08 — No instruction to re-verify the 2026-06-29 snapshot before acting (drift risk)
- **Location:** Current Decision (lines 9–16), Evidence Snapshot (lines 28–36), Minimal Next Command (lines 253–260).
- **Problem:** All run IDs and counts (`status=running`, 5/5 jobs, 479/193/10) are a single-moment snapshot that *will* drift. Nothing tells the operator to re-verify or to abort/re-plan if the fresh read disagrees. The Minimal Next Command *is* read-only re-verification (good) but isn't framed that way.
- **Change:** Add a "Re-verify before acting" preamble before Step 3: "These IDs/counts are a 2026-06-29 snapshot and will drift. The Minimal Next Command IS the re-verification. If the child run is no longer `running`, no longer reports the approval token, or 479/193/10 changed materially, STOP and re-derive from the fresh snapshot before Steps 3–9. Never run recover-stalled/dispatch against stale IDs."

---

## MEDIUM

### CHG-09 — Step 7 specifies a status string that exists nowhere (`catalog_complete_launch_pending`)
- **Location:** Step 7, "Required behavior" bullets (line ~189).
- **Problem:** The literal `catalog_complete_launch_pending` does not exist in the codebase; the code is a two-state model (`waiting_for_catalog_completion` is the only string, popped entirely once state ≠ pending). An implementer told to make the code emit this string would be inventing a new untested constant. (The Step 7 *gating* — "only if it still misleads" — is correct: for a `started` follow-up the catalog-waiting markers are already popped and a regression test enforces it.)
- **Evidence:** `scripts/socials/instagram/backfill_progress.py:413-418` (binary branch; else-branch pops the markers); only `waiting_for_catalog_completion` exists (`backfill_progress.py:415`, `run_lifecycle.py:779`); regression test `test_social_season_analytics.py:42219`.
- **Change:** Drop the fabricated `catalog_complete_launch_pending` literal, or explicitly mark it as a *proposed new constant* that requires matching additions in `run_lifecycle.py:766-780` and tests. Reword the bullets to the actual two-state model.

### CHG-10 — "has already cleared" is misleading wording in the Current Decision
- **Location:** Current Decision, line 7.
- **Problem:** `deferred_comments_followup.state=started` only means the child run was **launched (or reused)** — not that comments progressed. The plan's own evidence shows that child run is fully approval-blocked (5/5 failed). "Cleared" risks an operator reading comments as done. (The plan partially self-corrects in the same sentence.)
- **Evidence:** `run_lifecycle.py:375` (state set to `started` immediately after launch, before any comment scraped), `:356-363` (also `started` on the reused-run path).
- **Change:** Replace "has already cleared" with: "has advanced past its pending stage (state `pending → started`, i.e. the child comments run was launched). `state=started` confirms only that the child run was created/reused — not that comments completed. The child comments run is itself the active blocker (status=running, 5/5 jobs, `instagram_comments_public_requires_approval`)."

### CHG-11 — Stop Rules vs Steps 3–5: "recovering new year runs" is ambiguous and could be read as forbidding Step 5
- **Location:** Stop Rules (lines 37–51) vs Steps 3–5.
- **Problem:** The stop list includes the active blocker code and says to stop "launching or recovering new year runs," but Steps 3–5 literally recover a run while that token is present. An operator could read the stop rule as blocking Step 5.
- **Change:** Add a scope note to Stop Rules: "These block launching a NEW year run and any blind comments re-dispatch while the approval token is present. They do NOT block diagnosing or intentionally pausing the existing 2026 comments child run. A single Step-5 recovery pass is permitted only after Step 4 removes the approval token; if it is still present, pause with a recorded reason instead of dispatching."

### CHG-12 — Human checkpoint is stated as prose, not a hard STOP
- **Location:** `result.json` `requires_human_checkpoint=true` vs Step 1 (lines 67–68) and Step 8 (line 211).
- **Problem:** The dirty-backend-deploy checkpoint is advisory prose, not labeled as the result.json human checkpoint and not a blocking gate; Step 8's deploy commands follow with only "after scoped diff review," so an operator could run `deploy_backend.py` without explicit approval.
- **Change:** Add a STOP gate atop Step 8 echoing the `result.json` `human_checkpoint` string verbatim: "HUMAN CHECKPOINT (required) — the backend tree is dirty and ahead/behind origin. Do NOT run `deploy_backend.py` until a human explicitly approves deploying the dirty tree or the fix is reduced to a reviewed scoped patch. Hard stop."

### CHG-13 — Step 6 "recorded reason" gate is soft; 479 zero-comment posts pass trivially
- **Location:** Step 6 gate (lines 157–172) vs residuals (479 zero-comment posts, 193 hosted_unmarked, 10 unrecoverable).
- **Problem:** The gate "no high-volume posts at zero saved comments *without a recorded reason*" defines no high-volume threshold, no acceptable-reason set, and no field — so 2026 "passes" as soon as any reason string is attached to the 479.
- **Change:** Tighten: define high-volume (`reported_comments >= N`); require each zero-saved post's reason to be one of an enumerated set (`approval-blocked`, `public-pagination-exhausted`, `deleted-by-source`, `age-cutoff`) in a named field, not free text; pass only when high-volume zero-saved posts without an enumerated reason = 0, and state the expected post-recovery floor for the 479.

### CHG-14 — No Rollback/Abort section for an irreversible-mutation runbook
- **Location:** Whole plan (Steps 5 and 8 perform irreversible runtime/Modal mutations).
- **Problem:** No guidance if a pass worsens state (e.g. dispatches approval-blocked jobs that fail and increment auth-cooldown failures — itself a stop-rule condition). The Stop Rules say *to* stop but not *how* to quiesce or roll back an in-flight bad dispatch.
- **Change:** Add a Rollback/Abort section: on increased failed jobs / auth-cooldown failures > 0 / a re-introduced stop-rule token — (1) stop, no further recover-stalled/dispatch; (2) pause dispatch for the run; (3) capture progress JSON for both run IDs + failed-job error classes; (4) leave the run intentionally paused with a recorded reason. Deploys roll back by redeploying the prior known-good revision.

### CHG-15 — Reframe `requires_approval` as the default lane, not an accidental flag
- **Location:** Stop Rules (line 51) and Step 4 framing.
- **Problem:** The plan implies an over-eager switch "got set for this run" and can be flipped off. Public comments mode is the **default** (opt-out), and `requires_approval` is the intended terminal result for public-incomplete sub-MIN_GAP posts. There is no run-specific flag to un-set.
- **Evidence:** `public_mode.py:55-70` (`comments_public_mode_from_config` defaults to public via `SOCIAL_INSTAGRAM_SCRAPE_MODE` → `public_first`); `social_season_analytics_impl.py:233` (default `public_first`).
- **Change:** Add: "Public comments mode is the DEFAULT lane, not an accidentally-enabled flag. `requires_approval` is the intended terminal result for public-incomplete posts below the auto-escalation `MIN_GAP`. Choose between escalating (lower `MIN_GAP` / permit auth fallback) or recording targets as terminal."

---

## Confirmed correct — NO change needed (so codex doesn't 'fix' non-problems)

- **Both `recover-stalled` invocation forms work.** Step 3 (`make TARGET RUN_ID=x JSON=1`, args after) and Step 5 (`RUN_ID=x JSON=1 make TARGET`, env before) both propagate `RUN_ID`/`JSON` to the recipe's shell-variable reads (`$${RUN_ID:-}`, `$${JSON:-0}`). GNU Make 3.81 exports command-line assignments into the recipe shell. Neither runs against the wrong/no run. (This was the most obvious-looking "bug" and it is a non-issue — do not rewrite the invocations for this reason.)
- **`make instagram-backfill-progress` and `…-preflight` are read-only.** Progress is SELECT-only; preflight runs readiness probes + a summary. `ACCOUNT_HANDLE=bravotv` is accepted (stripped of `@`, lowercased, no allowlist). `Makefile:212-232`.
- **Step 2 is a safe forward-reference.** `recover_pending_deferred_comments_followups` exists nowhere; "do not implement it now" is correct. (Optional clarity: the real adjacent symbol is `recover_FAILED_deferred_comments_followups`, `run_lifecycle.py:518`, a `state=='failed'` sweep already gated behind `SOCIAL_DEFERRED_COMMENTS_FOLLOWUP_RETRY_ENABLED`.)
- **Step 8's lifecycle pytest selector is real.** `-k "deferred_comments_followup or recover_failed_deferred"` collects 3 tests (`test_social_run_lifecycle_repository.py:523/538/593`); `backfill_progress` collects 5.
- **Provenance pointer valid.** `result.json` `source_plan` resolves to the 2026-06-26 plan-work dir.
- **Step 7 gating is sound for the current run.** The `waiting_for_catalog_completion` defect does not reproduce for a `started` follow-up (markers popped; regression test at `test_social_season_analytics.py:42219`). Only the fabricated status string (CHG-09) needs fixing.

---

## Validation notes (for the audit trail)

- **Repo reality:** all three make targets, all five referenced script/test paths, and `_maybe_start_deferred_comments_followup` exist as the plan assumes. The two blockers (CHG-01, CHG-02) were re-verified by the auditor firsthand against `Makefile:234-251`, `recover_stalled_backfill.py:39-135`, `modal_jobs.py:226/301/568-570/629`, and `job_runner.py:2996/3008/3022/5133`.
- **Not verified (operator-owned, point-in-time):** the live run states and row counts (`status=running`, 5/5 jobs, 479/193/10, `cooldown_until=null`). These are inherently a snapshot — see CHG-08. The auditor did not run any mutating command, did not deploy, did not touch Modal.
- **Backend/API validation:** not run (audit is read-only). **App validation/build:** not applicable (no TRR-APP behavior changed). **SQL:** not applicable (no SQL ownership changed). **Modal:** not applicable until a real code/config fix is chosen — and note CHG-02 means a Modal env/redeploy is likely required, contradicting the plan's "no deploy" path.

---

## Blocking questions for codex / the user

1. **Approval residuals — escalate or accept?** For the sub-`MIN_GAP` (`expected_count < 100`) posts that trip `requires_approval`: lower `SOCIAL_INSTAGRAM_COMMENTS_AUTO_AUTH_FALLBACK_MIN_GAP` (permits authenticated escalation — conflicts with the public-first "no auth/proxy" policy), or accept them as terminal with a recorded reason? This decision determines whether a Modal env change / redeploy is needed and resolves the Step 4 internal contradiction.
2. **Dirty backend tree:** is deploying the dirty `TRR-Backend` tree approved, or must any fix be reduced to a scoped patch first? (`result.json` flags this as a required human checkpoint.)
3. **Step 6 acceptance floor:** what is the acceptable end-state for the 479 zero-comment posts (a numeric floor, or "all carry an enumerated reason")? Needed to make the 2026 completion gate operationally meaningful.

---

## Post-audit corrections (live + empirical verification, 2026-06-29)

These supersede parts of the findings above. Triggered by the question: *"why does it not scrape posts with >100 comments publicly — who said it can't be done publicly?"* Verified against live run `4f4160a4` and an empirical logged-out fetch.

### C-1 — `requires_approval` is NOT a "small post / accept-as-terminal" condition; it's a single-attempt transient `public_blocked` treated as terminal
- **What I got wrong (CHG-02 / CHG-15):** I claimed the residual blocked posts were small (`expected_count < MIN_GAP=100`) and "intended-terminal." Wrong.
- **Live reality (run `4f4160a4` failed comments shards):**
  - The blocked posts are **large**: e.g. `DUqgCY3Ag-u`=647, `DW9M_KFIAGt`=438, `DYfoxDBAeXW`=334, `DAOlWTtKnqR`=184, `DB91le2iNkD`=183, `DLYM0znh1_k`=150 reported comments — **all ≥ MIN_GAP**.
  - Every failed shard is `attempt_count: 1`. Dominant `incomplete_fetch_reasons` value is **`public_blocked`** (a few `persisted_reply_topology_gap`).
  - Run/job config: **`auto_auth_fallback: null`**, `comments_load_strategy: public_relay`. So the ≥100 auto-escalation path did not arm for this run; the large posts raised `requires_approval` directly.
- **What `public_blocked` actually means:** `fetcher.py:216-219` classifies purely by recovered count — `recovered == 0` → `public_blocked`. It means *zero comments came back on that one attempt*, not that Instagram walled the content.
- **Empirical proof (reachability):** a single logged-out `stealthy_fetch` of `https://www.instagram.com/p/DUqgCY3Ag-u/` returned HTTP 200 with the post and ~16 real comments embedded + the live comment/like counts. A cold cookieless API call → `/accounts/login/` redirect (the exact `public_blocked` failure mode = missing session cookies / rate-limit, not content gating).
- **Empirical proof (deep pagination, from the system's OWN data):** these are not theoretical — the public path already paginated deep on these very posts. Live rollups: `DUqgCY3Ag-u` 207 saved / 647 reported, `DYfoxDBAeXW` 237/334, `DAOlWTtKnqR` 121/184, `DB91le2iNkD` 120/183 — i.e. **4 of the 6 "blocked" posts already hold 120–237 publicly-scraped comments**; the `public_blocked` verdict was a transient zero-result on one later attempt, not a wall. Account-wide (bravotv), all logged-out via `public_relay` with `auto_auth_fallback` off: **4,733 posts with saved comments, 2,743 with ≥100, 414 with ≥500, 108 with ≥1000, max 3,094 on one post, 947,891 comments total.** Deep public pagination is the norm, not the exception.
- **Corrected fix space (send this to codex instead of "lower MIN_GAP / accept terminal"):**
  1. **A single zero-comment public fetch must not be terminal.** Before classifying `public_blocked` → `requires_approval`, retry the public path with cooldown / IP rotation / pacing. `attempt_count=1` failures are the core defect — these posts are publicly available.
  2. The plan's framing of `requires_approval` as an "approval/config switch to flip" (Step 4) is doubly wrong: it is neither a flippable switch (CHG-02) nor a real public-impossibility (C-1). It is a premature-give-up on a rate-limited public fetch.
  3. If escalation to the authenticated lane is wanted for big posts, note `auto_auth_fallback` is `null` in this run's config — it never armed. But escalation = switching to auth/proxy, which still conflicts with the public-first policy; retrying public is the cheaper, policy-aligned fix.
- **Plan impact:** Step 4 ("clear the approval blocker") and Step 6's "recorded reason" gate should be reframed around **public-retry recovery of these large posts**, not approval/terminal accounting. The 479 zero-comment / blocked posts are likely recoverable publicly, not genuinely un-scrapable.

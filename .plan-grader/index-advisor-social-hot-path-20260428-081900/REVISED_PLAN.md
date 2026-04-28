# Revised Plan: Index Advisor Social Hot Path Workflow

Date: 2026-04-28
Status: approved with revisions
Recommended executor after approval: `inline`
Source plan: `/Users/thomashulihan/Projects/TRR/docs/codex/plans/2026-04-28-index-advisor-social-hot-path-plan.md`

## Summary

Codify the already-installed Supabase `index_advisor` extension in TRR's backend migration contract, then add a repeatable read-only helper that asks for index recommendations against the existing social/admin hot-path query set.

This workflow is evidence-only. `index_advisor` output must never be treated as approval to create or drop indexes. Any index candidate still needs route ownership, existing-index review, EXPLAIN evidence, RLS/grants review, and explicit approval before DDL is written.

## Current Context

- Workspace: `/Users/thomashulihan/Projects/TRR`
- Backend repo: `/Users/thomashulihan/Projects/TRR/TRR-Backend`
- Live runtime state: `pg_extension` reports `index_advisor` installed in schema `extensions`; `pg_available_extensions` reports version `0.2.0`.
- Repo gap: `rg "index_advisor"` found no migration, test, helper script, or docs workflow.
- Existing evidence scaffold: `TRR-Backend/scripts/db/hot_path_explain/` already contains social/admin query labels and an EXPLAIN-first review workflow.
- Adjacent constraint: the 2026-04-28 Supabase advisor cleanup cycle is closed, with remaining unused-index cleanup deferred. This plan must not reopen destructive cleanup.

## Assumptions

1. `index_advisor` should live in schema `extensions`, matching the live database and avoiding extension objects in `public`.
2. Hosted Supabase supports `create extension if not exists index_advisor with schema extensions;` for this project because the live database already has the extension installed.
3. The helper calls `extensions.index_advisor(query text)` with one route-realistic SQL string at a time.
4. The helper runs in a read-only transaction and sets local `statement_timeout` and `lock_timeout`.
5. The helper records returned recommendations as evidence only and never executes returned DDL.
6. Generated JSON/Markdown reports are checked in only for approved, dated review runs. Ad hoc local runs should remain local.
7. Backend-only scope is enough unless a later approved index change requires app/admin follow-through.

## Goals

1. Make `index_advisor` reproducible in backend migrations.
2. Add tests preventing accidental public-schema extension placement.
3. Add a read-only social hot-path advisor helper.
4. Save redacted JSON/Markdown evidence under `docs/workspace/` for approved runs.
5. Keep advisor recommendations separate from EXPLAIN and DDL approval.
6. Reuse existing hot-path route labels and parameter conventions where practical.

## Non-Goals

- No automatic `CREATE INDEX`.
- No `DROP INDEX`.
- No Supabase compute, pool, or runtime env changes.
- No app route behavior changes.
- No self-hosting `supabase/index_advisor`.
- No broad rewrite of advisor remediation docs.

## Phase 0 - Baseline And Scope Guard

Create:

- `docs/workspace/index-advisor-social-hot-path-baseline-2026-04-28.md`

Record:

- installed extension name, schema, and version
- available extension version
- read-only command used for verification
- repo gap summary showing no existing migration/helper/docs
- explicit stop rule: this plan does not approve index creation or index removal

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python - <<'PY'
import os
from pathlib import Path
from dotenv import load_dotenv
import psycopg2

load_dotenv(Path(".env"), override=False)
dsn = os.getenv("TRR_DB_SESSION_URL") or os.getenv("TRR_DB_URL") or os.getenv("TRR_DB_FALLBACK_URL")
assert dsn, "TRR DB URL is required"
with psycopg2.connect(dsn, connect_timeout=10) as conn:
    conn.set_session(readonly=True, autocommit=False)
    with conn.cursor() as cur:
        cur.execute("""
            select e.extname, n.nspname, e.extversion
            from pg_extension e
            join pg_namespace n on n.oid = e.extnamespace
            where e.extname = 'index_advisor'
        """)
        print(cur.fetchall())
        cur.execute("""
            select name, default_version, installed_version
            from pg_available_extensions
            where name = 'index_advisor'
        """)
        print(cur.fetchall())
PY
```

Acceptance criteria:

- Baseline doc confirms live installed state and repo gap.
- No DDL is executed.
- The no-index-DDL stop rule is prominent.

## Phase 1 - Add Reproducible Extension Migration

Create a backend migration:

- `TRR-Backend/supabase/migrations/<timestamp>_enable_index_advisor_extension.sql`

Expected SQL shape:

```sql
create schema if not exists extensions;

create extension if not exists index_advisor
with schema extensions;

comment on extension index_advisor is
  'Index recommendation helper used by TRR operator tooling; recommendations require separate review before DDL.';
```

Add or extend tests:

- `TRR-Backend/tests/db/test_index_advisor_extension_sql.py`
- or `TRR-Backend/tests/db/test_advisor_remediation_sql.py` if the repo already has the right helper pattern there

Test requirements:

- migration contains `create schema if not exists extensions`
- migration contains `create extension if not exists index_advisor`
- migration contains `with schema extensions`
- test fails if the extension is created in `public`

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/db/test_index_advisor_extension_sql.py
.venv/bin/python -m pytest -q tests/db/test_advisor_remediation_sql.py
```

Acceptance criteria:

- Migration is idempotent.
- Extension placement is locked to `extensions`.
- Local reset environments can reproduce the schema contract when the extension is available.

## Phase 2 - Add Read-Only Advisor Helper

Create:

- `TRR-Backend/scripts/db/index_advisor_social_hot_paths.py`

Optional companion registry:

- `TRR-Backend/scripts/db/index_advisor_social_hot_paths.yml`
- or a typed Python constant if the query set is small

Required CLI:

- `--dry-run`: print labels and parameter summaries without connecting
- `--output-date YYYY-MM-DD`: set the report date
- `--labels label[,label...]`: optional targeted run filter if inexpensive to add
- `--output-dir PATH`: optional override, defaulting to workspace `docs/workspace/`

Runtime contract:

- load `.env` with `python-dotenv`
- resolve DB URL in this order: `TRR_DB_SESSION_URL`, `TRR_DB_URL`, `TRR_DB_FALLBACK_URL`
- connect with a short `connect_timeout`
- set `readonly=True`
- set local `statement_timeout` and `lock_timeout`
- verify `index_advisor` is installed in `extensions`
- call `extensions.index_advisor(query text)` for each query string
- record per-query errors without aborting the entire run
- never execute returned `CREATE INDEX` statements
- redact credentials and raw connection strings from all output

Initial query labels:

- `profile_dashboard/shared_account_source`
- `profile_dashboard/recent_catalog_jobs`
- `shared_ingest/recent_runs`
- `shared_review_queue/open_items`
- `social_landing/socialblade_rows`
- `season_analytics/season_targets`
- `week_live_health/instagram_week_bucket`
- comments/profile queries only if represented safely without heavyweight live reads

Output files for approved dated runs:

- `docs/workspace/index-advisor-social-hot-paths-YYYY-MM-DD.json`
- `docs/workspace/index-advisor-social-hot-paths-YYYY-MM-DD.md`

Minimum JSON shape:

```json
{
  "metadata": {
    "generated_at": "ISO-8601 timestamp",
    "output_date": "YYYY-MM-DD",
    "database": "redacted",
    "extension_schema": "extensions",
    "extension_version": "0.2.0",
    "read_only": true
  },
  "queries": [
    {
      "label": "profile_dashboard/shared_account_source",
      "route": "/api/v1/admin/socials/profiles/:platform/:handle/dashboard",
      "parameters": {"platform": "instagram", "handle": "thetraitorsus"},
      "status": "ok",
      "recommendations": [],
      "errors": [],
      "review_required": true
    }
  ]
}
```

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m py_compile scripts/db/index_advisor_social_hot_paths.py
.venv/bin/python scripts/db/index_advisor_social_hot_paths.py --dry-run
.venv/bin/python scripts/db/index_advisor_social_hot_paths.py --output-date 2026-04-28
```

Acceptance criteria:

- Dry run does not connect to the database.
- Live run writes redacted JSON and Markdown.
- Missing extension exits clearly without partial recommendation files.
- Failed query analysis is recorded per label.
- Returned DDL is never executed.

## Phase 3 - Integrate With Existing Hot-Path Docs

Update:

- `TRR-Backend/scripts/db/hot_path_explain/README.md`
- `docs/workspace/dev-commands.md`
- optionally `docs/workspace/supabase-advisor-snapshot-workflow.md`
- optionally root `Makefile` or backend `Makefile`

Docs must explain:

- `hot_path_explain.sql` proves planner behavior for route-realistic reads.
- `index_advisor_social_hot_paths.py` proposes candidate single-column B-tree indexes.
- Advisor output is not DDL approval.
- Any candidate requires EXPLAIN, existing-index review, RLS/grants review, and owner approval.

Optional Make target:

- `make index-advisor-social-hot-paths`

Validation:

```bash
cd /Users/thomashulihan/Projects/TRR
rg -n "index-advisor-social-hot-paths|index_advisor_social_hot_paths|index_advisor" docs TRR-Backend/scripts/db Makefile TRR-Backend/Makefile
```

Acceptance criteria:

- Operators can discover the workflow from existing DB/advisor docs.
- Docs avoid DB URLs, JWTs, service-role keys, and raw env dumps.
- The workflow remains backend/operator tooling, not an app UI feature.

## Phase 4 - Optional First Recommendation Review

Only run this phase if a dated review run is approved.

Actions:

- Run the helper against the configured dev/staging database.
- Classify each recommendation as:
  - `candidate_for_explain`
  - `defer_existing_index_or_low_value`
  - `advisor_error`
  - `unsafe_or_out_of_scope`
- For any candidate, run the matching hot-path EXPLAIN before proposing DDL.
- Save review notes as `docs/workspace/index-advisor-social-hot-path-review-YYYY-MM-DD.md`.

EXPLAIN follow-up should use the same DB URL precedence as the helper. Example shell pattern:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
DB_URL="${TRR_DB_SESSION_URL:-${TRR_DB_URL:-${TRR_DB_FALLBACK_URL:-}}}"
test -n "$DB_URL"
PGAPPNAME=trr-hot-path-explain \
psql "$DB_URL" \
  -v explain_analyze=false \
  -v account_platform=instagram \
  -v account_handle=thetraitorsus \
  -v source_scope=bravo \
  -v safe_limit=25 \
  -v safe_offset=0 \
  -v statement_timeout=8s \
  -f scripts/db/hot_path_explain/hot_path_explain.sql \
  -o /tmp/trr-hot-path-explain-index-advisor-followup.txt
```

Acceptance criteria:

- No index migration is created unless separately approved.
- Candidate classifications are tied to route labels.
- Duplicate or overlapping recommendations are marked low-value or no-op.

## Validation Plan

Automated checks:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python -m pytest -q tests/db/test_index_advisor_extension_sql.py
.venv/bin/python -m py_compile scripts/db/index_advisor_social_hot_paths.py
.venv/bin/python scripts/db/index_advisor_social_hot_paths.py --dry-run
```

Live/read-only checks:

```bash
cd /Users/thomashulihan/Projects/TRR/TRR-Backend
.venv/bin/python scripts/db/index_advisor_social_hot_paths.py --output-date 2026-04-28
```

Artifact checks:

```bash
cd /Users/thomashulihan/Projects/TRR
rg -n "postgres://|postgrest://|service_role|TRR_DB_" docs/workspace/index-advisor-social-hot-paths-2026-04-28.*
rg -n "index_advisor|index-advisor-social-hot-paths|index_advisor_social_hot_paths" docs TRR-Backend/scripts/db
```

Expected results:

- `index_advisor` is installed in `extensions`.
- Generated reports list recommendations and errors per query label.
- No generated file contains a database URL or secret.
- No returned DDL is executed during validation.

## Architecture Impact

- Backend owns migration, tests, helper script, and social query registry.
- Workspace docs own operator workflow discoverability.
- TRR-APP needs no code changes for this plan.
- This adds an advisor layer beside the EXPLAIN harness. It does not replace EXPLAIN, route timing, or Supabase Performance Advisor snapshots.

## Risks And Open Questions

- `index_advisor` only recommends single-column B-tree indexes.
- Placeholder queries may need explicit casts for type inference.
- Hot-path SQL may need a curated companion registry instead of parsing the EXPLAIN script.
- Local reset support still needs verification after the migration lands.
- Generated reports should default to approved dated evidence only, not every local run.

## Follow-Up Improvements

- Add report diffing.
- Add query registry tests.
- Add a redaction unit test.
- Add JSON schema validation for reports.
- Include existing-index context per recommendation.
- Link reports from the Supabase Advisor snapshot workflow.

## Recommended Next Step After Approval

Implement sequentially in one backend-first pass:

1. Baseline doc.
2. Extension migration and tests.
3. Read-only helper and optional registry.
4. Docs/command integration.
5. Optional dated recommendation review.

Do not parallelize the migration and helper work until the extension schema contract is settled.

## Ready For Execution

Yes. Execute from this revised plan or from the canonical docs plan after it has been aligned with this artifact.

## Cleanup Note

After this plan is completely implemented and verified, delete any temporary planning artifacts that are no longer needed, including generated audit, scorecard, suggestions, comparison, patch, benchmark, and validation files. Do not delete them before implementation is complete because they are part of the execution evidence trail.

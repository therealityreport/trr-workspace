# TRR Backend Batch 1 SQL Diagnosis

Date: 2026-03-25

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-03-25
  current_phase: "batch-1 backend-owned admin reads were traced to exact SQL; direct SQL is mostly reachable, but hanging backend requests still fail before matching SQL appears in pg_stat_activity"
  next_action: "fix the broken person-detail query and then diagnose backend pool init / connection acquisition churn separately from the SQL plans"
  detail: self
```

## Scope
- `GET /api/v1/admin/covered-shows`
- `GET /api/v1/admin/covered-shows/{show_id}`
- `GET /api/v1/admin/people/resolve-slug?slug=brandi-glanville&show_slug=rhobh`
- `GET /api/v1/admin/people/{person_id}`
- `GET /api/v1/admin/people/{person_id}/cover-photo`
- `GET /api/v1/admin/people/{person_id}/gallery?limit=120&offset=0`

Session-pooler DSN used for all direct tests:
- host: `aws-1-us-east-1.pooler.supabase.com`
- port: `5432`
- database: `postgres`
- user: `postgres.vwxfvzutyufrkhfgoeaa`
- added for probes: `sslmode=require`, `connect_timeout=10`, `application_name=...`

## Exact SQL

### 1. Covered shows list
SQL:
```sql
WITH covered AS (
  SELECT
    cs.id::text AS id,
    cs.trr_show_id::text AS trr_show_id,
    cs.show_name,
    s.name AS core_show_name,
    s.slug,
    COALESCE(s.alternative_names, ARRAY[]::text[]) AS alternative_names,
    s.show_total_episodes,
    si.hosted_url AS poster_url,
    lower(
      trim(
        both '-' FROM regexp_replace(
          regexp_replace(COALESCE(s.name, ''), '&', ' and ', 'gi'),
          '[^a-z0-9]+',
          '-',
          'gi'
        )
      )
    ) AS computed_slug
  FROM admin.covered_shows AS cs
  LEFT JOIN core.shows AS s
    ON s.id = cs.trr_show_id
  LEFT JOIN core.show_images AS si
    ON si.id = s.primary_poster_image_id
),
ranked AS (
  SELECT
    id,
    trr_show_id,
    show_name,
    alternative_names,
    show_total_episodes,
    poster_url,
    CASE
      WHEN COALESCE(NULLIF(trim(slug), ''), NULLIF(computed_slug, '')) IS NULL
        THEN NULL
      WHEN COUNT(*) OVER (PARTITION BY computed_slug) > 1
        THEN COALESCE(NULLIF(trim(slug), ''), computed_slug) || '--' || lower(left(trr_show_id, 8))
      ELSE COALESCE(NULLIF(trim(slug), ''), computed_slug)
    END AS canonical_slug
  FROM covered
)
SELECT
  id,
  trr_show_id,
  show_name,
  canonical_slug,
  alternative_names,
  show_total_episodes,
  poster_url
FROM ranked
ORDER BY show_name ASC
```

### 2. Covered shows detail
SQL:
```sql
WITH covered AS (
  SELECT
    cs.id::text AS id,
    cs.trr_show_id::text AS trr_show_id,
    cs.show_name,
    s.name AS core_show_name,
    s.slug,
    COALESCE(s.alternative_names, ARRAY[]::text[]) AS alternative_names,
    s.show_total_episodes,
    si.hosted_url AS poster_url,
    lower(
      trim(
        both '-' FROM regexp_replace(
          regexp_replace(COALESCE(s.name, ''), '&', ' and ', 'gi'),
          '[^a-z0-9]+',
          '-',
          'gi'
        )
      )
    ) AS computed_slug
  FROM admin.covered_shows AS cs
  LEFT JOIN core.shows AS s
    ON s.id = cs.trr_show_id
  LEFT JOIN core.show_images AS si
    ON si.id = s.primary_poster_image_id
),
ranked AS (
  SELECT
    id,
    trr_show_id,
    show_name,
    alternative_names,
    show_total_episodes,
    poster_url,
    CASE
      WHEN COALESCE(NULLIF(trim(slug), ''), NULLIF(computed_slug, '')) IS NULL
        THEN NULL
      WHEN COUNT(*) OVER (PARTITION BY computed_slug) > 1
        THEN COALESCE(NULLIF(trim(slug), ''), computed_slug) || '--' || lower(left(trr_show_id, 8))
      ELSE COALESCE(NULLIF(trim(slug), ''), computed_slug)
    END AS canonical_slug
  FROM covered
)
SELECT
  id,
  trr_show_id,
  show_name,
  canonical_slug,
  alternative_names,
  show_total_episodes,
  poster_url
FROM ranked
WHERE trr_show_id = %s
LIMIT 1
```
Params:
- `show_id = '7782652f-783a-488b-8860-41b97de32e75'`

### 3. Resolve slug
Actual execution path for `slug=brandi-glanville&show_slug=rhobh` is two queries.

Show lookup SQL:
```sql
WITH shows_with_slug AS (
  SELECT
    s.id::text AS id,
    s.name,
    COALESCE(s.alternative_names, ARRAY[]::text[]) AS alternative_names,
    lower(
      trim(
        both '-' FROM regexp_replace(
          regexp_replace(COALESCE(s.name, ''), '&', ' and ', 'gi'),
          '[^a-z0-9]+',
          '-',
          'gi'
        )
      )
    ) AS computed_slug,
    COALESCE(
      NULLIF(
        lower(
          trim(
            both '-' FROM regexp_replace(
              regexp_replace(COALESCE(s.slug, ''), '&', ' and ', 'gi'),
              '[^a-z0-9]+',
              '-',
              'gi'
            )
          )
        ),
        ''
      ),
      lower(
        trim(
          both '-' FROM regexp_replace(
            regexp_replace(COALESCE(s.name, ''), '&', ' and ', 'gi'),
            '[^a-z0-9]+',
            '-',
            'gi'
          )
        )
      )
    ) AS effective_slug
  FROM core.shows AS s
)
SELECT
  s.id,
  s.name,
  s.alternative_names,
  s.effective_slug AS slug,
  CASE
    WHEN COUNT(*) OVER (PARTITION BY s.effective_slug) > 1
      THEN s.effective_slug || '--' || lower(left(s.id, 8))
    ELSE s.effective_slug
  END AS canonical_slug
FROM shows_with_slug AS s
WHERE (
  s.effective_slug = %s
  OR s.computed_slug = %s
  OR EXISTS (
    SELECT 1
    FROM unnest(s.alternative_names) AS alt(name)
    WHERE lower(
      trim(
        both '-' FROM regexp_replace(
          regexp_replace(COALESCE(alt.name, ''), '&', ' and ', 'gi'),
          '[^a-z0-9]+',
          '-',
          'gi'
        )
      )
    ) = %s
  )
)
ORDER BY s.id ASC
```
Params:
- `['rhobh', 'rhobh', 'rhobh']`

Person exact-name SQL:
```sql
SELECT
  p.id::text AS id,
  p.full_name,
  CASE
    WHEN %s::uuid IS NOT NULL AND EXISTS (
      SELECT 1
      FROM core.show_cast AS sc
      WHERE sc.person_id = p.id
        AND sc.show_id = %s::uuid
    )
      THEN true
    ELSE false
  END AS on_show
FROM core.people AS p
WHERE p.full_name = ANY(%s::text[])
ORDER BY on_show DESC, p.id ASC
```
Params:
- `resolved_show_id = '3b09242e-daf5-4fbb-8ac0-4b82d0f77e50'`
- `candidate_full_names = ['Brandi Glanville', 'Brandi-Glanville']`

Fallback slug-normalized people SQL exists but was not reached for this input:
```sql
SELECT
  p.id::text AS id,
  p.full_name,
  CASE
    WHEN %s::uuid IS NOT NULL AND EXISTS (
      SELECT 1
      FROM core.show_cast AS sc
      WHERE sc.person_id = p.id
        AND sc.show_id = %s::uuid
    )
      THEN true
    ELSE false
  END AS on_show
FROM core.people AS p
WHERE lower(
  trim(
    both '-' FROM regexp_replace(
      regexp_replace(COALESCE(p.full_name, ''), '&', ' and ', 'gi'),
      '[^a-z0-9]+',
      '-',
      'gi'
    )
  )
) = %s
ORDER BY on_show DESC, p.id ASC
```

### 4. Person detail
SQL:
```sql
SELECT
  id::text AS id,
  full_name,
  known_for,
  external_ids,
  birthday,
  gender,
  biography,
  place_of_birth,
  homepage,
  profile_image_url,
  alternative_names
FROM core.people
WHERE id = %s::uuid
LIMIT 1
```
Params:
- `person_id = '66ce2444-c6c4-46bc-94d0-4c15ae3d04af'`

### 5. Cover photo GET
SQL:
```sql
SELECT
  person_id::text AS person_id,
  photo_id,
  photo_url
FROM admin.person_cover_photos
WHERE person_id = %s::uuid
LIMIT 1
```
Params:
- `person_id = '66ce2444-c6c4-46bc-94d0-4c15ae3d04af'`

### 6. Gallery GET
The route executes two queries.

Cast-photo leg:
```sql
SELECT
  cp.id,
  cp.person_id::text AS person_id,
  lower(cp.source) AS source,
  cp.url,
  cp.hosted_url,
  cp.hosted_content_type,
  cp.caption,
  cp.width,
  cp.height,
  cp.source_page_url,
  cp.metadata,
  tags.people_count,
  tags.people_count_source
FROM core.cast_photos AS cp
LEFT JOIN admin.cast_photo_people_tags AS tags
  ON tags.cast_photo_id = cp.id
WHERE cp.person_id = %s::uuid
  AND cp.hosted_url IS NOT NULL
  AND (%s::text[] IS NULL OR lower(cp.source) = ANY(%s::text[]))
ORDER BY cp.gallery_index ASC NULLS LAST, lower(cp.source) ASC, cp.id ASC
LIMIT %s::int
OFFSET %s::int
```

Media-link leg:
```sql
SELECT
  ml.id::text AS link_id,
  %s::text AS person_id,
  ml.media_asset_id::text AS media_asset_id,
  ml.context,
  lower(ma.source) AS source,
  ma.source_url,
  ma.hosted_url,
  ma.hosted_content_type,
  ma.caption,
  ma.width,
  ma.height,
  ma.metadata
FROM core.media_links AS ml
JOIN core.media_assets AS ma
  ON ma.id = ml.media_asset_id
WHERE ml.entity_type = 'person'
  AND ml.entity_id = %s::uuid
  AND ml.kind = 'gallery'
  AND ma.hosted_url IS NOT NULL
  AND (%s::text[] IS NULL OR lower(coalesce(ma.source, '')) = ANY(%s::text[]))
ORDER BY ml.position ASC NULLS LAST, ml.id ASC
LIMIT %s::int
OFFSET %s::int
```
Params:
- `person_id = '66ce2444-c6c4-46bc-94d0-4c15ae3d04af'`
- `sources = NULL`
- `limit = 121`
- `offset = 0`

## Direct Execution Timing
All timings below are direct `psycopg2` executions against the same session-pooler DSN from this machine.

| Route / Query | Result | Direct elapsed |
|---|---:|---:|
| covered-shows list | 12 rows | 188 ms |
| covered-shows detail | 1 row | 47 ms |
| resolve-slug show lookup | 1 row | 48 ms |
| resolve-slug person exact | 1 row | 77 ms |
| person detail | `UndefinedColumn` | 93 ms |
| cover-photo GET | 1 row | 58 ms |
| gallery cast rows | 121 rows | 1188 ms |
| gallery media rows | 121 rows | 737 ms |

Cold one-shot runs were materially slower:
- covered-shows list: `4359 ms`
- resolve-slug person exact: `2035 ms`
- gallery cast rows: `5951 ms`

## EXPLAIN / EXPLAIN ANALYZE

### Covered-shows list
- Engine execution time: `23.885 ms`
- Planning time: `103.093 ms`
- Plan summary:
  - `Seq Scan` on `admin.covered_shows`
  - `Seq Scan` on `core.shows`
  - `Memoize` + `Index Scan` on `core.show_images`
  - `WindowAgg` + final `Sort`
- First bottleneck:
  - not a bad query plan
  - route stalls are not explained by this SQL

### Resolve-slug person exact
- Engine execution time: `6.099 ms`
- Planning time: `36.586 ms`
- Plan summary:
  - `Index Scan` on `core.people` via `people_full_name_idx`
  - subplan probes `core.show_cast`
- First bottleneck:
  - not the current route problem for the Brandi input
  - current exact-name path is cheap

### Gallery cast rows
- Engine execution time: `1013.386 ms`
- Planning time: `61.784 ms`
- Plan summary:
  - `Index Scan` on `core.cast_photos_person_id_idx`
  - `Rows Removed by Filter: 4360`
  - `Hash Left Join` to `admin.cast_photo_people_tags`
  - `top-N heapsort` for `LIMIT 121`
- First bottleneck:
  - heavy row width because `cp.metadata` is returned for every row
  - person has `4873` rows on the index scan path, `513` survive `hosted_url IS NOT NULL`

### Gallery media rows
- Engine execution time: `390.355 ms`
- Planning time: `58.274 ms`
- Plan summary:
  - `Index Scan` on `core.media_links_kind_position_idx`
  - `Nested Loop` into `core.media_assets_pkey`
  - `176` asset lookups for the requested page window
- First bottleneck:
  - row width is still large because `ma.metadata` is returned
  - query is acceptable alone but additive with cast-photo leg

### Person detail
- Direct execution error:
```text
UndefinedColumn: column "alternative_names" does not exist
```
- Schema check on `core.people` confirmed there is no `alternative_names` column.
- First bottleneck:
  - contract drift / broken SQL, not a lock or pooler problem

## Lock Inspection During a Hanging Backend Request
Test:
- started authenticated request to `GET /api/v1/admin/covered-shows`
- client timed out after `40s`

Observed while request was hanging:
- no active `pg_stat_activity` rows matching:
  - `admin.covered_shows`
  - `admin.person_cover_photos`
  - `FROM core.people`
  - `FROM core.cast_photos`
  - `FROM core.media_links`
- no waiting locks
- no `wait_event_type = 'Lock'`

Additional DB state:
- `15` sessions with `application_name = 'Supavisor'` were `idle in transaction`
- max idle-in-transaction age observed: `22:33:28`

Interpretation:
- the hanging backend request did not reach a blocked SQL statement
- the stall is upstream of SQL execution, consistent with backend pool creation / connection acquisition retries

## Logs / Query Performance Evidence

### Backend runtime log
During the hanging covered-shows request:
- backend log showed repeated:
  - `[db-pool] init_attempt=0 ... host=aws-1-us-east-1.pooler.supabase.com port=5432`
  - `[db-pool] init_failed ... error=OperationalError`
  - later `init_selected ...`

Interpretation:
- route hang is consistent with pool init / connection acquisition churn

### Postgres logs
Visible project-side findings:
- `column "alternative_names" does not exist`
- many unrelated `canceling statement due to statement timeout`
- many long-running statements elsewhere in the project
- normal Supavisor auth lines for `user=postgres database=postgres application_name=Supavisor`

### `pg_stat_statements`
Matching statement performance evidence:
- new covered-shows list query:
  - `calls=4`
  - `mean_exec_time_ms=7191.09`
- gallery cast query:
  - `calls=1`
  - `mean_exec_time_ms=5364.67`
- gallery media query:
  - `calls=1`
  - `mean_exec_time_ms=3267.04`
- normalized slug-fallback people query:
  - `calls=2714`
  - `mean_exec_time_ms=488.82`
- exact-name people query:
  - `calls=12`
  - `mean_exec_time_ms=278.97`

Interpretation:
- gallery queries are the heaviest batch-1 read SQL
- covered-shows list shows high mean time in stats despite the fast plan, which points to end-to-end overhead outside pure engine execution

## Pooler Logs
- Direct Supabase dashboard Pooler Logs were not accessible from the current tool surface.
- No Supavisor-specific auth/GSS failure was visible in the accessible `postgres` log stream.

## Route-by-Route First Concrete Bottleneck
- covered-shows list:
  - not a bad SQL plan
  - hanging request did not reach Postgres
  - first concrete bottleneck is backend pool init / connection acquisition churn
- covered-shows detail:
  - direct SQL is fast
  - same likely runtime bottleneck as list route
- resolve-slug:
  - current Brandi execution path is not the slow normalized-slug fallback
  - exact-name path is cheap
  - route stall is not explained by current SQL
- person detail:
  - broken SQL: selects missing `core.people.alternative_names`
- cover-photo GET:
  - direct SQL is fast
  - route stall is not explained by query shape
- gallery GET:
  - real SQL cost exists
  - `cast_photos` leg is the main query bottleneck
  - both legs over-return wide `metadata` blobs
  - route still also suffers from backend pool/runtime churn before SQL on hanging requests

# Index Advisor Social Hot Paths - 2026-04-28

This report is evidence-only. Do not execute returned DDL without a separate owner-approved migration review.

## Metadata

- Generated at: `2026-04-28T12:37:20.113738+00:00`
- DB URL source: `TRR_DB_URL`
- Extension schema: `extensions`
- Extension version: `0.2.0`
- Read-only: `True`

## Query Results

| Label | Status | Recommendations | Errors |
| --- | --- | ---: | ---: |
| profile_dashboard/shared_account_source | ok | 1 | 0 |
| profile_dashboard/recent_catalog_jobs | ok | 1 | 0 |
| shared_ingest/recent_runs | ok | 1 | 0 |
| shared_review_queue/open_items | ok | 1 | 0 |
| social_landing/socialblade_rows | ok | 1 | 0 |
| season_analytics/season_targets | ok | 1 | 0 |
| week_live_health/instagram_week_bucket | ok | 1 | 0 |

## Details

### profile_dashboard/shared_account_source

- Route: `/api/v1/admin/socials/profiles/:platform/:handle/dashboard`
- Status: `ok`
- Review required: `True`
- Parameters: `{"handle": "thetraitorsus", "platform": "instagram", "safe_limit": "25"}`

Recommendations:

```json
[
  {
    "errors": [],
    "index_statements": [],
    "startup_cost_after": 2.21,
    "startup_cost_before": 2.21,
    "total_cost_after": 2.21,
    "total_cost_before": 2.21
  }
]
```

### profile_dashboard/recent_catalog_jobs

- Route: `/api/v1/admin/socials/profiles/:platform/:handle/dashboard`
- Status: `ok`
- Review required: `True`
- Parameters: `{"handle": "thetraitorsus", "platform": "instagram", "safe_limit": "25", "safe_offset": "0"}`

Recommendations:

```json
[
  {
    "errors": [],
    "index_statements": [],
    "startup_cost_after": 4968.18,
    "startup_cost_before": 4968.18,
    "total_cost_after": 4968.25,
    "total_cost_before": 4968.25
  }
]
```

### shared_ingest/recent_runs

- Route: `/api/v1/admin/socials/runs and /shared/runs`
- Status: `ok`
- Review required: `True`
- Parameters: `{"safe_limit": "25", "safe_offset": "0", "season_id": "00000000-0000-0000-0000-000000000000", "source_scope": "bravo"}`

Recommendations:

```json
[
  {
    "errors": [],
    "index_statements": [
      "CREATE INDEX ON social.scrape_runs USING btree (source_scope)"
    ],
    "startup_cost_after": 515.75,
    "startup_cost_before": 527.0,
    "total_cost_after": 515.78,
    "total_cost_before": 527.03
  }
]
```

### shared_review_queue/open_items

- Route: `/api/v1/admin/socials/shared/review-queue`
- Status: `ok`
- Review required: `True`
- Parameters: `{"review_status": "open", "safe_limit": "25", "safe_offset": "0", "source_scope": "bravo"}`

Recommendations:

```json
[
  {
    "errors": [],
    "index_statements": [],
    "startup_cost_after": 0.03,
    "startup_cost_before": 0.03,
    "total_cost_after": 0.03,
    "total_cost_before": 0.03
  }
]
```

### social_landing/socialblade_rows

- Route: `/api/v1/admin/socials/landing-socialblade-rows`
- Status: `ok`
- Review required: `True`
- Parameters: `{"handle": "thetraitorsus", "platforms": "instagram,youtube,facebook", "safe_limit": "25"}`

Recommendations:

```json
[
  {
    "errors": [],
    "index_statements": [
      "CREATE INDEX ON pipeline.socialblade_growth_data USING btree (account_handle)",
      "CREATE INDEX ON pipeline.socialblade_growth_data USING btree (person_id)"
    ],
    "startup_cost_after": 4.42,
    "startup_cost_before": 4.67,
    "total_cost_after": 4.42,
    "total_cost_before": 4.68
  }
]
```

### season_analytics/season_targets

- Route: `/api/v1/admin/socials/shows/:show_id/seasons/:season_number/social/analytics`
- Status: `ok`
- Review required: `True`
- Parameters: `{"season_id": "00000000-0000-0000-0000-000000000000", "source_scope": "bravo"}`

Recommendations:

```json
[
  {
    "errors": [],
    "index_statements": [
      "CREATE INDEX ON social.season_targets USING btree (season_id)"
    ],
    "startup_cost_after": 1.15,
    "startup_cost_before": 1.17,
    "total_cost_after": 1.16,
    "total_cost_before": 1.17
  }
]
```

### week_live_health/instagram_week_bucket

- Route: `/api/v1/admin/socials/shows/:show_id/seasons/:season_number/social/analytics/week/:week_index/live-health`
- Status: `ok`
- Review required: `True`
- Parameters: `{"handle": "thetraitorsus", "season_id": "00000000-0000-0000-0000-000000000000", "week_end": "2026-01-08T00:00:00+00:00", "week_start": "2026-01-01T00:00:00+00:00"}`

Recommendations:

```json
[
  {
    "errors": [],
    "index_statements": [
      "CREATE INDEX ON social.instagram_posts USING btree (season_id)"
    ],
    "startup_cost_after": 2.27,
    "startup_cost_before": 2.52,
    "total_cost_after": 2.3,
    "total_cost_before": 2.55
  }
]
```

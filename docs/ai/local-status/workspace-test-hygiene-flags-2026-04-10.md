# Workspace Test Hygiene Flags — 2026-04-10

Last updated: 2026-04-10

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: active
  last_updated: 2026-04-10
  current_phase: "repo-wide test hygiene tracking"
  next_action: "carry forward flagged non-TikTok test fall-through separately from TikTok path reprioritization"
  detail: self
```

## Flags

- `/Users/thomashulihan/Projects/TRR/TRR-Backend/tests/repositories/test_social_season_analytics.py:4950` — `test_scrape_shared_twitter_posts_catalog_adds_profile_snapshot` is falling through to live Twitter behavior instead of its fake-scraper path; unrelated to TikTok path reprioritization — flagged 2026-04-10.

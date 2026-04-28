# PATCHES

## Patch 1 - Correct Platform Matrix

Replace any claim that Twitter/X and YouTube are catalog-only with:

- Twitter/X has both `social.twitter_tweets` and `social.twitter_account_catalog_posts`.
- YouTube has both `social.youtube_videos` and `social.youtube_account_catalog_posts`.

## Patch 2 - Move Raw Payloads Out Of Public Canonical Tables

Replace `raw_data jsonb` on `social.social_posts` with a private observation table:

```sql
create table if not exists social.social_post_observations (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references social.social_posts(id) on delete cascade,
  platform text not null,
  source_table text not null,
  source_pk text,
  scrape_run_id uuid references social.scrape_runs(id) on delete set null,
  observed_at timestamptz not null default now(),
  raw_payload jsonb not null default '{}'::jsonb,
  normalized_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
```

Do not grant public select on this table. Public/app reads should use sanitized canonical rows or backend-owned routes.

## Patch 3 - Add Platform Integrity To Child Tables

Use composite platform FKs:

```sql
alter table social.social_posts
  add constraint social_posts_platform_id_key unique (platform, id);

foreign key (platform, post_id)
  references social.social_posts(platform, id)
  on delete cascade
```

Apply this pattern to memberships, entities, media assets, and platform reference/bridge tables.

## Patch 4 - Store Normalized Lookup Keys

Add normalized keys instead of relying only on expression indexes:

```sql
membership_key_norm text not null,
entity_key_norm text not null
```

Primary/unique keys and lookup indexes should use normalized keys.

## Patch 5 - Add Legacy Reference Bridge

Add a bridge table before read-path migration:

```sql
create table if not exists social.social_post_legacy_refs (
  platform text not null,
  post_id uuid not null references social.social_posts(id) on delete cascade,
  legacy_schema text not null default 'social',
  legacy_table text not null,
  legacy_pk text not null,
  legacy_source_id text not null,
  created_at timestamptz not null default now(),
  primary key (platform, legacy_table, legacy_pk),
  unique (platform, legacy_table, legacy_source_id)
);
```

Use this to bridge existing comments/replies and platform-specific read paths without changing comment FKs yet.


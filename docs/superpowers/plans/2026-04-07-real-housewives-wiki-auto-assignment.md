# Real Housewives Wiki Auto-Assignment

## Goal

Make `Refresh Links` automatically discover and persist Real Housewives wiki pages from `https://real-housewives.fandom.com/wiki/Special:AllPages` for show, season, and person entities when valid canonical pages exist.

## Scope

- Backend-powered `Refresh Links` flow in `TRR-Backend`
- Shared Fandom discovery helpers
- Existing admin progress stream contract

## Implementation Summary

1. Thread franchise-rule Fandom context into live link refresh for Real Housewives shows.
2. Replace broad All Pages anchor scraping with scoped parsing of the All Pages body and nav.
3. Keep Real Housewives fandom matches additive instead of replacing other valid fandom links.
4. Reject noncanonical fandom subpages such as `/Gallery`, `/Storylines`, and `/Connections` for show, season, and person canonical assignment.
5. Preserve the existing progress payload shape and stage-budget reporting.

## Primary Files

- `TRR-Backend/api/routers/admin_show_links.py`
- `TRR-Backend/trr_backend/integrations/fandom_discovery.py`
- `TRR-Backend/trr_backend/repositories/brands_franchises.py`
- `TRR-Backend/tests/api/routers/test_admin_show_links.py`
- `TRR-Backend/tests/integrations/fandom/test_fandom_discovery.py`

## Verification Targets

- Real Housewives refresh uses franchise-rule context even without Bravo network metadata.
- All Pages pagination follows the live `Next page (...)` control.
- All Pages parsing only reads actual page-list entries.
- Show refresh keeps existing fandom links and adds the RH wiki page.
- Season and person discovery can add RH wiki links from All Pages.
- Gallery/storylines/connections pages do not satisfy canonical assignment.
- Progress payload compatibility stays intact.

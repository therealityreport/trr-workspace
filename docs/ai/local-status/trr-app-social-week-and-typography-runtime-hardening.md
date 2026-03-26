# TRR-APP social-week and typography runtime hardening

Last updated: 2026-03-24

## Handoff Snapshot
```yaml
handoff:
  include: false
  state: archived
  last_updated: 2026-03-24
  current_phase: "archived continuity note"
  next_action: "See newer TRR-APP runtime notes if follow-up is needed"
  detail: self
```

- `make dev` startup hardening remains in place at the workspace level.
- `TRR-APP` social week admin route now uses the standard `next/dynamic` loader boundary and no longer reproduces the observed dev-time webpack `undefined.call` crash in browser validation.
- `TRR-APP` typography runtime fallback now silently uses seeded client state, and the repository layer retries parallel seed races so `next build` no longer emits the earlier typography concurrency warning.
- Along the way, the full production build blockers in `PersonPageClient.tsx` and `person-gallery-media-view.ts` were also repaired so the app now passes a full webpack production build again.
- Validation:
  - Playwright browser checks for `/admin/trr-shows/rhoslc/seasons/6/social/week/0` returned HTTP `200` and settled without console/page errors after the loader change.
  - `pnpm -C /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web exec next build --webpack` completes successfully.

# Admin slugless root route canonicalization

Date: 2026-03-26

## Handoff Snapshot
```yaml
handoff:
  include: true
  state: recent
  last_updated: 2026-03-26
  current_phase: "complete"
  next_action: "Use slugless first-level admin URLs on admin.localhost and keep /admin/... only as compatibility redirects for landing-page sections."
  detail: self
```

## Summary

- Canonical admin host entry is now `/`, with the existing admin dashboard rendered there through proxy rewrites.
- First-level landing-page admin destinations now use slugless canonical URLs, including `/shows`, `/screenalytics`, `/people`, `/games`, `/surveys`, `/social`, `/brands`, `/users`, `/groups`, `/docs`, `/dev-dashboard`, `/design-system`, `/design-docs`, `/api-references`, and `/settings`.
- Legacy `/admin/...` paths for those landing-page sections remain supported as compatibility redirects on `admin.localhost`.
- Admin navigation, breadcrumbs, dashboard links, social-profile route builders, and targeted redirects now point at the slugless canonical URLs.

## Validation

- `pnpm -C /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web exec eslint src/proxy.ts src/lib/admin/admin-navigation.ts src/lib/admin/admin-breadcrumbs.ts src/lib/admin/show-admin-routes.ts src/components/admin/AdminGlobalHeader.tsx src/components/admin/SocialAccountProfilePage.tsx src/app/admin/social/page.tsx src/app/admin/social/creator-content/page.tsx src/app/admin/social/bravo-content/page.tsx src/app/admin/dev-dashboard/_components/DevDashboardShell.tsx src/app/admin/dev-dashboard/page.tsx src/app/admin/dev-dashboard/skills-and-agents/page.tsx`
- `pnpm -C /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web exec vitest run tests/admin-host-middleware.test.ts tests/admin-global-header.test.tsx tests/admin-navigation.test.ts tests/admin-breadcrumbs.test.ts tests/admin-breadcrumbs-component.test.tsx tests/admin-network-detail-page-auth.test.tsx tests/show-admin-routes.test.ts tests/social-account-profile-page.runtime.test.tsx tests/social-account-hashtag-timeline.runtime.test.tsx tests/admin-social-page-auth-bypass.test.tsx tests/social-account-profile-auth-bypass.test.tsx`
- `pnpm -C /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web exec playwright test tests/e2e/admin-breadcrumbs.spec.ts tests/e2e/admin-global-header-menu.spec.ts tests/e2e/admin-dashboard-utility-copy.spec.ts`

## Notes

- Full repo validation commands from `TRR-APP/AGENTS.md` were not run in this pass: `pnpm -C apps/web run lint`, `pnpm -C apps/web exec next build --webpack`, and `pnpm -C apps/web run test:ci`.
- The TRR-APP worktree already contained unrelated modifications before this route-normalization session; they were left intact.

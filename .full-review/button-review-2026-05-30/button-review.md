# TRR Web App Button Review

Generated: 2026-05-30

Scope: `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/app` and `/Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/components`; excludes tests, node_modules, .next, API-only code, and generated build output.

## Summary

- Controls inventoried: 1350
- Files with controls: 175
- Static-review revisions flagged: 280
- Confirmed issue groups: 13

## Confirmed Findings

### High: src/components/admin/AdminGlobalHeader.tsx:65

- UI text/icon: see code at line 65
- What it does: Logo link has aria-label "Go to admin dashboard" but href="/" sends the user to the public home page.
- What it should do: Change the destination to ADMIN_ROOT_PATH or update the label if the public home page is intentional.

### High: src/app/admin/dev-dashboard/_components/DevDashboardShell.tsx:68

- UI text/icon: see code at line 68
- What it does: Back to Admin points to /, so it leaves the admin area instead of returning to /admin.
- What it should do: Use ADMIN_ROOT_PATH.

### High: src/app/admin/docs/page.tsx:42

- UI text/icon: see code at line 42
- What it does: Back to Admin points to /, so it leaves the admin area instead of returning to /admin.
- What it should do: Use ADMIN_ROOT_PATH.

### High: src/app/admin/games/page.tsx:39

- UI text/icon: see code at line 39
- What it does: Back to Admin points to /, so it leaves the admin area instead of returning to /admin.
- What it should do: Use ADMIN_ROOT_PATH.

### High: src/app/admin/groups/page.tsx:38

- UI text/icon: see code at line 38
- What it does: Back to Admin points to /, so it leaves the admin area instead of returning to /admin.
- What it should do: Use ADMIN_ROOT_PATH.

### High: src/app/admin/settings/page.tsx:38

- UI text/icon: see code at line 38
- What it does: Back to Admin points to /, so it leaves the admin area instead of returning to /admin.
- What it should do: Use ADMIN_ROOT_PATH.

### High: src/app/admin/social/page.tsx:2133

- UI text/icon: see code at line 2133
- What it does: Back to Admin points to /, so it leaves the admin area instead of returning to /admin.
- What it should do: Use ADMIN_ROOT_PATH.

### High: src/app/admin/social/page.tsx:2171

- UI text/icon: see code at line 2171
- What it does: Back to Admin points to /, so it leaves the admin area instead of returning to /admin.
- What it should do: Use ADMIN_ROOT_PATH.

### High: src/app/admin/surveys/page.tsx:109

- UI text/icon: see code at line 109
- What it does: Back to Dashboard points to /, so it leaves the admin area instead of returning to /admin.
- What it should do: Use ADMIN_ROOT_PATH.

### High: src/app/admin/trr-shows/page.tsx:481

- UI text/icon: see code at line 481
- What it does: Back to Admin points to /, so it leaves the admin area instead of returning to /admin.
- What it should do: Use ADMIN_ROOT_PATH.

### High: src/app/admin/users/page.tsx:38

- UI text/icon: see code at line 38
- What it does: Back to Admin points to /, so it leaves the admin area instead of returning to /admin.
- What it should do: Use ADMIN_ROOT_PATH.

### High: src/components/admin/UnifiedBrandsWorkspace.tsx:817

- UI text/icon: see code at line 817
- What it does: Back to Admin points to /, so it leaves the admin area instead of returning to /admin.
- What it should do: Use ADMIN_ROOT_PATH.

### Medium: src/components/admin/show-tabs/ShowSeasonCards.tsx:75

- UI text/icon: see code at line 75
- What it does: Season card uses a clickable div with role="button" and nested links; nested interactive controls make click and keyboard behavior fragile.
- What it should do: Split the expand button from the Season/TMDB links so each control has one clear job.

## Revision Buckets

- Wrong admin destination: 11
- Missing explicit button type: 136
- Clickable non-button / mixed interaction: 57
- Inert button-like control: 63
- Missing accessible label: 13

## Button Inventory

Every row below lists the UI text/icon we can infer statically, what the control does from code, and what it should do. Dynamic labels are marked `{dynamic}`.

### src/app/admin/cast-screentime/CastScreentimePageClient.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 1116 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1183 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1246 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1254 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1286 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1300 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1308 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1406 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1415 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1426 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1696 | Load | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1744 | Load | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1824 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1833 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 2071 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 2141 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |

### src/app/admin/dev-dashboard/_components/DevDashboardShell.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 68 | Back to Admin | Link | Navigates to / | Point this control to /admin (ADMIN_ROOT_PATH), or change the label if the public home page is intentional. | Yes |

### src/app/admin/dev-dashboard/_components/SkillsAgentsDashboardContent.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 39 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/app/admin/dev-dashboard/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 409 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 417 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 472 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 760 | Link | a | Navigates to {dynamic} | No revision found in static review. | No |

### src/app/admin/docs/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 42 | Back to Admin | Link | Navigates to / | Point this control to /admin (ADMIN_ROOT_PATH), or change the label if the public home page is intentional. | Yes |

### src/app/admin/fonts/_components/ButtonsTab.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 23 | {dynamic} | button | Button type is button | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 29 | {dynamic} | button | Button type is button | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 35 | {dynamic} | button | Button type is button; Has disabled state | No revision found in static review. | No |
| 69 | Edit | Button | No click/navigation behavior found | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 75 | Save | Button | No click/navigation behavior found | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 78 | Cancel | Button | No click/navigation behavior found | Add a real action, convert it to a link, or render it as non-button text. | Yes |

### src/app/admin/fonts/_components/QuestionsTab.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 1192 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1316 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1372 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1405 | Mobile | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1415 | Tablet | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1425 | Desktop | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 2077 | (icon/empty) Edit Template | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 2088 | Use Defaults | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 2104 | (icon/empty) | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 2125 | Reset | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 2132 | Close | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 2709 | (icon/empty) Edit Template | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 2726 | (icon/empty) | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 2747 | Reset | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 2754 | Close | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/app/admin/games/bravodle/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 49 | Back to Games | Link | Navigates to {ADMIN_GAMES_PATH} | No revision found in static review. | No |
| 63 | Cover | Link | Navigates to {dynamic} | No revision found in static review. | No |
| 69 | Play | Link | Navigates to {dynamic} | No revision found in static review. | No |
| 75 | Stats | a | Navigates to {dynamic} | No revision found in static review. | No |

### src/app/admin/games/flashback/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 226 | Back to Games | Link | Navigates to {ADMIN_GAMES_PATH} | No revision found in static review. | No |
| 247 | Create New Quiz | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 272 | {dynamic} {dynamic} {dynamic} | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 296 | {dynamic} | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 324 | Add Event | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 381 | Delete | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |

### src/app/admin/games/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 39 | Back to Admin | Link | Navigates to / | Point this control to /admin (ADMIN_ROOT_PATH), or change the label if the public home page is intentional. | Yes |
| 69 | Open Admin | Link | Navigates to {dynamic} | No revision found in static review. | No |
| 76 | Open Live Game | Link | Navigates to {dynamic} | No revision found in static review. | No |

### src/app/admin/games/realitease/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 49 | Back to Games | Link | Navigates to {ADMIN_GAMES_PATH} | No revision found in static review. | No |
| 63 | Cover | Link | Navigates to {dynamic} | No revision found in static review. | No |
| 69 | Play | Link | Navigates to {dynamic} | No revision found in static review. | No |
| 75 | Stats | a | Navigates to {dynamic} | No revision found in static review. | No |

### src/app/admin/groups/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 38 | Back to Admin | Link | Navigates to / | Point this control to /admin (ADMIN_ROOT_PATH), or change the label if the public home page is intentional. | Yes |

### src/app/admin/networks/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 895 | Back to Admin | Link | Navigates to {ADMIN_ROOT_PATH} | No revision found in static review. | No |
| 965 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 973 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 981 | Re-run Unresolved Only | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 989 | Re-run Unresolved Production Only | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1004 | Resume Sync | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1089 | All | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1100 | Network | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1111 | Streaming Services | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1124 | Production Companies | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1173 | {dynamic} {dynamic} {dynamic} {dynamic} (icon/empty) (icon/empty) {dynamic} {dynamic} {dynamic} {dynamic} {dynamic} {dynamic} {dynamic} {dynamic} {dynamic} | tr | Runs click handler | No revision found in static review. | No |
| 1243 | TMDb | a | Navigates to {dynamic}; Runs click handler | No revision found in static review. | No |
| 1256 | IMDb | a | Navigates to {dynamic}; Runs click handler | No revision found in static review. | No |
| 1269 | Wikidata | a | Navigates to {dynamic}; Runs click handler | No revision found in static review. | No |
| 1282 | Wikipedia | a | Navigates to {dynamic}; Runs click handler | No revision found in static review. | No |
| 1295 | Website | a | Navigates to {dynamic}; Runs click handler | No revision found in static review. | No |
| 1349 | {dynamic} unresolved ( {dynamic} ) | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1356 | Export CSV | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1432 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |

### src/app/admin/news/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 321 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 329 | Back to Admin | Link | Navigates to {ADMIN_ROOT_PATH} | No revision found in static review. | No |
| 364 | Clear | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 379 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 394 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 458 | {dynamic} {dynamic} {dynamic} (icon/empty) (icon/empty) {dynamic} Wordmark: {dynamic} · Icon: {dynamic} {dynamic} | article | Runs click handler | No revision found in static review. | No |
| 542 | {dynamic} {dynamic} {dynamic} (icon/empty) (icon/empty) {dynamic} Wordmark: {dynamic} · Icon: {dynamic} {dynamic} | article | Runs click handler | No revision found in static review. | No |

### src/app/admin/other/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 223 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 231 | Back to Admin | Link | Navigates to {ADMIN_ROOT_PATH} | No revision found in static review. | No |
| 251 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 282 | {dynamic} {dynamic} (icon/empty) (icon/empty) {dynamic} {dynamic} | article | Runs click handler | No revision found in static review. | No |

### src/app/admin/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 218 | {dynamic} {dynamic} {dynamic} Open (icon/empty) | Link | Navigates to {dynamic} | No revision found in static review. | No |
| 271 | {dynamic} {dynamic} {dynamic} | Link | Navigates to {dynamic} | No revision found in static review. | No |

### src/app/admin/reddit-post-details/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 1567 | {dynamic} {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1604 | Retry | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1624 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1632 | Sync Details | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1642 | Back to Window | a | Navigates to {windowHref} | No revision found in static review. | No |
| 1692 | Refresh runs | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1702 | Attach | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1733 | Open on Reddit | a | Navigates to {dynamic} | No revision found in static review. | No |
| 1804 | Source | a | Navigates to {dynamic} | No revision found in static review. | No |
| 1813 | Hosted | a | Navigates to {dynamic} | No revision found in static review. | No |

### src/app/admin/reddit-window-posts/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 1994 | Retry | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 2024 | Sync posts, comments, details, and media for this window | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 2033 | Back to Community | a | Navigates to {communityHref} | No revision found in static review. | No |
| 2083 | Refresh runs | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 2093 | Attach | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 2181 | View Details | a | Navigates to {detailsHref} | No revision found in static review. | No |
| 2188 | Open Post | a | Navigates to {dynamic} | No revision found in static review. | No |
| 2228 | View Details | a | Navigates to {detailsHref} | No revision found in static review. | No |
| 2235 | Open Post | a | Navigates to {dynamic} | No revision found in static review. | No |
| 2247 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 2260 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 2302 | View Details | a | Navigates to {detailsHref} | No revision found in static review. | No |
| 2309 | Open Post | a | Navigates to {dynamic} | No revision found in static review. | No |
| 2344 | View Details | a | Navigates to {detailsHref} | No revision found in static review. | No |
| 2351 | Open Post | a | Navigates to {dynamic} | No revision found in static review. | No |
| 2393 | View Details | a | Navigates to {detailsHref} | No revision found in static review. | No |
| 2400 | Open Post | a | Navigates to {dynamic} | No revision found in static review. | No |

### src/app/admin/scrape-images/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 851 | &larr; Admin | Link | Navigates to {ADMIN_ROOT_PATH} | No revision found in static review. | No |
| 872 | Dismiss | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 889 | Show/Season | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 900 | Person | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 956 | {dynamic} {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1022 | {dynamic} {dynamic} {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1068 | × | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1083 | {dynamic} | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |
| 1117 | {dynamic} | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 1214 | Apply | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1248 | Apply | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1267 | Clear | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1278 | Clear all people tags | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1307 | {dynamic} {dynamic} | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 1430 | Search | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1592 | {dynamic} | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |
| 1702 | Scrape Another URL | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |

### src/app/admin/settings/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 38 | Back to Admin | Link | Navigates to / | Point this control to /admin (ADMIN_ROOT_PATH), or change the label if the public home page is intentional. | Yes |

### src/app/admin/social/bravo-content/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 43 | Back to Social Analytics | Link | Navigates to /admin/social | No revision found in static review. | No |
| 74 | Back | Link | Navigates to {ADMIN_SOCIAL_PATH} | No revision found in static review. | No |
| 80 | Open Shows | Link | Navigates to /shows | No revision found in static review. | No |

### src/app/admin/social/creator-content/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 35 | Back to Social Analytics | Link | Navigates to /admin/social | No revision found in static review. | No |
| 65 | Back | Link | Navigates to {ADMIN_SOCIAL_PATH} | No revision found in static review. | No |

### src/app/admin/social/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 507 | {label} | button | Runs click handler; Button type is {type} | No revision found in static review. | No |
| 640 | {dynamic} | button | Button type is button | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 664 | {dynamic} {dynamic} people {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 760 | {dynamic} | Link | Navigates to {dynamic} | No revision found in static review. | No |
| 897 | {dynamic} | Link | Navigates to {dynamic} | No revision found in static review. | No |
| 1342 | Cancel | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1354 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1413 | Add social handle | button | Button type is button | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 1506 | Cancel | Button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1514 | {dynamic} | Button | Button type is submit; Has disabled state | No revision found in static review. | No |
| 1572 | {dynamic} | button | Button type is button | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 1664 | Cancel | Button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1672 | {dynamic} | Button | Button type is submit; Has disabled state | No revision found in static review. | No |
| 1806 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 2133 | Back to Admin | Link | Navigates to / | Point this control to /admin (ADMIN_ROOT_PATH), or change the label if the public home page is intentional. | Yes |
| 2171 | Back to Admin | Link | Navigates to / | Point this control to /admin (ADMIN_ROOT_PATH), or change the label if the public home page is intentional. | Yes |
| 2177 | Reddit Dashboard | Link | Navigates to {dynamic} | No revision found in static review. | No |

### src/app/admin/social/reddit/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 200 | Back to Social | Link | Navigates to {ADMIN_SOCIAL_PATH} | No revision found in static review. | No |

### src/app/admin/survey-responses/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 331 | Back to Admin Dashboard | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 338 | Back to Hub | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 345 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 455 | Previous | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 464 | Next | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 479 | Response ID {dynamic} Close {dynamic} {dynamic} | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 480 | Response ID {dynamic} Close {dynamic} {dynamic} | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 486 | Close | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/app/admin/surveys/[surveyKey]/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 755 | Back to Surveys | Link | Navigates to /admin/surveys | No revision found in static review. | No |
| 795 | Back to Surveys | Link | Navigates to /admin/surveys | No revision found in static review. | No |
| 807 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 921 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 995 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1106 | Reset to Defaults | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1113 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1135 | + Add Cast Member | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1181 | Edit | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1188 | Delete | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1212 | + Add Episode | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1257 | Set Current | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1266 | Edit | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1273 | Delete | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1299 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1307 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1427 | Prev | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1435 | Next | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1465 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1635 | Cancel | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1642 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1733 | Cancel | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1740 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1764 | Close | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1885 | Reset to default | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/app/admin/surveys/normalized/[surveySlug]/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 181 | {dynamic} | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 261 | {dynamic} | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |
| 268 | Delete Survey | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |

### src/app/admin/surveys/normalized/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 139 | {dynamic} | button | Button type is submit; Has disabled state | No revision found in static review. | No |
| 157 | {dynamic} / {dynamic} {dynamic} {dynamic} | Link | Navigates to {dynamic} | No revision found in static review. | No |

### src/app/admin/surveys/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 109 | Back to Dashboard | Link | Navigates to / | Point this control to /admin (ADMIN_ROOT_PATH), or change the label if the public home page is intentional. | Yes |
| 134 | + New Survey | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 157 | {dynamic} {dynamic} {dynamic} {dynamic} {dynamic} {dynamic} {dynamic} {dynamic} Updated {dynamic} Edit → | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |

### src/app/admin/trr-shows/[showId]/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 1843 | {dynamic} | a | Navigates to {dynamic} | No revision found in static review. | No |
| 1885 | {dynamic} | button | Button type is button; Has disabled state | No revision found in static review. | No |
| 1897 | {dynamic} | a | Navigates to {openUrl} | No revision found in static review. | No |
| 1942 | {dynamic} | button | Button type is button; Has disabled state | No revision found in static review. | No |
| 1951 | Cancel | button | Button type is button; Has disabled state | No revision found in static review. | No |
| 11949 | {dynamic} | Link | Navigates to {personHref} | No revision found in static review. | No |
| 11974 | {dynamic} | Link | Navigates to {personHref} | No revision found in static review. | No |
| 12004 | {dynamic} {dynamic} {dynamic} {dynamic} {dynamic} | Link | Navigates to {personHref} | No revision found in static review. | No |
| 12326 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 12366 | {dynamic} | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 12388 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 12416 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 12517 | (icon/empty) {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 12533 | (icon/empty) Filters | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 12542 | Auto-Load: {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 12554 | Clear Filters ( {dynamic} ) | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 12562 | Batch Jobs | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 12574 | (icon/empty) {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 12586 | (icon/empty) Import Images | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 12730 | {dynamic} | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 12757 | Load More Profile Pictures | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 12777 | {dynamic} | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 12804 | Load More Cast Promos | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 12983 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 12992 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 13003 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 13016 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 13092 | Retry Cast | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 13104 | Retry Cast | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 13116 | Retry Crew | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 13144 | Retry | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 13156 | Retry Roles | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 13176 | Retry Cast Intelligence | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 13183 | Retry Roles | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 13210 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 13217 | Retry failed only | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 13300 | Clear Filters | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 13373 | S {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 13412 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 13526 | {dynamic} {dynamic} {dynamic} | Link | Navigates to {dynamic} | No revision found in static review. | No |
| 13649 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 13657 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 13692 | Retry links | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 13701 | Retry roles | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 13719 | Cancel | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 13727 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 13737 | Edit Metadata | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 13798 | Clear premiere date | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 13957 | Add Role | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 13982 | Rename | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 13989 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 14010 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 14037 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 14075 | Delete | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 14121 | Delete | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 14167 | {dynamic} | a | Navigates to {dynamic} | No revision found in static review. | No |
| 14197 | Delete | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 14289 | Delete | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 14334 | Delete | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 14379 | Open Reddit Admin | Link | Navigates to /admin/social/reddit | No revision found in static review. | No |
| 14411 | Open Community | Link | Navigates to {dynamic} | No revision found in static review. | No |
| 14487 | Open Settings | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 14494 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 14590 | \| {dynamic} | a | Navigates to {dynamic} | No revision found in static review. | No |
| 14635 | Open Reddit Admin | Link | Navigates to /admin/social/reddit | No revision found in static review. | No |
| 14667 | Open Community | Link | Navigates to {dynamic} | No revision found in static review. | No |
| 14720 | {dynamic} | a | Navigates to {dynamic} | No revision found in static review. | No |
| 14942 | Open Settings | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 14966 | (icon/empty) {dynamic} | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |
| 14977 | (icon/empty) {dynamic} | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |
| 15129 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 15151 | Close | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 15377 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 15393 | Close | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 15422 | {dynamic} {dynamic} {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 15494 | Retry | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 15522 | {dynamic} {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 15667 | Sync All Info | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 15674 | Cast Info only | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 15682 | Cancel | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 15721 | Close | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 15789 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 16047 | {dynamic} {dynamic} | a | Navigates to {dynamic} | No revision found in static review. | No |
| 16657 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 16672 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 16707 | Close | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 16769 | Cancel | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 16777 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 16815 | Cancel | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 16823 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 16867 | Cancel | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 16875 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |

### src/app/admin/trr-shows/[showId]/seasons/[seasonNumber]/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 911 | {dynamic} ( {dynamic} ) {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 4920 | {dynamic} | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 4939 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 5002 | (icon/empty) | button | Runs click handler | Add visible text or aria-label so assistive tech can identify the control. | Yes |
| 5154 | Images | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 5165 | Videos | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 5176 | Branding | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 5191 | (icon/empty) {dynamic} | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |
| 5201 | (icon/empty) Filters | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 5210 | Batch Jobs | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 5221 | (icon/empty) Assign TMDb Backdrops | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |
| 5231 | (icon/empty) Import Images | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |
| 5278 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 5291 | Gallery Diagnostics Source quality, variant status, and quick risk filters. Assets {dynamic} Missing variants {dynamic} Oversized {dynamic} Unclassified {dynamic} Fallback recovered {dynamic} Fallback failed {dynamic} (icon/empty) | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 5350 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 5406 | (icon/empty) | button | Runs click handler | Add visible text or aria-label so assistive tech can identify the control. | Yes |
| 5431 | (icon/empty) | button | Runs click handler | Add visible text or aria-label so assistive tech can identify the control. | Yes |
| 5455 | (icon/empty) | button | Runs click handler | Add visible text or aria-label so assistive tech can identify the control. | Yes |
| 5479 | {dynamic} | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 5508 | {dynamic} | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 5537 | {dynamic} | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 5566 | (icon/empty) | button | Runs click handler | Add visible text or aria-label so assistive tech can identify the control. | Yes |
| 5590 | (icon/empty) | button | Runs click handler | Add visible text or aria-label so assistive tech can identify the control. | Yes |
| 5614 | (icon/empty) | button | Runs click handler | Add visible text or aria-label so assistive tech can identify the control. | Yes |
| 5635 | Load More Images | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 5658 | Retry | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 5695 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 5769 | Open Show News | Link | Navigates to {dynamic} | No revision found in static review. | No |
| 5788 | Sync by Fandom | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 5817 | View on Fandom → | a | Navigates to {dynamic} | No revision found in static review. | No |
| 5869 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 5878 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 5888 | Cancel | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 5911 | Retry Crew | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 5943 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 5950 | Retry failed only | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 5985 | Retry | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 5997 | Retry | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 6015 | Retry | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 6082 | Clear Filters | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 6113 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 6148 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 6204 | {dynamic} {dynamic} {dynamic} Role: {dynamic} {dynamic} {dynamic} | Link | Navigates to {dynamic} | No revision found in static review. | No |
| 6260 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 6360 | {dynamic} {dynamic} {dynamic} archived episodes this season {dynamic} | Link | Navigates to {dynamic} | No revision found in static review. | No |
| 6605 | Close | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 6667 | Cancel | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 6675 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 6755 | Close | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 6763 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 6780 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 6809 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/app/admin/trr-shows/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 446 | Open show settings | Link | Navigates to /shows/settings | No revision found in static review. | No |
| 473 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 481 | Back to Admin | Link | Navigates to / | Point this control to /admin (ADMIN_ROOT_PATH), or change the label if the public home page is intentional. | Yes |
| 546 | {dynamic} {dynamic} {dynamic} | Link | Navigates to {dynamic} | No revision found in static review. | No |
| 586 | {dynamic} | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |
| 647 | Retry | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 747 | {dynamic} | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |

### src/app/admin/trr-shows/people/[personId]/PersonPageClient.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 2492 | × | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 2546 | {dynamic} {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 2562 | Add “ {dynamic} ” | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 2683 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 2692 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 2711 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 2775 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 2783 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 2810 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 10062 | Refresh Log ( {dynamic} ) | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 10076 | Clear | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 10146 | {dynamic} | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 10180 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 10244 | View all → | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 10254 | (icon/empty) | button | Runs click handler | Add visible text or aria-label so assistive tech can identify the control. | Yes |
| 10277 | View all → | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 10293 | {dynamic} {dynamic} {dynamic} cast {dynamic} crew | Link | Navigates to {dynamic} | No revision found in static review. | No |
| 10328 | View all → | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 10407 | Up | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 10415 | Down | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 10428 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 10436 | Reset | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 10494 | {dynamic} | a | Navigates to {dynamic} | No revision found in static review. | No |
| 10641 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 10660 | {dynamic} | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |
| 10675 | {dynamic} | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |
| 10735 | Sync source + mirror stages. | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |
| 10743 | Run Tagging stage (face boxes + identity + owner focus) for existing images. | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |
| 10751 | Run Crop (save thumbnail framing/focus metadata) for existing images. | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |
| 10759 | Run ID Text stage for existing images. | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |
| 10767 | Run Auto-Crop (resize variants) stage for existing images. | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |
| 10776 | (icon/empty) Filters | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 10785 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 10796 | (icon/empty) Import Images | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 10836 | Run Person Pipeline on filtered scope | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 10848 | Run Person Pipeline on full gallery | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 10878 | All Media ( {dynamic} ) | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 10891 | {dynamic} ( {dynamic} ) | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 10904 | {dynamic} ( {dynamic} ) | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 10921 | {dynamic} ( {dynamic} ) | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 10934 | {dynamic} ( {dynamic} ) | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 10990 | {dynamic} ( {dynamic} ) | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 11040 | (icon/empty) | button | Runs click handler; Button type is button | Add visible text or aria-label so assistive tech can identify the control. | Yes |
| 11053 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 11089 | (icon/empty) | button | Runs click handler; Button type is button | Add visible text or aria-label so assistive tech can identify the control. | Yes |
| 11102 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 11129 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 11159 | {dynamic} {dynamic} {dynamic} Click to scrape | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 11206 | Clear References Filter | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 11245 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 11405 | Open Show | Link | Navigates to {dynamic}; Runs click handler | No revision found in static review. | No |
| 11612 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 11620 | Sync by Fandom | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 11654 | View on Fandom → | a | Navigates to {dynamic} | No revision found in static review. | No |
| 11780 | {dynamic} · @ {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 11798 | Open account page | Link | Navigates to {dynamic} | No revision found in static review. | No |

### src/app/admin/users/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 38 | Back to Admin | Link | Navigates to / | Point this control to /admin (ADMIN_ROOT_PATH), or change the label if the public home page is intentional. | Yes |

### src/app/auth/finish/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 491 | Deselect all | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 522 | Don&apos;t see a show? Request on here | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 541 | Add | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 553 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 577 | {dynamic} | button | Button type is submit; Has disabled state | No revision found in static review. | No |

### src/app/auth/forgot-password/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 59 | The Reality Report | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 112 | {dynamic} | button | Button type is submit; Has disabled state | No revision found in static review. | No |
| 128 | request a new one. | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |

### src/app/auth/register/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 322 | Edit | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 351 | Edit | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 491 | {dynamic} | button | Button type is submit; Has disabled state | No revision found in static review. | No |
| 515 | (icon/empty) {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 548 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |

### src/app/brands/[brandSlug]/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 164 | Manage Logos | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 255 | Open Profile | Link | Navigates to {dynamic} | No revision found in static review. | No |
| 262 | Open Platform | a | Navigates to {dynamic} | No revision found in static review. | No |
| 277 | {dynamic} | Link | Navigates to {dynamic} | No revision found in static review. | No |
| 466 | Manage Logos | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 475 | Open Section | Link | Navigates to {dynamic} | No revision found in static review. | No |
| 508 | {dynamic} {dynamic} / {dynamic} | Link | Navigates to {dynamic} | No revision found in static review. | No |
| 537 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 564 | View More Logos | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 591 | View More | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 603 | {url} | a | Navigates to {url} | No revision found in static review. | No |
| 664 | {dynamic} {dynamic} {dynamic} | Link | Navigates to {dynamic} | No revision found in static review. | No |
| 755 | {url} | a | Navigates to {url} | No revision found in static review. | No |

### src/app/brands/shows-and-franchises/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 425 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 433 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 441 | Open Shows Settings | Link | Navigates to /shows/settings | No revision found in static review. | No |
| 447 | Back to Admin | Link | Navigates to / | No revision found in static review. | No |
| 524 | Search | button | Button type is submit | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 530 | Clear | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 555 | {dynamic} {dynamic} {dynamic} (icon/empty) (icon/empty) {dynamic} Wordmark: {dynamic} · Icon: {dynamic} {dynamic} · Assets: {dynamic} {dynamic} | article | Runs click handler | No revision found in static review. | No |
| 662 | {dynamic} {dynamic} {dynamic} (icon/empty) (icon/empty) {dynamic} Wordmark: {dynamic} · Icon: {dynamic} {dynamic} · Assets: {dynamic} {dynamic} | article | Runs click handler | No revision found in static review. | No |

### src/app/bravodle/cover/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 230 | Go back | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 262 | {dynamic} | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |
| 291 | (icon/empty) | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 301 | Close settings | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/app/bravodle/play/completed-view.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 97 | Back to puzzle (icon/empty) | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 159 | Share (icon/empty) | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |

### src/app/bravodle/play/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 247 | (icon/empty) | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 253 | Close How to Play | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 285 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 304 | Got it | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1028 | Back to Cover | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 1162 | (icon/empty) | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 1166 | Close settings | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1181 | AGE | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1182 | ZODIAC | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1250 | Close report a problem | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1317 | Cancel | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1325 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1403 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1856 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1993 | {aria} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |

### src/app/flashback/play/clue-card.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 117 | Tap to confirm | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/app/flashback/play/timeline.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 81 | {ariaLabel} | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/app/hub/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 86 | {dynamic} | button | Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |

### src/app/hub/surveys/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 129 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 395 | Exit | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 431 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 452 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 475 | {dynamic} {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 523 | Back | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 531 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |

### src/app/login/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 157 | Edit | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 194 | {dynamic} | button | Button type is submit; Has disabled state | No revision found in static review. | No |
| 212 | (icon/empty) {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 244 | Forgot password? | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 257 | Create one here | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/app/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 261 | Go to hub | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 273 | Finish profile | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 280 | Sign out | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 357 | Continue | button | Button type is submit | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 378 | Continue with Google | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/app/people/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 66 | {dynamic} {dynamic} {dynamic} {dynamic} {dynamic} | Link | Navigates to {href} | No revision found in static review. | No |
| 364 | {dynamic} {dynamic} | Link | Navigates to {dynamic}; Runs click handler | No revision found in static review. | No |

### src/app/profile/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 179 | Go to login | Link | Navigates to /login | No revision found in static review. | No |
| 216 | Update photo | button | Button type is button | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 246 | Edit interests | Link | Navigates to /hub/surveys | No revision found in static review. | No |
| 252 | Update profile | Link | Navigates to /auth/finish | No revision found in static review. | No |

### src/app/realitease/cover/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 230 | Go back | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 262 | {dynamic} | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |
| 290 | (icon/empty) | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 300 | Close settings | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/app/realitease/play/completed-view.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 96 | Back to puzzle (icon/empty) | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 158 | Share (icon/empty) | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |

### src/app/realitease/play/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 292 | (icon/empty) | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 298 | Close How to Play | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 330 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 349 | Got it | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1085 | Back to Cover | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 1188 | (icon/empty) | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 1192 | Close settings | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1210 | AGE | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1211 | ZODIAC | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1217 | NETWORKS | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1218 | STREAMERS | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1313 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1380 | Close report a problem | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1447 | Cancel | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1455 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1894 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 2031 | {aria} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |

### src/app/shows/settings/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 613 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 621 | Open Show Branding | Link | Navigates to /brands/shows-and-franchises | No revision found in static review. | No |
| 627 | Back to Shows | Link | Navigates to /shows | No revision found in static review. | No |
| 668 | Franchises | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 676 | Networks | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 856 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 864 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 872 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1147 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1155 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1163 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1248 | Imported Wikipedia Diagnostics | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/app/surveys/cast-verdict-demo/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 56 | Try Full Cast Flow | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 80 | Start Over | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/app/surveys/rhop-s10/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 39 | Start Ranking | Link | Navigates to /surveys/rhop-s10/play | No revision found in static review. | No |
| 45 | See Results | Link | Navigates to /surveys/rhop-s10/results | No revision found in static review. | No |

### src/app/surveys/rhop-s10/play/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 182 | Back to Cover | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 203 | See Results | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 210 | Back to Cover | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 227 | RHOP · Season 10 | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 265 | Reset selections | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 285 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |

### src/app/surveys/rhop-s10/results/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 15 | Update My Ranking | Link | Navigates to /surveys/rhop-s10/play | No revision found in static review. | No |

### src/app/surveys/rhoslc-s6/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 143 | Back to Hub | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 166 | Back | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 234 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |

### src/app/surveys/rhoslc-s6/play/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 255 | Back to Cover | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 278 | See Results | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 285 | Back to Cover | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 302 | Back | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 353 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 384 | Add rating | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 394 | Submit without rating | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/app/surveys/rhoslc-s6/results/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 68 | Sign In | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 84 | Back | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 167 | Go to Survey | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/app/test-auth/page.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 54 | Sign out | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 65 | {dynamic} | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |

### src/components/DebugPanel.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 34 | DEBUG | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 50 | × | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 59 | Refresh | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 65 | Clear | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 71 | Export | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |

### src/components/ErrorBoundary.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 43 | Refresh Page | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |

### src/components/GameHeader.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 147 | {ariaLabel} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 164 | Go to profile | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 177 | View statistics | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 191 | Help | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 210 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 230 | Settings | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 249 | Game Settings | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 261 | Sign Out | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/components/GlobalHeader.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 105 | Open navigation menu | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 119 | Go to home | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 138 | Go to profile | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 150 | Settings | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 169 | Admin Dashboard | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 181 | Sign Out | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/components/SideMenuProvider.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 234 | Close menu | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 247 | + Expand All | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 282 | (icon/empty) | button | Runs click handler; Button type is button | Add visible text or aria-label so assistive tech can identify the control. | Yes |
| 352 | Log Out | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 372 | (icon/empty) | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |

### src/components/SignOutButton.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 14 | Sign out | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |

### src/components/admin/AdminApiReferencesLibraryContent.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 326 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 347 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 362 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 384 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 405 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 420 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 441 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 456 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 473 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 636 | Open in editor | a | Navigates to {sourceHref} | No revision found in static review. | No |

### src/components/admin/AdminDocsCatalogContent.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 101 | All ( {dynamic} ) | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 115 | {dynamic} ( {dynamic} ) | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 132 | All ( {dynamic} ) | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 144 | {dynamic} ( {dynamic} ) | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 163 | All ( {dynamic} ) | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 175 | {dynamic} ( {dynamic} ) | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/components/admin/AdminGlobalHeader.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 52 | Open admin navigation menu | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/components/admin/AdminGlobalSearch.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 234 | Open admin search | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 278 | {dynamic} | Link | Navigates to {dynamic}; Runs click handler | No revision found in static review. | No |
| 300 | {dynamic} {dynamic} | Link | Navigates to {dynamic}; Runs click handler | No revision found in static review. | No |
| 343 | {dynamic} {dynamic} {dynamic} | Link | Navigates to {dynamic}; Runs click handler | No revision found in static review. | No |

### src/components/admin/AdminModal.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 133 | {closeLabel} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |

### src/components/admin/AdminSideMenu.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 143 | Close menu | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 190 | Toggle shows submenu | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 228 | View All Shows | Link | Navigates to {dynamic}; Runs click handler | No revision found in static review. | No |
| 244 | (icon/empty) | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |

### src/components/admin/AdvancedFilterDrawer.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 91 | (icon/empty) | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 112 | Clear | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 119 | Done | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 143 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 166 | Classify Visible Images | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 219 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 248 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 278 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/components/admin/BrandLogoOptionsModal.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 458 | {dynamic} | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 1339 | {dynamic} | Button | Runs click handler; Has disabled state | No revision found in static review. | No |
| 1343 | {dynamic} | Button | Runs click handler; Has disabled state | No revision found in static review. | No |
| 1356 | Add Slug | Button | Runs click handler; Has disabled state | No revision found in static review. | No |
| 1383 | Save | Button | No click/navigation behavior found | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 1384 | Cancel | Button | No click/navigation behavior found | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 1387 | Edit slug | Button | No click/navigation behavior found | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 1406 | Add | Button | Runs click handler; Has disabled state | No revision found in static review. | No |
| 1407 | Cancel | Button | Runs click handler; Has disabled state | No revision found in static review. | No |
| 1436 | Import Image URL | Button | Runs click handler; Has disabled state | No revision found in static review. | No |
| 1455 | {dynamic} ( {dynamic} ) | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1505 | Add Query | Button | Runs click handler; Has disabled state | No revision found in static review. | No |
| 1535 | Save | Button | Has disabled state | No revision found in static review. | No |
| 1536 | Cancel | Button | Has disabled state | No revision found in static review. | No |
| 1539 | Edit query | Button | Has disabled state | No revision found in static review. | No |
| 1558 | Add | Button | Runs click handler; Has disabled state | No revision found in static review. | No |
| 1565 | Cancel | Button | Runs click handler; Has disabled state | No revision found in static review. | No |
| 1588 | Add All Suggestions | Button | Runs click handler; Has disabled state | No revision found in static review. | No |
| 1615 | Add | Button | Runs click handler; Has disabled state | No revision found in static review. | No |
| 1648 | {dynamic} | Button | Runs click handler; Has disabled state | No revision found in static review. | No |
| 1754 | Load More | Button | Runs click handler; Has disabled state | No revision found in static review. | No |
| 1815 | {dynamic} | Button | Runs click handler; Has disabled state | No revision found in static review. | No |
| 1817 | {dynamic} | Button | Runs click handler; Has disabled state | No revision found in static review. | No |

### src/components/admin/BravotvImageRunPanel.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 521 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 541 | (icon/empty) {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 552 | Refresh Latest Run | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 561 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 690 | {dynamic} ( {dynamic} ) | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 706 | Clear filter | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 719 | All roles | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 731 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 756 | Open drawer | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 782 | All | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 794 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 819 | Approve selected | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 916 | Approve | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 955 | Close | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1024 | Ignore group | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1031 | Mark non-primary duplicates | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/components/admin/CastMatrixSyncPanel.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 72 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |

### src/components/admin/FandomSyncModal.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 174 | Close | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 304 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 318 | Next | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 334 | Back | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 341 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |

### src/components/admin/GalleryAssetEditTools.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 460 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 469 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 486 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 544 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 553 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 562 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 571 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |

### src/components/admin/ImageLightbox.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 879 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 889 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 899 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 910 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 924 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 944 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 964 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 983 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1003 | Open hosted media asset | a | Navigates to {hostedMediaUrl} | No revision found in static review. | No |
| 1019 | Open original source file | a | Navigates to {originalSourceFileUrl} | No revision found in static review. | No |
| 1167 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1409 | {dynamic} | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 1562 | {dynamic} | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |
| 1570 | {dynamic} | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |
| 1578 | {dynamic} | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |
| 1586 | {dynamic} | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |
| 1594 | {dynamic} | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |
| 1607 | {dynamic} | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |
| 1616 | {dynamic} | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |
| 1625 | {dynamic} | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |
| 1634 | {dynamic} | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |
| 1647 | {dynamic} | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |
| 1666 | {dynamic} | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |
| 1685 | {dynamic} | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |
| 1703 | {dynamic} | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |
| 1713 | {dynamic} | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |
| 1732 | {dynamic} | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |
| 1740 | {dynamic} | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |
| 2108 | Close lightbox | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 2119 | {dynamic} | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 2136 | Previous image | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 2150 | Next image | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 2163 | {dynamic} {dynamic} | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 2209 | Open Original Source | a | Navigates to {currentSrc} | No revision found in static review. | No |
| 2305 | Resize crop from top-left corner | button | Button type is button | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 2311 | Resize crop from top-right corner | button | Button type is button | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 2317 | Resize crop from bottom-left corner | button | Button type is button | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 2323 | Resize crop from bottom-right corner | button | Button type is button | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 2494 | (icon/empty) | button | Runs click handler | Add visible text or aria-label so assistive tech can identify the control. | Yes |

### src/components/admin/ImageScrapeDrawer.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 1235 | (icon/empty) | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 1257 | Close drawer | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |
| 1274 | Dismiss | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 1298 | {dynamic} | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |
| 1319 | {dynamic} | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 1461 | Apply | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1521 | {dynamic} {dynamic} | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 1658 | Search | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1787 | {dynamic} | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |
| 1868 | Link All | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 1897 | Link | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 1911 | Import More | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 1921 | Done | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |

### src/components/admin/NbcumvSeasonBios.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 114 | Retry | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |

### src/components/admin/PeopleSearchMultiSelect.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 95 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 139 | {dynamic} {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |

### src/components/admin/PersonExternalIdsEditor.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 51 | Add ID | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 61 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 98 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 108 | {dynamic} | a | Navigates to {previewUrl} | No revision found in static review. | No |
| 119 | Remove | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/components/admin/QuestionBuilder.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 167 | Dismiss | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 236 | {dynamic} | button | Button type is submit; Has disabled state | No revision found in static review. | No |
| 278 | Delete | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 308 | Remove | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 337 | Add | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 343 | Cancel | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 355 | + Add Option | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |

### src/components/admin/ReassignImageModal.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 190 | Re-assign Image (icon/empty) Currently assigned to: {dynamic} • {dynamic} {dynamic} Destination type: {dynamic} {dynamic} Search for {dynamic} {dynamic} : {dynamic} {dynamic} {dynamic} {dynamic} {dynamic} Cancel {dynamic} | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 194 | Re-assign Image (icon/empty) Currently assigned to: {dynamic} • {dynamic} {dynamic} Destination type: {dynamic} {dynamic} Search for {dynamic} {dynamic} : {dynamic} {dynamic} {dynamic} {dynamic} {dynamic} Cancel {dynamic} | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 203 | (icon/empty) | button | Runs click handler | Add visible text or aria-label so assistive tech can identify the control. | Yes |
| 286 | {dynamic} | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 327 | Cancel | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 333 | {dynamic} | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |

### src/components/admin/RedditCommunityViewPage.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 328 | Back | a | Navigates to {backHref} | No revision found in static review. | No |

### src/components/admin/ScreenalyticsPickerPage.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 183 | Show {dynamic} / {dynamic} Open {dynamic} {dynamic} | Link | Navigates to {href}; Runs click handler | No revision found in static review. | No |
| 237 | Recent show {dynamic} {dynamic} | Link | Navigates to {dynamic} | No revision found in static review. | No |

### src/components/admin/ShowBrandEditor.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 364 | Remove | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 534 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 542 | Seed from TRR Cast | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 549 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 624 | + Add | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1182 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1215 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1247 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1269 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1291 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1433 | Set as show icon | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1445 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1485 | Default Media Picker Select {dynamic} Close {dynamic} | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 1489 | Default Media Picker Select {dynamic} Close {dynamic} | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 1502 | Close | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1516 | {dynamic} {dynamic} {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1588 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |

### src/components/admin/SocialAccountProfilePage.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 7469 | (icon/empty) {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 7527 | {dynamic} | Link | Navigates to {href} | No revision found in static review. | No |
| 7565 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 7577 | Copy terminal command | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 7589 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 7597 | Copy terminal command | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 7610 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 7624 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 7681 | Retry | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 7714 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 7839 | Pending Review {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 7872 | Close pending review details | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 7916 | Open Hashtags | Link | Navigates to {dynamic}; Runs click handler | No revision found in static review. | No |
| 7941 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 8026 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 8077 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 8087 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 8129 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 8145 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 8163 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 8215 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 8345 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 8355 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 8418 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 8448 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 8705 | Recent Logs Latest worker events for this account run {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 8923 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 9031 | Previous | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 9042 | Next | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 9138 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 9147 | View Details | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 9283 | Previous | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 9291 | Next | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 9361 | Add Assignment | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 9369 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 9411 | Remove | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 9468 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 9627 | Close | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 9670 | Fast Bravo TV | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 9681 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 9713 | Fast Bravo TV | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 9724 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 9798 | Cancel | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 9805 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 9829 | Close | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/components/admin/SocialAdminPageHeader.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 29 | {dynamic} | Link | Navigates to {dynamic} | No revision found in static review. | No |

### src/components/admin/SurveyQuestionsEditor.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 1231 | Reset | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1238 | Close | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1261 | Dismiss | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 1274 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1282 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1398 | {dynamic} | button | Button type is submit; Has disabled state | No revision found in static review. | No |
| 1519 | Save | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1527 | Cancel | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1542 | Move up | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1551 | Move down | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1565 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1574 | Preview | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1582 | Edit | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1593 | Delete | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1625 | Save Icon | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1646 | {dynamic} Rows ( {dynamic} ) | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1702 | Save | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1710 | Cancel | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1725 | Move up | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1734 | Move down | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1746 | Edit | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1756 | Remove | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1798 | Add Row | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1806 | Cancel | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1822 | + Add Row | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1839 | {dynamic} Options ( {dynamic} ) | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1898 | Save | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1906 | Cancel | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1921 | Move up | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1930 | Move down | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1942 | Edit | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1952 | Remove | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1994 | Add Option | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 2002 | Cancel | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 2018 | + Add Option | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |

### src/components/admin/SurveyRunManager.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 161 | Dismiss | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 238 | {dynamic} | button | Button type is submit; Has disabled state | No revision found in static review. | No |
| 301 | {dynamic} | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 308 | Delete | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |

### src/components/admin/SystemHealthModal.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 1709 | By Platform | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1716 | By Stage | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1804 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1822 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1831 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1853 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1878 | Debug current job | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1990 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 2039 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 2083 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 2126 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 2231 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 2239 | Apply suggested patch | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 2292 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 3088 | Copy debug snapshot | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 3100 | Refresh | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 3135 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 3145 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 3155 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 3165 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 3240 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 3269 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 3402 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 3430 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 3443 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 3456 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 3477 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |

### src/components/admin/UnifiedBrandsWorkspace.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 785 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 801 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 809 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 817 | Back to Admin | Link | Navigates to / | Point this control to /admin (ADMIN_ROOT_PATH), or change the label if the public home page is intentional. | Yes |
| 832 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 914 | {dynamic} {dynamic} {dynamic} {dynamic} (icon/empty) (icon/empty) {dynamic} {dynamic} | tr | Runs click handler | No revision found in static review. | No |
| 986 | TMDb | a | Navigates to {dynamic}; Runs click handler | No revision found in static review. | No |
| 997 | IMDb | a | Navigates to {dynamic}; Runs click handler | No revision found in static review. | No |
| 1008 | Wikidata | a | Navigates to {dynamic}; Runs click handler | No revision found in static review. | No |
| 1019 | Wikipedia | a | Navigates to {dynamic}; Runs click handler | No revision found in static review. | No |
| 1030 | Site | a | Navigates to {dynamic}; Runs click handler | No revision found in static review. | No |
| 1071 | {dynamic} {dynamic} {dynamic} (icon/empty) (icon/empty) {dynamic} Wordmark: {dynamic} · Icon: {dynamic} {dynamic} {dynamic} {dynamic} | article | Runs click handler | No revision found in static review. | No |

### src/components/admin/cast-content-section.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 189 | Retry | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 224 | {dynamic} | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 254 | {dynamic} | Link | Navigates to {dynamic} | No revision found in static review. | No |
| 296 | {dynamic} | a | Navigates to {dynamic} | No revision found in static review. | No |
| 321 | View Social (icon/empty) | Link | Navigates to {dynamic} | No revision found in static review. | No |

### src/components/admin/cast-socialblade-comparison.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 1321 | {dynamic} | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |
| 1329 | Retry Failed | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |
| 1372 | {dynamic} | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |
| 1380 | Retry Failed | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |

### src/components/admin/color-lab/ImagePaletteLab.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 664 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 721 | Increase palette count | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 730 | Decrease palette count | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 750 | Apply Palette to Brand Fields | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 790 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 839 | {dynamic} | button | Button type is button | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 891 | Refresh | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 926 | Delete | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 935 | {dynamic} Click to load palette + markers | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/components/admin/color-lab/ImageSourceModal.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 261 | Select Image Close {dynamic} Library Scope Show {dynamic} {dynamic} Season ALL {dynamic} {dynamic} {dynamic} {dynamic} {dynamic} | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 262 | Select Image Close {dynamic} Library Scope Show {dynamic} {dynamic} Season ALL {dynamic} {dynamic} {dynamic} {dynamic} {dynamic} | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 268 | Close | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 284 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 322 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 360 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 417 | Use URL | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 444 | {dynamic} {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/components/admin/color-lab/PaletteExportPanel.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 83 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 90 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 97 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 104 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 113 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 121 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/components/admin/color-lab/ShadeThemePanels.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 20 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/components/admin/comments/AdminCommentThread.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 55 | {dynamic} | a | Navigates to {mediaUrl} | No revision found in static review. | No |
| 172 | {dynamic} {dynamic} {dynamic} {dynamic} | Button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/components/admin/design-docs/AIIllustration.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 240 | Original | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 256 | TRR | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 288 | {dynamic} | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 355 | {dynamic} | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |
| 454 | Re-generate | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 552 | Retry | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 578 | (icon/empty) Generate with {dynamic} | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 687 | Close lightbox {dynamic} Prompt {dynamic} | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 712 | Close lightbox | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 739 | {dynamic} Prompt {dynamic} | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |

### src/components/admin/design-docs/ArticleDetailPage.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 85 | Close {dynamic} | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 87 | Close | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 131 | {dynamic} | button | Button type is button | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 218 | Listen to article | button | Button type is button | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 360 | {dynamic} | button | Button type is button | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 1574 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1642 | Close table of contents | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1706 | {dynamic} | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 3775 | Play today&apos;s puzzle (icon/empty) | button | No click/navigation behavior found | Add a real action, convert it to a link, or render it as non-button text. | Yes |

### src/components/admin/design-docs/DesignDocsPageClient.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 251 | Open navigation | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |

### src/components/admin/design-docs/DesignDocsSidebar.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 115 | {dynamic} (icon/empty) | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 451 | Close navigation | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 488 | (icon/empty) | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |

### src/components/admin/design-docs/FilterCardTracker.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 108 | {dynamic} {dynamic} {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 228 | {dynamic} {dynamic} {dynamic} {dynamic} {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 336 | Expand all | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 341 | Collapse all | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/components/admin/design-docs/InteractiveTariffRateTable.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 161 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/components/admin/design-docs/NytInteractiveShell.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 32 | {label} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 329 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 354 | Section Navigation | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 366 | Section Navigation | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 398 | Close Section Navigation | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 464 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 675 | {dynamic} | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 688 | {dynamic} | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 715 | Close Search | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 821 | Account Information | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 830 | Account Information | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 869 | Close Account Information | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/components/admin/design-docs/VotingDeadlinesArticle.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 386 | (icon/empty) | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 418 | Close menu | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 457 | {dynamic} &#9654; | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 781 | Gift this article | button | No click/navigation behavior found | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 788 | Share | button | No click/navigation behavior found | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 794 | Save | button | No click/navigation behavior found | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 902 | {dynamic} | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 959 | Open navigation menu | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |

### src/components/admin/design-docs/sections/AnimationsSection.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 456 | Hover Me | button | Button type is button | Add a real action, convert it to a link, or render it as non-button text. | Yes |

### src/components/admin/design-docs/sections/CarouselsSection.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 89 | {dynamic} | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 125 | (icon/empty) | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 393 | {dynamic} | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 445 | {dynamic} {dynamic} | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |

### src/components/admin/design-docs/sections/FormsSection.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 724 | Add Show | button | Button type is button | Add a real action, convert it to a link, or render it as non-button text. | Yes |

### src/components/admin/design-docs/sections/GalleriesSection.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 291 | {dynamic} | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |

### src/components/admin/design-docs/sections/IconsSection.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 385 | Search | button | Button type is button | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 505 | {dynamic} | button | Button type is button | Add a real action, convert it to a link, or render it as non-button text. | Yes |

### src/components/admin/design-docs/sections/InteractiveElementsSection.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 292 | Cancel | button | Button type is button | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 308 | Confirm | button | Button type is button | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 371 | Actions | button | Button type is button | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 650 | Filter | button | Button type is button | Add a real action, convert it to a link, or render it as non-button text. | Yes |

### src/components/admin/design-docs/sections/OverviewSection.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 383 | {dynamic} {dynamic} | Link | Navigates to {dynamic} | No revision found in static review. | No |

### src/components/admin/design-docs/sections/brand-athletic/BrandAthleticComponents.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 727 | Toggle menu | button | No click/navigation behavior found | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 1922 | International | button | No click/navigation behavior found | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 1923 | Stay on this edition | button | No click/navigation behavior found | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 2087 | International | button | No click/navigation behavior found | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 2092 | Stay on this edition | button | No click/navigation behavior found | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 2110 | Subscribe Now | button | No click/navigation behavior found | Add a real action, convert it to a link, or render it as non-button text. | Yes |

### src/components/admin/design-docs/sections/brand-athletic/BrandAthleticShapes.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 383 | Read More | button | No click/navigation behavior found | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 398 | Share | button | No click/navigation behavior found | Add a real action, convert it to a link, or render it as non-button text. | Yes |

### src/components/admin/design-docs/sections/brand-nyt/BrandNYTTypography.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 711 | {dynamic} {dynamic} font families &middot; {dynamic} {dynamic} &middot; {dynamic} &#9660; | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/components/admin/design-docs/sections/games/HubComponents.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 186 | Close subscription offer | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 353 | Navigation menu button | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 385 | Back | button | Button type is button | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 437 | Subscribe | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 956 | {dynamic} + | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1081 | {dynamic} {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1580 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1634 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/components/admin/design-docs/sections/games/NYTGamesPreviewShell.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 54 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 78 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 374 | Close table of contents | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/components/admin/design-system/BrandFontMatchesPanel.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 718 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 729 | Catalog | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 748 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/components/admin/design-system/ComponentsTab.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 420 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 452 | Save | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 462 | Cancel | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 474 | Edit | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 492 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 514 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 536 | Cancel | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 543 | Confirm | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 554 | Open modal | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 569 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 579 | Next image | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 596 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 608 | Run import | button | Button type is button | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 631 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 664 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 681 | Question list | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 682 | Live preview | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 740 | Next | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 802 | {dynamic} {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1199 | Set as Cover | button | Button type is button | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 1242 | {dynamic} poster_ {dynamic} .webp | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1362 | Save | Button | No click/navigation behavior found | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 1363 | Cancel | Button | No click/navigation behavior found | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 1381 | Hub | button | Button type is button | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 1382 | Admin | button | Button type is button | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 1521 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/components/admin/design-system/DesignSystemPageClient.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 1079 | {dynamic} {dynamic} {dynamic} Close {dynamic} {dynamic} {dynamic} This specimen keeps the original page’s typography feel while focusing on the text that actually uses this font. {dynamic} | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 1087 | {dynamic} {dynamic} {dynamic} Close {dynamic} {dynamic} {dynamic} This specimen keeps the original page’s typography feel while focusing on the text that actually uses this font. {dynamic} | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 1103 | Close | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1142 | Open actual page | a | Navigates to {dynamic} | No revision found in static review. | No |
| 1176 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1266 | {dynamic} {dynamic} {dynamic} used {dynamic} style {dynamic} {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1299 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1344 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1484 | {dynamic} {dynamic} CDN Font Reference {dynamic} used {dynamic} style {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1519 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1550 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1635 | Remove | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 2201 | Admin | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 2208 | Hub | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 2225 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 2242 | Catalog | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 2257 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 2330 | Add Base Color | button | Button type is submit | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 2470 | Catalog | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 2481 | Brand Matches | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 2492 | Typography Sets | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 2500 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 2553 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 2566 | Currently Used | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/components/admin/design-system/FontPairAudit.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 126 | {dynamic} → {dynamic} {dynamic} % | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 236 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/components/admin/design-system/TypographyTab.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 1165 | {dynamic} {dynamic} {dynamic} Close Example preview (icon/empty) {dynamic} | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 1173 | {dynamic} {dynamic} {dynamic} Close Example preview (icon/empty) {dynamic} | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 1189 | Close | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1213 | Open actual page | a | Navigates to {dynamic} | No revision found in static review. | No |
| 1686 | New Set | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1806 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1883 | {dynamic} {dynamic} | button | Button type is button | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 1949 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1998 | Mobile | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 2009 | Desktop | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 2023 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 2031 | Duplicate | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 2039 | Delete | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 2095 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 2162 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 2180 | Reset | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 2187 | Delete | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 2250 | Add Role | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/components/admin/image-lightbox/LightboxShell.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 14 | {alt} | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |

### src/components/admin/image-lightbox/ReplaceGettyDrawer.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 86 | Close | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 152 | {dynamic} | button | Runs click handler; Has disabled state | Add type="button" unless the control intentionally submits a form. | Yes |

### src/components/admin/instagram/InstagramCommentsPanel.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 1094 | {dynamic} | Button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1132 | Incomplete Fill | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1140 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1149 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1160 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1231 | {dynamic} {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1308 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1376 | Previous | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1387 | Next | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |

### src/components/admin/instagram/InstagramCommentsPostModal.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 595 | Open comment media | a | Navigates to {previewMediaUrl} | No revision found in static review. | No |
| 656 | Close | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 754 | {dynamic} | Button | Runs click handler; Button type is button | No revision found in static review. | No |
| 776 | Retry | Button | Runs click handler; Button type is button | No revision found in static review. | No |
| 795 | Previous | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 806 | Next | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |

### src/components/admin/instagram/PostScrapeCommentsButton.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 145 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |

### src/components/admin/reddit-sources-manager.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 1825 | Sync Posts | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1837 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1935 | Episode {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1964 | Sync Posts | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 1976 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 3579 | All flairs | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 3594 | {dynamic} · {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 7607 | Add Thread | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 7652 | {dynamic} : {dynamic} × | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 7677 | Add | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 7704 | + {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 7801 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 7835 | Export Sync Audit CSV | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 7986 | Clear filters | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 8109 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 8139 | Back to communities | a | Navigates to {dedicatedBackHref} | No revision found in static review. | No |
| 8156 | Open community settings | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 8177 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 8188 | Season {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 8267 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 8277 | Add Community | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 8285 | Add Thread | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 8295 | Sync Posts | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 8306 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 8317 | Enrich Missing Detail | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 8332 | Sync Posts | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 8343 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 8354 | Enrich Missing Detail | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 8363 | Delete | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 8494 | {dynamic} × | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 8516 | Add | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 8538 | + {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 8561 | {dynamic} × | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 8583 | Add | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 8605 | + {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 8622 | Save Community | button | Button type is submit; Has disabled state | No revision found in static review. | No |
| 8629 | Cancel | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 8699 | Save Thread | button | Button type is submit; Has disabled state | No revision found in static review. | No |
| 8706 | Cancel | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 8735 | Auto-Categorize All Flairs | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 8870 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 8946 | Open community settings | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 8967 | Community View | a | Navigates to {communityViewHref} | No revision found in static review. | No |
| 9013 | Community Settings Delete Close Display Name Save Display Name Defaults to the subreddit name without r/ . Post Flairs {dynamic} {dynamic} {dynamic} {dynamic} Community Scope {dynamic} Show-based Franchise-based Network-based Show-based communities include all discovered posts. Franchise-based and network-based communities use their configured focus targets. {dynamic} {dynamic} {dynamic} {dynamic} {dynamic} | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 9026 | Delete | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 9034 | Close | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 9055 | Save Display Name | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 9137 | Manage Flair Assignments | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 9186 | All posts | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 9198 | Scan terms | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 9212 | Advanced | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 9239 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 9282 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 9383 | {dynamic} × | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 9410 | Add | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 9439 | + {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 9475 | {dynamic} × | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 9502 | Add | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 9531 | + {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 9587 | {dynamic} {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 9630 | {dynamic} {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 9674 | Flair Assignments | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 9695 | Close | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 9702 | Save Assignments | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 9737 | {dynamic} {dynamic} assignments | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 9963 | Assigned Threads {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 10054 | Remove | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |

### src/components/admin/season-social-analytics-section.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 5993 | Close | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 6057 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 6108 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 6130 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 6140 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 6152 | Export CSV | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 6159 | Export PDF | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 6317 | Ingest + Export (icon/empty) | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 6381 | {dynamic} @ {dynamic} | Link | Navigates to {dynamic} | No revision found in static review. | No |
| 6455 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 6726 | {dynamic} (icon/empty) | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 6899 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 7253 | Post Count | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 7264 | Comment Count | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 7275 | Completeness | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 7290 | Compact | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 7304 | Comfortable | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 7319 | Alerts {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 7380 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 7424 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 7562 | Vs Prev | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 7573 | Vs 3wk | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 7633 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 7644 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 7661 | Total | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 7673 | Saved | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 7950 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 7962 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 8155 | Open leaderboard media lightbox | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 8187 | Open Post | a | Navigates to {dynamic} | No revision found in static review. | No |
| 8221 | Open discussion media lightbox | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 8255 | Open Post | a | Navigates to {dynamic} | No revision found in static review. | No |
| 8444 | Ingest Job Status {dynamic} {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 8461 | Refresh Jobs | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 8553 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 8579 | Retry Failed Stage | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 8623 | Manual Sources (Fallback) {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/components/admin/season-tabs/SeasonTabsNav.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 56 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/components/admin/show-tabs/FeaturedImageDrawer.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 66 | Close | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 86 | {dynamic} {dynamic} {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |

### src/components/admin/show-tabs/FeaturedLogoDrawer.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 93 | Close | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 124 | {dynamic} {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 195 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |

### src/components/admin/show-tabs/ShowAssetsImageSections.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 103 | {dynamic} {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 125 | Load More Backdrops | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 145 | {dynamic} {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 166 | Load More Posters | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 186 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 203 | Load More Banners | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/components/admin/show-tabs/ShowBrandLogosSection.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 82 | {dynamic} {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 122 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/components/admin/show-tabs/ShowCreditsViews.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 102 | Gallery View | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 112 | List View | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 127 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/components/admin/show-tabs/ShowFeaturedMediaSelectors.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 87 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |

### src/components/admin/show-tabs/ShowNewsTab.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 134 | Trending | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 145 | Latest | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 157 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 233 | Clear Filters | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 360 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |

### src/components/admin/show-tabs/ShowSeasonCards.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 75 | Season {dynamic} {dynamic} {dynamic} {dynamic} (icon/empty) | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 98 | (icon/empty) | span | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 127 | {dynamic} | Link | Navigates to {dynamic} | No revision found in static review. | No |

### src/components/admin/show-tabs/ShowSeasonsTab.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 86 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |

### src/components/admin/show-tabs/ShowTabsNav.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 56 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/components/admin/social-growth-section.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 723 | (icon/empty) {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 904 | Re-scrape SocialBlade data. Historical totals older than one day are preserved. | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 949 | Open following list | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 981 | Close following list | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1038 | Load next following page | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |

### src/components/admin/social-posts-section.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 385 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 395 | Add Post | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 421 | Dismiss | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 516 | {dynamic} | button | Button type is submit; Has disabled state | No revision found in static review. | No |
| 523 | Cancel | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 615 | Open | a | Navigates to {safeHref} | No revision found in static review. | No |
| 624 | Unsupported URL | button | Button type is button; Has disabled state | No revision found in static review. | No |
| 633 | Edit | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 641 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 680 | Add First Post | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/components/admin/social-week/WeekDetailPageView.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 3790 | (icon/empty) | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 3797 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 3805 | × | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 3887 | Open post media lightbox from details | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 3944 | Previous slide | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 3959 | Next slide | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 4092 | Replies | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 4104 | Quotes | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 4392 | Open post detail modal | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 4517 | Send To Cast Screentime | Link | Navigates to {castScreentimeImportHref} | No revision found in static review. | No |
| 4524 | Post Details {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 8255 | {dynamic} | Link | Navigates to {dynamic} | No revision found in static review. | No |
| 8269 | {dynamic} {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 8324 | Clear day filter | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 8348 | {dynamic} ( {dynamic} ) | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 8397 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 8418 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 8642 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 8683 | Attach to selected run | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 8726 | Cancel Sync | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 8811 | Retry | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 8834 | Recent Run Log {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 9055 | {dynamic} {dynamic} {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 9123 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 9139 | (icon/empty) | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 9148 | Close token summary list | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 9218 | View | a | Navigates to {dynamic} | No revision found in static review. | No |

### src/components/admin/surveys-section.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 358 | Create Survey | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 373 | Dismiss | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |
| 553 | {dynamic} | button | Button type is submit; Has disabled state | No revision found in static review. | No |
| 560 | Cancel | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 626 | Manage | Link | Navigates to {dynamic} | No revision found in static review. | No |
| 632 | Responses | Link | Navigates to {dynamic} | No revision found in static review. | No |
| 638 | Preview | Link | Navigates to {dynamic} | No revision found in static review. | No |
| 689 | Create First Survey | button | Runs click handler | Add type="button" unless the control intentionally submits a form. | Yes |

### src/components/admin/tiktok-season-analytics-section.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 485 | Refresh | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 524 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 533 | Save Cast Preset | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 543 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 544 | x | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 574 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 685 | {dynamic} Usage {dynamic} · Creator posts {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 735 | Post Detail | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 770 | Post Detail | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 818 | Close | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/components/cast-verdict.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 126 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 160 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 282 | Back | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 295 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |

### src/components/episode-rating.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 180 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/components/ex-wife-verdict.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 121 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 154 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/components/flashback-ranker.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 1093 | {dynamic} | button | Button type is button | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 1162 | {dynamic} | button | Button type is button | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 1299 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1316 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1356 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1373 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1396 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1424 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1487 | {dynamic} Close picker {dynamic} | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 1488 | {dynamic} Close picker {dynamic} | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 1502 | Close picker | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1531 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1553 | {dynamic} {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1614 | {dynamic} Close picker {dynamic} | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 1615 | {dynamic} Close picker {dynamic} | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 1637 | Close picker | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1663 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 1685 | {dynamic} {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/components/public/PublicRouteShell.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 59 | {dynamic} | Link | Navigates to {dynamic} | No revision found in static review. | No |

### src/components/season-rating.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 218 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/components/survey/CastCircleToken.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 56 | {dynamic} | button | Button type is {type} | Add a real action, convert it to a link, or render it as non-button text. | Yes |

### src/components/survey/CastDecisionCardInput.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 685 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |

### src/components/survey/CastMultiSelectInput.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 457 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |

### src/components/survey/MatrixLikertInput.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 626 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |

### src/components/survey/MultiSelectInput.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 288 | {dynamic} {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 339 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |

### src/components/survey/MultiSelectPills.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 72 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |

### src/components/survey/NormalizedSurveyPlay.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 262 | Go Back | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 285 | Go Back | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 308 | View Results | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 328 | ← Back | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 386 | Go to previous question | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 480 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |

### src/components/survey/PosterSingleSelect.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 396 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |

### src/components/survey/RankTextFields.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 242 | {dynamic} | button | Button type is button; Has disabled state | No revision found in static review. | No |

### src/components/survey/ReunionSeatingPredictionInput.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 404 | {label} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |

### src/components/survey/SingleSelectCastInput.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 387 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |

### src/components/survey/SingleSelectInput.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 281 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 314 | {dynamic} {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |
| 361 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |

### src/components/survey/SurveyContinueButton.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 85 | {dynamic} | button | Button type is {type} | Add a real action, convert it to a link, or render it as non-button text. | Yes |

### src/components/survey/TwoAxisGridInput.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 403 | Two axis grid board | div | Runs click handler | Use a real button/link, or add keyboard support and an accessible name. | Yes |
| 493 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/components/survey/TwoChoiceCast.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 263 | {dynamic} | button | Runs click handler; Button type is button; Has disabled state | No revision found in static review. | No |

### src/components/ui/button.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 37 | (icon/empty) | button | Button type is {type} | Add a real action, convert it to a link, or render it as non-button text. | Yes |

### src/components/ui/editable.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 167 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 192 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 211 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |

### src/components/uitripled/comment-thread-shadcnui.tsx

| Line | UI text/icon | Element | What it does | What it should do | Revise? |
|---:|---|---|---|---|---|
| 216 | Add image | Button | Button type is button | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 226 | Attach file | Button | Button type is button | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 236 | Add emoji | Button | Button type is button | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 249 | Cancel reply | Button | Runs click handler; Button type is button | No revision found in static review. | No |
| 260 | {dynamic} | Button | Runs click handler; Button type is submit; Has disabled state | No revision found in static review. | No |
| 371 | {dynamic} | Button | Button type is button | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 402 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 426 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 446 | {dynamic} | button | Button type is button | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 503 | {dynamic} | button | Runs click handler; Button type is button | No revision found in static review. | No |
| 633 | Sort by newest | Button | Button type is button | Add a real action, convert it to a link, or render it as non-button text. | Yes |
| 643 | Sort by top | Button | Button type is button | Add a real action, convert it to a link, or render it as non-button text. | Yes |


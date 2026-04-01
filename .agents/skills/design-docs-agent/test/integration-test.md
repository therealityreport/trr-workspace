# Integration Test: Design Docs Brand Page Generator Agent

## Purpose

Validate the Design Docs Brand Page Generator Agent end-to-end against the
existing NYT reference implementation. This test uses a known-good article as
input and asserts that every generated artifact matches the established baseline.

---

## Test: NYT Trump Economy Article (Known-Good Reference)

### Test Input

The existing NYT article "Trump Said He'd Unleash the Economy in Year 1.
Here's How He Did." serves as the test case.

Inputs to provide:

| Parameter        | Value |
|------------------|-------|
| **brandName**    | `"New York Times"` |
| **articleUrl**   | `https://www.nytimes.com/interactive/2026/01/19/business/economy/trump-economy.html` |

**cssUrls** (4 stylesheets):

1. `global-bf55b3b62e74478ad488922130f07a8e.css` -- NYT vi platform global styles
2. `web-fonts.c851560786173ad206e1f76c1901be7e096e8f8b.css` -- 7 proprietary fonts
3. `2.DkPSoQwJ.css` -- Birdkit theme
4. `index.CyB6tk6K.css` -- Birdkit components

**datawrapperUrls** (8 charts):

| # | URL | Label |
|---|-----|-------|
| 1 | `https://datawrapper.dwcdn.net/2Iq0I/6/?plain=1` | Food Prices |
| 2 | `https://datawrapper.dwcdn.net/JRwRC/6/?plain=1` | Gas Prices |
| 3 | `https://datawrapper.dwcdn.net/tKBPt/5/?plain=1` | Electricity |
| 4 | `https://datawrapper.dwcdn.net/WMpGc/6/?plain=1` | Auto Jobs |
| 5 | `https://datawrapper.dwcdn.net/Y9bME/5/?plain=1` | Manufacturing |
| 6 | `https://datawrapper.dwcdn.net/HwUbK/3/?plain=1` | S&P 500 |
| 7 | `https://datawrapper.dwcdn.net/FPRyD/5/?plain=1` | Tariff Revenue |
| 8 | `https://datawrapper.dwcdn.net/UosFj/4/?plain=1` | Trade Deficit |

---

### Expected Outputs

#### 1. CSS Token Extraction

**Font families** -- must find 6 or more:

- `nyt-cheltenham`
- `nyt-franklin`
- `nyt-imperial`
- `nyt-karnak`
- `nyt-karnakcondensed`
- `nyt-cheltenham-cond`

**Core colors**:

| Token use   | Expected value |
|-------------|----------------|
| Body text   | `#363636`      |
| Link blue   | `#326891`      |
| Headings    | `#121212`      |

**Layout widths**:

| Context | Width   |
|---------|---------|
| Body    | `600px` |
| Wide    | `1050px`|

#### 2. Page Structure

| Field     | Expected value |
|-----------|----------------|
| Title     | Starts with "Trump Said He'd Unleash the Economy in Year 1" |
| Authors   | `["Ben Casselman", "Jacqueline Gu", "Rebecca Lieberman"]` |
| Date      | `"2026-01-18"` |

Additional structure assertions:

- Must identify **8 Datawrapper embeds** in the page
- Must identify **ai2html artboard blocks**

#### 3. Chart Data

**General**: 8 chart data constants must be generated.

| Chart | Type | Key assertions |
|-------|------|----------------|
| Food Prices | `LineChartData` | 132 monthly values; `lineColor` = `"#bf1d02"`; dual-line (`values2` for "All items") |
| Gas Prices | `LineChartData` | Monthly values; single line |
| Electricity | `LineChartData` | Monthly values |
| Auto Jobs | `LineChartData` or `BarChartData` | Industry employment data |
| Manufacturing | `LineChartData` or `BarChartData` | Employment data |
| S&P 500 | `LineChartData` | `lineColor` = `"#8b8b00"` (olive/yellow-green) |
| Tariff Revenue | `BarChartData` | 120 values; `barColor` = `"#fdba58"` |
| Trade Deficit | Stacked area/bars | China + Rest of world series |

#### 4. Quote Sections

8 quote sections must be generated, each mapping to a verdict label and color:

| Topic | Verdict | Color |
|-------|---------|-------|
| Food Prices | HASN'T HAPPENED | `#bc261a` |
| Gas Prices | SOME PROGRESS | `#c49012` |
| Electricity Prices | HASN'T HAPPENED | `#bc261a` |
| Auto Industry | HASN'T HAPPENED | `#bc261a` |
| Manufacturing Jobs | HASN'T HAPPENED | `#bc261a` |
| Stock Market | SO FAR, SO GOOD | `#53a451` |
| Tariff revenue | SOME PROGRESS | `#c49012` |
| Trade deficit | SOME PROGRESS | `#c49012` |

#### 5. Brand Section Component

The generated `BrandNYTSection.tsx` must:

- Expose **5 section IDs**: `typography`, `colors`, `layout`, `architecture`, `resources`
- Include a **font mapping table**
- Follow the **BrandNYTSection.tsx** component pattern established in the codebase

#### 6. Config Wiring

| Check | Assertion |
|-------|-----------|
| `DesignDocSectionId` type | Includes `"brand-nyt"` |
| `DESIGN_DOC_SECTIONS` map | Has an entry for NYT |
| `BRAND_SECTION_IDS` array | Includes `"brand-nyt"` |
| `sectionComponents` map | Has a dynamic import for the NYT brand section |
| Type-check | `npx tsc --noEmit` exits with 0 errors |

---

### Validation Commands

```bash
# Type check -- must exit 0
cd /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web && npx tsc --noEmit

# Verify config references brand-nyt (expect >= 1 match)
grep -c "brand-nyt" /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/lib/admin/design-docs-config.ts

# Verify component file exists
ls /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/components/admin/design-docs/sections/BrandNYTSection.tsx

# Verify chart data constants were generated
grep -c "DATA" /Users/thomashulihan/Projects/TRR/TRR-APP/apps/web/src/components/admin/design-docs/chart-data.ts

# Count skill files (expect 17)
find /Users/thomashulihan/Projects/TRR/.agents/skills/design-docs-agent -mindepth 2 -maxdepth 2 -name SKILL.md | wc -l
```

---

### Pass / Fail Criteria

The test **passes** if and only if ALL of the following hold:

1. Every validation command above exits with status 0.
2. CSS token extraction finds all 6+ font families, 3 core colors, and 2 layout widths.
3. Page structure metadata (title, authors, date) matches expected values.
4. All 8 chart data constants are present with correct types and key color values.
5. All 8 quote sections have the correct verdict label and hex color.
6. The brand section component has all 5 section IDs and a font mapping table.
7. Config wiring places `"brand-nyt"` in all required locations.
8. `npx tsc --noEmit` produces zero errors.

The test **fails** if any single assertion above is not met.

---

### Notes

- This test is designed to be run after the full agent pipeline has executed.
- The NYT article is the first and primary reference implementation; future
  brands will have their own integration test files following this same pattern.
- Chart color values are extracted from Datawrapper SVG source and must be
  exact hex matches (case-insensitive).
- The `plain=1` query parameter on Datawrapper URLs is required to get the
  raw embed without the iframe wrapper.

---

## Lessons Learned (Pitfalls to Watch For)

These are documented failure modes from real agent runs that the test should
catch:

### 1. ArticleDetailPage Was Hardcoded

Early versions hardcoded Trump economy content for ALL articles. The page is
now fully data-driven via `contentBlocks` array. Test assertion: each article
must have its own unique `contentBlocks` array that matches the source
article's actual content order.

### 2. Heading Styles Differ by Article Type

`"interactive"` articles use 45px/800/normal/center headings.
`"article"` type uses 31px/700/italic/left. The test should verify that the
`fonts` array in each article config entry reflects the correct heading style
for that article's type.

### 3. Bot Detection Blocks Chrome DevTools MCP

NYT (Datadome) returns CAPTCHA instead of article HTML when accessed via
DevTools. The test should not depend on live page scraping -- use saved HTML.

### 4. Font Data Must Be Per-Article

The sweepstakes article had identical font entries to the Trump article because
data was copy-pasted. Test assertion: no two articles in the ARTICLES array
should have byte-identical `fonts` arrays unless they genuinely share the same
heading styles.

### 5. Chart Types Need Visualization Type Names

The `chartTypes` array entries should include human-readable visualization type
names ("Line chart", "Bar chart", "Stacked area chart") not just the tool name
("datawrapper"). Test assertion: each `chartTypes` entry has a descriptive
`type` field.

### 6. Background Color: bg-white Not bg-zinc-50

The design docs page background must be `bg-white`. Using `bg-zinc-50` causes
a gray background that conflicts with card styling. Visual regression check.

### 7. ai2html: Use img Only for Report Cards

Report card artboards have text baked into the PNG. HTML text overlays on top
create doubling. Test assertion: when ai2html artboards are classified as
`category=report-card`, the rendering code uses `<img>` only with no text
overlay children.

### 8. Cross-Population to Brand Section

Article fonts, colors, chart types, and components should flow back into the
parent brand section. Test assertion: after adding a new article, the brand
section's `FONTS` array includes all weights used across all articles.

### 9. contentBlocks Array

New system for defining article content blocks in order. Types: header, byline,
ai2html, subhed, birdkit-chart, author-bio. Test assertion: every ARTICLES
entry has a non-empty `contentBlocks` array.

---

## Test: Sweepstakes Casino Article

### Assertions

1. **Article type**: `type: "article"` (not `"interactive"`)
2. **Heading style**: 31px / fontWeight 700 / italic / textAlign left
3. **quoteSections**: MUST be empty array `[]`
4. **Fonts**: MUST have independently extracted font data — NOT identical to Trump Economy article
5. **contentBlocks**: Non-empty array with at least `header`, `byline`, `author-bio`
6. **url**: Must be set
7. **Background**: `bg-white`

---

## Test: Winter Olympics Article

### Assertions

1. **Table blocks**: At least 6 `birdkit-table` or `birdkit-table-interactive` entries in `contentBlocks`
2. **Medal colors**: Gold `#C9B037`, Silver `#A8A8A8`, Bronze `#AD8A56`
3. **Consistent row count**: Every dropdown option shows same number of rows (padded with `---`)
4. **Medal circle headers**: Colored circles (SVG/spans), NOT text "G", "S", "B", "Tot."
5. **Interactive tables**: `birdkit-table-interactive` blocks have working `useState` dropdowns
6. **Fonts**: Independently extracted
7. **contentBlocks order**: Matches document order

---

## Test: NFL Playoff Coaches Article (The Athletic)

### Assertions

1. **Datawrapper table**: `contentBlocks` includes `datawrapper-table` with `id: "UYsk6"`
2. **Chart data**: `ATHLETIC_NFL_FOURTH_DOWN_DATA` typed as `DatawrapperTableData` (NOT `BarChartData`)
3. **Table rows**: 14 rows with `team` field per row
4. **Heatmap**: `heatmapGradient` with 8 stops; `HEATMAP_EXACT` with 14 bg/fg pairs
5. **Athletic heading**: h1 = 40px/400/italic/center
6. **h2 vs h3**: h2 "Takeaways" = 30px/700/36px; h3 "Let's go LaFleur it" = 24px/500/28.8px — MUST differ
7. **Content blocks**: At least 20 entries: 1 storyline, 1 featured-image, 1 header, 1 byline, 3 ad-container, 3 showcase-link, 1 datawrapper-table, 1 twitter-embed, 5+ subhed, 1 puzzle-entry-point, 1 author-bio
8. **Fonts**: 4 families — nyt-cheltenham [400,500,700], nyt-franklin [300,400,500,600,700], nyt-imperial [400,500], RegularSlab [400]
9. **Colors**: Must include `#386C92`, `#DBDBD9`, `#000000`, `#F0F0EE`, `#C4C4C0`
10. **Icons**: Team logos for 14 teams, NFL league logo, Connections logo, 6+ SVG icons

---

## Cross-Article Validation Rules

1. **No duplicate fonts**: No two articles have byte-identical `fonts` arrays
2. **All URLs set**: Every article has non-empty `url`
3. **Background white**: All article pages use `bg-white`
4. **Non-empty contentBlocks**: At least 3 entries (header + byline + author-bio)
5. **Chart data exists**: Every `datawrapper-table` block references a constant in `chart-data.ts`
6. **Per-article colors**: No identical `colors.datawrapperHeatmap` between articles
7. **Interactive components work**: Every interactive block has `useState` for interactivity

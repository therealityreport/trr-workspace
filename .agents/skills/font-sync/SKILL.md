---
name: font-sync
description: Collect Monotype fonts from local cache, stage on Desktop/FONTS, upload to R2, and register in the web app (cdn-fonts.css + DesignSystemPageClient.tsx).
---

# Font Sync Skill

Automates the full font pipeline: **Monotype cache -> Desktop/FONTS -> R2 upload -> Web app registration**.

## When to use

- Adding a new font family to the TRR design system.
- Re-syncing fonts after a Monotype Fonts app refresh.
- Bulk-uploading fonts to R2 and registering them in the web app.

## When NOT to use

- Fonts that are NOT from Monotype (use manual upload instead).
- Google Fonts (already handled via `next/font`).

---

## Step 1: Collect fonts from Monotype cache

Monotype Fonts stores cached font files here:

```
~/Library/Application Support/Monotype Fonts/Monotype Fonts_d74c9132-777f-46eb-9b37-263fce1b0ed1/.Fonts/
```

For each requested font family:

1. Search the Monotype cache for matching files (case-insensitive, match on family name prefix).
2. Create a folder on Desktop: `~/Desktop/FONTS/<Family Name>/`
3. Copy all weight/style variants (`.otf`, `.ttf`, `.woff`, `.woff2`) into that folder.

```bash
# Example: collect "Stafford Serial"
MONOTYPE_CACHE="$HOME/Library/Application Support/Monotype Fonts/Monotype Fonts_d74c9132-777f-46eb-9b37-263fce1b0ed1/.Fonts"
DEST="$HOME/Desktop/FONTS/Stafford Serial"
mkdir -p "$DEST"
find "$MONOTYPE_CACHE" -iname "stafford*" -type f \( -name "*.otf" -o -name "*.ttf" -o -name "*.woff" -o -name "*.woff2" \) -exec cp {} "$DEST/" \;
```

If no files are found for a family, report it as missing — the user may need to re-sync in the Monotype Fonts app first.

---

## Step 2: Upload to R2

Use the existing upload script with `python3.11` (which has boto3 installed):

```bash
python3.11 /Users/thomashulihan/Projects/TRR/TRR-APP/scripts/upload-fonts-to-s3.py \
  --source "$HOME/Desktop/FONTS/<Family Name>" \
  --bucket trr-media-prod \
  --prefix "fonts/trr/<Family Name>"
```

### R2 connection details

| Setting | Value |
|---|---|
| Endpoint | `https://73204b3e632bd7137a1bd2c867dc8ae8.r2.cloudflarestorage.com` |
| Bucket | `trr-media-prod` |
| Key prefix | `fonts/trr/<Family Name>/` |
| Public URL | `https://pub-a3c452f3df0d40319f7c585253a4776c.r2.dev/fonts/trr/<Family Name>/` |
| Access Key ID | `5db1e6591cf4c68c880c16b8d809f351` |

The upload script reads credentials from these env vars (already set in `TRR-Backend/.env`):

```
OBJECT_STORAGE_ACCESS_KEY_ID
OBJECT_STORAGE_SECRET_ACCESS_KEY
OBJECT_STORAGE_ENDPOINT_URL
```

**Important:** The upload script uses boto3 with S3-compatible API. Set these env vars before running:

```bash
export OBJECT_STORAGE_ACCESS_KEY_ID="$(grep OBJECT_STORAGE_ACCESS_KEY_ID /Users/thomashulihan/Projects/TRR/TRR-Backend/.env | cut -d= -f2)"
export OBJECT_STORAGE_SECRET_ACCESS_KEY="$(grep OBJECT_STORAGE_SECRET_ACCESS_KEY /Users/thomashulihan/Projects/TRR/TRR-Backend/.env | cut -d= -f2)"
export OBJECT_STORAGE_ENDPOINT_URL="$(grep OBJECT_STORAGE_ENDPOINT_URL /Users/thomashulihan/Projects/TRR/TRR-Backend/.env | cut -d= -f2)"
export OBJECT_STORAGE_REGION=auto
```

### Content-Type mapping

| Extension | Content-Type |
|---|---|
| `.ttf` | `font/ttf` |
| `.otf` | `font/otf` |
| `.woff` | `font/woff` |
| `.woff2` | `font/woff2` |

All uploads use `Cache-Control: public, max-age=31536000, immutable`.

---

## Step 3: Add `@font-face` rules to `cdn-fonts.css`

File: `TRR-APP/apps/web/src/styles/cdn-fonts.css`

Add a section for the new family, following the existing pattern:

```css
/* ============================================================
   <Family Name>
   ============================================================ */

@font-face {
  font-family: "<Family Name>";
  src: url("https://pub-a3c452f3df0d40319f7c585253a4776c.r2.dev/fonts/trr/<Family Name>/<filename>.otf") format("opentype");
  font-weight: <weight>;
  font-style: normal;
  font-display: swap;
}
```

### Weight mapping conventions

Map filenames to CSS `font-weight` values:

| Filename contains | `font-weight` |
|---|---|
| Thin, Hairline | 100 |
| ExtraLight, UltraLight | 200 |
| Light | 300 |
| Regular, Book, Roman, Normal | 400 |
| Medium | 500 |
| SemiBold, DemiBold | 600 |
| Bold | 700 |
| ExtraBold, UltraBold | 800 |
| Black, Heavy | 900 |

- If filename contains `Italic` or `Oblique`, set `font-style: italic`.
- If filename contains `Condensed`, add to a separate `@font-face` with `font-stretch: condensed` or note it in the family name.
- URL-encode spaces as `%20` in the URL path.
- Format: `.otf` -> `format("opentype")`, `.ttf` -> `format("truetype")`, `.woff` -> `format("woff")`, `.woff2` -> `format("woff2")`.

### Alphabetical insertion

Insert the new family section in **alphabetical order** among existing sections in `cdn-fonts.css`.

---

## Step 4: Add font card to `DesignSystemPageClient.tsx`

File: `TRR-APP/apps/web/src/components/admin/design-system/DesignSystemPageClient.tsx`

Add an entry to the `CDN_FONTS` array (in **alphabetical order** by `name`):

```typescript
{
  name: "<Family Name>",
  weights: [w(<weight1>), w(<weight2>, true), ...],  // true = has italic
  type: "CDN Font",
  source: "CloudFront CDN",
  cdnPath: `${CDN_BASE}/monotype/<Family%20Name>/`,
  description: "<Brief description of the typeface>",
  fontFamilyValue: '"<Family Name>"',
  usedOn: [{ page: "Not yet used", path: "Available on CDN" }],
},
```

### Notes on the `weights` array

- Use the `w()` helper: `w(400)` for normal, `w(400, true)` for weight with italic variant.
- Match exactly the weights you uploaded and declared in `cdn-fonts.css`.
- The `source` field says `"CloudFront CDN"` for historical reasons (it's an enum in the TypeScript type) — this is correct even though fonts are now on R2.

---

## Step 5: Verify fonts are actually rendering (not falling back)

This is the most critical step. Browsers silently fall back to system fonts when `@font-face` loading fails, so the page may *look* like it works while displaying the wrong font.

### 5a. Verify R2 URLs return 200 (not 404)

For every `@font-face` `src` URL you added, confirm the file is actually accessible:

```bash
# Curl each font URL — must return HTTP 200 and correct content-type
curl -sI "https://pub-a3c452f3df0d40319f7c585253a4776c.r2.dev/fonts/trr/<Family%20Name>/<filename>.otf" | head -5
```

Expected output:
```
HTTP/2 200
content-type: font/otf
cache-control: public, max-age=31536000, immutable
```

**If you get 403 or 404**, the file wasn't uploaded or the URL path is wrong. Common issues:
- Spaces not encoded as `%20` in the URL
- Filename case mismatch (R2 keys are case-sensitive)
- File uploaded to wrong prefix path

### 5b. Cross-check `font-family` name consistency

The **exact same string** must appear in three places. Any mismatch causes a silent fallback.

| Location | What to check |
|---|---|
| `cdn-fonts.css` | `font-family: "<Family Name>";` in the `@font-face` rule |
| `DesignSystemPageClient.tsx` | `fontFamilyValue: '"<Family Name>"'` in the `CDN_FONTS` entry |
| Browser render | `style={{ fontFamily: '"<Family Name>"' }}` applied to preview text |

**These must be identical**, including quotes, casing, and spacing. For example:
- `"Stafford Serial"` (correct)
- `"stafford serial"` (wrong — CSS font-family is case-sensitive in `@font-face` matching)
- `"StaffordSerial"` (wrong — missing space)

### 5c. Verify in browser with `document.fonts` API

After the dev server is running, open the design system page (`/admin/fonts`) and run this in the browser console:

```javascript
// Check if a specific font loaded successfully
document.fonts.check('16px "<Family Name>"');
// Returns true if loaded, false if fell back

// List all loaded fonts to see which ones actually loaded
for (const font of document.fonts) {
  if (font.status === 'loaded') {
    console.log(`${font.family} ${font.weight} ${font.style}`);
  }
}

// Check all CDN fonts at once — any that return false are falling back
const cdnFonts = [
  "Beton", "Biotif Pro", "Cheltenham", /* ... add new family here ... */
];
cdnFonts.forEach(f => {
  const loaded = document.fonts.check(`16px "${f}"`);
  console.log(`${loaded ? 'OK' : 'FALLBACK'}: ${f}`);
});
```

### 5d. Visual confirmation on the design system page

1. Navigate to `/admin/fonts` (redirects to design system page).
2. Find the new font card and expand it.
3. **Compare the preview text against a known reference** — the font name in the card header renders in its own font (`style={{ fontFamily: family.fontFamilyValue }}`). If it looks like the surrounding UI text (Inter/Geist), the font is falling back.
4. Check each weight row — each one renders preview text at that weight. Verify distinct visual differences between weights (e.g., 300 should look noticeably thinner than 700).

### 5e. Network tab verification

1. Open DevTools > Network tab, filter by "Font" type.
2. Reload the page.
3. Confirm each font file appears in the network log with status `200` (not `(failed)` or missing).
4. If a font file shows `(canceled)` or isn't requested at all, the `@font-face` rule is malformed or the `font-display: swap` fallback kicked in before the font loaded.

### Common fallback causes and fixes

| Symptom | Cause | Fix |
|---|---|---|
| All weights look the same | Wrong `font-weight` values in `@font-face` rules | Match weight numbers to actual filenames (see weight mapping table) |
| Font name renders in system font | `font-family` name mismatch between CSS and component | Exact-match the string in `cdn-fonts.css` and `fontFamilyValue` |
| Font loads on refresh but not first visit | Missing `font-display: swap` | Add `font-display: swap;` to every `@font-face` rule |
| Font shows in Network tab but doesn't render | `format()` hint is wrong | `.otf` = `format("opentype")`, `.ttf` = `format("truetype")` |
| 404 on font URL | Filename has spaces/special chars not URL-encoded | Encode spaces as `%20` in the `src` URL |
| Works locally but not deployed | Font file not uploaded to R2 | Re-run the upload script without `--dry-run` |

---

## Verification checklist (summary)

Before marking a font as done, confirm ALL of these:

- [ ] `~/Desktop/FONTS/<Family>/` folder exists with all weight/style files
- [ ] Upload script ran successfully (no `[ERROR]` lines)
- [ ] Every `@font-face` URL returns HTTP 200 via `curl -sI`
- [ ] `font-family` name is identical in `cdn-fonts.css` and `fontFamilyValue` in `DesignSystemPageClient.tsx`
- [ ] `document.fonts.check('16px "<Family Name>"')` returns `true` in browser console
- [ ] Font card on `/admin/fonts` visually renders in the correct typeface (not system fallback)
- [ ] Each weight row shows visually distinct thickness

---

## Quick reference: full single-family example

```bash
# 1. Collect
FAMILY="Stafford Serial"
MONOTYPE_CACHE="$HOME/Library/Application Support/Monotype Fonts/Monotype Fonts_d74c9132-777f-46eb-9b37-263fce1b0ed1/.Fonts"
mkdir -p "$HOME/Desktop/FONTS/$FAMILY"
find "$MONOTYPE_CACHE" -iname "stafford*" -type f \( -name "*.otf" -o -name "*.ttf" -o -name "*.woff" -o -name "*.woff2" \) -exec cp {} "$HOME/Desktop/FONTS/$FAMILY/" \;

# 2. Upload (set R2 creds first)
python3.11 /Users/thomashulihan/Projects/TRR/TRR-APP/scripts/upload-fonts-to-s3.py \
  --source "$HOME/Desktop/FONTS/$FAMILY" \
  --bucket trr-media-prod \
  --prefix "fonts/trr/$FAMILY"

# 3. Verify upload — curl each file URL
for f in "$HOME/Desktop/FONTS/$FAMILY"/*; do
  FNAME=$(basename "$f" | sed 's/ /%20/g')
  STATUS=$(curl -sI "https://pub-a3c452f3df0d40319f7c585253a4776c.r2.dev/fonts/trr/$(echo "$FAMILY" | sed 's/ /%20/g')/$FNAME" | head -1)
  echo "$FNAME: $STATUS"
done

# 4. Edit cdn-fonts.css — add @font-face rules
# 5. Edit DesignSystemPageClient.tsx — add CDN_FONTS entry
# 6. Open /admin/fonts in browser
# 7. Run in console: document.fonts.check('16px "Stafford Serial"')  → must be true
# 8. Visually confirm the card header + weight previews render in the correct typeface
```

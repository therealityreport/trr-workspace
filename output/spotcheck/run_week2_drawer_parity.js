const fs = require('fs');
const path = require('path');
const { chromium } = require('@playwright/test');

(async () => {
  const outDir = '/Users/thomashulihan/Projects/TRR/output/spotcheck/week2c';
  fs.mkdirSync(outDir, { recursive: true });

  const browser = await chromium.connectOverCDP('http://127.0.0.1:9222');
  const context = browser.contexts()[0] ?? await browser.newContext();
  const page = context.pages()[0] ?? await context.newPage();

  const url = 'http://admin.localhost:3000/7782652f-783a-488b-8860-41b97de32e75/s6/social/w2/instagram';
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 });
  await page.waitForSelector('button[aria-label="Open post detail modal"]', { timeout: 60000 });
  await page.waitForTimeout(1500);

  const sourceIds = await page.evaluate(() => {
    const ids = new Set();
    for (const el of document.querySelectorAll('[data-testid^="instagram-tag-markers-card-"]')) {
      const tid = el.getAttribute('data-testid') || '';
      const m = tid.match(/^instagram-tag-markers-card-(.+)$/);
      if (!m) continue;
      const sourceId = m[1];
      if (sourceId.includes('-item-')) continue;
      ids.add(sourceId);
    }
    return Array.from(ids);
  });

  const sampled = [];
  const maxSamples = 12;
  for (const sourceId of sourceIds.slice(0, maxSamples)) {
    const cardOverlay = page.locator(`[data-testid="instagram-tag-markers-card-${sourceId}"]`).first();
    const cardMarkerItems = page.locator(`[data-testid^="instagram-tag-markers-card-${sourceId}-item-"]`);
    const cardMarkerCount = await cardMarkerItems.count();

    const row = {
      sourceId,
      cardMarkerCount,
      drawerMarkerCount: 0,
      drawerExists: false,
      countsMatch: false,
      sampleLabels: [],
      sampleStyles: [],
      cardScreenshot: null,
      drawerScreenshot: null,
      error: null,
    };

    try {
      const labels = await cardMarkerItems.locator('span').allTextContents();
      row.sampleLabels = labels.slice(0, 4).map((t) => t.trim()).filter(Boolean);
      const styles = await page.evaluate((sid) => {
        return Array.from(document.querySelectorAll(`[data-testid^="instagram-tag-markers-card-${sid}-item-"]`))
          .slice(0, 4)
          .map((el) => (el).getAttribute('style') || '');
      }, sourceId);
      row.sampleStyles = styles;

      const cardPng = path.join(outDir, `${sourceId}_card.png`);
      const cardButton = page.locator('button[aria-label="Open post detail modal"]', {
        has: page.locator(`[data-testid="instagram-tag-markers-card-${sourceId}"]`),
      }).first();
      await cardButton.scrollIntoViewIfNeeded();
      await cardButton.screenshot({ path: cardPng });
      row.cardScreenshot = cardPng;

      await cardButton.click({ timeout: 20000 });
      await page.waitForSelector('h2:has-text("Post Details")', { timeout: 20000 });

      // Wait for detail payload to populate the drawer image block.
      await page.waitForFunction(
        () => {
          const loading = Array.from(document.querySelectorAll('div')).some((n) => n.textContent?.includes('Loading all comments...'));
          const thumb = document.querySelector('img[alt="Instagram post thumbnail"]');
          return !loading && !!thumb;
        },
        { timeout: 25000 }
      ).catch(() => {});

      const drawerOverlay = page.locator(`[data-testid="instagram-tag-markers-drawer-${sourceId}"]`).first();
      row.drawerExists = (await drawerOverlay.count()) > 0;
      if (row.drawerExists) {
        const drawerItems = page.locator(`[data-testid^="instagram-tag-markers-drawer-${sourceId}-item-"]`);
        row.drawerMarkerCount = await drawerItems.count();
        const drawerPng = path.join(outDir, `${sourceId}_drawer.png`);
        await page.locator('div.fixed.inset-0.z-50').first().screenshot({ path: drawerPng });
        row.drawerScreenshot = drawerPng;
      }

      row.countsMatch = row.cardMarkerCount === row.drawerMarkerCount;

      await page.keyboard.press('Escape');
      await page.waitForTimeout(450);
    } catch (error) {
      row.error = String(error?.message || error);
      try {
        await page.keyboard.press('Escape');
        await page.waitForTimeout(300);
      } catch {}
    }

    sampled.push(row);
  }

  const report = {
    url,
    totalCardOverlays: sourceIds.length,
    sampledCount: sampled.length,
    sampled,
  };

  const reportPath = path.join(outDir, 'spotcheck-report.json');
  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));
  console.log(JSON.stringify(report, null, 2));
  console.log(`REPORT_PATH=${reportPath}`);

  await browser.close();
})();

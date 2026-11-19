// Probe: Struktur der Live-Referenz-App erfassen (Einmal, Wegwerfdaten).
const { chromium } = require('/Volumes/T7/Projekte/alexle135.de/node_modules/.pnpm/node_modules/playwright-core');
const fs = require('fs');

const BASE = 'https://alex-schneider.dev/projekte/terminal-missionen/app/staffel-2/';
const OUT = '/Volumes/T7/Projekte/linux-mac/.worker/probe';
fs.mkdirSync(OUT, { recursive: true });

(async () => {
  const browser = await chromium.launch({ headless: true });
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 1000 }, locale: 'de-DE' });
  const page = await ctx.newPage();
  const report = { steps: [] };

  try {
    await page.goto(BASE, { waitUntil: 'networkidle', timeout: 45000 });
    report.url = page.url();
    report.title = await page.title();
    await page.waitForTimeout(2500);
    await page.screenshot({ path: `${OUT}/00-initial.png` });

    // Sichtbare Klickbare sammeln
    const inventory = await page.evaluate(() => {
      const out = [];
      document.querySelectorAll('button,a,[role="tab"],[role="button"],select,input').forEach((el) => {
        const r = el.getBoundingClientRect();
        if (r.width < 2 || r.height < 2) return;
        out.push({
          tag: el.tagName,
          text: (el.innerText || el.getAttribute('aria-label') || el.value || '').trim().slice(0, 80),
          role: el.getAttribute('role') || '',
          testid: el.getAttribute('data-testid') || '',
          href: el.getAttribute('href') || '',
          x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height),
        });
      });
      return out;
    });
    report.inventory = inventory;
    report.bodyText = (await page.locator('body').innerText()).slice(0, 4000);
    fs.writeFileSync(`${OUT}/inventory.json`, JSON.stringify(report, null, 2));
    console.log('OK url=' + report.url);
    console.log('INVENTORY_COUNT=' + inventory.length);
    console.log('TEXT_LEN=' + report.bodyText.length);
  } catch (e) {
    report.error = String(e);
    fs.writeFileSync(`${OUT}/inventory.json`, JSON.stringify(report, null, 2));
    console.log('ERROR=' + e.message);
  } finally {
    await browser.close();
  }
})();

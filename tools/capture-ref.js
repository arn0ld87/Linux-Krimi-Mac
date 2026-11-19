// Capture der echten Referenz-Screens (public, frischer Browser-Kontext, keine Nutzerdaten).
const { chromium } = require('/Volumes/T7/Projekte/alexle135.de/node_modules/.pnpm/node_modules/playwright-core');
const fs = require('fs');

const APP = 'https://alex-schneider.dev/projekte/terminal-missionen/app/staffel-2/';
const PROJEKT = 'https://alex-schneider.dev/projekte/linux-krimi-staffel-2/';
const OUT = '/Volumes/T7/Projekte/linux-mac/docs/screens';
fs.mkdirSync(OUT, { recursive: true });

const captured = [];
const blocked = [];

(async () => {
  const browser = await chromium.launch({ headless: true });
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 1000 }, locale: 'de-DE' });
  const page = await ctx.newPage();

  const shot = async (name, note) => {
    const file = `${OUT}/${name}.png`;
    await page.screenshot({ path: file });
    captured.push({ name, file, note });
    console.log(`CAPTURED ${name} :: ${note}`);
  };

  const step = async (name, note, fn) => {
    try {
      await fn();
      await shot(name, note);
    } catch (e) {
      blocked.push({ name, reason: String(e.message || e).slice(0, 200) });
      console.log(`BLOCKED ${name} :: ${String(e.message || e).slice(0, 160)}`);
    }
  };

  // Cookie-Banner wegklicken (Ablehnen), falls vorhanden
  const dismissCookie = async () => {
    try {
      const b = page.getByRole('button', { name: 'Ablehnen' });
      if (await b.count()) { await b.first().click({ timeout: 3000 }); await page.waitForTimeout(400); }
    } catch (e) { /* nicht kritisch */ }
  };

  await page.goto(PROJEKT, { waitUntil: 'domcontentloaded', timeout: 45000 });
  await page.waitForTimeout(1800);
  await dismissCookie();
  await step('01-projektseite', 'Projektseite der Web-Fassung (kein App-Screen, Kontext)', async () => {
    await page.waitForTimeout(600);
  });

  await page.goto(APP, { waitUntil: 'networkidle', timeout: 60000 });
  await page.waitForTimeout(3000);
  await dismissCookie();

  await step('02-einsatzrahmen-pager', 'Initialer Einsatzrahmen/Briefing im Pager über dem Terminal', async () => {
    await page.waitForTimeout(1200);
  });

  await step('03-terminal', 'Hauptansicht Terminal (Prompt azubi@rw-srv01)', async () => {
    const t = page.getByRole('tab', { name: 'Terminal' });
    if (await t.count()) await t.first().click();
    await page.waitForTimeout(1500);
  });

  await step('04-aktenwand', 'Aktenwand / Fallakte (Belegliste, Fortschritt)', async () => {
    const f = page.getByRole('button', { name: 'Fallakte' });
    if (await f.count()) await f.first().click();
    await page.waitForTimeout(1200);
  });

  await step('05-serverraum', 'Serverraum (Episodenübersicht der Web-Fassung)', async () => {
    const s = page.getByRole('tab', { name: 'Serverraum' });
    if (await s.count()) await s.first().click();
    await page.waitForTimeout(1200);
  });

  await step('06-vorwurf-leer', 'Vorwurf-Sheet im leeren Zustand (Belege 0)', async () => {
    const t = page.getByRole('tab', { name: 'Terminal' });
    if (await t.count()) await t.first().click();
    await page.waitForTimeout(700);
    const v = page.getByRole('button', { name: 'Vorwurf erheben' });
    if (await v.count()) await v.first().click();
    await page.waitForTimeout(1200);
  });

  await step('07-vorwurf-dialog', 'Bestätigungsdialog für Fortschritt löschen (nicht bestätigen)', async () => {
    await page.keyboard.press('Escape');
    await page.waitForTimeout(600);
    const f = page.getByRole('button', { name: 'Fortschritt löschen' });
    if (await f.count()) await f.first().click();
    await page.waitForTimeout(1000);
  });

  await step('08-episode-1', 'Episodenübersicht Episode 1 (Zu viele Rechte) - nur Auswahl, kein Start', async () => {
    await page.keyboard.press('Escape');
    await page.waitForTimeout(500);
    const sel = page.locator('select').first();
    if (await sel.count()) {
      await sel.selectOption({ index: 1 });
      await page.waitForTimeout(1200);
    }
  });

  await step('09-episode-2', 'Episodenübersicht Episode 2 (Der Prozess, der nicht stirbt)', async () => {
    const sel = page.locator('select').first();
    if (await sel.count()) {
      await sel.selectOption({ index: 2 });
      await page.waitForTimeout(1200);
    }
  });

  await step('10-episode-3', 'Episodenübersicht Episode 3 (Die Lücke im Log)', async () => {
    const sel = page.locator('select').first();
    if (await sel.count()) {
      await sel.selectOption({ index: 3 });
      await page.waitForTimeout(1200);
    }
  });

  // Dark Mode über die prefers-color-scheme-Emulation des frischen Kontexts
  await step('11-hauptansicht-dark', 'Hauptansicht im Dark Mode (Browser-Emulation, kein globales macOS-Appearance)', async () => {
    const sel = page.locator('select').first();
    if (await sel.count()) await sel.selectOption({ index: 0 });
    await page.waitForTimeout(800);
    await page.emulateMedia({ colorScheme: 'dark' });
    await page.waitForTimeout(1200);
  });

  await step('12-hauptansicht-light', 'Hauptansicht im Light Mode', async () => {
    await page.emulateMedia({ colorScheme: 'light' });
    await page.waitForTimeout(1000);
  });

  fs.writeFileSync(`${OUT}/_capture-report.json`, JSON.stringify({ captured, blocked }, null, 2));
  console.log(`DONE captured=${captured.length} blocked=${blocked.length}`);
  await browser.close();
})();

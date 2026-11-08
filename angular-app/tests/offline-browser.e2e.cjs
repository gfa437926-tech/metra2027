const assert = require('node:assert/strict');
const fs = require('node:fs');
const http = require('node:http');
const path = require('node:path');
const { chromium } = require('playwright');

// Angular application builder places browser-served files in the browser subdirectory.
const root = path.resolve(__dirname, '../dist/metra2027/browser');
const port = Number(process.env.PORT || 4173);
const mime = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.svg': 'image/svg+xml', '.webmanifest': 'application/manifest+json', '.json': 'application/json' };

async function main() {
  assert.ok(fs.existsSync(path.join(root, 'index.html')), 'Angular production index must exist');
  const server = http.createServer((req, res) => {
    const pathname = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
    const candidate = path.resolve(root, '.' + pathname);
    const safe = candidate.startsWith(root + path.sep) || candidate === path.join(root, 'index.html');
    const exists = safe && fs.existsSync(candidate) && fs.statSync(candidate).isFile();
    // Only application navigations receive the SPA shell; missing assets must remain 404s.
    const isNavigation = req.method === 'GET' && (req.headers.accept || '').includes('text/html');
    if (!exists && !isNavigation) {
      res.statusCode = 404;
      res.end('Not found');
      return;
    }
    const file = exists ? candidate : path.join(root, 'index.html');
    res.setHeader('Content-Type', mime[path.extname(file)] || 'application/octet-stream');
    fs.createReadStream(file).pipe(res);
  });
  await new Promise(resolve => server.listen(port, '127.0.0.1', resolve));

  let browser;
  try {
    browser = await chromium.launch({ headless: true });
    const context = await browser.newContext();
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.goto(`http://127.0.0.1:${port}/`, { waitUntil: 'domcontentloaded' });
    await page.locator('metra-root').waitFor({ state: 'attached', timeout: 20000 });

    // The offline queue is initialized by the daily reports feature, not by the app shell.
    // Visit that route before asserting the production-created IndexedDB schema.
    await page.goto(`http://127.0.0.1:${port}/reports/daily`, { waitUntil: 'domcontentloaded' });
    await page.locator('metra-daily-reports').waitFor({ state: 'attached', timeout: 20000 });

    const pwa = await page.evaluate(async () => {
      if (!('serviceWorker' in navigator)) return { supported: false };
      const registration = await navigator.serviceWorker.ready;
      return { supported: true, active: Boolean(registration.active), scope: registration.scope };
    });
    assert.equal(pwa.supported, true, 'Service Worker API should be available on localhost');
    assert.equal(pwa.active, true, 'PWA service worker should become active');

    const dbResult = await page.evaluate(async () => {
      const db = await new Promise((resolve, reject) => {
        const request = indexedDB.open('metra-offline-outbox', 3);
        request.onsuccess = () => resolve(request.result);
        request.onerror = () => reject(request.error);
      });
      const required = ['daily-submissions', 'station-catalogue', 'sync-locks'];
      const missing = required.filter(name => !db.objectStoreNames.contains(name));
      if (missing.length) throw new Error('Missing IndexedDB stores: ' + missing.join(', '));
      const key = 'browser-e2e-' + crypto.randomUUID();
      const record = { idempotencyKey: key, observationType: 'daily', stationId: 'browser-test', stationName: 'اختبار المتصفح', reportDate: '2099-01-01', reportType: '24h', observedAt: new Date().toISOString(), payload: {}, createdAt: new Date().toISOString(), attempts: 0, state: 'pending' };
      await new Promise((resolve, reject) => {
        const tx = db.transaction('daily-submissions', 'readwrite');
        tx.objectStore('daily-submissions').put(record);
        tx.oncomplete = resolve; tx.onerror = () => reject(tx.error); tx.onabort = () => reject(tx.error);
      });
      const found = await new Promise((resolve, reject) => {
        const tx = db.transaction('daily-submissions', 'readonly');
        const request = tx.objectStore('daily-submissions').get(key);
        request.onsuccess = () => resolve(request.result);
        request.onerror = () => reject(request.error);
      });
      await new Promise((resolve, reject) => {
        const tx = db.transaction('daily-submissions', 'readwrite');
        tx.objectStore('daily-submissions').delete(key);
        tx.oncomplete = resolve; tx.onerror = () => reject(tx.error);
      });
      db.close();
      return { stores: required, persisted: found?.idempotencyKey === key };
    });
    assert.equal(dbResult.persisted, true, 'IndexedDB should persist and retrieve an outbox record');

    await context.setOffline(true);
    await page.reload({ waitUntil: 'domcontentloaded' });
    await page.locator('metra-root').waitFor({ state: 'attached', timeout: 20000 });
    const offline = await page.evaluate(() => ({ online: navigator.onLine, title: document.title }));
    assert.equal(offline.online, false, 'Browser should be offline during offline reload');
    assert.deepEqual(errors, [], 'Angular page should not throw uncaught runtime errors');
    console.log(JSON.stringify({ browser: 'Chromium', serviceWorker: pwa.active, indexedDbPersisted: dbResult.persisted, offlineReload: true, runtimeErrors: errors.length }));
  } finally {
    if (browser) await browser.close();
    await new Promise(resolve => server.close(resolve));
  }
}
main().catch(error => { console.error(error); process.exitCode = 1; });

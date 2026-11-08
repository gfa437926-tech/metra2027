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

    // Supply a disposable test identity and intercept only the auth user lookup.
    // No real Supabase project, credentials, or database are contacted by this test.
    // Replace the bundled runtime config before the application reads it.
    // This prevents the smoke test from contacting the configured production project.
    await page.route('**/metra-config.js', route => route.fulfill({
      status: 200,
      contentType: 'application/javascript',
      body: `window.__METRA_CONFIG__ = Object.freeze({
        apiBaseUrl: '',
        supabaseUrl: 'https://metra-e2e.supabase.co',
        supabaseAnonKey: 'metra-browser-e2e-anon-key'
      });`
    }));
    await page.addInitScript(() => {
      localStorage.setItem('sb-metra-e2e-auth-token', JSON.stringify({
        access_token: 'metra-e2e-access-token',
        token_type: 'bearer',
        expires_in: 3600,
        expires_at: Math.floor(Date.now() / 1000) + 3600,
        refresh_token: 'metra-e2e-refresh-token',
        user: {
          id: '00000000-0000-4000-8000-000000000001',
          aud: 'authenticated',
          role: 'authenticated',
          email: 'browser-e2e@example.test',
          app_metadata: { provider: 'email', providers: ['email'] },
          user_metadata: {},
          created_at: '2026-01-01T00:00:00.000Z'
        }
      }));
    });
    await page.route('https://metra-e2e.supabase.co/auth/v1/user**', route => route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        id: '00000000-0000-4000-8000-000000000001',
        aud: 'authenticated',
        role: 'authenticated',
        email: 'browser-e2e@example.test',
        app_metadata: { provider: 'email', providers: ['email'] },
        user_metadata: {},
        created_at: '2026-01-01T00:00:00.000Z'
      })
    }));
    await page.goto(`http://127.0.0.1:${port}/`, { waitUntil: 'domcontentloaded' });
    await page.locator('metra-root').waitFor({ state: 'attached', timeout: 20000 });

    // The offline queue is initialized by the daily reports feature, not by the app shell.
    // Visit that route before asserting the production-created IndexedDB schema.
    await page.goto(`http://127.0.0.1:${port}/reports/daily`, { waitUntil: 'domcontentloaded' });
    try {
      await page.locator('metra-daily-reports').waitFor({ state: 'attached', timeout: 20000 });
    } catch (error) {
      const diagnostics = await page.evaluate(() => ({
        href: location.href,
        config: window.__METRA_CONFIG__,
        authStorage: Object.keys(localStorage).filter(key => key.startsWith('sb-')),
        body: document.body.innerText.slice(0, 1200)
      }));
      throw new Error('Daily route did not mount. Diagnostics=' + JSON.stringify({ diagnostics }) + '; cause=' + error.message);
    }

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

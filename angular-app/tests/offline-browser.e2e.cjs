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
    // The Service Worker pre-caches metra-config.js during installation. Serve an
    // isolated test configuration at the origin so both page requests and SW cache
    // population receive the same disposable values (never the real project config).
    if (req.method === 'GET' && pathname === '/metra-config.js') {
      res.setHeader('Content-Type', 'text/javascript; charset=utf-8');
      res.end(`window.__METRA_CONFIG__ = Object.freeze({
        apiBaseUrl: '',
        supabaseUrl: 'https://metra-e2e.supabase.co',
        supabaseAnonKey: 'metra-browser-e2e-anon-key'
      });`);
      return;
    }
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
    await page.route('**/auth/v1/user**', route => route.fulfill({
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

    // Seed one disposable station in the same IndexedDB cache used by the app.
    // This keeps the test fully isolated from the configured Supabase project.
    await page.evaluate(async () => {
      const db = await new Promise((resolve, reject) => {
        const request = indexedDB.open('metra-offline-outbox', 3);
        request.onupgradeneeded = () => {
          const value = request.result;
          if (!value.objectStoreNames.contains('daily-submissions')) value.createObjectStore('daily-submissions', { keyPath: 'idempotencyKey' });
          if (!value.objectStoreNames.contains('station-catalogue')) value.createObjectStore('station-catalogue', { keyPath: 'id' });
          if (!value.objectStoreNames.contains('sync-locks')) value.createObjectStore('sync-locks', { keyPath: 'id' });
        };
        request.onsuccess = () => resolve(request.result);
        request.onerror = () => reject(request.error);
      });
      await new Promise((resolve, reject) => {
        const tx = db.transaction('station-catalogue', 'readwrite');
        tx.objectStore('station-catalogue').put({ id: '00000000-0000-4000-8000-000000000002', stations: [{
          id: '00000000-0000-4000-8000-000000000002', local_station_code: 'E2E', wmo_station_id: null,
          name_ar: 'محطة اختبار المتصفح', name_en: 'Browser test station', station_type: 'classic',
          operational_status: 'operational', approval_status: 'approved', is_demo: true,
          elevation_m: 10, station_coordinates: []
        }], cachedAt: new Date().toISOString() });
        tx.oncomplete = resolve; tx.onerror = () => reject(tx.error);
      });
      db.close();
    });

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

    await page.locator('select[name="stationId"] option[value="00000000-0000-4000-8000-000000000002"]').waitFor({ state: 'attached', timeout: 10000 });
    await page.locator('select[name="stationId"]').selectOption('00000000-0000-4000-8000-000000000002');
    await page.locator('input[name="currentDate"]').fill('2099-01-01');
    await page.locator('input[name="observer"]').fill('راصد الاختبار');
    await page.getByRole('button', { name: /إدخال بيانات تجريبية/ }).click();

    // Submit through the real Angular form while offline, not by writing a fake
    // outbox record directly. The app must persist the submitted payload locally.
    await context.setOffline(true);
    await page.getByRole('button', { name: /إرسال النشرة للمراجعة/ }).click();
    await page.getByText(/تم حفظ النشرة محلياً داخل صندوق الإرسال/).waitFor({ timeout: 10000 });
    await page.getByText('نشرات محفوظة على هذا الجهاز').waitFor({ timeout: 10000 });
    const saved = await page.evaluate(async () => {
      const db = await new Promise((resolve, reject) => {
        const request = indexedDB.open('metra-offline-outbox', 3);
        request.onsuccess = () => resolve(request.result);
        request.onerror = () => reject(request.error);
      });
      const records = await new Promise((resolve, reject) => {
        const tx = db.transaction('daily-submissions', 'readonly');
        const request = tx.objectStore('daily-submissions').getAll();
        request.onsuccess = () => resolve(request.result);
        request.onerror = () => reject(request.error);
      });
      db.close();
      return records.find(item => item.stationId === '00000000-0000-4000-8000-000000000002');
    });
    assert.ok(saved, 'Submitting the daily form offline must persist a queue record');
    assert.equal(saved.state, 'pending');
    assert.equal(saved.payload.observerName, 'راصد الاختبار');
    assert.equal(saved.payload.values.maxTemp, '25.7');

    // Reload the app with the network still unavailable, then reopen the queued
    // report through the UI and verify the original values are restored to fields.
    await page.reload({ waitUntil: 'domcontentloaded' });
    await page.locator('metra-daily-reports').waitFor({ state: 'attached', timeout: 20000 });
    await page.getByText('نشرات محفوظة على هذا الجهاز').waitFor({ timeout: 10000 });
    await page.getByRole('button', { name: 'إعادة فتح النشرة' }).click();
    await page.locator('input[name="observer"]').waitFor({ state: 'visible' });
    const restored = await page.evaluate(() => ({
      online: navigator.onLine,
      date: document.querySelector('input[name="currentDate"]')?.value,
      station: document.querySelector('select[name="stationId"]')?.value,
      observer: document.querySelector('input[name="observer"]')?.value,
      maxTemp: document.querySelector('input[name="maxTemp"]')?.value,
      precipitation: document.querySelector('input[name="precipitation"]')?.value,
      agreement: document.querySelector('input[name="responsibilityAgreement"]')?.checked
    }));
    assert.equal(restored.online, false, 'Browser should remain offline after reload');
    assert.equal(restored.date, '2099-01-01');
    assert.equal(restored.station, '00000000-0000-4000-8000-000000000002');
    assert.equal(restored.observer, 'راصد الاختبار');
    assert.equal(restored.maxTemp, '25.7');
    assert.equal(restored.precipitation, '012.5');
    assert.equal(restored.agreement, true, 'Reopened report should restore its acknowledgement state');
    console.log(JSON.stringify({ browser: 'Chromium', serviceWorker: pwa.active, submittedThroughFormOffline: true, persistedInIndexedDB: true, reopenedAfterOfflineReload: true, restoredFields: Object.keys(restored).length - 1, runtimeErrors: errors.length }));
    assert.deepEqual(errors, [], 'Angular page should not throw uncaught runtime errors');
    console.log(JSON.stringify({ browser: 'Chromium', serviceWorker: pwa.active, runtimeErrors: errors.length }));
  } finally {
    if (browser) await browser.close();
    await new Promise(resolve => server.close(resolve));
  }
}
main().catch(error => { console.error(error); process.exitCode = 1; });

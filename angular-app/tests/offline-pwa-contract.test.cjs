const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const worker = fs.readFileSync(path.join(__dirname, '../src/metra-sw.js'), 'utf8');
const queue = fs.readFileSync(path.join(__dirname, '../src/app/core/offline/daily-offline-queue.ts'), 'utf8');
const main = fs.readFileSync(path.join(__dirname, '../src/main.ts'), 'utf8');

test('PWA worker installs an application shell and activates immediately', () => {
  assert.match(worker, /caches\.open\(CACHE_NAME\)/);
  assert.match(worker, /self\.skipWaiting\(\)/);
  assert.match(worker, /self\.clients\.claim\(\)/);
  assert.match(worker, /APP_SHELL/);
});

test('PWA worker never intercepts or caches API/authenticated traffic', () => {
  assert.match(worker, /request\.method !== 'GET'/);
  assert.match(worker, /url\.origin !== self\.location\.origin/);
  assert.match(worker, /url\.pathname\.startsWith\('\/api\/'\)/);
  assert.match(worker, /return;/);
});

test('offline navigation falls back to cached application shell', () => {
  assert.match(worker, /request\.mode === 'navigate'/);
  assert.match(worker, /cache\.match\('\/'\)/);
  assert.match(worker, /catch\s*\{/);
});

test('outbox confirms writes only after IndexedDB transaction completion', () => {
  assert.match(queue, /operation\(transaction\.objectStore\(storeName\)\)/);
  assert.match(queue, /transaction\.oncomplete\s*=\s*\(\)\s*=>\s*resolve\(result\)/);
  assert.match(queue, /keyPath: 'idempotencyKey'/);
});

test('application registers service worker only in secure context', () => {
  assert.match(main, /'serviceWorker' in navigator/);
  assert.match(main, /location\.protocol === 'https:'/);
  assert.match(main, /register\('\.\/metra-sw\.js'\)/);
});

test('web manifest declares an Arabic standalone application', () => {
  const manifest = JSON.parse(fs.readFileSync(path.join(__dirname, '../src/manifest.webmanifest'), 'utf8'));
  assert.equal(manifest.lang, 'ar');
  assert.equal(manifest.dir, 'rtl');
  assert.equal(manifest.display, 'standalone');
  assert.equal(manifest.start_url, '/');
});

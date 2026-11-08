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
  assert.match(worker, /'metra-icon\.svg'/);
});

test('PWA worker never intercepts or caches API/authenticated traffic', () => {
  assert.match(worker, /request\.method !== 'GET'/);
  assert.match(worker, /url\.origin !== self\.location\.origin/);
  assert.match(worker, /url\.pathname\.startsWith\('\/api\/'\)/);
  assert.match(worker, /return;/);
});

test('offline navigation falls back to cached application shell', () => {
  assert.match(worker, /request\.mode === 'navigate'/);
  assert.match(worker, /new URL\('\.\/', self\.registration\.scope\)/);
  assert.match(worker, /cache\.match\(APP_ROOT\)/);
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
  assert.equal(manifest.start_url, './');
  assert.equal(manifest.scope, './');
  assert.ok(manifest.icons.some(icon => icon.src === './metra-icon.svg' && icon.type === 'image/svg+xml'));
  assert.ok(fs.existsSync(path.join(__dirname, '../src/metra-icon.svg')));
});


test('hourly report permits local queueing without API configuration and uses secure UUID helper', () => {
  const hourly = fs.readFileSync(path.join(__dirname, '../src/app/features/reports/hourly-reports.component.ts'), 'utf8');
  assert.match(hourly, /createIdempotencyKey\(\)/);
  assert.match(hourly, /!this\.isOnline \|\| !this\.apiReady/);
  assert.match(hourly, /getConfirmedDailySubmission\(result\)/);
  assert.doesNotMatch(hourly, /crypto\.randomUUID\(\)/);
  assert.doesNotMatch(hourly, /disabled]="saving \|\| !apiReady \|\| !selectedStationId"/);
});

test('daily report keeps local queue available when API configuration is absent', () => {
  const daily = fs.readFileSync(path.join(__dirname, '../src/app/features/reports/daily-reports.component.ts'), 'utf8');
  assert.match(daily, /!this\.isOnline \|\| !this\.apiReady/);
  assert.doesNotMatch(daily, /disabled]="saving \|\| !apiReady \|\| !selectedStationId"/);
});


test('daily and hourly sync use one shared IndexedDB lease', () => {
  const daily = fs.readFileSync(path.join(__dirname, '../src/app/features/reports/daily-reports.component.ts'), 'utf8');
  const hourly = fs.readFileSync(path.join(__dirname, '../src/app/features/reports/hourly-reports.component.ts'), 'utf8');
  assert.match(queue, /sync-locks/);
  assert.match(queue, /acquireSyncLease\(owner: string/);
  assert.match(queue, /releaseSyncLease\(owner: string/);
  assert.match(queue, /indexedDB\.open\(this\.databaseName, 3\)/);
  assert.match(daily, /acquireSyncLease\(this\.syncOwner\)/);
  assert.match(daily, /releaseSyncLease\(this\.syncOwner\)/);
  assert.match(hourly, /acquireSyncLease\(this\.syncOwner\)/);
  assert.match(hourly, /releaseSyncLease\(this\.syncOwner\)/);
});

test('hourly submit does not block offline enqueue when API is unconfigured', () => {
  const hourly = fs.readFileSync(path.join(__dirname, '../src/app/features/reports/hourly-reports.component.ts'), 'utf8');
  assert.doesNotMatch(hourly, /if \(!this\.apiReady\) \{ this\.message = 'لم يتم الإرسال/);
  assert.match(hourly, /if \(!this\.isOnline \|\| !this\.apiReady\)\s*\{/);
});


test('daily and hourly screens distinguish blocked records and expose explicit retry', () => {
  const daily = fs.readFileSync(path.join(__dirname, '../src/app/features/reports/daily-reports.component.ts'), 'utf8');
  const hourly = fs.readFileSync(path.join(__dirname, '../src/app/features/reports/hourly-reports.component.ts'), 'utf8');
  for (const source of [daily, hourly]) {
    assert.match(source, /blockedOfflineCount/);
    assert.match(source, /state === 'blocked'/);
    assert.match(source, /retryBlockedOffline\(\)/);
    assert.match(source, /إعادة محاولة النشرات المتوقفة/);
  }
  assert.match(hourly, /observationType === 'hourly' && item\.state === 'blocked'/);
  assert.match(daily, /\(item\.observationType \?\? 'daily'\) !== 'daily'/);
  assert.match(daily, /blockedOfflineItems/);
  assert.match(hourly, /blockedOfflineItems/);
  assert.match(daily, /item\.lastError/);
  assert.match(hourly, /item\.lastError/);
});


test('shared sync lease is renewed before each queued submission', () => {
  const daily = fs.readFileSync(path.join(__dirname, '../src/app/features/reports/daily-reports.component.ts'), 'utf8');
  const hourly = fs.readFileSync(path.join(__dirname, '../src/app/features/reports/hourly-reports.component.ts'), 'utf8');
  assert.match(queue, /renewSyncLease\(owner: string/);
  assert.match(daily, /renewSyncLease\(this\.syncOwner\)/);
  assert.match(hourly, /renewSyncLease\(this\.syncOwner\)/);
});

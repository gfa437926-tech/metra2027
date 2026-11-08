/* METRA offline application shell. API/auth traffic is deliberately never cached. */
const CACHE_PREFIX = 'metra-app-shell-';
const CACHE_NAME = CACHE_PREFIX + 'v1';
const APP_SHELL = ['/', '/index.html', '/metra-config.js', '/manifest.webmanifest'];

self.addEventListener('install', event => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE_NAME);
    await Promise.all(APP_SHELL.map(async path => {
      try { await cache.add(new Request(path, { cache: 'reload' })); } catch { /* deployment path may differ */ }
    }));
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.filter(key => key.startsWith(CACHE_PREFIX) && key !== CACHE_NAME).map(key => caches.delete(key)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', event => {
  const request = event.request;
  const url = new URL(request.url);
  if (request.method !== 'GET' || url.origin !== self.location.origin || url.pathname.startsWith('/api/')) return;

  if (request.mode === 'navigate') {
    event.respondWith((async () => {
      const cache = await caches.open(CACHE_NAME);
      try {
        const response = await fetch(request);
        if (response.ok) await cache.put('/', response.clone());
        return response;
      } catch {
        return (await cache.match(request)) || (await cache.match('/')) || Response.error();
      }
    })());
    return;
  }

  // Cache only same-origin static resources; never cache authenticated API responses.
  if (['script', 'style', 'font', 'image', 'worker'].includes(request.destination) ||
      /\/metra-config\.js$/.test(url.pathname)) {
    event.respondWith((async () => {
      const cache = await caches.open(CACHE_NAME);
      const cached = await cache.match(request);
      if (cached) return cached;
      const response = await fetch(request);
      if (response.ok && response.type === 'basic') await cache.put(request, response.clone());
      return response;
    })());
  }
});

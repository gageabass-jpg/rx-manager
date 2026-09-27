/* Rx Manager — offline service worker
   Strategy:
   - NAVIGATIONS (the HTML page): network-first. Always try the network so a new
     deploy shows up immediately when online; fall back to cache when offline.
     This is what fixes "the iPad won't reflect my changes".
   - STATIC ASSETS (js/fonts/icons): cache-first (fast, and they rarely change);
     refreshed in the background when online.
   Bump CACHE_VERSION on every deploy so old caches are cleared on activate. */
const CACHE_VERSION = 'rx-manager-v15';
const ASSETS = [
  './',
  './index.html',
  './support.js',
  './manifest.webmanifest',
  './apple-touch-icon.png',
  './icon-192.png',
  './icon-512.png',
  './vendor/react.production.min.js',
  './vendor/react-dom.production.min.js',
  './vendor/babel.min.js',
  './fonts/plex.local.css',
  './fonts/plex--F63fjptAgt5VM-kVkqdyU8n1i8q131nj-o.woff2',
  './fonts/plex--F63fjptAgt5VM-kVkqdyU8n1iAq131nj-otFQ.woff2',
  './fonts/plex--F63fjptAgt5VM-kVkqdyU8n1iEq131nj-otFQ.woff2',
  './fonts/plex--F63fjptAgt5VM-kVkqdyU8n1iIq131nj-otFQ.woff2',
  './fonts/plex--F63fjptAgt5VM-kVkqdyU8n1isq131nj-otFQ.woff2',
  './fonts/plex--F6qfjptAgt5VM-kVkqdyU8n3pQPwl1FgsAXHNlYzg.woff2',
  './fonts/plex--F6qfjptAgt5VM-kVkqdyU8n3pQPwl5FgsAXHNlYzg.woff2',
  './fonts/plex--F6qfjptAgt5VM-kVkqdyU8n3pQPwl9FgsAXHNlYzg.woff2',
  './fonts/plex--F6qfjptAgt5VM-kVkqdyU8n3pQPwlBFgsAXHNk.woff2',
  './fonts/plex--F6qfjptAgt5VM-kVkqdyU8n3pQPwlRFgsAXHNlYzg.woff2',
  './fonts/plex--F6qfjptAgt5VM-kVkqdyU8n3twJwl1FgsAXHNlYzg.woff2',
  './fonts/plex--F6qfjptAgt5VM-kVkqdyU8n3twJwl5FgsAXHNlYzg.woff2',
  './fonts/plex--F6qfjptAgt5VM-kVkqdyU8n3twJwl9FgsAXHNlYzg.woff2',
  './fonts/plex--F6qfjptAgt5VM-kVkqdyU8n3twJwlBFgsAXHNk.woff2',
  './fonts/plex--F6qfjptAgt5VM-kVkqdyU8n3twJwlRFgsAXHNlYzg.woff2',
  './fonts/plex--F6qfjptAgt5VM-kVkqdyU8n3vAOwl1FgsAXHNlYzg.woff2',
  './fonts/plex--F6qfjptAgt5VM-kVkqdyU8n3vAOwl5FgsAXHNlYzg.woff2',
  './fonts/plex--F6qfjptAgt5VM-kVkqdyU8n3vAOwl9FgsAXHNlYzg.woff2',
  './fonts/plex--F6qfjptAgt5VM-kVkqdyU8n3vAOwlBFgsAXHNk.woff2',
  './fonts/plex--F6qfjptAgt5VM-kVkqdyU8n3vAOwlRFgsAXHNlYzg.woff2',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_VERSION)
      .then((cache) => cache.addAll(ASSETS))
      .then(() => self.skipWaiting())      // new SW takes over ASAP
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE_VERSION).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())    // control open pages immediately
  );
});

function isNavigation(req) {
  return req.mode === 'navigate' ||
    (req.method === 'GET' && (req.headers.get('accept') || '').includes('text/html'));
}

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;

  if (isNavigation(req)) {
    // Network-first: fresh page when online, cached page when offline.
    event.respondWith(
      fetch(req)
        .then((res) => {
          const copy = res.clone();
          caches.open(CACHE_VERSION).then((cache) => cache.put('./index.html', copy));
          return res;
        })
        .catch(() => caches.match('./index.html', { ignoreSearch: true })
          .then((c) => c || caches.match('./', { ignoreSearch: true })))
    );
    return;
  }

  // Static assets: cache-first, refresh in background.
  event.respondWith(
    caches.match(req, { ignoreSearch: true }).then((cached) => {
      const network = fetch(req).then((res) => {
        if (res && res.status === 200 && res.type === 'basic') {
          const copy = res.clone();
          caches.open(CACHE_VERSION).then((cache) => cache.put(req, copy));
        }
        return res;
      }).catch(() => cached);
      return cached || network;
    })
  );
});

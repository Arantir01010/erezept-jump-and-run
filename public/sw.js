/**
 * Service Worker der PWA — abhängigkeitsfrei (kein Workbox/Plugin).
 *
 * Strategie:
 *  - Vite-gehashte Bundles (assets/name-HASH.ext) sind unveränderlich
 *    → Cache-first: schnell und garantiert konsistent.
 *  - Alles andere (index.html, Configs, Tilemaps, Level-JSON) → Network-first
 *    mit Cache-Rückfall: Deploys landen sofort, offline läuft der letzte
 *    vollständige Stand weiter. Nach EINEM kompletten Durchlauf ist alles
 *    im Cache (Configs lädt die BootScene, Assets die PreloadScene).
 *
 * CACHE-Version bei Strategie-Änderungen hochzählen — activate räumt alte auf.
 */
const CACHE = 'paul-rezi-v1'

/** Vite-Fingerprint im Dateinamen? Dann ist der Inhalt unveränderlich. */
const istGehasht = (url) => /\/assets\/[^/]+-[A-Za-z0-9_-]{8,}\.[a-z0-9]+$/.test(url.pathname)

self.addEventListener('install', () => {
  self.skipWaiting()
})

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim()),
  )
})

self.addEventListener('fetch', (event) => {
  const { request } = event
  if (request.method !== 'GET') return
  const url = new URL(request.url)
  if (url.origin !== self.location.origin) return

  if (istGehasht(url)) {
    event.respondWith(
      caches.open(CACHE).then(async (cache) => {
        const hit = await cache.match(request)
        if (hit) return hit
        const res = await fetch(request)
        if (res.ok) cache.put(request, res.clone())
        return res
      }),
    )
    return
  }

  event.respondWith(
    caches.open(CACHE).then(async (cache) => {
      try {
        const res = await fetch(request)
        if (res.ok) cache.put(request, res.clone())
        return res
      } catch (err) {
        const hit = await cache.match(request)
        if (hit) return hit
        // Offline-Navigation ohne Cache-Treffer: auf die Startseite zurückfallen
        if (request.mode === 'navigate') {
          const start = await cache.match('./')
          if (start) return start
        }
        throw err
      }
    }),
  )
})

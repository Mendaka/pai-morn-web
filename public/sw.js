// Two independent caching rules — see each section below for what it does and why.
self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", (event) => event.waitUntil(self.clients.claim()));

// --- 1. Static assets: cache-first, forever -------------------------------
// This site's own built CSS/JS/fonts under /_next/static/ are content-hashed by
// Next.js and never change once built, so a page reload never needs to depend on
// the network for them again after the first successful fetch. Fixes a real bug:
// switching apps on a phone and coming straight back often hits a few seconds of
// flaky mobile network exactly when the browser reloads the page — if the
// stylesheet request fails at that moment, the browser paints the raw,
// completely unstyled HTML (bulleted nav, blue underlined links, no layout at
// all) since there is nothing else to fall back on.
const STATIC_CACHE = "static-assets-v1";

function isCacheableStatic(url) {
  return url.origin === self.location.origin && (url.pathname.startsWith("/_next/static/") || url.pathname.startsWith("/icons/") || url.pathname === "/promptpay-qr.png");
}

// --- 2. Recently-read songs: network-first, cache as a fallback -----------
// Lets a song someone has already opened stay readable with no signal at all
// (a real request: mobile data is unreliable for a lot of this site's
// audience). Unlike the static-asset rule above, this DOES touch a page that
// shows live data (view count, approval edits) — on purpose, and safely: the
// network is always tried FIRST, so anyone online always sees the current
// version; the cached copy is only ever used when the network request itself
// fails (genuinely offline, or a mid-flight drop). A page that was never
// opened before while online was never cached, so it behaves exactly as
// before (no false promise of offline access to songs never visited).
const SONG_CACHE = "song-pages-v1";
const MAX_CACHED_SONGS = 40; // a phone's worth of "recently read", not unbounded growth

function isSongPage(url) {
  return url.origin === self.location.origin && url.pathname.startsWith("/songbook/song/");
}

async function trimCache(cache, max) {
  const keys = await cache.keys();
  const excess = keys.length - max;
  for (let i = 0; i < excess; i++) await cache.delete(keys[i]); // oldest-inserted first
}

self.addEventListener("fetch", (event) => {
  const url = new URL(event.request.url);
  if (event.request.method !== "GET") return; // never intercept writes (Firestore, uploads, ...)

  if (isCacheableStatic(url)) {
    event.respondWith(
      caches.open(STATIC_CACHE).then(async (cache) => {
        const cached = await cache.match(event.request);
        if (cached) return cached;
        // One retry before giving up. Found 2026-10-06 (owner screenshotted
        // the exact raw-HTML bug this cache was meant to prevent, still
        // happening): a bare, uncaught `fetch()` here turns a single
        // transient drop into a GUARANTEED failure for that resource — no
        // retry, no fallback, nothing cached yet to serve instead — which is
        // worse than not intercepting the request at all, since the
        // browser's own native loading might have recovered from the exact
        // same blip on its own. This is the "switching apps on a phone and
        // coming straight back" scenario described above, playing out
        // against this cache's own fetch wrapper instead of being protected
        // by it.
        try {
          const response = await fetch(event.request);
          if (response.ok) cache.put(event.request, response.clone());
          return response;
        } catch (err) {
          try {
            const retry = await fetch(event.request);
            if (retry.ok) cache.put(event.request, retry.clone());
            return retry;
          } catch {
            throw err;
          }
        }
      }),
    );
    return;
  }

  if (isSongPage(url)) {
    event.respondWith(
      (async () => {
        const cache = await caches.open(SONG_CACHE);
        try {
          const response = await fetch(event.request);
          if (response.ok) {
            await cache.put(event.request, response.clone());
            trimCache(cache, MAX_CACHED_SONGS);
          }
          return response;
        } catch (err) {
          const cached = await cache.match(event.request);
          if (cached) return cached;
          throw err; // never visited before while online — no cache to fall back to
        }
      })(),
    );
  }
  // everything else (Home, SongBook listing, Firestore, auth, ...) is left alone
});

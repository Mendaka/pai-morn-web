// Cutover kill switch. Visitors of the old Flutter web app have Flutter's
// service worker (registered at exactly this URL) cached on their device; left
// alone it would keep answering requests from the OLD app's cache and hide this
// site. Browsers re-fetch a service worker script on every visit, so serving
// this one makes each returning device unregister the old worker, clear its
// caches and reload onto the new site. Harmless for everyone else.
self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", (event) => {
  event.waitUntil(
    (async () => {
      const keys = await caches.keys();
      await Promise.all(keys.map((k) => caches.delete(k)));
      await self.registration.unregister();
      const clients = await self.clients.matchAll({ type: "window" });
      clients.forEach((c) => c.navigate(c.url));
    })(),
  );
});

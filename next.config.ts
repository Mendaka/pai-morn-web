import type { NextConfig } from "next";

// Pages that read the song catalog are rendered per request; this short CDN cache
// keeps Firebase Hosting from invoking the SSR function for every visit while new
// songs still show up within a minute.
const CDN_CACHE = [{ key: "Cache-Control", value: "public, max-age=0, s-maxage=60" }];

// sitemap.xml gets its own, much longer CDN cache (2026-10-14): Search
// Console showed Google had never successfully fetched it ("Couldn't fetch",
// 0 discovered pages) — only the homepage was indexed on the whole site. A
// 60s cache means almost any crawl attempt on a low-traffic site hits a cold
// SSR function invocation directly (this one's bundle is 300-400MB, a real
// cold-start risk) rather than a warm CDN response; a sitemap changes only
// when a song gets approved, so an hour-stale copy costs nothing.
const SITEMAP_CACHE = [{ key: "Cache-Control", value: "public, max-age=0, s-maxage=3600" }];

const nextConfig: NextConfig = {
  async headers() {
    return [
      ...[
        "/",
        "/songbook",
        "/songbook/song/:id",
        "/songbook/artist/:id",
        "/about",
        "/songs-index.json",
        "/artists-index.json",
      ].map((source) => ({ source, headers: CDN_CACHE })),
      { source: "/sitemap.xml", headers: SITEMAP_CACHE },
    ];
  },
  images: {
    // The optimizer (/_next/image) rejected every remote URL on the deployed
    // Cloud Function ("url" parameter is not allowed), so avatars, artist
    // photos and covers never showed. The sources are already small (photos
    // are resized on upload, covers are YouTube's mqdefault), so serve them
    // as-is and let the browser load them directly.
    unoptimized: true,
    remotePatterns: [
      // Song cover art: the YouTube thumbnail of each song's linked video.
      { protocol: "https", hostname: "img.youtube.com", pathname: "/vi/**" },
      // Artist / profile photos uploaded to Firebase Storage.
      { protocol: "https", hostname: "firebasestorage.googleapis.com", pathname: "/v0/b/**" },
    ],
  },
};

export default nextConfig;

// Public origin of THIS deployment: used for og:url / og:image / canonical /
// sitemap / robots. Facebook, Line and search engines follow og:url, so it has
// to be where the page really lives.
//
// Cutover done 2026-09-23: song-and-chord.web.app now serves this app (used to
// be the old Flutter build), so that's the default. Override with
// NEXT_PUBLIC_SITE_URL at build time for any other deployment (e.g. a preview
// channel) that needs its own og:url instead of this default.
export const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL ?? "https://song-and-chord.web.app";

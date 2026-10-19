import type { MetadataRoute } from "next";
import { getCatalog } from "@/lib/catalog";
import { SITE_URL } from "@/lib/site";

// Replaces the old `sitemap` Cloud Function. Same content (fixed pages plus
// every approved song), now also listing artist pages since those are real
// crawlable pages here. Rendered per request (CDN-cached briefly, see next.config.ts).
export const dynamic = "force-dynamic";

const STATIC_PATHS = [
  "/",
  "/songbook",
  "/book",
  "/tuner",
  "/chords",
  "/request-song",
  "/about",
  "/contact",
  "/guide",
  "/shop",
  "/privacy",
  "/terms",
  "/community",
  "/song-requests/vote",
];

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const { songs, artists } = await getCatalog();

  return [
    ...STATIC_PATHS.map((path) => ({ url: `${SITE_URL}${path}` })),
    ...artists.map((a) => ({ url: `${SITE_URL}/songbook/artist/${a.id}` })),
    ...songs.map((s) => ({
      url: `${SITE_URL}/songbook/song/${s.id}`,
      ...(s.approvedAt ? { lastModified: new Date(s.approvedAt) } : {}),
    })),
  ];
}

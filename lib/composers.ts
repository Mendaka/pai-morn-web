import type { SongSummary } from "@/lib/catalog";

export type ComposerSummary = { name: string; songCount: number };

// Composers aren't their own Firestore collection (unlike artists) — just the
// free-text `songwriter` field on each song — so a composer's "identity" is
// its trimmed name and its route param is that name, URL-encoded.
export function composersFrom(songs: SongSummary[]): ComposerSummary[] {
  const counts = new Map<string, number>();
  for (const s of songs) {
    if (!s.songwriter) continue;
    counts.set(s.songwriter, (counts.get(s.songwriter) ?? 0) + 1);
  }
  return [...counts.entries()]
    .map(([name, songCount]) => ({ name, songCount }))
    .sort((a, b) => b.songCount - a.songCount || a.name.localeCompare(b.name));
}

export function composerHref(name: string): string {
  return `/songbook/composer/${encodeURIComponent(name)}`;
}

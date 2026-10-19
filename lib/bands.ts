export type BandSummary = { name: string; songCount: number };

// Bands aren't their own Firestore collection (unlike artists) — just the
// free-text `band` field on each song — so a band's "identity" is its
// trimmed name and its route param is that name, URL-encoded. Mirrors
// lib/composers.ts's composersFrom/composerHref pattern.
export function bandHref(name: string): string {
  return `/songbook/band/${encodeURIComponent(name)}`;
}

import { cache } from "react";
import { collection, getDocs, query, where } from "firebase/firestore";
import { canonicalChordName } from "@/lib/chord-shapes";
import { serverDb } from "@/lib/firebase/server";
import { extractYoutubeVideoId } from "@/lib/youtube";

// Lightweight shapes for list pages — no lyrics, plain serializable values
// only (these cross the server -> client component boundary).
export type SongSummary = {
  id: string;
  songName: string;
  artistNames: string[];
  artistIds: string[];
  band: string;
  category: string;
  gender: string;
  key: string;
  keyIsMinor: boolean;
  songwriter: string;
  viewCount: number;
  approvedAt: number; // epoch ms, 0 if unknown
  youtubeId: string | null;
  // Unique chord names as authored (no transpose applied), canonicalized the same
  // way the Chords page names its diagrams — so this always lines up with
  // usePinnedChords()'s stored names for the "songs I can play" filter (SongBrowser).
  chords: string[];
};

export type ArtistSummary = {
  id: string;
  name: string;
  bio: string;
  photoUrl: string;
  songCount: number;
};

export type Catalog = { songs: SongSummary[]; artists: ArtistSummary[] };

// A song's Band (if set) is a joint act covering multiple singers, so it
// reads better on a card/byline than the individual artist names — matches
// the rule the Flutter app used (see lib/widget/song_reader_screen.dart's
// _buildArtistLine and book_screen.dart's entity grouping).
export function displayArtistName(song: { artistNames: string[]; band: string }): string {
  return song.band.trim() || song.artistNames.join(", ");
}

// The SongBook "Artists" tab browsing entity (or entities) a song belongs
// to. A Band song belongs to exactly ONE entity — that band's own shared
// card ("band:$name") — instead of each of its artistIds, merging every
// singer who's recorded under that band into one card rather than one
// per singer (the real bug this fixes: two different singers on the same
// "Sumai" album each getting their own "Sumai"-labeled card). A song with
// no Band belongs to each of its own artistIds, same as before.
export function songEntityIds(song: { artistIds: string[]; band: string }): string[] {
  const band = song.band.trim();
  return band ? [`band:${band}`] : song.artistIds;
}

const str = (v: unknown): string => (typeof v === "string" ? v : "");
const strList = (v: unknown): string[] => (Array.isArray(v) ? v.filter((x): x is string => typeof x === "string") : []);

// Every distinct chord a song's lyrics use, in the same canonical spelling
// GUITAR_SHAPES/UKULELE_SHAPES key on (e.g. "Bb" and "A#" both become "A#") —
// anything canonicalChordName doesn't recognize (a typo, an unusual chord not
// in the library) is dropped rather than left in a form nothing can match.
function uniqueChords(lyrics: unknown): string[] {
  if (!Array.isArray(lyrics)) return [];
  const seen = new Set<string>();
  for (const line of lyrics) {
    const content = (line as { content?: unknown })?.content;
    if (!Array.isArray(content)) continue;
    for (const token of content) {
      const t = token as { type?: unknown; text?: unknown };
      if (t?.type !== "chord" || typeof t.text !== "string") continue;
      const canonical = canonicalChordName(t.text);
      if (canonical) seen.add(canonical);
    }
  }
  return [...seen];
}

/**
 * Every approved song plus every artist that has at least one. ~150 songs
 * today, so one cheap read of both collections feeds the songbook, artist
 * pages and the home page alike — cached per request here, and across
 * requests by each page's `revalidate`. Only `approved` is ever returned
 * (firestore.rules alone would also let pending/rejected songs through).
 */
export const getCatalog = cache(() => memoizedCatalog());

// Every artist/song page needs the catalog, and a build (or a burst of ISR
// regenerations) renders many of those pages in one process — without this
// each would re-read ~230 Firestore documents. A short in-process TTL means
// they share one read, while data stays fresh well inside the pages' own
// `revalidate` window.
const CATALOG_TTL_MS = 60_000;
let memo: { at: number; promise: Promise<Catalog> } | null = null;

function memoizedCatalog(): Promise<Catalog> {
  if (memo && Date.now() - memo.at < CATALOG_TTL_MS) return memo.promise;
  const promise = fetchCatalog();
  memo = { at: Date.now(), promise };
  // Don't keep a failed read around for the TTL — let the next call retry.
  promise.catch(() => {
    if (memo?.promise === promise) memo = null;
  });
  return promise;
}

async function fetchCatalog(): Promise<Catalog> {
  const [songSnap, artistSnap] = await Promise.all([
    getDocs(query(collection(serverDb, "songs"), where("status", "==", "approved"))),
    getDocs(collection(serverDb, "artists")),
  ]);

  const songs: SongSummary[] = songSnap.docs.map((doc) => {
    const d = doc.data();
    const approvedAt = d.approvedAt?.toMillis?.() ?? d.createdAt?.toMillis?.() ?? 0;
    return {
      id: doc.id,
      songName: str(d.songName),
      artistNames: strList(d.artistNames).length ? strList(d.artistNames) : [str(d.artist)].filter(Boolean),
      artistIds: strList(d.artistIds),
      band: str(d.band),
      category: str(d.category).toLowerCase(),
      gender: str(d.gender).toLowerCase(),
      key: str(d.key),
      keyIsMinor: d.keyIsMinor === true,
      songwriter: str(d.songwriter).trim(),
      viewCount: typeof d.viewCount === "number" ? d.viewCount : 0,
      approvedAt,
      youtubeId: extractYoutubeVideoId(str(d.youtubeLink)),
      chords: uniqueChords(d.lyrics),
    };
  });

  const counts = new Map<string, number>();
  for (const s of songs) for (const id of s.artistIds) counts.set(id, (counts.get(id) ?? 0) + 1);

  const artists: ArtistSummary[] = artistSnap.docs
    .filter((doc) => (counts.get(doc.id) ?? 0) > 0)
    .map((doc) => {
      const d = doc.data();
      return {
        id: doc.id,
        name: str(d.name),
        bio: str(d.bio),
        photoUrl: str(d.photoUrl),
        songCount: counts.get(doc.id) ?? 0,
      };
    })
    .sort((a, b) => b.songCount - a.songCount || a.name.localeCompare(b.name));

  return { songs, artists };
}

import { cache } from "react";
import { collection, doc, documentId, getDoc, getDocs, query, where, type DocumentData, type DocumentSnapshot } from "firebase/firestore";
import { serverDb } from "@/lib/firebase/server";
import type { LyricLineData } from "@/lib/lyrics";

// Plain, serializable song shape handed from Server Components to Client
// Components — no Firestore Timestamps or other class instances (those
// can't cross the server/client boundary).
export type Song = {
  id: string;
  songName: string;
  artist: string;
  artistIds: string[];
  band: string;
  songwriter: string;
  /** Display name of the user who submitted this song (denormalized at submit time in SongEditor.tsx) — the site's own contributor, not the song's original songwriter. */
  authorName: string;
  key: string;
  keyIsMinor: boolean;
  category: string;
  youtubeLink: string;
  viewCount: number;
  lyrics: LyricLineData[];
};

const str = (v: unknown): string => (typeof v === "string" ? v : "");
const strList = (v: unknown): string[] => (Array.isArray(v) ? v.filter((x): x is string => typeof x === "string") : []);

// Shared by getApprovedSong and getApprovedSongsByIds so the two never drift
// apart on which fields a "Song" actually has. Returns null for anything not
// `approved` — firestore.rules alone would also let pending/rejected songs
// through, so this check is what keeps unreviewed content off public pages
// (same gate the old songPreview Cloud Function applied).
function songFromDoc(snap: DocumentSnapshot<DocumentData>): Song | null {
  if (!snap.exists()) return null;
  const d = snap.data();
  if (d.status !== "approved") return null;
  return {
    id: snap.id,
    songName: str(d.songName),
    artist: str(d.artist),
    artistIds: strList(d.artistIds),
    band: str(d.band),
    songwriter: str(d.songwriter),
    authorName: str(d.authorName),
    key: str(d.key),
    keyIsMinor: d.keyIsMinor === true,
    category: str(d.category),
    youtubeLink: str(d.youtubeLink),
    viewCount: typeof d.viewCount === "number" ? d.viewCount : 0,
    lyrics: Array.isArray(d.lyrics) ? (d.lyrics as LyricLineData[]) : [],
  };
}

/** `cache` dedupes the read between generateMetadata and the page for a single request. */
export const getApprovedSong = cache(async (id: string): Promise<Song | null> => {
  const snap = await getDoc(doc(serverDb, "songs", id));
  return songFromDoc(snap);
});

// Firestore's docs say `in` supports up to 30 values, but that's not the
// real ceiling here: this collection's read rule evaluates `resource.data`
// per matched document (see firestore.rules' songs/{songId} — status-based,
// not a flat "allow read: if true"), and empirically, against the real
// production database, a `where(documentId(), "in", batch)` query under that
// rule shape starts failing with permission-denied at 21 ids — 20 always
// succeeded, 21 always failed (verified directly with a binary search, not
// assumed). Chunking at 20 stays inside the real, tested boundary.
const FIRESTORE_IN_LIMIT = 20;
function chunk<T>(items: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size) out.push(items.slice(i, i + size));
  return out;
}

/** Book mode's batch fetch: full Song (with lyrics) for many ids at once, approved-only. */
export const getApprovedSongsByIds = cache(async (ids: string[]): Promise<Song[]> => {
  const uniqueIds = [...new Set(ids)];
  if (uniqueIds.length === 0) return [];
  const songsCol = collection(serverDb, "songs");
  const batches = await Promise.all(
    chunk(uniqueIds, FIRESTORE_IN_LIMIT).map((batch) => getDocs(query(songsCol, where(documentId(), "in", batch)))),
  );
  const byId = new Map<string, Song>();
  for (const snap of batches) for (const doc of snap.docs) {
    const song = songFromDoc(doc);
    if (song) byId.set(song.id, song);
  }
  // Preserve the caller's requested order (book mode's reading order) rather
  // than Firestore's arbitrary per-batch order.
  return uniqueIds.map((id) => byId.get(id)).filter((s): s is Song => s !== undefined);
});

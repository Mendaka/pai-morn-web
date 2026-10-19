import { cache } from "react";
import { collection, doc, getDoc, getDocs, orderBy, query, where } from "firebase/firestore";
import { serverDb } from "@/lib/firebase/server";

// Admin-curated song collections (e.g. "Songs for the heartbroken") shown on
// the SongBook page — distinct from a signed-in user's own private Setlists.
// See firestore.rules' playlists/{playlistId}: a viewer only ever reads a
// published one, an admin reads everything.

export type PlaylistSummary = {
  id: string;
  title: string;
  description: string;
  coverUrl: string;
  songCount: number;
};

export type Playlist = {
  id: string;
  title: string;
  description: string;
  coverUrl: string;
  songIds: string[];
};

const str = (v: unknown): string => (typeof v === "string" ? v : "");
const strArray = (v: unknown): string[] => (Array.isArray(v) ? v.filter((x): x is string => typeof x === "string") : []);

/** Every published playlist, newest first — for the SongBook page's shelf. */
export const getPublishedPlaylists = cache(async (): Promise<PlaylistSummary[]> => {
  try {
    const snap = await getDocs(
      query(collection(serverDb, "playlists"), where("published", "==", true), orderBy("createdAt", "desc")),
    );
    return snap.docs.map((d) => {
      const data = d.data();
      return {
        id: d.id,
        title: str(data.title),
        description: str(data.description),
        coverUrl: str(data.coverUrl),
        songCount: strArray(data.songIds).length,
      };
    });
  } catch {
    return []; // best effort: the SongBook page still works without the shelf
  }
});

/** One playlist for its public detail page — null if missing OR not published (never leaks a draft). */
export const getPlaylist = cache(async (id: string): Promise<Playlist | null> => {
  const snap = await getDoc(doc(serverDb, "playlists", id));
  if (!snap.exists()) return null;
  const data = snap.data();
  if (data.published !== true) return null;
  return {
    id: snap.id,
    title: str(data.title),
    description: str(data.description),
    coverUrl: str(data.coverUrl),
    songIds: strArray(data.songIds),
  };
});

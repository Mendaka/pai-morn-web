"use client";

import { useEffect, useState } from "react";

export type IndexedSong = { id: string; name: string; artist: string; key: string };

let cached: Promise<IndexedSong[]> | null = null;
const load = () => (cached ??= fetch("/songs-index.json").then((r) => (r.ok ? r.json() : Promise.reject(new Error(String(r.status))))).catch((e) => {
  cached = null; // let the next call retry
  throw e;
}));

/** Every approved song (id, title, artist, key), or null while loading. */
export function useSongsIndex(): { songs: IndexedSong[] | null; byId: Map<string, IndexedSong> } {
  const [songs, setSongs] = useState<IndexedSong[] | null>(null);
  useEffect(() => {
    let alive = true;
    load().then((s) => alive && setSongs(s)).catch(() => alive && setSongs([]));
    return () => {
      alive = false;
    };
  }, []);
  return { songs, byId: new Map((songs ?? []).map((s) => [s.id, s])) };
}

export type IndexedArtist = { id: string; name: string; count: number };

let cachedArtists: Promise<IndexedArtist[]> | null = null;
const loadArtists = () =>
  (cachedArtists ??= fetch("/artists-index.json")
    .then((r) => (r.ok ? r.json() : Promise.reject(new Error(String(r.status)))))
    .catch((e) => {
      cachedArtists = null;
      throw e;
    }));

/** Every artist with approved songs, or null while loading. Only fetches once `enabled`. */
export function useArtistsIndex(enabled = true): IndexedArtist[] | null {
  const [artists, setArtists] = useState<IndexedArtist[] | null>(null);
  useEffect(() => {
    if (!enabled) return;
    let alive = true;
    loadArtists().then((a) => alive && setArtists(a)).catch(() => alive && setArtists([]));
    return () => {
      alive = false;
    };
  }, [enabled]);
  return artists;
}

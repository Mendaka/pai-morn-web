"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import type { Song } from "@/lib/songs";

// A book page's flip physics need every page mounted (react-pageflip clones
// each child into a page slot up front), but rendering ~150 songs' worth of
// real lyrics at once would be a heavy payload and a heavy DOM — so only a
// sliding window around the current page ever holds real data; everything
// else renders BookPage's title-only skeleton until the window reaches it.
const INITIAL_RADIUS = 4; // pages loaded ahead/behind on first mount
const PREFETCH_MARGIN = 3; // start extending this many pages before the loaded edge
const CHUNK = 8;

async function fetchSongs(ids: string[]): Promise<Song[]> {
  if (ids.length === 0) return [];
  const res = await fetch(`/book/songs?ids=${ids.map(encodeURIComponent).join(",")}`);
  return res.ok ? res.json() : [];
}

export function useBookWindow(orderedIds: string[]) {
  const [songs, setSongs] = useState<Map<string, Song>>(new Map());
  // Indices into orderedIds already requested (loaded or in flight) — a Ref
  // since it's bookkeeping, not something a render should depend on.
  const requested = useRef(new Set<string>());
  const range = useRef({ start: 0, end: -1 });

  const extend = useCallback((from: number, to: number) => {
    from = Math.max(0, from);
    to = Math.min(orderedIds.length - 1, to);
    if (from > to) return;
    const need: string[] = [];
    for (let i = from; i <= to; i++) {
      const id = orderedIds[i];
      if (id && !requested.current.has(id)) {
        requested.current.add(id);
        need.push(id);
      }
    }
    range.current = { start: Math.min(range.current.start, from), end: Math.max(range.current.end, to) };
    if (need.length === 0) return;
    fetchSongs(need).then((fetched) => {
      if (fetched.length === 0) return;
      setSongs((prev) => {
        const next = new Map(prev);
        for (const s of fetched) next.set(s.id, s);
        return next;
      });
    });
  }, [orderedIds]);

  useEffect(() => {
    extend(0, INITIAL_RADIUS * 2);
    // Runs once per mount: a book-reading session's id list is expected
    // stable for its whole lifetime (BookReader memoizes it) — same
    // assumption react-pageflip itself makes by computing its page list once.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const onPageChange = useCallback(
    (index: number) => {
      if (index + PREFETCH_MARGIN >= range.current.end) extend(range.current.end + 1, range.current.end + CHUNK);
      if (index - PREFETCH_MARGIN <= range.current.start) extend(range.current.start - CHUNK, range.current.start - 1);
    },
    [extend],
  );

  const getSong = useCallback((id: string) => songs.get(id), [songs]);

  return { getSong, onPageChange };
}

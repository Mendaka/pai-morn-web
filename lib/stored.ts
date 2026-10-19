"use client";

import { useCallback, useMemo, useSyncExternalStore } from "react";

// Small localStorage-backed prefs (instrument, left-handed, pinned chords…),
// device-local like the Flutter app's shared_preferences. Reads go through
// useSyncExternalStore, so server render and first client render agree
// (defaults) and the stored value applies right after hydration. If storage
// is blocked (private windows, some previews) it degrades to memory.

const EVENT = "pm-storage";
const memory = new Map<string, string>();

function read(key: string): string | null {
  try {
    return window.localStorage.getItem(key);
  } catch {
    return memory.get(key) ?? null;
  }
}

export function writeStored(key: string, value: string | null): void {
  try {
    if (value === null) window.localStorage.removeItem(key);
    else window.localStorage.setItem(key, value);
  } catch {
    if (value === null) memory.delete(key);
    else memory.set(key, value);
  }
  window.dispatchEvent(new Event(EVENT));
}

export function readStored(key: string): string | null {
  return read(key);
}

export function useStored(key: string): string | null {
  const subscribe = useCallback((cb: () => void) => {
    window.addEventListener(EVENT, cb);
    window.addEventListener("storage", cb);
    return () => {
      window.removeEventListener(EVENT, cb);
      window.removeEventListener("storage", cb);
    };
  }, []);
  return useSyncExternalStore(subscribe, () => read(key), () => null);
}

function parseList(raw: string | null): string[] {
  try {
    const v = raw ? JSON.parse(raw) : [];
    return Array.isArray(v) ? v.filter((x): x is string => typeof x === "string") : [];
  } catch {
    return [];
  }
}

// ---- concrete prefs -------------------------------------------------------

/** One global instrument preference: the Chords page and the tap-a-chord popup agree. */
export function useInstrument() {
  const raw = useStored("pm.instrument");
  return { ukulele: raw === "ukulele", set: (u: boolean) => writeStored("pm.instrument", u ? "ukulele" : "guitar") };
}

export function useLeftHanded() {
  const raw = useStored("pm.leftHanded");
  return { leftHanded: raw === "1", set: (v: boolean) => writeStored("pm.leftHanded", v ? "1" : "0") };
}

export function usePinnedChords() {
  const raw = useStored("pm.pinnedChords");
  const pinned = useMemo(() => new Set(parseList(raw)), [raw]);
  const toggle = (name: string) => {
    const next = new Set(pinned);
    if (!next.delete(name)) next.add(name);
    writeStored("pm.pinnedChords", JSON.stringify([...next]));
  };
  return { pinned, toggle };
}

const MAX_RECENT = 10;

/** Chords looked up from inside a song, newest first — resurfaced on /chords. */
export function useRecentChords(): string[] {
  const raw = useStored("pm.recentChords");
  return useMemo(() => parseList(raw), [raw]);
}
export function recordLookedUpChord(name: string): void {
  const list = parseList(read("pm.recentChords")).filter((n) => n !== name);
  writeStored("pm.recentChords", JSON.stringify([name, ...list].slice(0, MAX_RECENT)));
}

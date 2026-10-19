import type { LyricLineData } from "@/lib/lyrics";
import { transposeChord } from "@/lib/chords";
import { canonicalChordName } from "@/lib/chord-shapes";

// The handful of guitar chords every method book teaches first — genuinely
// playable with no barre at all. Deliberately a fixed, hand-picked list, not
// derived from GUITAR_SHAPES' baseFret: baseFret can be 1 for a real barre
// chord that just happens to land right next to the nut (F and the whole
// A#/Bb family do exactly that via the movable E-/A-shape generators in
// chord-shapes.ts), so "baseFret === 1" alone would wrongly call F "open".
const EASY_CHORDS = new Set(["C", "D", "E", "G", "A", "Am", "Em", "Dm", "C7", "D7", "E7", "G7", "A7", "Em7", "Am7"]);

// Past fret 5 a capo is rarely used in practice (thin tone, awkward reach), so a
// "solution" up there would be mathematically valid but not something a real
// guitarist would actually do — better to suggest nothing than something odd.
export const MAX_CAPO_FRET = 5;

/** Every distinct chord a song's lyrics use, canonicalized the way chord-shapes.ts keys its dictionaries. */
export function uniqueChords(lyrics: LyricLineData[]): string[] {
  const seen = new Set<string>();
  for (const line of lyrics)
    for (const token of line.content ?? []) {
      if (token.type !== "chord" || !token.text) continue;
      const canonical = canonicalChordName(token.text);
      if (canonical) seen.add(canonical);
    }
  return [...seen];
}

export type CapoSuggestion = { fret: number; shapes: string[] };

/**
 * If putting a capo somewhere between fret 1 and MAX_CAPO_FRET would let every
 * chord in the song be played as one of the classic open shapes above — while
 * the song's own, un-capo'd chords do NOT already qualify — returns the
 * lowest such fret and what to actually play there. Otherwise null: no
 * confident suggestion beats a shaky one (a song with, say, one chord outside
 * the easy set at every fret gets no suggestion at all, rather than a "close
 * enough" guess).
 */
export function suggestCapo(chords: string[]): CapoSuggestion | null {
  if (chords.length === 0) return null;
  const allEasyAt = (fret: number) => chords.every((c) => EASY_CHORDS.has(transposeChord(c, -fret)));
  if (allEasyAt(0)) return null;
  for (let fret = 1; fret <= MAX_CAPO_FRET; fret++) {
    if (allEasyAt(fret)) return { fret, shapes: [...new Set(chords.map((c) => transposeChord(c, -fret)))] };
  }
  return null;
}

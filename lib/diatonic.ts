// Port of lib/data/diatonic_chords.dart — the quick-pick chord chips for a key.

// Both spellings of every accidental, in chromatic order — flats were the
// only option before; sharps were added 2026-09-25 (owner: "อยากให้มี sharp
// เพิ่ม") without removing the existing flat picks, since some songs are
// written in one spelling and some in the other.
export const CHROMATIC_ROOTS = [
  "C", "C#", "Db", "D", "D#", "Eb", "E", "F", "F#", "Gb", "G", "G#", "Ab", "A", "A#", "Bb", "B",
] as const;

// Two parallel 12-note chromatic scales, index-aligned (position 0 = C,
// 1 = C#/Db, ...). Which one generates a key's OTHER chords (not just its
// root) is decided per-key: an explicitly sharp- or flat-spelled root (C#,
// Db, D#, Eb, ...) uses that same scale throughout — the user already chose
// that spelling. A natural root (C, D, E, F, G, A, B) has no such hint, so it
// falls back to the real key-signature convention below (MAJOR_SHARP_ROOTS /
// MINOR_SHARP_ROOTS).
//
// Also exported as the two 12-option root lists for ChordPanel's sharp/flat
// toggle (2026-09-30, owner passing on user feedback: "คีย์มีให้เลือกเยอะ
// เกินไปตาลาย") — CHROMATIC_ROOTS' own 17 entries (both spellings of every
// accidental, all at once) is what was overwhelming; picking sharp vs. flat
// FIRST, the same way major/minor already works, narrows the dropdown to 12.
export const SHARP_ROOTS = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"] as const;
export const FLAT_ROOTS = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"] as const;
const FLAT_SCALE: readonly string[] = FLAT_ROOTS;
const SHARP_SCALE: readonly string[] = SHARP_ROOTS;

function chromaticIndex(root: string): number {
  const i = FLAT_SCALE.indexOf(root);
  if (i !== -1) return i;
  return SHARP_SCALE.indexOf(root);
}

// Re-spells a root in the other scale at the same pitch (e.g. "C#" -> "Db")
// — used when the sharp/flat toggle flips, so the actual key selected
// doesn't silently change, only how it's written.
export function respellRoot(root: string, preferFlat: boolean): string {
  const i = chromaticIndex(root);
  if (i === -1) return root;
  return (preferFlat ? FLAT_SCALE : SHARP_SCALE)[i];
}

// Which scale generates a NATURAL root's (C/D/E/F/G/A/B, no accidental in the
// name) other chords — real key-signature convention (circle of fifths), not
// a guess. This genuinely differs by major vs. minor for the same letter
// (D major has 2 sharps; D minor has 1 flat), so it can't be folded into one
// list. Only C and F (major) / A and C (minor, both incidentally flat-side or
// accidental-free) are left out of their list — their diatonic chords have no
// accidentals either way, so the scale choice for them is moot.
// Bug found 2026-09-28 (owner: "เลือกคีย์ A มันขึ้น Gbm Dbm" instead of the
// standard C#m/F#m): every natural root used to fall through to FLAT_SCALE
// unconditionally, which only happens to be correct for C and F.
const MAJOR_SHARP_ROOTS = ["D", "E", "G", "A", "B"];
const MINOR_SHARP_ROOTS = ["B", "E"];

// `core` marks the 7 plain triads (one per scale degree) — the chords a
// beginner reaches for first and, per real usage, what most songs are
// actually built from. Everything else (7ths, maj7, dim7, and the alternate
// vii°/vii°7 spelling) is `core: false`. Added 2026-09-30 (owner passing on
// user feedback: "คอร์ดเยอะเกินไปตาลาย" — 16 chips per key was overwhelming)
// so ChordPanel.tsx can show just the 7 by default with a "more chords"
// expand for the rest, instead of dropping any of them.
export type DiatonicChord = { degree: string; chordName: string; core: boolean };

/**
 * Major key: I ii iii IV V vi vii, with vii offered as both `Xm` and `Xdim`
 * (real sheets use either) plus each degree's 7th extension. Minor key:
 * natural minor, except V is deliberately major (Am -> E, not Em) — the
 * common folk/luk-thung convention.
 */
export function diatonicChordsForKey(root: string, isMinor: boolean): DiatonicChord[] {
  const rootIndex = chromaticIndex(root);
  if (rootIndex === -1) return [];
  const sharpRoots = isMinor ? MINOR_SHARP_ROOTS : MAJOR_SHARP_ROOTS;
  const usesSharp = root.includes("#") || (!root.includes("b") && sharpRoots.includes(root));
  const scale = usesSharp ? SHARP_SCALE : FLAT_SCALE;
  const at = (semitones: number) => scale[(rootIndex + semitones) % 12];
  const c = (degree: string, chordName: string, core = false): DiatonicChord => ({ degree, chordName, core });

  if (!isMinor) {
    return [
      c("I", at(0), true), c("I maj7", `${at(0)}maj7`),
      c("ii", `${at(2)}m`, true), c("ii7", `${at(2)}m7`),
      c("iii", `${at(4)}m`, true), c("iii7", `${at(4)}m7`),
      c("IV", at(5), true), c("IV maj7", `${at(5)}maj7`),
      c("V", at(7), true), c("V7", `${at(7)}7`),
      c("vi", `${at(9)}m`, true), c("vi7", `${at(9)}m7`),
      c("vii", `${at(11)}m`, true), c("vii°", `${at(11)}dim`),
      c("vii7", `${at(11)}m7`), c("vii°7", `${at(11)}dim7`),
    ];
  }
  return [
    c("i", `${at(0)}m`, true), c("i7", `${at(0)}m7`),
    c("ii°", `${at(2)}dim`, true), c("ii°7", `${at(2)}dim7`),
    c("III", at(3), true), c("III maj7", `${at(3)}maj7`),
    c("iv", `${at(5)}m`, true), c("iv7", `${at(5)}m7`),
    c("V", at(7), true), c("V7", `${at(7)}7`),
    c("VI", at(8), true), c("VI maj7", `${at(8)}maj7`),
    c("VII", at(10), true), c("VII maj7", `${at(10)}maj7`),
  ];
}

// Port of lib/data/chord_shapes.dart + ukulele_chord_shapes.dart.
//
// frets: one entry per string, in the order the strings are drawn left to
// right (guitar: low E -> high e; ukulele: G C E A, physical order). null =
// muted, 0 = open. baseFret is the fret at the top of the 5-fret window
// drawn by <ChordDiagram>; 1 means the diagram starts at the nut, anything
// higher is a movable barre shape drawn from that fret with an "Nfr" label.

export type ChordShape = { baseFret: number; frets: (number | null)[] };

const ROOTS = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"] as const;
const semitonesFrom = (from: string, root: string) => (ROOTS.indexOf(root as never) - ROOTS.indexOf(from as never) + 12) % 12;

// ---- guitar ---------------------------------------------------------------

// Movable E-shape barre: pattern is the fingering for root = E; shifting every
// string up by the root's distance from E gives the same shape at any root.
function eShape(root: string, pattern: number[]): ChordShape {
  const shift = semitonesFrom("E", root);
  return { baseFret: shift === 0 ? 1 : shift, frets: pattern.map((f) => f + shift) };
}

// Movable A-shape barre: 5 entries A/D/G/B/e, low E always muted.
function aShape(root: string, pattern: number[]): ChordShape {
  const shift = semitonesFrom("A", root);
  return { baseFret: shift === 0 ? 1 : shift, frets: [null, ...pattern.map((f) => f + shift)] };
}

// Movable diminished triad: x-2-3-4-3-x on strings A/D/G/B at root = B. No open
// voicing exists, so baseFret is always shift + 2.
function dimShape(root: string): ChordShape {
  const shift = semitonesFrom("B", root);
  const [a, d, g, b] = [2, 3, 4, 3].map((f) => f + shift);
  return { baseFret: shift + 2, frets: [null, a, d, g, b, null] };
}

// An ordered list, not an object: JS enumerates integer-like keys ("7") first,
// which would put C7 before C. Order is the poster order: major, m, 7, ...
type Generators = [string, (root: string) => ChordShape][];
const GUITAR_GENERATORS: Generators = [
  ["", (r) => eShape(r, [0, 2, 2, 1, 0, 0])],
  ["m", (r) => eShape(r, [0, 2, 2, 0, 0, 0])],
  ["7", (r) => eShape(r, [0, 2, 0, 1, 0, 0])],
  ["maj7", (r) => eShape(r, [0, 2, 1, 1, 0, 0])],
  ["m7", (r) => eShape(r, [0, 2, 0, 0, 0, 0])],
  ["sus2", (r) => aShape(r, [0, 2, 2, 0, 0])],
  ["sus4", (r) => aShape(r, [0, 2, 2, 3, 0])],
  ["dim", dimShape],
];

// Hand-verified open-position voicings for the chords most players expect
// to see played open; they override the generated barre shape.
const s = (...frets: (number | null)[]): ChordShape => ({ baseFret: 1, frets });
const GUITAR_OPEN: Record<string, ChordShape> = {
  C: s(null, 3, 2, 0, 1, 0),
  D: s(null, null, 0, 2, 3, 2),
  G: s(3, 2, 0, 0, 0, 3),
  Dm: s(null, null, 0, 2, 3, 1),
  C7: s(null, 3, 2, 3, 1, 0),
  D7: s(null, null, 0, 2, 1, 2),
  G7: s(3, 2, 0, 0, 0, 1),
  Dsus2: s(null, null, 0, 2, 3, 0),
  Dsus4: s(null, null, 0, 2, 3, 3),
};

// ---- ukulele --------------------------------------------------------------

// Movable shape anchored at root = A, pattern given as G/C/E/A offsets.
function ukeShape(root: string, pattern: number[]): ChordShape {
  const shift = semitonesFrom("A", root);
  return { baseFret: shift === 0 ? 1 : shift, frets: pattern.map((f) => f + shift) };
}
const UKE_GENERATORS: Generators = [
  ["", (r) => ukeShape(r, [2, 1, 0, 0])],
  ["m", (r) => ukeShape(r, [2, 0, 0, 0])],
  ["7", (r) => ukeShape(r, [0, 1, 0, 0])],
  ["maj7", (r) => ukeShape(r, [1, 1, 0, 0])],
  ["m7", (r) => ukeShape(r, [0, 0, 0, 0])],
];
const UKE_OPEN: Record<string, ChordShape> = {
  C: s(0, 0, 0, 3),
  C7: s(0, 0, 0, 1),
  F: s(2, 0, 1, 0),
  G: s(0, 2, 3, 2),
  G7: s(0, 2, 1, 2),
  Dm: s(2, 2, 1, 0),
  Em: s(0, 4, 0, 2),
  D7: s(2, 2, 2, 3),
  E7: s(1, 2, 0, 2),
  "A#": s(3, 2, 1, 1),
};

function build(gens: Generators, open: Record<string, ChordShape>): Record<string, ChordShape> {
  const out: Record<string, ChordShape> = {};
  for (const root of ROOTS) {
    for (const [suffix, gen] of gens) {
      const name = `${root}${suffix}`;
      out[name] = open[name] ?? gen(root);
    }
  }
  return out;
}

// Insertion order (root by root, then quality) reads like a chord poster.
export const GUITAR_SHAPES = build(GUITAR_GENERATORS, GUITAR_OPEN);
export const UKULELE_SHAPES = build(UKE_GENERATORS, UKE_OPEN);

export const OPEN_STRING_HZ = {
  // E2 A2 D3 G3 B3 E4
  guitar: [82.41, 110.0, 146.83, 196.0, 246.94, 329.63],
  // Re-entrant GCEA: the high G is genuinely above the C beside it.
  ukulele: [392.0, 261.63, 329.63, 440.0],
} as const;

// ---- lookup ---------------------------------------------------------------

const FLAT_TO_SHARP: Record<string, string> = { Db: "C#", Eb: "D#", Gb: "F#", Ab: "G#", Bb: "A#" };
const QUALITY_ALIASES: Record<string, string> = {
  "": "", maj: "", M: "",
  m: "m", min: "m", "-": "m",
  "7": "7", dom7: "7",
  maj7: "maj7", M7: "maj7", "Δ": "maj7",
  m7: "m7", min7: "m7", "-7": "m7",
  sus2: "sus2", sus4: "sus4", sus: "sus4",
  dim: "dim", "°": "dim", o: "dim", dim7: "dim",
};

/**
 * The key a chord symbol resolves to in the dictionaries ("Bbm7" -> "A#m7",
 * "D/F#" -> "D"; slash bass notes are dropped). null if the root or quality
 * isn't one of the common ones covered.
 */
export function canonicalChordName(chord: string): string | null {
  const base = chord.split("/")[0].trim();
  const m = /^([A-G])(#|b)?/.exec(base);
  if (!m) return null;
  const note = m[1] + (m[2] ?? "");
  const root = FLAT_TO_SHARP[note] ?? note;
  if (!(ROOTS as readonly string[]).includes(root)) return null;
  const quality = QUALITY_ALIASES[base.slice(m[0].length)];
  return quality === undefined ? null : `${root}${quality}`;
}

export function lookupChordShape(chord: string, ukulele: boolean): ChordShape | null {
  const key = canonicalChordName(chord);
  if (!key) return null;
  return (ukulele ? UKULELE_SHAPES : GUITAR_SHAPES)[key] ?? null;
}

/** Root of a canonical name ("A#m7" -> "A#"), for colouring chords by root. */
export const chordRoot = (name: string): string => /^[A-G]#?/.exec(name)?.[0] ?? name;
export const rootColor = (root: string): string => `hsl(${Math.max(0, ROOTS.indexOf(root as never)) * 30} 68% 42%)`;

// Port of lib/utils/chord_transposer.dart. Output always uses sharp
// spellings (a transposed Bb comes back as A#), same as the Flutter app —
// when there's nothing to transpose the chord is returned untouched, so
// authored flats survive at 0 semitones.

const SHARP_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"];

const FLAT_TO_SHARP: Record<string, string> = {
  Db: "C#",
  Eb: "D#",
  Gb: "F#",
  Ab: "G#",
  Bb: "A#",
};

const ROOT_REGEX = /^([A-G])(#|b)?/;

// A chord-like "word" anywhere in the string: a note letter followed by any
// run of letters/digits/#/b. Only ever *starts* at an A-G letter, so label
// text mixed into the same token ("Key-G", "Intro .G/Em/C") is left alone
// wherever it doesn't itself begin with a note letter, while every embedded
// chord is still found and transposed.
const CHORD_WORD_REGEX = /[A-G][A-Za-z0-9#b]*/g;

function noteIndex(note: string): number {
  return SHARP_NAMES.indexOf(FLAT_TO_SHARP[note] ?? note);
}

function transposeToken(token: string, semitones: number): string {
  const match = ROOT_REGEX.exec(token);
  if (!match) return token;

  const note = match[1] + (match[2] ?? "");
  const suffix = token.slice(match[0].length);
  const index = noteIndex(note);
  if (index === -1) return token;

  const newIndex = (((index + semitones) % 12) + 12) % 12;
  return SHARP_NAMES[newIndex] + suffix;
}

/** Transposes every chord symbol in [chord] by [semitones] ("Am7" -> "Bm7", "D/F#" -> "E/G#"). */
export function transposeChord(chord: string, semitones: number): string {
  if (semitones === 0 || chord.length === 0) return chord;
  return chord.replace(CHORD_WORD_REGEX, (m) => transposeToken(m, semitones));
}

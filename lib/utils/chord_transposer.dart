const List<String> _sharpNames = [
  'C',
  'C#',
  'D',
  'D#',
  'E',
  'F',
  'F#',
  'G',
  'G#',
  'A',
  'A#',
  'B',
];

const Map<String, String> _flatToSharp = {
  'Db': 'C#',
  'Eb': 'D#',
  'Gb': 'F#',
  'Ab': 'G#',
  'Bb': 'A#',
};

final RegExp _rootRegex = RegExp(r'^([A-G])(#|b)?');

// Matches a chord-like "word" anywhere in the string: a note letter (A-G)
// followed by any run of letters/digits/#/b (the quality suffix). Because
// the match only ever *starts* at an A-G letter, label text mixed into the
// same token (e.g. "Key-G", "Intro .G/Em/C", "Solo-F/Dm/Gm") is left alone
// wherever it doesn't itself begin with a note letter, while every embedded
// chord — regardless of whether it's separated by '/', '.', '-' or a space —
// still gets found and transposed.
final RegExp _chordWordRegex = RegExp(r'[A-G][A-Za-z0-9#b]*');

/// Transposes every chord symbol found in [chord] up/down by [semitones],
/// e.g. "Am7" -> "Bm7", "D/F#" -> "E/G#", "Key-G" -> "Key-A". Only the root
/// note of each chord word shifts; the quality suffix (m, 7, maj7, sus4,
/// add9, ...) and any non-chord text in between is left untouched.
String transposeChord(String chord, int semitones) {
  if (semitones == 0 || chord.isEmpty) return chord;
  return chord.replaceAllMapped(
    _chordWordRegex,
    (match) => _transposeToken(match.group(0)!, semitones),
  );
}

String _transposeToken(String token, int semitones) {
  final match = _rootRegex.firstMatch(token);
  if (match == null) return token;

  final note = match.group(1)! + (match.group(2) ?? '');
  final suffix = token.substring(match.end);

  final index = _noteIndex(note);
  if (index == -1) return token;

  final newIndex = ((index + semitones) % 12 + 12) % 12;
  return _sharpNames[newIndex] + suffix;
}

int _noteIndex(String note) {
  final normalized = _flatToSharp[note] ?? note;
  return _sharpNames.indexOf(normalized);
}

/// Parses the root note of a single chord token (e.g. "F#" from "F#m7",
/// "Bb" from "Bb7") and normalizes it to its sharp-name spelling. Returns
/// null if [token] doesn't start with a recognizable note letter.
String? parseChordRoot(String token) {
  final match = _rootRegex.firstMatch(token);
  if (match == null) return null;
  final note = match.group(1)! + (match.group(2) ?? '');
  final index = _noteIndex(note);
  return index == -1 ? null : _sharpNames[index];
}

/// Returns the part of a single chord token after its root note, e.g. "m7"
/// from "Am7", "" from "C". Assumes [token] is one chord word, not a full
/// mixed-text line — call this on output from [parseChordRoot]'s match, or
/// on already-isolated chord text.
String chordQualitySuffix(String token) {
  final match = _rootRegex.firstMatch(token);
  return match == null ? token : token.substring(match.end);
}

import 'package:pai_morn_web/data/chord_shapes.dart';

/// Ukulele chord diagrams, reusing [ChordShape] from chord_shapes.dart.
///
/// [ChordShape.frets] has 4 entries here instead of guitar's 6, ordered
/// G-C-E-A left to right — the standard way every ukulele chord chart is
/// drawn, i.e. physical string order, not pitch order (the G string is
/// re-entrant: tuned an octave above where its position in the sequence
/// would suggest). `null`/`0` mean the same thing as on guitar (muted/open).
///
/// Only major, minor, dominant 7th, major 7th, and minor 7th are covered —
/// sus2/sus4/dim were left out rather than including a fingering pattern
/// that wasn't independently verified note-by-note the way every shape
/// below was. [lookupUkuleleChordShape] returns null for those (and for
/// anything else outside this dictionary), same graceful "skip it" handling
/// already used everywhere a chord diagram might not be found.
const List<String> _roots = [
  'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
];

int _semitonesFrom(String from, String root) {
  final rootIndex = _roots.indexOf(root);
  final fromIndex = _roots.indexOf(from);
  return (rootIndex - fromIndex + 12) % 12;
}

// Movable shape anchored at root = A (shift = 0), pattern given as
// G/C/E/A fret offsets. Verified by working out the actual notes each
// pattern produces at root A before trusting it as a template — e.g. the
// major pattern [2,1,0,0] plays G:A C:C# E:E A:A, i.e. A-C#-E, a genuine A
// major triad — rather than copied from memory unchecked.
ChordShape _aShape(String root, List<int> pattern) {
  final shift = _semitonesFrom('A', root);
  final frets = pattern.map((f) => f + shift).toList();
  return ChordShape(baseFret: shift == 0 ? 1 : shift, frets: frets);
}

final Map<String, ChordShape Function(String root)> _generators = {
  '': (root) => _aShape(root, [2, 1, 0, 0]), // major: G:A C:C# E:E A:A
  'm': (root) => _aShape(root, [2, 0, 0, 0]), // minor: G:A C:C E:E A:A
  '7': (root) => _aShape(root, [0, 1, 0, 0]), // dom7: G:G C:C# E:E A:A
  'maj7': (root) => _aShape(root, [1, 1, 0, 0]), // G:G# C:C# E:E A:A
  'm7': (root) => _aShape(root, [0, 0, 0, 0]), // G:G C:C E:E A:A
};

// Hand-verified open-position voicings for the chords ukulele players most
// expect to see played open — same idea as chord_shapes.dart's own
// _openOverrides, each checked note-by-note against the chord it's meant to
// be rather than taken on faith.
final Map<String, ChordShape> _openOverrides = {
  'C': const ChordShape(baseFret: 1, frets: [0, 0, 0, 3]), // G C E C(A+3)
  'C7': const ChordShape(baseFret: 1, frets: [0, 0, 0, 1]), // G C E A#(Bb)
  'F': const ChordShape(baseFret: 1, frets: [2, 0, 1, 0]), // A C F A
  'G': const ChordShape(baseFret: 1, frets: [0, 2, 3, 2]), // G D G B
  'G7': const ChordShape(baseFret: 1, frets: [0, 2, 1, 2]), // G D F B
  'Dm': const ChordShape(baseFret: 1, frets: [2, 2, 1, 0]), // A D F A
  'Em': const ChordShape(baseFret: 1, frets: [0, 4, 0, 2]), // G E E B
  'D7': const ChordShape(baseFret: 1, frets: [2, 2, 2, 3]), // A D F# C
  'E7': const ChordShape(baseFret: 1, frets: [1, 2, 0, 2]), // G# D E B
  'A#': const ChordShape(baseFret: 1, frets: [3, 2, 1, 1]), // A#(Bb) D F A#
};

final Map<String, ChordShape> ukuleleChordShapes = {
  for (final root in _roots)
    for (final entry in _generators.entries)
      '$root${entry.key}':
          _openOverrides['$root${entry.key}'] ?? entry.value(root),
};

/// Same chord-name parsing as [lookupChordShape] (root + quality alias),
/// just resolved against [ukuleleChordShapes] instead of the guitar
/// dictionary — a quality not covered here (sus2/sus4/dim) resolves to a
/// canonical name that simply isn't a key in this map, so the lookup
/// returns null the same as an unrecognized chord would.
ChordShape? lookupUkuleleChordShape(String chordName) {
  final key = canonicalChordName(chordName);
  return key == null ? null : ukuleleChordShapes[key];
}

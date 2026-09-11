import 'package:pai_morn_web/utils/chord_transposer.dart';

/// A guitar chord diagram: which fret each string is pressed at.
///
/// [frets] has 6 entries ordered low E -> high e (the order strings are
/// conventionally drawn left-to-right on a chord chart). `null` means the
/// string is muted, `0` means it's played open.
///
/// [baseFret] is the fret shown at the top of the 5-fret window drawn by
/// [ChordDiagramPainter]. `1` means the diagram starts at the nut (open
/// strings are marked directly); anything higher means it's a movable
/// barre-chord shape shown starting at that fret, with a "Nfr" label.
class ChordShape {
  final int baseFret;
  final List<int?> frets;

  const ChordShape({required this.baseFret, required this.frets});
}

const List<String> _roots = [
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

int _semitonesFrom(String from, String root) {
  final rootIndex = _roots.indexOf(root);
  final fromIndex = _roots.indexOf(from);
  return (rootIndex - fromIndex + 12) % 12;
}

// Movable "E-shape" barre chords: fingering pattern for root = E (no shift),
// 6 entries low E -> high e. Shifting every fretted string up by the root's
// distance from E gives the same shape rooted at any other note.
ChordShape _eShape(String root, List<int> openPattern) {
  final shift = _semitonesFrom('E', root);
  final frets = openPattern.map((f) => f + shift).toList();
  return ChordShape(baseFret: shift == 0 ? 1 : shift, frets: frets);
}

// Movable "A-shape" barre chords: fingering pattern for root = A (no
// shift), 5 entries A/D/G/B/e (low E is always muted in this shape).
ChordShape _aShape(String root, List<int> openPattern) {
  final shift = _semitonesFrom('A', root);
  final frets = [null, ...openPattern.map((f) => f + shift)];
  return ChordShape(baseFret: shift == 0 ? 1 : shift, frets: frets);
}

// Movable diminished-triad shape, fingering pattern for root = B (no
// shift): x-2-3-4-3-x on strings A/D/G/B (low E and high e both muted).
// Verified notes at root=B: B(A+2) F(D+3) B(G+4) D(B+3) = B-D-F, i.e. the
// diminished triad root-b3-b5. Unlike the E/A-shapes above this pattern has
// no open-string (shift=0) voicing, so baseFret is always shift+2.
ChordShape _dimShape(String root) {
  final shift = _semitonesFrom('B', root);
  final pattern = [2, 3, 4, 3];
  final frets = pattern.map((f) => f + shift).toList();
  return ChordShape(
    baseFret: shift + 2,
    frets: [null, frets[0], frets[1], frets[2], frets[3], null],
  );
}

/// quality suffix -> shape generator, applied to every root to build the
/// full dictionary below.
final Map<String, ChordShape Function(String root)> _generators = {
  '': (root) => _eShape(root, [0, 2, 2, 1, 0, 0]), // major
  'm': (root) => _eShape(root, [0, 2, 2, 0, 0, 0]), // minor
  '7': (root) => _eShape(root, [0, 2, 0, 1, 0, 0]), // dominant 7th
  'maj7': (root) => _eShape(root, [0, 2, 1, 1, 0, 0]),
  'm7': (root) => _eShape(root, [0, 2, 0, 0, 0, 0]),
  'sus2': (root) => _aShape(root, [0, 2, 2, 0, 0]),
  'sus4': (root) => _aShape(root, [0, 2, 2, 3, 0]),
  'dim': (root) => _dimShape(root),
};

// Hand-verified open-position voicings for the handful of chords guitarists
// most expect to see played open, overriding the generated barre shape for
// just these roots so the diagram is the familiar one.
final Map<String, ChordShape> _openOverrides = {
  'C': const ChordShape(baseFret: 1, frets: [null, 3, 2, 0, 1, 0]),
  'D': const ChordShape(baseFret: 1, frets: [null, null, 0, 2, 3, 2]),
  'G': const ChordShape(baseFret: 1, frets: [3, 2, 0, 0, 0, 3]),
  'Dm': const ChordShape(baseFret: 1, frets: [null, null, 0, 2, 3, 1]),
  'C7': const ChordShape(baseFret: 1, frets: [null, 3, 2, 3, 1, 0]),
  'D7': const ChordShape(baseFret: 1, frets: [null, null, 0, 2, 1, 2]),
  'G7': const ChordShape(baseFret: 1, frets: [3, 2, 0, 0, 0, 1]),
  'Dsus2': const ChordShape(baseFret: 1, frets: [null, null, 0, 2, 3, 0]),
  'Dsus4': const ChordShape(baseFret: 1, frets: [null, null, 0, 2, 3, 3]),
};

final Map<String, ChordShape> chordShapes = {
  for (final root in _roots)
    for (final entry in _generators.entries)
      '$root${entry.key}':
          _openOverrides['$root${entry.key}'] ?? entry.value(root),
};

const Map<String, String> _qualityAliases = {
  '': '',
  'maj': '',
  'M': '',
  'm': 'm',
  'min': 'm',
  '-': 'm',
  '7': '7',
  'dom7': '7',
  'maj7': 'maj7',
  'M7': 'maj7',
  'Δ': 'maj7',
  'm7': 'm7',
  'min7': 'm7',
  '-7': 'm7',
  'sus2': 'sus2',
  'sus4': 'sus4',
  'sus': 'sus4',
  'dim': 'dim',
  '°': 'dim',
  'o': 'dim',
  'dim7': 'dim',
};

/// Looks up the diagram for a chord symbol as it appears in a song, e.g.
/// "Am7", "F#", "Bb/D" (slash bass notes are dropped — the diagram shows
/// only the base chord shape). Returns null if the root isn't recognized or
/// the quality isn't one of the common ones this dictionary covers.
ChordShape? lookupChordShape(String chordName) {
  final key = canonicalChordName(chordName);
  return key == null ? null : chordShapes[key];
}

/// The exact key [chordName] resolves to in [chordShapes] (e.g. "Am7" as
/// authored in a song and "Am7" as this dictionary's own canonical name
/// happen to match here, but an alias like "Adim7" resolves to the
/// dictionary's "Adim") — null on the same unrecognized-root/quality cases
/// [lookupChordShape] returns null for. Used by
/// `recently_looked_up_chords.dart` to record a name that will actually
/// re-resolve to the same entry later (e.g. on the Chords reference page),
/// rather than whatever exact spelling a song happened to use.
String? canonicalChordName(String chordName) {
  final base = chordName.split('/').first.trim();
  final root = parseChordRoot(base);
  if (root == null) return null;

  final rawSuffix = chordQualitySuffix(base);
  final quality = _qualityAliases[rawSuffix];
  if (quality == null) return null;

  return '$root$quality';
}

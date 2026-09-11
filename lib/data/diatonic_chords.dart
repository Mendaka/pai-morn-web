const List<String> _chromatic = [
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

/// All 12 chromatic roots, e.g. for populating a key picker.
const List<String> chromaticRoots = _chromatic;

class DiatonicChord {
  final String degree;
  final String chordName;

  const DiatonicChord({required this.degree, required this.chordName});
}

/// The chords that "belong" to a given major/minor key, for the submit-song
/// form's quick-pick chord chips — lets someone writing a Thai/Shan lyric
/// tap a chord in rather than switching keyboards to type it.
///
/// Major key: standard diatonic triads (I ii iii IV V vi vii), with the
/// 7th degree offered as *both* `Xm` and `Xdim` chips since real chord
/// sheets use either loosely (vii is technically diminished).
///
/// Minor key: natural minor, except the V is deliberately raised to major
/// (e.g. Am -> E, not Em) — the common folk/luk-thung convention for a
/// stronger dominant resolution.
List<DiatonicChord> diatonicChordsForKey(String root, {required bool isMinor}) {
  final rootIndex = _chromatic.indexOf(root);
  if (rootIndex == -1) return const [];

  String noteAt(int semitones) => _chromatic[(rootIndex + semitones) % 12];

  if (!isMinor) {
    return [
      DiatonicChord(degree: 'I', chordName: noteAt(0)),
      DiatonicChord(degree: 'ii', chordName: '${noteAt(2)}m'),
      DiatonicChord(degree: 'iii', chordName: '${noteAt(4)}m'),
      DiatonicChord(degree: 'IV', chordName: noteAt(5)),
      DiatonicChord(degree: 'V', chordName: noteAt(7)),
      DiatonicChord(degree: 'vi', chordName: '${noteAt(9)}m'),
      DiatonicChord(degree: 'vii', chordName: '${noteAt(11)}m'),
      DiatonicChord(degree: 'vii°', chordName: '${noteAt(11)}dim'),
    ];
  }

  return [
    DiatonicChord(degree: 'i', chordName: '${noteAt(0)}m'),
    DiatonicChord(degree: 'ii°', chordName: '${noteAt(2)}dim'),
    DiatonicChord(degree: 'III', chordName: noteAt(3)),
    DiatonicChord(degree: 'iv', chordName: '${noteAt(5)}m'),
    DiatonicChord(degree: 'V', chordName: noteAt(7)),
    DiatonicChord(degree: 'VI', chordName: noteAt(8)),
    DiatonicChord(degree: 'VII', chordName: noteAt(10)),
  ];
}

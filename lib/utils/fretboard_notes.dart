/// One chromatic pitch class's display name(s) — natural notes (C, D, E, F,
/// G, A, B) have no enharmonic [alt]; the other five are always shown as
/// both spellings (e.g. "F♯" over "G♭") since a fretboard chart is a neutral
/// reference, not tied to any one key's preferred spelling.
class FretNote {
  const FretNote(this.primary, [this.alt]);
  final String primary;
  final String? alt;
}

// Index 0 = C, ascending chromatically — the standard pitch-class ordering,
// independent of which note any given string happens to open on.
const List<FretNote> chromaticNotes = [
  FretNote('C'),
  FretNote('C♯', 'D♭'),
  FretNote('D'),
  FretNote('D♯', 'E♭'),
  FretNote('E'),
  FretNote('F'),
  FretNote('F♯', 'G♭'),
  FretNote('G'),
  FretNote('G♯', 'A♭'),
  FretNote('A'),
  FretNote('A♯', 'B♭'),
  FretNote('B'),
];

// Standard guitar tuning, ordered high string -> low string (left to right
// on the chart) to match how a player sees their own fretboard looking down
// at it while playing — thinnest/high-E string nearest their own body.
const List<String> standardTuningLabels = ['E', 'B', 'G', 'D', 'A', 'E'];
const List<int> _standardTuningPitchClass = [4, 11, 7, 2, 9, 4];

/// The note at [stringIndex] (0 = high E ... 5 = low E) and [fret] (0 =
/// open string).
FretNote noteAt(int stringIndex, int fret) {
  final openPitchClass = _standardTuningPitchClass[stringIndex];
  return chromaticNotes[(openPitchClass + fret) % 12];
}

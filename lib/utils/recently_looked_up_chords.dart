import 'package:shared_preferences/shared_preferences.dart';

/// Per-device history of chord names looked up from inside a song (tapping
/// a chord in the reader opens `chord_diagram_dialog.dart`), most-recent-
/// first, capped at [_maxEntries]. Surfaced as a "Recently Looked Up" row on
/// the Chords reference page (`chords_screen.dart`) so a chord someone just
/// had to look up mid-song is right there next time they open the
/// reference instead of needing to search for it again. Same shape/
/// convention as `recently_viewed_songs.dart`, kept as a separate key since
/// these track a different kind of thing (chord names, not song ids).
const _prefsKey = 'recently_looked_up_chord_names';
const _maxEntries = 10;

Future<void> recordLookedUpChord(String chordName) async {
  final prefs = await SharedPreferences.getInstance();
  final names = prefs.getStringList(_prefsKey) ?? [];
  names.remove(chordName);
  names.insert(0, chordName);
  await prefs.setStringList(_prefsKey, names.take(_maxEntries).toList());
}

Future<List<String>> loadRecentlyLookedUpChords() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList(_prefsKey) ?? [];
}

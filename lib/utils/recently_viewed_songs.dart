import 'package:shared_preferences/shared_preferences.dart';

/// Per-device (not per-account — works the same for a signed-out visitor)
/// history of opened songs, most-recent-first, capped at [_maxEntries] so it
/// stays a quick "what did I just look at" list rather than an unbounded
/// log. Shared between `song_reader_screen.dart` (writes on open) and
/// `book_screen.dart` (reads for the "Recently Viewed" row) so both sides
/// agree on the storage key/shape in exactly one place.
const _prefsKey = 'recently_viewed_song_ids';
const _maxEntries = 10;

Future<void> recordViewedSong(String songId) async {
  final prefs = await SharedPreferences.getInstance();
  final ids = prefs.getStringList(_prefsKey) ?? [];
  ids.remove(songId); // move it to the front instead of duplicating
  ids.insert(0, songId);
  await prefs.setStringList(_prefsKey, ids.take(_maxEntries).toList());
}

Future<List<String>> loadRecentlyViewedIds() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList(_prefsKey) ?? [];
}

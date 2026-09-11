import 'dart:convert';

import 'package:http/http.dart' as http;

/// Fires a one-shot request to the `recordSongView` Cloud Function
/// (exposed same-origin at /api/record-song-view — see firebase.json) to
/// increment `songs/{songId}.viewCount` server-side. Deliberately not
/// awaited by its caller and never throws — a lost view count is never
/// worth surfacing an error or blocking the reader page over, unlike a
/// real user action such as favoriting.
Future<void> recordSongView(String songId) async {
  try {
    final origin = Uri.base.origin;
    await http.post(
      Uri.parse('$origin/api/record-song-view'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'songId': songId}),
    );
  } catch (_) {
    // Best-effort — see doc comment above.
  }
}

import 'package:http/http.dart' as http;

/// Fires a one-shot request to the `recordSiteView` Cloud Function
/// (exposed same-origin at /api/record-site-view — see firebase.json) to
/// increment `stats/siteViews.count` server-side. Same fire-and-forget,
/// never-throws shape as song_view_recorder.dart's recordSongView — a lost
/// hit is never worth surfacing an error over. Called once from MyApp's
/// initState (a real page load), not from per-route navigation.
Future<void> recordSiteView() async {
  try {
    final origin = Uri.base.origin;
    await http.post(Uri.parse('$origin/api/record-site-view'), body: '');
  } catch (_) {
    // Best-effort — see doc comment above.
  }
}

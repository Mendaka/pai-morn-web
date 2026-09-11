/// Pulls the 11-character video ID out of any standard YouTube link shape a
/// submitter might paste: a full `watch?v=` URL, a shortened `youtu.be/`
/// link, or an already-`embed/` URL. Returns null for anything else (an
/// empty field, a non-YouTube link, a malformed URL) so callers can treat
/// "no playable link" and "couldn't parse it" the same way — just don't
/// show the listen button.
String? extractYoutubeVideoId(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return null;

  final host = uri.host.toLowerCase();
  if (host.contains('youtu.be')) {
    return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
  }
  if (host.contains('youtube.com')) {
    final segments = uri.pathSegments;
    final embedIndex = segments.indexOf('embed');
    if (embedIndex != -1 && embedIndex + 1 < segments.length) {
      return segments[embedIndex + 1];
    }
    final shortsIndex = segments.indexOf('shorts');
    if (shortsIndex != -1 && shortsIndex + 1 < segments.length) {
      return segments[shortsIndex + 1];
    }
    return uri.queryParameters['v'];
  }
  return null;
}

final RegExp _chordBracket = RegExp(r'\[([^\]]+)\]');

/// Parses one line of bracket-syntax lyrics, e.g. `[Am]หวังว่า[C]คงจะดี`,
/// into the same `{type, text}` shape `book_screen.dart`'s renderer already
/// expects. Anything inside `[...]` becomes a chord token; everything else
/// becomes a plain lyric token. `type` for non-chord tokens is `'lyric'` —
/// the renderer only ever special-cases `type == 'chord'`, so any other
/// string here is safe.
List<Map<String, dynamic>> parseLyricsLine(String line) {
  final result = <Map<String, dynamic>>[];
  var lastEnd = 0;
  for (final match in _chordBracket.allMatches(line)) {
    if (match.start > lastEnd) {
      result.add({
        'type': 'lyric',
        'text': line.substring(lastEnd, match.start),
      });
    }
    result.add({'type': 'chord', 'text': match.group(1)!});
    lastEnd = match.end;
  }
  if (lastEnd < line.length) {
    result.add({'type': 'lyric', 'text': line.substring(lastEnd)});
  }
  return result;
}

/// Parses a whole multi-line bracket-syntax lyrics block into the
/// `lyrics: [{content: [...]}]` shape stored on a song document.
List<Map<String, dynamic>> parseLyricsBlock(String block) {
  return block
      .split('\n')
      .map((line) => {'content': parseLyricsLine(line)})
      .toList();
}

/// The inverse of [parseLyricsBlock] — reconstructs editable bracket-syntax
/// text from a stored `lyrics` array, e.g. so an admin editing an existing
/// song sees the same `[Am]หวังว่า[C]คงจะดี` text they'd type fresh. Any
/// non-chord token type round-trips as plain text (parseLyricsLine always
/// re-tags it `'lyric'` on the next parse, which is harmless).
String lyricsBlockToText(List lyrics) {
  return lyrics
      .map((line) {
        final content = line['content'] as List;
        return content
            .map((item) {
              final text = (item['text'] ?? '').toString();
              return item['type'] == 'chord' ? '[$text]' : text;
            })
            .join();
      })
      .join('\n');
}

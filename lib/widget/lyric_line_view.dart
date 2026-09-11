import 'package:flutter/material.dart';
import 'package:pai_morn_web/utils/chord_transposer.dart';
import 'package:pai_morn_web/widget/chord_diagram_dialog.dart';

class _ChordEntry {
  const _ChordEntry(this.offset, this.text, {this.isChord = true});
  final int offset;
  final String text;
  final bool isChord;
}

// Matches a bar/beat separator or half-step chord link authored as plain
// text between two chord brackets, e.g. "Intro- [F]/[F]" or "[C]-[C#]"
// parses to a lyric-type token whose text is just "/" or "-" — one or more
// of either character, nothing else.
final RegExp _separatorPattern = RegExp(r'^[/-]+$');

// Recognizes a leading section-label keyword — the same vocabulary as
// submit_song_screen.dart's quick-insert label chips. Shan/Thai lyric text
// never starts with a run of a-z letters, so this can't misfire on real
// sung lyrics.
const Set<String> _sectionLabelKeywords = {
  'key',
  'intro',
  'verse',
  'chorus',
  'bridge',
  'solo',
  'outro',
};
final RegExp _leadingWordPattern = RegExp(r'^([a-zA-Z]+)');

bool _isSectionLabelText(String trimmedText) {
  final match = _leadingWordPattern.firstMatch(trimmedText);
  if (match == null) return false;
  return _sectionLabelKeywords.contains(match.group(1)!.toLowerCase());
}

/// Whether [content] should always stand alone as its own row/cell whenever
/// something else groups lines together (`book_screen.dart`'s Compact mode
/// merge and Horizontal-mode column chunking) — either a pure chord/
/// separator line with no real lyric text (an Intro/Solo/Outro-style chord
/// progression), or a short recognized section-label line like "Key"/
/// "Intro" that may carry one attached chord (e.g. "Key D" for the song's
/// key) but isn't real sung lyric content either. Grouping these with
/// neighboring lines is exactly what caused chord progressions to get glued
/// to unrelated lines and section labels to end up buried mid-row.
/// The distinct chord names used anywhere in [lyrics] (the song's full
/// `data['lyrics']` list), transposed by [transposeSteps] and in
/// first-appearance order — backs the faint chord-diagram background in
/// song_reader_screen.dart. A song rarely uses more than a handful of
/// chords, so a plain growing List + `contains` check is simpler than a
/// LinkedHashSet for the same effect.
List<String> uniqueChordsInOrder(List lyrics, int transposeSteps) {
  final seen = <String>[];
  for (final lyric in lyrics) {
    final content = lyric['content'] as List;
    for (final item in content) {
      if (item['type'] != 'chord') continue;
      final rawText = (item['text'] ?? '').toString().trim();
      if (rawText.isEmpty) continue;
      final chord = transposeChord(rawText, transposeSteps);
      if (!seen.contains(chord)) seen.add(chord);
    }
  }
  return seen;
}

bool isStandaloneLabelLine(List content) {
  final buffer = StringBuffer();
  for (final item in content) {
    if (item['type'] == 'chord') continue;
    final text = (item['text'] ?? '').toString();
    if (_separatorPattern.hasMatch(text.trim())) continue;
    buffer.write(text);
  }
  final trimmed = buffer.toString().trim();
  return trimmed.isEmpty || _isSectionLabelText(trimmed);
}

/// Renders one lyrics line's `content` array (`{type, text}` tokens, chord
/// tokens marked `type == 'chord'`) with chords floating in their own row
/// directly above the lyric text they attach to, instead of being spliced
/// inline into the lyric text itself — splicing used to visually break a
/// word apart wherever a chord landed mid-word. Shared by
/// `book_screen.dart`'s reading view and `submit_song_screen.dart`'s live
/// preview so both always look identical; tapping a chord opens the same
/// chord-diagram popup in both places.
///
/// Chord/label-only lines with no lyric text at all (e.g. "Intro- F/F") and
/// short recognized section-label lines that carry one attached chord (e.g.
/// "Key" + chord "D", meant to read as "Key D") fall back to a single-row
/// inline layout in original token order — for "Key" specifically, stacking
/// the chord above the word like a real sung lyric line reads oddly, since
/// it's a label:value pair, not a lyric with a chord change. A bar/beat
/// separator authored as plain text between two chords (e.g. "Intro- [F]/[F]"
/// parses to a lone "/" lyric token) renders as plain text in that same
/// inline row, staying grouped with the chords it separates instead of
/// landing alone in a lyric row below them.
///
/// Chord x-positions are measured against a single non-wrapping render of
/// the lyric text (`softWrap: false`) — this keeps chords exactly aligned
/// for normal-length lines, at the cost of a very long line overflowing
/// horizontally instead of wrapping. Wrapping was already rare in practice
/// given the font size and container width, so this trade favors alignment
/// accuracy for the common case over graceful handling of the rare one.
Widget buildLyricLine(
  BuildContext context,
  List content, {
  required int transposeSteps,
  required double fontScale,
  required Color textColor,
}) {
  const fontFamily = 'Courier New';
  final fontSize = 12 * fontScale;
  final lyricStyle = TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSize,
    color: textColor,
  );
  final chordStyle = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.bold,
    color: Colors.blueAccent,
    decoration: TextDecoration.underline,
    decorationStyle: TextDecorationStyle.dotted,
    fontSize: fontSize,
  );

  // Reconstruct the exact original lyric text (no separators added — the
  // parser's non-bracket substrings already carry whatever whitespace was
  // in the authored line) and remember each chord's character offset into
  // that reconstructed text.
  //
  // A lyric-type token that's just "/"/"-" (or a run of either, e.g. "//")
  // is a bar/beat separator or half-step chord link authored as plain text
  // between two chord brackets (e.g. "Intro- [F]/[F]" or "[C]-[C#]"). It
  // gets promoted into the chord row alongside the real chords — not
  // styled as a chord (no color/underline/tap), just positioned on the
  // same row — so it stays visually grouped with the chords it separates
  // instead of landing alone in the lyric row below them.
  final buffer = StringBuffer();
  final chords = <_ChordEntry>[];
  for (final item in content) {
    final rawText = (item['text'] ?? '') as String;
    if (item['type'] == 'chord') {
      chords.add(
        _ChordEntry(buffer.length, transposeChord(rawText, transposeSteps)),
      );
    } else if (_separatorPattern.hasMatch(rawText.trim())) {
      // Real space characters on both sides (not just extra layout padding)
      // — see the matching comment in the chord-only-line branch below for
      // why padding alone doesn't read as a visible gap next to a chord's
      // dotted underline.
      chords.add(
        _ChordEntry(buffer.length, ' ${rawText.trim()} ', isChord: false),
      );
    } else {
      buffer.write(rawText);
    }
  }
  final lyricText = buffer.toString();

  void onChordTap(String chordText) => showChordDiagramDialog(context, chordText);

  final trimmedLyricText = lyricText.trim();
  if (trimmedLyricText.isEmpty || _isSectionLabelText(trimmedLyricText)) {
    // Render in original token order (not the extracted `chords`/`lyricText`
    // above) so a label like "Key" keeps whatever position it was actually
    // authored in relative to its chord, e.g. "Key D" rather than always
    // dumping chords first.
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children:
            content
                .map<Widget>((item) {
                  final rawText = (item['text'] ?? '').toString();
                  if (item['type'] == 'chord') {
                    final chordText = transposeChord(rawText, transposeSteps);
                    return Padding(
                      padding: const EdgeInsets.only(right: 4.0),
                      child: GestureDetector(
                        onTap: () => onChordTap(chordText),
                        child: Text(chordText, style: chordStyle),
                      ),
                    );
                  }
                  final trimmed = rawText.trim();
                  if (trimmed.isEmpty) return const SizedBox.shrink();
                  // A bar/beat or half-step separator ("/" or "-") reads as
                  // glued to the chord chips on either side without its own
                  // breathing room — padding this widget's Padding widget
                  // alone isn't enough (it visually merges with a chord's
                  // dotted underline decoration right next to it). Real
                  // space characters around the glyph itself give it the
                  // same visual gap "/" already had.
                  final display =
                      _separatorPattern.hasMatch(trimmed)
                          ? ' $trimmed '
                          : trimmed;
                  return Padding(
                    padding: const EdgeInsets.only(right: 4.0),
                    child: Text(display, style: lyricStyle),
                  );
                })
                .toList(),
      ),
    );
  }

  final lyricPainter = TextPainter(
    text: TextSpan(text: lyricText, style: lyricStyle),
    textDirection: TextDirection.ltr,
  )..layout();

  double widthUpTo(int offset) {
    if (offset <= 0) return 0;
    final clamped = offset.clamp(0, lyricText.length);
    final painter = TextPainter(
      text: TextSpan(text: lyricText.substring(0, clamped), style: lyricStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width;
  }

  final chordWidgets = <Widget>[];
  var cursorX = 0.0;
  var chordRowHeight = fontSize + 4;
  for (final c in chords) {
    final style = c.isChord ? chordStyle : lyricStyle;
    final chordPainter = TextPainter(
      text: TextSpan(text: c.text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final naturalX = widthUpTo(c.offset);
    final x = naturalX < cursorX ? cursorX : naturalX;
    chordWidgets.add(
      Positioned(
        left: x,
        top: 0,
        child:
            c.isChord
                ? GestureDetector(
                  onTap: () => onChordTap(c.text),
                  child: Text(c.text, style: style),
                )
                : Text(c.text, style: style),
      ),
    );
    // Keeps back-to-back (or very close) chords/separators from overlapping
    // each other even when their anchor offsets are identical or nearly so.
    cursorX = x + chordPainter.width + 6;
    if (chordPainter.height > chordRowHeight) {
      chordRowHeight = chordPainter.height;
    }
  }

  // A normal single authored line rarely needs this — softWrap:false above
  // is the common case, sized to fit. Compact mode (song_reader_screen.dart's
  // _mergeLyricsForCompact) can hand this several original lines' worth of
  // content at once though, which reliably runs past a phone-width screen;
  // wrapping the whole block in a horizontal scroller keeps the rest of the
  // line reachable by swiping instead of just clipped off past the edge —
  // without touching softWrap itself, so alignment stays exact either way.
  return Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (chords.isNotEmpty)
            SizedBox(
              width: lyricPainter.width,
              height: chordRowHeight,
              child: Stack(clipBehavior: Clip.none, children: chordWidgets),
            ),
          Text(
            lyricText,
            style: lyricStyle,
            softWrap: false,
            overflow: TextOverflow.visible,
          ),
        ],
      ),
    ),
  );
}

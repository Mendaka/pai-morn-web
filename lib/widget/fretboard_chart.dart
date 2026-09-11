import 'package:flutter/material.dart';
import 'package:pai_morn_web/theme/app_theme.dart';
import 'package:pai_morn_web/utils/artist_palette.dart';
import 'package:pai_morn_web/utils/fretboard_notes.dart';

/// A horizontal fretboard note-map — nut on the left, frets receding to the
/// right, top-to-bottom string order (high E on top, low E on bottom)
/// matching standard tab notation — the conventional layout for a
/// full-neck reference chart (as opposed to `data/chord_shapes.dart`'s
/// vertical chord-window diagrams, which are a different, equally-standard
/// convention for a *handful* of finger positions). Rendered with a wood-
/// toned board, metallic fret wire and strings, and pearl-style position
/// inlays via [_FretboardPainter] — a deliberately more realistic look than
/// flat colored circles, since there's no real product photo to use
/// instead (a photo would need per-image manual fret/string coordinate
/// calibration and wouldn't adapt to light/dark mode or a left-handed
/// flip the way this vector version does).
///
/// [mirrored] (left-handed mode) flips which row each string draws in (low
/// E on top instead of bottom) — frets still run left-to-right, since a
/// left-handed player's neck isn't laid out back-to-front, just strung in
/// reverse.
class FretboardChart extends StatelessWidget {
  const FretboardChart({super.key, this.fretCount = 12, this.mirrored = false});

  final int fretCount;
  final bool mirrored;

  static const double _stringSpacing = 42;
  static const double _cellWidth = 58;
  static const double _nutWidth = 12;
  static const double _openLabelColWidth = 48;
  static const double _noteSize = 32;
  static const double _fretNumberRowHeight = 28;

  // Real guitar necks inlay position markers at these frets (double dot at
  // 12, the octave) purely as visual landmarks — they carry no note
  // information of their own, just help a reader's eye find their place the
  // way they would on a real neck.
  static const Set<int> _singleMarkerFrets = {3, 5, 7, 9};
  static const int _doubleMarkerFret = 12;

  double get _boardWidth => _nutWidth + fretCount * _cellWidth;
  double get _boardHeight => _stringSpacing * 6;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labels =
        mirrored ? standardTuningLabels.reversed.toList() : standardTuningLabels;

    // Wide on any real fret count (12 frets ≈ 700px) — scrolls horizontally
    // on narrow/mobile viewports rather than squeezing note circles down to
    // an unreadable size, same tradeoff this app already accepts for wide
    // chord-lyrics content elsewhere (see book_screen.dart's Horizontal
    // view mode).
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: _openLabelColWidth,
                  height: _boardHeight,
                  child: Column(
                    children: [
                      for (final label in labels)
                        SizedBox(
                          height: _stringSpacing,
                          child: Center(child: _openStringBadge(scheme, label)),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  width: _boardWidth,
                  height: _boardHeight,
                  child: CustomPaint(
                    painter: _FretboardPainter(
                      fretCount: fretCount,
                      stringSpacing: _stringSpacing,
                      cellWidth: _cellWidth,
                      nutWidth: _nutWidth,
                      singleMarkerFrets: _singleMarkerFrets,
                      doubleMarkerFret: _doubleMarkerFret,
                    ),
                    child: Stack(
                      children: [
                        for (var s = 0; s < 6; s++)
                          for (var fret = 1; fret <= fretCount; fret++)
                            Positioned(
                              left:
                                  _nutWidth +
                                  (fret - 1) * _cellWidth +
                                  (_cellWidth - _noteSize) / 2,
                              top: s * _stringSpacing + (_stringSpacing - _noteSize) / 2,
                              child: _noteCircle(
                                noteAt(mirrored ? 5 - s : s, fret),
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: _openLabelColWidth),
                const SizedBox(width: _nutWidth),
                for (var fret = 1; fret <= fretCount; fret++)
                  SizedBox(
                    width: _cellWidth,
                    height: _fretNumberRowHeight,
                    child: Center(
                      child: Text(
                        '$fret',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _openStringBadge(ColorScheme scheme, String label) {
    return Container(
      width: _noteSize + 4,
      height: _noteSize + 4,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: scheme.onSurface, width: 2),
      ),
      child: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.bold, color: scheme.onSurface),
      ),
    );
  }

  Widget _noteCircle(FretNote note) {
    final color = colorForArtist(note.primary);
    return Container(
      width: _noteSize,
      height: _noteSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.3),
          colors: [Color.lerp(color, Colors.white, 0.35)!, color],
        ),
        border: Border.all(color: Colors.black.withOpacity(0.25), width: 0.5),
        boxShadow: AppShadows.subtle(Colors.black),
      ),
      child:
          note.alt == null
              ? Text(
                note.primary,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.white,
                ),
              )
              : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    note.primary,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 8,
                      height: 1.1,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    note.alt!,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 8,
                      height: 1.1,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
    );
  }
}

/// Paints the wood-toned board, metallic nut/fret wires, metallic strings,
/// and pearl-style position-marker inlays — everything that isn't a note
/// circle or a text label (those stay plain widgets, drawing text on a
/// Canvas is more code for no visual benefit here).
class _FretboardPainter extends CustomPainter {
  const _FretboardPainter({
    required this.fretCount,
    required this.stringSpacing,
    required this.cellWidth,
    required this.nutWidth,
    required this.singleMarkerFrets,
    required this.doubleMarkerFret,
  });

  final int fretCount;
  final double stringSpacing;
  final double cellWidth;
  final double nutWidth;
  final Set<int> singleMarkerFrets;
  final int doubleMarkerFret;

  // A fixed (not randomized) wood-grain palette — deterministic so this
  // paints identically on every rebuild/screen without needing a seeded
  // Random or storing state anywhere.
  static const _woodBase = Color(0xFF8B5A2B);
  static const _woodDark = Color(0xFF6E4423);
  static const _woodLight = Color(0xFFA06B3A);

  @override
  void paint(Canvas canvas, Size size) {
    final boardRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final boardRRect = RRect.fromRectAndRadius(boardRect, const Radius.circular(4));

    // Wood board with a few faint horizontal grain streaks running the
    // length of the neck (the direction real wood grain runs on a guitar
    // neck), not literally random so the render is deterministic.
    final woodPaint =
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_woodLight, _woodBase, _woodDark, _woodBase, _woodLight],
          ).createShader(boardRect);
    canvas.drawRRect(boardRRect, woodPaint);

    final grainPaint =
        Paint()
          ..color = Colors.black.withOpacity(0.06)
          ..strokeWidth = 1.2;
    const grainFractions = [0.12, 0.28, 0.5, 0.63, 0.82, 0.93];
    for (final f in grainFractions) {
      final y = size.height * f;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grainPaint);
    }

    // Position-marker inlays — drawn before the fret wires/strings so the
    // wires/strings paint cleanly on top, matching a real inlaid neck.
    final inlayPaint = Paint()..color = Colors.white.withOpacity(0.85);
    final inlayShadow = Paint()..color = Colors.black.withOpacity(0.15);
    void drawInlay(double cx, double cy) {
      canvas.drawCircle(Offset(cx, cy + 1), 6, inlayShadow);
      canvas.drawCircle(Offset(cx, cy), 6, inlayPaint);
    }

    for (final fret in singleMarkerFrets) {
      if (fret > fretCount) continue;
      final cx = nutWidth + (fret - 0.5) * cellWidth;
      drawInlay(cx, stringSpacing * 3);
    }
    if (doubleMarkerFret <= fretCount) {
      final cx = nutWidth + (doubleMarkerFret - 0.5) * cellWidth;
      drawInlay(cx, stringSpacing * 2);
      drawInlay(cx, stringSpacing * 4);
    }

    // Nut — a thick bone-colored bar at the very left edge (fret 0).
    final nutPaint =
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFF5F0E6), Color(0xFFD8CFBB)],
          ).createShader(Rect.fromLTWH(0, 0, nutWidth, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, nutWidth, size.height), nutPaint);

    // Fret wires — a dark hairline shadow plus a thin bright highlight
    // offset by a pixel, so each wire reads as a small raised metal ridge
    // instead of a flat line.
    final fretShadow =
        Paint()
          ..color = Colors.black.withOpacity(0.35)
          ..strokeWidth = 2.5;
    final fretHighlight =
        Paint()
          ..color = Colors.white.withOpacity(0.55)
          ..strokeWidth = 1;
    for (var fret = 1; fret <= fretCount; fret++) {
      final x = nutWidth + fret * cellWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), fretShadow);
      canvas.drawLine(Offset(x - 1, 0), Offset(x - 1, size.height), fretHighlight);
    }

    // Strings — thicker/duller toward the low-E row, thinner/brighter
    // toward the high-E row, each with a light-dark-light cross-section
    // gradient so it reads as a round wound string rather than a flat line.
    for (var s = 0; s < 6; s++) {
      final y = s * stringSpacing + stringSpacing / 2;
      final thickness = 1.2 + s * 0.55;
      final stringPaint =
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: const [
                Color(0xFFEDEDED),
                Color(0xFF9A9A9A),
                Color(0xFFEDEDED),
              ],
            ).createShader(Rect.fromLTWH(0, y - thickness, size.width, thickness * 2))
            ..strokeWidth = thickness;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), stringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FretboardPainter oldDelegate) {
    return oldDelegate.fretCount != fretCount;
  }
}

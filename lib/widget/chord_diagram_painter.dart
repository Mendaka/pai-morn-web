import 'package:flutter/material.dart';
import 'package:pai_morn_web/data/chord_shapes.dart';

/// Draws a chord diagram for [shape]: a 5-fret grid, filled dots on pressed
/// strings, "O"/"X" markers above open/muted strings, and a fret-position
/// label ("3fr") when it's a movable shape that doesn't start at the nut.
/// String count is read from `shape.frets.length` rather than assumed —
/// originally 6-string-guitar-only, now also draws 4-string ukulele shapes
/// (see data/ukulele_chord_shapes.dart) with no changes needed here beyond
/// that.
class ChordDiagramPainter extends CustomPainter {
  final ChordShape shape;
  final Color lineColor;
  final Color dotColor;
  final Color textColor;
  // Mirrors which physical x-position each string draws at (low E on the
  // right instead of the left) for a left-handed player — text ("X"/"O"/
  // fret-number) is still drawn upright via _drawText, only the string/dot
  // x-coordinates flip, so nothing ends up backwards/unreadable the way a
  // naive whole-widget Transform.flip would.
  final bool mirrored;

  const ChordDiagramPainter({
    required this.shape,
    required this.lineColor,
    required this.dotColor,
    required this.textColor,
    this.mirrored = false,
  });

  static const double leftPad = 22;
  static const double topPad = 28;
  static const double stringGap = 18;
  static const double fretGap = 20;
  static const int fretRows = 5;

  int get stringCount => shape.frets.length;

  /// The canvas size this painter draws at for a chord with [stringCount]
  /// strings — callers wrap the painter in a `SizedBox` of this size (via a
  /// `FittedBox` to scale to whatever the surrounding layout needs, since
  /// the painter itself always draws at this intrinsic size). A 4-string
  /// ukulele diagram is correspondingly narrower than a 6-string guitar one.
  static Size preferredSizeFor(int stringCount) => Size(
    leftPad + (stringCount - 1) * stringGap + 26,
    topPad + fretRows * fretGap + 14,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint =
        Paint()
          ..color = lineColor
          ..strokeWidth = 1.2;
    final nutPaint =
        Paint()
          ..color = lineColor
          ..strokeWidth = 4;
    final gridWidth = (stringCount - 1) * stringGap;
    final isOpenPosition = shape.baseFret <= 1;

    double stringX(int s) =>
        leftPad + (mirrored ? stringCount - 1 - s : s) * stringGap;

    for (int s = 0; s < stringCount; s++) {
      final x = stringX(s);
      canvas.drawLine(
        Offset(x, topPad),
        Offset(x, topPad + fretRows * fretGap),
        linePaint,
      );
    }

    for (int f = 0; f <= fretRows; f++) {
      final y = topPad + f * fretGap;
      final isNut = f == 0 && isOpenPosition;
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(leftPad + gridWidth, y),
        isNut ? nutPaint : linePaint,
      );
    }

    if (!isOpenPosition) {
      _drawText(
        canvas,
        '${shape.baseFret}fr',
        leftPad + gridWidth + 6,
        topPad - 6,
        textColor,
      );
    }

    for (int s = 0; s < stringCount; s++) {
      final x = stringX(s);
      final fret = shape.frets[s];

      if (fret == null) {
        _drawText(canvas, 'X', x, topPad - 16, textColor, center: true);
        continue;
      }
      if (isOpenPosition && fret == 0) {
        _drawText(canvas, 'O', x, topPad - 16, textColor, center: true);
        continue;
      }
      final row = isOpenPosition ? fret : (fret - shape.baseFret + 1);
      if (row < 1 || row > fretRows) continue;
      final y = topPad + (row - 0.5) * fretGap;
      canvas.drawCircle(Offset(x, y), 6.5, Paint()..color = dotColor);
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    double x,
    double y,
    Color color, {
    bool center = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = center ? x - painter.width / 2 : x;
    final dy = y - painter.height / 2;
    painter.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant ChordDiagramPainter oldDelegate) =>
      oldDelegate.shape != shape ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.dotColor != dotColor ||
      oldDelegate.textColor != textColor ||
      oldDelegate.mirrored != mirrored;
}

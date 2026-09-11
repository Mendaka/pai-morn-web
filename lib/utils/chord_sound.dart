import 'dart:math' as math;

import 'package:web/web.dart' as web;
import 'package:pai_morn_web/data/chord_shapes.dart';

/// Synthesizes a short strummed chord via the Web Audio API — the same
/// no-asset, no-package approach `metronome_sound.dart` already uses for its
/// click, extended to one oscillator per string with a staggered start time
/// so it reads as an actual strum (low string to high) instead of all
/// strings hitting at once.
class ChordSound {
  web.AudioContext? _context;

  // Standard guitar tuning open-string frequencies, low E (string index 0)
  // to high e (index 5) — matches ChordShape.frets' own string ordering
  // exactly (see data/chord_shapes.dart's doc comment). This is the
  // default; ukulele shapes (4 strings, GCEA) pass their own tuning below.
  static const List<double> guitarOpenStringHz = [
    82.41, // E2
    110.00, // A2
    146.83, // D3
    196.00, // G3
    246.94, // B3
    329.63, // E4
  ];

  // Standard ukulele (soprano/concert) re-entrant GCEA tuning, in the same
  // G-C-E-A left-to-right order data/ukulele_chord_shapes.dart draws and
  // indexes its frets — the re-entrant high G is genuinely higher-pitched
  // than the C next to it, not a typo.
  static const List<double> ukuleleOpenStringHz = [
    392.00, // G4
    261.63, // C4
    329.63, // E4
    440.00, // A4
  ];

  static const double _stringDelay =
      0.035; // seconds between successive strings
  static const double _noteDuration = 1.1;

  void strum(ChordShape shape, {List<double> openStringHz = guitarOpenStringHz}) {
    final ctx = _context ??= web.AudioContext();
    if (ctx.state == 'suspended') {
      ctx.resume();
    }
    final now = ctx.currentTime;

    var stringsPlayed = 0;
    for (var i = 0; i < shape.frets.length; i++) {
      final fret = shape.frets[i];
      if (fret == null) continue; // muted string — nothing to play
      final freq = openStringHz[i] * math.pow(2, fret / 12);
      final startAt = now + stringsPlayed * _stringDelay;
      stringsPlayed++;

      final oscillator = ctx.createOscillator();
      final gain = ctx.createGain();
      oscillator.type = 'triangle';
      oscillator.frequency.value = freq.toDouble();
      // A tiny non-zero starting value (rather than 0) because
      // exponentialRampToValueAtTime throws on a zero starting gain.
      gain.gain.setValueAtTime(0.0001, startAt);
      gain.gain.exponentialRampToValueAtTime(0.22, startAt + 0.012);
      gain.gain.exponentialRampToValueAtTime(0.0001, startAt + _noteDuration);
      oscillator.connect(gain);
      gain.connect(ctx.destination);
      oscillator.start(startAt);
      oscillator.stop(startAt + _noteDuration + 0.05);
    }
  }
}

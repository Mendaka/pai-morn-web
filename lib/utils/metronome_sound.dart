import 'package:web/web.dart' as web;

/// Plays a short synthesized click via the Web Audio API — no audio asset
/// or extra package needed. Lazily creates one AudioContext and reuses it
/// (browsers cap how many can exist, and creating one is not free).
class MetronomeSound {
  web.AudioContext? _context;

  void click() {
    final ctx = _context ??= web.AudioContext();
    if (ctx.state == 'suspended') {
      ctx.resume();
    }
    final now = ctx.currentTime;
    final oscillator = ctx.createOscillator();
    final gain = ctx.createGain();
    oscillator.type = 'square';
    oscillator.frequency.value = 1000;
    gain.gain.setValueAtTime(0.25, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.05);
    oscillator.connect(gain);
    gain.connect(ctx.destination);
    oscillator.start(now);
    oscillator.stop(now + 0.05);
  }
}

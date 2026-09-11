import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:web/web.dart' as web;
import 'package:pai_morn_web/l10n/l10n.dart';
import 'package:pai_morn_web/l10n/locale_provider.dart';
import 'package:pai_morn_web/theme/app_theme.dart';
import 'package:pai_morn_web/utils/pitch_detector.dart';

enum _TunerStatus { idle, requesting, listening, denied, error }

/// A standard-tuning (EADGBE) guitar tuner using the browser's own
/// microphone + Web Audio API — no server round-trip, no extra native
/// plugin, since this app is web-only. Autocorrelation pitch detection
/// (see utils/pitch_detector.dart) runs client-side on a short rolling
/// buffer read from an AnalyserNode a few times a second.
class TunerScreen extends StatefulWidget {
  const TunerScreen({super.key});

  @override
  State<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends State<TunerScreen> {
  _TunerStatus _status = _TunerStatus.idle;
  web.MediaStream? _stream;
  web.AudioContext? _audioContext;
  web.AnalyserNode? _analyser;
  Timer? _pollTimer;

  TunerReading? _reading;
  double? _frequency;

  // Separate, lazily-created context just for reference-tone playback, kept
  // independent of _audioContext (the mic-listening one) so tapping a string
  // to hear its pitch works even before the mic is started/granted.
  web.AudioContext? _toneContext;
  GuitarString? _playingString;
  Timer? _toneTimer;

  @override
  void dispose() {
    _stopListening();
    _toneTimer?.cancel();
    try {
      _toneContext?.close();
    } catch (_) {}
    super.dispose();
  }

  void _playReferenceTone(GuitarString string) {
    final ctx = _toneContext ??= web.AudioContext();
    final osc = ctx.createOscillator();
    final gain = ctx.createGain();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(string.frequency, ctx.currentTime);
    osc.connect(gain);
    gain.connect(ctx.destination);
    final now = ctx.currentTime;
    // Quick fade in/out envelope so the tone doesn't click at start/stop.
    gain.gain.setValueAtTime(0.0001, now);
    gain.gain.exponentialRampToValueAtTime(0.25, now + 0.02);
    gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.9);
    osc.start();
    osc.stop(now + 0.95);

    _toneTimer?.cancel();
    setState(() => _playingString = string);
    _toneTimer = Timer(const Duration(milliseconds: 950), () {
      if (mounted) setState(() => _playingString = null);
    });
  }

  Future<void> _start() async {
    setState(() => _status = _TunerStatus.requesting);
    try {
      final stream =
          await web.window.navigator.mediaDevices
              .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
              .toDart;
      if (!mounted) {
        for (final track in stream.getTracks().toDart) {
          track.stop();
        }
        return;
      }
      final audioContext = web.AudioContext();
      final source = audioContext.createMediaStreamSource(stream);
      final analyser = audioContext.createAnalyser();
      analyser.fftSize = 2048;
      source.connect(analyser);

      _stream = stream;
      _audioContext = audioContext;
      _analyser = analyser;
      _pollTimer = Timer.periodic(
        const Duration(milliseconds: 100),
        (_) => _poll(),
      );
      setState(() => _status = _TunerStatus.listening);
    } catch (_) {
      // getUserMedia rejects for several reasons (permission denied, no
      // mic present, insecure context) — the tuner is unusable either way,
      // so one shared "can't access the microphone" state covers all of
      // them rather than trying to distinguish the exact browser error.
      if (mounted) setState(() => _status = _TunerStatus.denied);
    }
  }

  void _poll() {
    final analyser = _analyser;
    final audioContext = _audioContext;
    if (analyser == null || audioContext == null) return;
    final buffer = Float32List(analyser.fftSize);
    analyser.getFloatTimeDomainData(buffer.toJS);
    final frequency = detectPitch(buffer, audioContext.sampleRate);
    if (!mounted) return;
    if (frequency == null ||
        frequency < minDetectableFrequency ||
        frequency > maxDetectableFrequency) {
      setState(() {
        _frequency = null;
        _reading = null;
      });
      return;
    }
    setState(() {
      _frequency = frequency;
      _reading = nearestGuitarString(frequency);
    });
  }

  void _stopListening() {
    _pollTimer?.cancel();
    _pollTimer = null;
    // Best-effort teardown — releasing the mic and audio graph matters, but
    // must never block _stop() from returning the UI to idle. Wrapped
    // because a JS interop hiccup here (observed intermittently with
    // Chromium's fake-media-device test double; not confirmed against a
    // real microphone) must not leave the screen stuck showing "Listening".
    try {
      for (final track in _stream?.getTracks().toDart ?? const []) {
        track.stop();
      }
    } catch (_) {}
    _stream = null;
    try {
      _audioContext?.close();
    } catch (_) {}
    _audioContext = null;
    _analyser = null;
    _frequency = null;
    _reading = null;
  }

  void _stop() {
    _stopListening();
    setState(() => _status = _TunerStatus.idle);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final language = context.watch<LocaleProvider>().currentLanguage;
    final activeString =
        _status == _TunerStatus.listening ? _reading?.string : null;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 28),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppShadows.soft(scheme.onSurface),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppTranslations.getText('tunerLabel', language),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 28),
                // Always shown, regardless of mic status — tapping a string
                // plays its reference pitch, so this row alone is already
                // useful before the mic is ever started (or if it's denied),
                // rather than leaving the idle/denied states as just an
                // icon and a line of text.
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final string in standardGuitarTuning)
                      _stringChip(scheme, string, active: string == activeString),
                  ],
                ),
                if (_status != _TunerStatus.listening) ...[
                  const SizedBox(height: 10),
                  Text(
                    AppTranslations.getText('tunerReferenceTip', language),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                switch (_status) {
                  _TunerStatus.idle => _buildStartPrompt(scheme, language),
                  _TunerStatus.requesting => const CircularProgressIndicator(),
                  _TunerStatus.denied ||
                  _TunerStatus.error => _buildDenied(scheme, language),
                  _TunerStatus.listening => _buildListening(scheme, language),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStartPrompt(ColorScheme scheme, String language) {
    return Column(
      children: [
        IconButton(
          iconSize: 72,
          icon: FaIcon(FontAwesomeIcons.microphone, color: scheme.onSurface),
          onPressed: _start,
        ),
        const SizedBox(height: 12),
        Text(
          AppTranslations.getText('tunerTapToStart', language),
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onSurface.withOpacity(0.7)),
        ),
      ],
    );
  }

  Widget _buildDenied(ColorScheme scheme, String language) {
    return Column(
      children: [
        FaIcon(FontAwesomeIcons.microphoneSlash, size: 56, color: scheme.error),
        const SizedBox(height: 12),
        Text(
          AppTranslations.getText('tunerMicDenied', language),
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onSurface.withOpacity(0.8)),
        ),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: _start, child: const Text('Retry')),
      ],
    );
  }

  Widget _buildListening(ColorScheme scheme, String language) {
    final reading = _reading;
    // Green/amber/red matches what every clip-on tuner already trains
    // guitarists to expect — a functional color code, not a decorative
    // one, so it's kept separate from the app's usual artist-palette
    // accents (see book_screen.dart's _artistPalette).
    final cents = reading?.cents ?? 0;
    final centsAbs = cents.abs();
    final feedbackColor =
        reading == null
            ? scheme.onSurface.withOpacity(0.3)
            : centsAbs <= 5
            ? Colors.green
            : centsAbs <= 20
            ? Colors.orange
            : Colors.redAccent;

    return Column(
      children: [
        Text(
          reading?.string.name ?? '—',
          style: TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.w800,
            color: feedbackColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _frequency == null
              ? AppTranslations.getText('tunerListening', language)
              : centsAbs <= 5
              ? AppTranslations.getText('tunerInTune', language)
              : '${cents > 0 ? '+' : ''}${cents.round()} ¢  ·  ${_frequency!.toStringAsFixed(1)} Hz',
          style: TextStyle(fontSize: 16, color: scheme.onSurface.withOpacity(0.7)),
        ),
        const SizedBox(height: 28),
        _buildMeter(scheme, cents, feedbackColor, reading != null),
        const SizedBox(height: 36),
        OutlinedButton.icon(
          onPressed: _stop,
          icon: const FaIcon(FontAwesomeIcons.circleStop, size: 18),
          label: Text(AppTranslations.getText('tunerStop', language)),
        ),
      ],
    );
  }

  // `active` means the mic currently hears this string (only meaningful
  // while listening); tapping always plays the string's reference tone
  // regardless of mic status, shown via a brief blue highlight distinct
  // from the green/amber/red tuning-feedback colors used elsewhere.
  Widget _stringChip(ColorScheme scheme, GuitarString string, {required bool active}) {
    final playing = _playingString == string;
    return GestureDetector(
      onTap: () => _playReferenceTone(string),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active ? scheme.onSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color:
                  playing
                      ? Colors.blueAccent
                      : scheme.onSurface.withOpacity(active ? 1 : 0.25),
              width: playing ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (playing) ...[
                const FaIcon(
                  FontAwesomeIcons.volumeHigh,
                  size: 14,
                  color: Colors.blueAccent,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                string.name,
                style: TextStyle(
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  color: active ? scheme.surface : scheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // A horizontal needle track from -50 to +50 cents (one full semitone
  // either way, the same range a physical clip-on tuner's dial covers) —
  // the marker's x-position is the only thing that moves, so this reads at
  // a glance without needing to parse the exact cents number underneath it.
  Widget _buildMeter(ColorScheme scheme, double cents, Color color, bool hasReading) {
    final clamped = cents.clamp(-50, 50);
    final fraction = clamped / 50; // -1..1
    return SizedBox(
      height: 40,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trackWidth = constraints.maxWidth;
          final markerX = (trackWidth / 2) + (fraction * trackWidth / 2);
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: scheme.onSurface.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Container(width: 2, height: 20, color: scheme.onSurface.withOpacity(0.4)),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 120),
                left: (markerX - 10).clamp(0, trackWidth - 20),
                child: AnimatedOpacity(
                  opacity: hasReading ? 1 : 0.3,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: AppShadows.subtle(Colors.black),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

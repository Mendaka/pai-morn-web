import 'dart:math' as math;
import 'dart:typed_data';

/// One of a standard 6-string guitar's target pitches, low to high.
class GuitarString {
  const GuitarString(this.name, this.frequency);
  final String name;
  final double frequency;
}

const List<GuitarString> standardGuitarTuning = [
  GuitarString('E2', 82.41),
  GuitarString('A2', 110.00),
  GuitarString('D3', 146.83),
  GuitarString('G3', 196.00),
  GuitarString('B3', 246.94),
  GuitarString('E4', 329.63),
];

/// The guitar string whose target pitch is closest to a detected
/// frequency, and how many cents sharp (positive) or flat (negative) that
/// frequency is relative to it — 100 cents per semitone, same convention a
/// standard clip-on tuner's needle uses.
class TunerReading {
  const TunerReading(this.string, this.cents);
  final GuitarString string;
  final double cents;
}

TunerReading nearestGuitarString(double frequency) {
  var closest = standardGuitarTuning.first;
  var closestAbsCents = double.infinity;
  var closestCents = 0.0;
  for (final string in standardGuitarTuning) {
    final cents = 1200 * (math.log(frequency / string.frequency) / math.ln2);
    if (cents.abs() < closestAbsCents) {
      closestAbsCents = cents.abs();
      closest = string;
      closestCents = cents;
    }
  }
  return TunerReading(closest, closestCents);
}

// Guitar's 6 open strings span ~82–330Hz; a little margin on each side
// covers a string tuned somewhat flat/sharp of pitch without also picking
// up an autocorrelation octave error onto some unrelated distant note.
const double minDetectableFrequency = 60;
const double maxDetectableFrequency = 450;

/// Autocorrelation-based pitch detector — the technique behind most simple
/// browser guitar tuners: find the buffer's fundamental period by
/// correlating it against shifted copies of itself, then refine the peak
/// with parabolic interpolation for sub-sample accuracy. Returns null when
/// the signal is too quiet for a confident reading (silence, or the mic
/// picking up only room noise) rather than a wild guess.
double? detectPitch(Float32List buffer, double sampleRate) {
  final size = buffer.length;

  var rms = 0.0;
  for (final sample in buffer) {
    rms += sample * sample;
  }
  rms = math.sqrt(rms / size);
  if (rms < 0.01) return null;

  // Trim near-silent leading/trailing samples so the correlation sum isn't
  // diluted by silence at the edges of the buffer.
  const threshold = 0.2;
  var start = 0;
  for (var i = 0; i < size ~/ 2; i++) {
    if (buffer[i].abs() >= threshold) {
      start = i;
      break;
    }
  }
  var end = size - 1;
  for (var i = 1; i < size ~/ 2; i++) {
    if (buffer[size - i].abs() >= threshold) {
      end = size - i;
      break;
    }
  }
  final trimmed = buffer.sublist(start, end);
  final n = trimmed.length;
  if (n < 8) return null;

  final correlation = Float64List(n);
  for (var lag = 0; lag < n; lag++) {
    var sum = 0.0;
    for (var i = 0; i < n - lag; i++) {
      sum += trimmed[i] * trimmed[i + lag];
    }
    correlation[lag] = sum;
  }

  // Correlation always peaks at lag 0 (a signal matches itself perfectly);
  // skip past that initial downward slope before hunting for the real
  // period's peak, or lag 0 would win every time.
  var d = 0;
  while (d < n - 1 && correlation[d] > correlation[d + 1]) {
    d++;
  }

  var maxPos = -1;
  var maxVal = double.negativeInfinity;
  for (var i = d; i < n; i++) {
    if (correlation[i] > maxVal) {
      maxVal = correlation[i];
      maxPos = i;
    }
  }
  if (maxPos <= 0) return null;

  var period = maxPos.toDouble();
  if (maxPos < n - 1) {
    final x1 = correlation[maxPos - 1];
    final x2 = correlation[maxPos];
    final x3 = correlation[maxPos + 1];
    final a = (x1 + x3 - 2 * x2) / 2;
    final b = (x3 - x1) / 2;
    if (a != 0) period -= b / (2 * a);
  }
  if (period <= 0) return null;

  return sampleRate / period;
}

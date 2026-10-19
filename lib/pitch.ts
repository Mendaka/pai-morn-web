// Guitar tuner maths. The string table and cents convention come from
// lib/utils/pitch_detector.dart; the pitch detector itself is deliberately
// different (see detectPitch).

export type GuitarString = { name: string; frequency: number };

export const STANDARD_TUNING: GuitarString[] = [
  { name: "E2", frequency: 82.41 },
  { name: "A2", frequency: 110.0 },
  { name: "D3", frequency: 146.83 },
  { name: "G3", frequency: 196.0 },
  { name: "B3", frequency: 246.94 },
  { name: "E4", frequency: 329.63 },
];

export type TunerReading = { string: GuitarString; cents: number };

/**
 * The open string closest to `frequency`, and how many cents sharp (+) or flat
 * (-) it is against that string — 100 cents per semitone, the same convention
 * as a clip-on tuner's needle.
 */
export function nearestGuitarString(frequency: number): TunerReading {
  let best = STANDARD_TUNING[0];
  let bestAbs = Infinity;
  let bestCents = 0;
  for (const s of STANDARD_TUNING) {
    const cents = 1200 * (Math.log(frequency / s.frequency) / Math.LN2);
    if (Math.abs(cents) < bestAbs) {
      bestAbs = Math.abs(cents);
      best = s;
      bestCents = cents;
    }
  }
  return { string: best, cents: bestCents };
}

// The six open strings span ~82–330 Hz; a little margin either side covers a
// string tuned flat/sharp without an octave error landing on a distant note.
export const MIN_FREQUENCY = 60;
export const MAX_FREQUENCY = 450;

/** Samples read from the microphone per reading (a power of two for the AnalyserNode). */
export const TUNER_FFT_SIZE = 4096;

/**
 * Pitch detection with the YIN method (de Cheveigne & Kawahara, 2002): a
 * difference function over a fixed-length window, cumulative-mean normalised,
 * with the first dip under a threshold taken as the period and refined by
 * parabolic interpolation. Returns null for a signal too quiet to trust
 * (silence, room noise) or with no clear pitch, instead of guessing.
 *
 * Deliberately NOT a port of pitch_detector.dart's plain autocorrelation.
 * That one sums fewer samples as the lag grows, which distorts the peak;
 * measured on synthetic tones it read perfectly in-tune strings up to ~20
 * cents off, enough to mistune a guitar. YIN integrates the same number of
 * samples for every lag, and its "first dip" rule stops a multiple of the
 * period (an octave error) being chosen over the real pitch.
 */
export function detectPitch(buffer: Float32Array, sampleRate: number): number | null {
  const size = buffer.length;

  let sumSq = 0;
  for (let i = 0; i < size; i++) sumSq += buffer[i] * buffer[i];
  if (Math.sqrt(sumSq / size) < 0.01) return null;

  const minLag = Math.floor(sampleRate / MAX_FREQUENCY);
  const maxLag = Math.ceil(sampleRate / MIN_FREQUENCY);
  // The window must span more than the longest period we look for.
  const window = size - maxLag - 2;
  if (window < maxLag) return null;

  // Difference function d(tau) = sum_i (x[i] - x[i+tau])^2, then its
  // cumulative-mean-normalised form: it starts at 1 and dips toward 0 at the
  // true period (and at multiples of it).
  const cmnd = new Float64Array(maxLag + 2);
  cmnd[0] = 1;
  let running = 0;
  for (let tau = 1; tau <= maxLag + 1; tau++) {
    let d = 0;
    for (let i = 0; i < window; i++) {
      const diff = buffer[i] - buffer[i + tau];
      d += diff * diff;
    }
    running += d;
    cmnd[tau] = running === 0 ? 1 : (d * tau) / running;
  }

  // First dip below the threshold, followed down to its local minimum.
  const THRESHOLD = 0.15;
  let tau = -1;
  for (let t = minLag; t <= maxLag; t++) {
    if (cmnd[t] < THRESHOLD) {
      while (t + 1 <= maxLag && cmnd[t + 1] < cmnd[t]) t++;
      tau = t;
      break;
    }
  }
  if (tau < 0) return null; // no clear pitch

  // Parabolic interpolation around the minimum for sub-sample accuracy.
  const a = cmnd[tau - 1];
  const b = cmnd[tau];
  const c = cmnd[tau + 1];
  const denom = a + c - 2 * b;
  const period = denom !== 0 ? tau + (a - c) / (2 * denom) : tau;
  if (period <= 0) return null;

  return sampleRate / period;
}

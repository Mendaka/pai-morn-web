import { OPEN_STRING_HZ, type ChordShape } from "@/lib/chord-shapes";

// Port of lib/utils/plucked_string.dart + chord_sound_web.dart.
//
// Each string is a Karplus-Strong plucked note: a burst of noise fed through a
// delay line whose length sets the pitch, averaged with itself on every pass.
// That averaging is a one-pole low-pass inside the loop, so high harmonics die
// faster than the fundamental — the "brightness fades before the note does"
// character of a real string that a fixed oscillator waveform can't make.

export function synthesizePluckedString(opts: {
  frequency: number;
  durationSeconds: number;
  sampleRate: number;
  peakAmplitude?: number;
  decay?: number;
}): Float32Array<ArrayBuffer> {
  const { frequency, durationSeconds, sampleRate, peakAmplitude = 1, decay = 0.996 } = opts;
  const count = Math.round(durationSeconds * sampleRate);
  const samples = new Float32Array(count);
  const period = Math.min(count, Math.max(2, Math.round(sampleRate / frequency)));

  // The pluck: white noise, lightly smoothed so the attack reads as a pick
  // striking a string rather than a digital click.
  const ring = new Float64Array(period);
  let prev = 0;
  for (let i = 0; i < period; i++) {
    prev = prev * 0.35 + (Math.random() * 2 - 1) * 0.65;
    ring[i] = prev;
  }

  let index = 0;
  for (let i = 0; i < count; i++) {
    const current = ring[index];
    samples[i] = current * peakAmplitude;
    ring[index] = decay * 0.5 * (current + ring[(index + 1) % period]);
    index = (index + 1) % period;
  }
  return samples;
}

const STRING_DELAY = 0.035; // seconds between successive strings of the strum
const NOTE_DURATION = 1.1;

let ctx: AudioContext | null = null;

/** A short strummed chord, low string to high, from a chord shape. */
export function strum(shape: ChordShape, ukulele: boolean): void {
  const AudioCtor = window.AudioContext ?? (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
  if (!AudioCtor) return;
  ctx ??= new AudioCtor();
  if (ctx.state === "suspended") void ctx.resume();

  const hz = ukulele ? OPEN_STRING_HZ.ukulele : OPEN_STRING_HZ.guitar;
  const now = ctx.currentTime;
  const rate = ctx.sampleRate;

  let played = 0;
  shape.frets.forEach((fret, i) => {
    if (fret === null) return; // muted
    const samples = synthesizePluckedString({
      frequency: hz[i] * Math.pow(2, fret / 12),
      durationSeconds: NOTE_DURATION,
      sampleRate: rate,
      peakAmplitude: 0.35,
    });
    const buffer = ctx!.createBuffer(1, samples.length, rate);
    buffer.copyToChannel(samples, 0);
    const source = ctx!.createBufferSource();
    source.buffer = buffer;
    source.connect(ctx!.destination);
    source.start(now + played * STRING_DELAY);
    played++;
  });
}

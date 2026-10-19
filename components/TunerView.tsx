"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { Loader2, Mic, MicOff, Square, Volume2 } from "lucide-react";
import { useT } from "@/components/LanguageProvider";
import {
  MAX_FREQUENCY,
  MIN_FREQUENCY,
  STANDARD_TUNING,
  TUNER_FFT_SIZE,
  detectPitch,
  nearestGuitarString,
  type GuitarString,
  type TunerReading,
} from "@/lib/pitch";

type Status = "idle" | "requesting" | "listening" | "denied";
type Live = { reading: TunerReading; frequency: number } | null;

const POLL_MS = 100;
const IN_TUNE_CENTS = 5;
const CLOSE_CENTS = 20;

const AudioCtor = (): typeof AudioContext | undefined =>
  window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;

// A standard-tuning (EADGBE) guitar tuner using the browser's own microphone
// and Web Audio — nothing leaves the device. Pitch detection runs on a short
// buffer read from an AnalyserNode ten times a second (see lib/pitch.ts).
export default function TunerView() {
  const { t } = useT();
  const [status, setStatus] = useState<Status>("idle");
  const [live, setLive] = useState<Live>(null);
  const [playing, setPlaying] = useState<GuitarString | null>(null);

  const stream = useRef<MediaStream | null>(null);
  const micCtx = useRef<AudioContext | null>(null);
  const timer = useRef<ReturnType<typeof setInterval> | null>(null);
  // Reference tones use their own context, so tapping a string works before
  // the mic is ever started (or if it is denied).
  const toneCtx = useRef<AudioContext | null>(null);
  const toneTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  const stopListening = useCallback(() => {
    if (timer.current) clearInterval(timer.current);
    timer.current = null;
    // Best effort: releasing the mic must never leave the UI stuck on "listening".
    try {
      stream.current?.getTracks().forEach((track) => track.stop());
    } catch {}
    stream.current = null;
    try {
      void micCtx.current?.close();
    } catch {}
    micCtx.current = null;
  }, []);

  useEffect(
    () => () => {
      stopListening();
      if (toneTimer.current) clearTimeout(toneTimer.current);
      try {
        void toneCtx.current?.close();
      } catch {}
    },
    [stopListening],
  );

  async function start() {
    setStatus("requesting");
    try {
      const media = await navigator.mediaDevices.getUserMedia({ audio: true });
      const Ctor = AudioCtor();
      if (!Ctor) throw new Error("no Web Audio");
      const ctx = new Ctor();
      const analyser = ctx.createAnalyser();
      analyser.fftSize = TUNER_FFT_SIZE;
      ctx.createMediaStreamSource(media).connect(analyser);
      stream.current = media;
      micCtx.current = ctx;

      const buffer = new Float32Array(analyser.fftSize);
      timer.current = setInterval(() => {
        analyser.getFloatTimeDomainData(buffer);
        const frequency = detectPitch(buffer, ctx.sampleRate);
        if (frequency === null || frequency < MIN_FREQUENCY || frequency > MAX_FREQUENCY) {
          setLive(null);
        } else {
          setLive({ reading: nearestGuitarString(frequency), frequency });
        }
      }, POLL_MS);
      setStatus("listening");
    } catch {
      // Permission denied, no microphone, or an insecure context: the tuner is
      // unusable either way, so one shared message covers all of them.
      setStatus("denied");
    }
  }

  function stop() {
    stopListening();
    setLive(null);
    setStatus("idle");
  }

  function playReference(string: GuitarString) {
    const Ctor = AudioCtor();
    if (!Ctor) return;
    const ctx = (toneCtx.current ??= new Ctor());
    if (ctx.state === "suspended") void ctx.resume();
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = "sine";
    osc.frequency.setValueAtTime(string.frequency, ctx.currentTime);
    osc.connect(gain);
    gain.connect(ctx.destination);
    // Quick fade in and out so the tone doesn't click.
    const now = ctx.currentTime;
    gain.gain.setValueAtTime(0.0001, now);
    gain.gain.exponentialRampToValueAtTime(0.25, now + 0.02);
    gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.9);
    osc.start();
    osc.stop(now + 0.95);

    if (toneTimer.current) clearTimeout(toneTimer.current);
    setPlaying(string);
    toneTimer.current = setTimeout(() => setPlaying(null), 950);
  }

  const listening = status === "listening";
  const reading = live?.reading ?? null;
  const cents = reading?.cents ?? 0;
  const abs = Math.abs(cents);
  // Green / amber / red: the code every clip-on tuner already teaches.
  const tone = !reading ? "idle" : abs <= IN_TUNE_CENTS ? "good" : abs <= CLOSE_CENTS ? "close" : "off";
  const color = { idle: "#a3a3a3", good: "#16a34a", close: "#f59e0b", off: "#ef4444" }[tone];
  const activeName = listening ? reading?.string.name : undefined;

  return (
    <div className="mx-auto w-full max-w-xl px-4 pb-24 pt-8 sm:px-6">
      <div className="rounded-[2rem] border border-black/5 bg-white p-6 shadow-[0_2px_24px_-8px_rgba(0,0,0,0.15)] sm:p-9">
        <h1 className="text-center text-3xl font-extrabold tracking-tight">{t("tunerLabel")}</h1>

        <div className="mt-8 flex flex-wrap justify-center gap-2">
          {STANDARD_TUNING.map((s) => {
            const isActive = activeName === s.name;
            const isPlaying = playing?.name === s.name;
            return (
              <button
                key={s.name}
                type="button"
                onClick={() => playReference(s)}
                aria-label={`${s.name} — ${s.frequency} Hz`}
                className={`flex h-11 min-w-[3.6rem] items-center justify-center gap-1.5 rounded-full border px-4 text-[15px] transition ${
                  isActive
                    ? "border-black bg-black font-bold text-white"
                    : isPlaying
                      ? "border-2 border-blue-500 font-semibold text-blue-600"
                      : "border-black/15 text-neutral-600 hover:border-black/40 hover:text-black"
                }`}
              >
                {isPlaying && <Volume2 size={14} />}
                {s.name}
              </button>
            );
          })}
        </div>
        {!listening && <p className="mt-3 text-center text-xs text-neutral-400">{t("tunerReferenceTip")}</p>}

        <div className="mt-9 flex flex-col items-center">
          {status === "idle" && (
            <>
              <button
                type="button"
                onClick={start}
                aria-label={t("tunerTapToStart")}
                className="flex h-28 w-28 items-center justify-center rounded-full bg-gradient-to-br from-indigo-600 to-sky-500 text-white shadow-[0_18px_40px_-12px_rgba(37,99,235,0.6)] transition hover:scale-105 active:scale-95"
              >
                <Mic size={44} />
              </button>
              <p className="mt-5 text-neutral-500">{t("tunerTapToStart")}</p>
            </>
          )}

          {status === "requesting" && <Loader2 size={44} className="animate-spin text-neutral-400" />}

          {status === "denied" && (
            <>
              <span className="flex h-20 w-20 items-center justify-center rounded-full bg-red-50 text-red-500">
                <MicOff size={36} />
              </span>
              <p role="alert" className="mt-5 max-w-sm text-center text-neutral-600">
                {t("tunerMicDenied")}
              </p>
              <button
                type="button"
                onClick={start}
                className="mt-6 h-11 rounded-full bg-black px-7 text-sm font-semibold text-white transition hover:scale-[1.03]"
              >
                {t("retryLabel")}
              </button>
            </>
          )}

          {listening && (
            <div className="w-full">
              <p
                data-testid="note"
                className="text-center text-7xl font-extrabold tracking-tight transition-colors duration-150"
                style={{ color }}
              >
                {reading?.string.name ?? "—"}
              </p>
              <p data-testid="status" aria-live="polite" className="mt-2 text-center text-neutral-500">
                {!live
                  ? t("tunerListening")
                  : abs <= IN_TUNE_CENTS
                    ? t("tunerInTune")
                    : `${cents > 0 ? "+" : ""}${Math.round(cents)} ¢  ·  ${live.frequency.toFixed(1)} Hz`}
              </p>

              <Meter cents={cents} color={color} active={!!reading} />

              <div className="mt-9 flex justify-center">
                <button
                  type="button"
                  onClick={stop}
                  className="flex h-11 items-center gap-2 rounded-full border border-black/15 px-6 text-sm font-semibold transition hover:bg-neutral-50"
                >
                  <Square size={15} className="fill-current" /> {t("tunerStop")}
                </button>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

// A needle track from -50 to +50 cents (a semitone either way, the range of a
// physical clip-on tuner's dial). Only the marker moves, so it reads at a
// glance without parsing the number under it.
function Meter({ cents, color, active }: { cents: number; color: string; active: boolean }) {
  const clamped = Math.max(-50, Math.min(50, cents));
  const left = 50 + clamped; // percent
  return (
    <div className="mt-8 px-2" role="img" aria-label={`${Math.round(cents)} cents`}>
      <div className="relative h-10">
        <div className="absolute inset-x-0 top-1/2 h-1.5 -translate-y-1/2 rounded-full bg-neutral-100" />
        {/* the "in tune" zone */}
        <div className="absolute left-[45%] top-1/2 h-1.5 w-[10%] -translate-y-1/2 rounded-full bg-emerald-200" />
        {[0, 25, 50, 75, 100].map((p) => (
          <div
            key={p}
            className={`absolute top-1/2 -translate-x-1/2 -translate-y-1/2 rounded bg-neutral-300 ${p === 50 ? "h-6 w-0.5 bg-neutral-500" : "h-3 w-px"}`}
            style={{ left: `${p}%` }}
          />
        ))}
        <div
          className="absolute top-1/2 h-5 w-5 -translate-x-1/2 -translate-y-1/2 rounded-full shadow-md transition-[left,opacity,background-color] duration-150"
          style={{ left: `${left}%`, background: color, opacity: active ? 1 : 0.3 }}
        />
      </div>
      <div className="mt-1 flex justify-between text-[11px] font-medium text-neutral-400">
        <span>♭ −50</span>
        <span>0</span>
        <span>+50 ♯</span>
      </div>
    </div>
  );
}

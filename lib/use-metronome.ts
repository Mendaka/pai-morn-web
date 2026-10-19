"use client";

import { useEffect, useRef, useState } from "react";

export const MIN_BPM = 30;
export const MAX_BPM = 250;
export const DEFAULT_BPM = 80;

// How far ahead clicks are queued on the audio clock, and how often the queue
// is topped up. Scheduling on the AudioContext's own clock (rather than one
// setTimeout per beat, as the Flutter app does) keeps the tempo steady even
// when the page's timers are busy or throttled.
const LOOKAHEAD_S = 0.12;
const TICK_MS = 25;

function click(ctx: AudioContext, at: number) {
  const osc = ctx.createOscillator();
  const gain = ctx.createGain();
  osc.type = "square";
  osc.frequency.value = 1000;
  gain.gain.setValueAtTime(0.25, at);
  gain.gain.exponentialRampToValueAtTime(0.001, at + 0.05);
  osc.connect(gain);
  gain.connect(ctx.destination);
  osc.start(at);
  osc.stop(at + 0.05);
}

/** A click track for the song reader: on/off plus BPM (30-250, default 80). */
export function useMetronome() {
  const [enabled, setEnabled] = useState(false);
  const [bpm, setBpmState] = useState(DEFAULT_BPM);
  // The running scheduler reads the current tempo from here, so changing BPM
  // takes effect on the next beat without restarting the click track.
  const bpmRef = useRef(bpm);
  useEffect(() => {
    bpmRef.current = bpm;
  }, [bpm]);

  useEffect(() => {
    if (!enabled) return;
    const Ctx = window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
    if (!Ctx) return;
    const ctx = new Ctx();
    void ctx.resume();
    let next = ctx.currentTime + 0.05;
    const id = window.setInterval(() => {
      while (next < ctx.currentTime + LOOKAHEAD_S) {
        click(ctx, next);
        next += 60 / bpmRef.current;
      }
    }, TICK_MS);
    return () => {
      window.clearInterval(id);
      void ctx.close();
    };
  }, [enabled]);

  return {
    enabled,
    setEnabled,
    bpm,
    changeBpm: (delta: number) => setBpmState((b) => Math.min(MAX_BPM, Math.max(MIN_BPM, b + delta))),
  };
}

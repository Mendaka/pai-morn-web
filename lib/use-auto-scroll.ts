"use client";

import { useCallback, useEffect, useRef, useState } from "react";

// Port of the song reader's auto-scroll (song_reader_screen.dart). Speed is a
// 5-100 level mapped through a quadratic curve, so the slow end — the part
// actually used for reading lyrics while playing — has fine control:
// px/s = 64 * (level/100)^2. The scroll position is computed from elapsed time
// rather than nudged per frame, so it stays smooth even when the browser
// rounds each frame's scroll to whole pixels.
export const MIN_SPEED = 5;
export const MAX_SPEED = 100;
export const DEFAULT_SPEED = 40;
const MAX_PX_PER_SECOND = 64;

const pxPerSecondFor = (level: number) => {
  const fraction = Math.min(MAX_SPEED, Math.max(MIN_SPEED, level)) / 100;
  return MAX_PX_PER_SECOND * fraction * fraction;
};

export function useAutoScroll(speed: number) {
  const [running, setRunning] = useState(false);
  const frame = useRef(0);
  const runningRef = useRef(false);
  // Where and when the current run started, and how fast it moves.
  const base = useRef({ offset: 0, time: 0, pxPerSecond: 0 });

  const stop = useCallback(() => {
    cancelAnimationFrame(frame.current);
    runningRef.current = false;
    setRunning(false);
  }, []);

  // Re-bases the timer at the current position, so a new speed applies from
  // where the page is now without a jump.
  const rebase = useCallback((level: number) => {
    base.current = { offset: window.scrollY, time: performance.now(), pxPerSecond: pxPerSecondFor(level) };
  }, []);

  const begin = useCallback(
    (level: number) => {
      cancelAnimationFrame(frame.current);
      rebase(level);
      const tick = (now: number) => {
        const { offset, time, pxPerSecond } = base.current;
        const target = offset + (pxPerSecond * (now - time)) / 1000;
        const max = document.documentElement.scrollHeight - window.innerHeight;
        if (target >= max) {
          window.scrollTo(0, max);
          stop();
          return;
        }
        window.scrollTo(0, target);
        frame.current = requestAnimationFrame(tick);
      };
      runningRef.current = true;
      frame.current = requestAnimationFrame(tick);
      setRunning(true);
    },
    [rebase, stop],
  );

  // Moving the slider mid-scroll changes the speed in place.
  useEffect(() => {
    if (runningRef.current) rebase(speed);
  }, [speed, rebase]);

  // Someone grabbing the page themselves (wheel, touch, keys) wins.
  useEffect(() => {
    if (!running) return;
    const yield_ = () => stop();
    // A tap on a reader control (pause, speed slider, ...) must NOT count as
    // "grabbing the page": on a phone touchstart fires before the button's
    // click, so it stopped the scroll and the click then started it again —
    // pause could never work by touch. Controls opt in with data-keep-scrolling.
    const onTouch = (e: TouchEvent) => {
      const target = e.target instanceof Element ? e.target : null;
      if (target?.closest("[data-keep-scrolling] button, [data-keep-scrolling] input")) return;
      stop();
    };
    const onKey = (e: KeyboardEvent) => {
      if (["ArrowUp", "ArrowDown", "PageUp", "PageDown", "Home", "End", " "].includes(e.key)) stop();
    };
    window.addEventListener("wheel", yield_, { passive: true });
    window.addEventListener("touchstart", onTouch, { passive: true });
    window.addEventListener("keydown", onKey);
    return () => {
      window.removeEventListener("wheel", yield_);
      window.removeEventListener("touchstart", onTouch);
      window.removeEventListener("keydown", onKey);
    };
  }, [running, stop]);

  useEffect(() => () => cancelAnimationFrame(frame.current), []);

  const toggle = useCallback(() => {
    if (running) stop();
    else begin(speed);
  }, [running, speed, begin, stop]);

  const reset = useCallback(() => {
    stop();
    window.scrollTo({ top: 0, behavior: "smooth" });
  }, [stop]);

  return { running, toggle, reset };
}

"use client";

import { useEffect, useRef, useState } from "react";

/**
 * Fades a section in as it scrolls into view (see the .reveal/.reveal-stagger
 * rules in globals.css). With `stagger`, each direct child animates on its
 * own — give each child a `style={{ ["--i"]: index }}` for the cascade.
 * Elements already on screen at mount (e.g. above the fold on load) reveal
 * almost immediately, since IntersectionObserver reports them as intersecting
 * on its first callback.
 */
export default function Reveal({
  children,
  className = "",
  stagger = false,
}: {
  children: React.ReactNode;
  className?: string;
  stagger?: boolean;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const [inView, setInView] = useState(false);

  useEffect(() => {
    const el = ref.current;
    if (!el || typeof IntersectionObserver === "undefined") {
      setInView(true);
      return;
    }
    const obs = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setInView(true);
          obs.disconnect();
        }
      },
      // threshold is a fraction of the TARGET's own height, not the viewport's —
      // a `threshold` above 0 quietly breaks for any target taller than the
      // viewport itself (e.g. an unpaginated grid of 90+ cards, 2 columns on a
      // phone: several thousand px tall), since no scroll position can ever
      // show that big a fraction of it on screen. 0 fires the instant any part
      // of the target enters view, which is correct at any target height.
      { threshold: 0, rootMargin: "0px 0px -8% 0px" },
    );
    obs.observe(el);
    return () => obs.disconnect();
  }, []);

  return (
    <div ref={ref} className={`${stagger ? "reveal-stagger" : "reveal"} ${inView ? "reveal-in" : ""} ${className}`}>
      {children}
    </div>
  );
}

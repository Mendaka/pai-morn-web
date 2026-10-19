"use client";

import { useLayoutEffect, useMemo, useRef } from "react";
import { useT } from "@/components/LanguageProvider";
import { buildLineModel, type LyricToken } from "@/lib/lyrics";

const CHORD_GAP_PX = 6;

// Chord alignment, done in the browser's own layout engine instead of the
// Flutter app's per-glyph TextPainter measurement:
//
// - The lyric is split into segments at each chord's character offset, and
//   the chord is absolutely positioned at the left edge of its segment — so
//   it sits over the exact character it was authored on, with zero JS and
//   zero font assumptions. This is also what gets server-rendered, so the
//   page is correctly aligned before (or without) hydration.
// - Chords that would collide (two chords on one syllable, a wide chord over
//   a short syllable) are pushed right by the same running-cursor rule the
//   Flutter version used, applied after layout via a transform. The lyric
//   text itself is never touched, so words stay unbroken.
function layoutAnchors(root: HTMLElement) {
  const anchors = root.querySelectorAll<HTMLElement>("[data-anchor]");
  let cursor = 0;
  anchors.forEach((anchor) => {
    const segment = anchor.parentElement as HTMLElement;
    const natural = segment.offsetLeft;
    const x = Math.max(natural, cursor);
    anchor.style.transform = x === natural ? "" : `translateX(${x - natural}px)`;
    cursor = x + anchor.offsetWidth + CHORD_GAP_PX;
  });
}

export default function LyricLine({
  content,
  transpose,
  onChordClick,
}: {
  content: LyricToken[];
  transpose: number;
  /** Makes chords tappable (the reader opens the chord diagram popup). */
  onChordClick?: (chord: string) => void;
}) {
  const model = useMemo(() => buildLineModel(content, transpose), [content, transpose]);
  const rootRef = useRef<HTMLDivElement>(null);
  const { t } = useT();
  const tap = (chord: string) =>
    onChordClick
      ? {
          role: "button" as const,
          tabIndex: 0,
          title: t("showChordLabel"),
          onClick: () => onChordClick(chord),
          onKeyDown: (e: React.KeyboardEvent) => (e.key === "Enter" || e.key === " ") && onChordClick(chord),
        }
      : {};

  useLayoutEffect(() => {
    const root = rootRef.current;
    if (!root || model.kind !== "aligned" || !model.hasAnchors) return;

    const relayout = () => layoutAnchors(root);
    relayout();

    // Glyph widths change when a web font finishes loading (Myanmar/Shan
    // text starts in a fallback font and swaps), and `document.fonts.ready`
    // alone can resolve *before* a lazily-requested font even starts
    // loading — so watch the line's own width (shrink-to-fit, so it moves
    // with the text: font swap, text-size control) plus the fonts'
    // loadingdone event, rather than the fixed-width scroll wrapper.
    const observer = new ResizeObserver(relayout);
    if (root.firstElementChild) observer.observe(root.firstElementChild);
    const fonts = document.fonts;
    fonts?.addEventListener("loadingdone", relayout);
    fonts?.ready.then(relayout);
    return () => {
      observer.disconnect();
      fonts?.removeEventListener("loadingdone", relayout);
    };
  }, [model]);

  if (model.kind === "inline") {
    return (
      <div className="lyric-inline">
        {model.tokens.map((t, i) =>
          t.isChord ? (
            <span key={i} className="chord" {...tap(t.text)}>
              {t.text}
            </span>
          ) : (
            <span key={i} className="whitespace-pre text-neutral-600">
              {t.text}
            </span>
          ),
        )}
      </div>
    );
  }

  return (
    <div ref={rootRef} translate="no" className="lyric-scroll">
      <div className={`lyric-line ${model.hasAnchors ? "has-chords" : ""}`}>
        {model.segments.map((seg, i) => (
          <span key={i} className="lyric-seg">
            {seg.anchors.map((a, j) => (
              <span
                key={j}
                data-anchor
                className={a.isChord ? "chord chord-anchor" : "chord-anchor text-neutral-400"}
                {...(a.isChord ? tap(a.text) : {})}
              >
                {a.text}
              </span>
            ))}
            {seg.text}
          </span>
        ))}
      </div>
    </div>
  );
}

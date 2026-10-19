"use client";

import { useEffect } from "react";
import { Volume2, X } from "lucide-react";
import ChordDiagram from "@/components/ChordDiagram";
import { useT } from "@/components/LanguageProvider";
import { canonicalChordName, chordRoot, lookupChordShape, rootColor } from "@/lib/chord-shapes";
import { strum } from "@/lib/chord-sound";
import { recordLookedUpChord, useInstrument, useLeftHanded } from "@/lib/stored";

// The popup opened by tapping a chord inside a song: its finger positions for
// the instrument chosen on the Chords page, with a button to hear it strummed.
export default function ChordDialog({ chord, onClose }: { chord: string; onClose: () => void }) {
  const { t } = useT();
  const { ukulele } = useInstrument();
  const { leftHanded } = useLeftHanded();
  const shape = lookupChordShape(chord, ukulele);
  const canonical = canonicalChordName(chord);

  // Only a chord the dictionary recognised is worth resurfacing later on the
  // Chords page's "Recently looked up" row, under its canonical name.
  useEffect(() => {
    if (canonical) recordLookedUpChord(canonical);
  }, [canonical]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [onClose]);

  const color = canonical ? rootColor(chordRoot(canonical)) : "#2563eb";

  return (
    <div translate="no" className="fixed inset-0 z-[70] flex items-center justify-center bg-black/40 p-4 backdrop-blur-sm" onClick={onClose}>
      <div
        role="dialog"
        aria-modal="true"
        aria-label={`${t("chordsLabel")} ${chord}`}
        onClick={(e) => e.stopPropagation()}
        className="relative w-full max-w-xs rounded-3xl bg-white p-6 text-center shadow-2xl"
      >
        <button
          type="button"
          onClick={onClose}
          aria-label={t("closeLabel")}
          className="absolute right-3 top-3 flex h-9 w-9 items-center justify-center rounded-full text-neutral-500 hover:bg-neutral-100"
        >
          <X size={18} />
        </button>
        <span className="inline-block rounded-full px-4 py-1 text-xl font-bold" style={{ color, background: `${color}22` }}>
          {chord}
        </span>
        <p className="mt-1 text-xs text-neutral-400">{ukulele ? t("instrumentUkulele") : t("instrumentGuitar")}</p>

        {shape ? (
          <>
            <ChordDiagram shape={shape} mirrored={leftHanded} dotColor={color} className="mx-auto mt-4 w-44 text-neutral-800" label={`${chord} chord diagram`} />
            <button
              type="button"
              onClick={() => strum(shape, ukulele)}
              className="mx-auto mt-5 flex h-11 items-center gap-2 rounded-full bg-black px-6 text-sm font-semibold text-white transition hover:scale-[1.03]"
            >
              <Volume2 size={16} /> {t("playLabel")}
            </button>
          </>
        ) : (
          <p className="my-8 text-neutral-500">{t("chordNotFound")}</p>
        )}
      </div>
    </div>
  );
}

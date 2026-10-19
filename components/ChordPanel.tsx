"use client";

import { useState } from "react";
import { useT } from "@/components/LanguageProvider";
import { FLAT_ROOTS, SHARP_ROOTS, diatonicChordsForKey, respellRoot } from "@/lib/diatonic";

const SECTION_LABELS = ["Key", "Intro", "Verse", "Chorus", "Bridge", "Solo", "Outro"];

// Key picker + the key's diatonic chord chips + separators and section
// labels. Buttons keep focus in the lyrics field on mouse-down, so the caret
// (and on phones, the keyboard) stays where it was.
export default function ChordPanel({
  root,
  minor,
  onRoot,
  onMinor,
  onInsert,
}: {
  root: string;
  minor: boolean;
  onRoot: (r: string) => void;
  onMinor: (m: boolean) => void;
  onInsert: (text: string) => void;
}) {
  const { t } = useT();
  const keep = (e: React.MouseEvent) => e.preventDefault();

  // Sharp vs. flat is a display preference over the same 12 pitches, not
  // part of the saved key itself — derived from whichever accidental the
  // current root happens to use (2026-09-30, owner passing on user
  // feedback: "คีย์มีให้เลือกเยอะเกินไปตาลาย" — the old single dropdown had
  // all 17 CHROMATIC_ROOTS at once, both spellings of every accidental
  // together, which is what was overwhelming). Picking sharp/flat first,
  // the same way major/minor already works, narrows it to 12.
  // A natural root (C, D, ...) doesn't reveal a preference on its own, so
  // that case falls back to whatever the user last explicitly chose here —
  // an explicitly-accidental root (C#, Db, ...) always wins over that
  // stored preference, keeping the toggle and the select in agreement
  // without needing an effect to sync them (derived during render instead).
  const [userPreferFlat, setUserPreferFlat] = useState(root.includes("b"));
  const preferFlat = root.includes("#") ? false : root.includes("b") ? true : userPreferFlat;

  function toggleAccidental(flat: boolean) {
    setUserPreferFlat(flat);
    onRoot(respellRoot(root, flat)); // e.g. C# -> Db, same pitch either way
  }

  // 16 chords per key (7ths, maj7, dim7, the alternate vii°/vii°7 spelling)
  // was the other half of the same complaint — collapsed to the 7 plain
  // triads (DiatonicChord.core) by default, the rest behind this toggle.
  const [showMore, setShowMore] = useState(false);
  const allChords = diatonicChordsForKey(root, minor);
  const chords = showMore ? allChords : allChords.filter((c) => c.core);
  const rootOptions = preferFlat ? FLAT_ROOTS : SHARP_ROOTS;

  return (
    <div translate="no">
      <div className="flex flex-wrap items-center gap-3">
        <span className="text-sm font-semibold text-neutral-800">{t("keyLabel")}</span>
        <div className="flex rounded-full bg-neutral-100 p-0.5 text-sm font-semibold">
          {[
            [false, t("sharpLabel")],
            [true, t("flatLabel")],
          ].map(([v, label]) => (
            <button
              key={String(label)}
              type="button"
              onMouseDown={keep}
              onClick={() => toggleAccidental(v as boolean)}
              aria-pressed={preferFlat === v}
              className={`rounded-full px-4 py-1.5 transition ${preferFlat === v ? "bg-white shadow" : "text-neutral-500"}`}
            >
              {label as string}
            </button>
          ))}
        </div>
        <select
          value={root}
          onChange={(e) => onRoot(e.target.value)}
          aria-label={t("keyRootLabel")}
          className="h-10 rounded-xl border border-black/10 bg-white px-3 font-semibold outline-none focus:border-blue-500"
        >
          {rootOptions.map((r) => (
            <option key={r} value={r}>
              {r}
            </option>
          ))}
        </select>
        <div className="flex rounded-full bg-neutral-100 p-0.5 text-sm font-semibold">
          {[
            [false, t("majorLabel")],
            [true, t("minorLabel")],
          ].map(([v, label]) => (
            <button
              key={String(label)}
              type="button"
              onClick={() => onMinor(v as boolean)}
              aria-pressed={minor === v}
              className={`rounded-full px-4 py-1.5 transition ${minor === v ? "bg-white shadow" : "text-neutral-500"}`}
            >
              {label as string}
            </button>
          ))}
        </div>
      </div>

      <div className="mt-4 flex flex-wrap gap-2">
        {chords.map((c) => (
          <button
            key={c.degree}
            type="button"
            onMouseDown={keep}
            onClick={() => onInsert(`[${c.chordName}]`)}
            title={c.degree}
            className="rounded-full border border-blue-600/20 bg-blue-50 px-3 py-1.5 text-sm font-bold text-blue-700 transition hover:bg-blue-100 active:scale-95"
          >
            {c.chordName}
            <span className="ml-1.5 text-[10px] font-medium text-blue-400">{c.degree}</span>
          </button>
        ))}
        <button
          type="button"
          onMouseDown={keep}
          onClick={() => setShowMore((s) => !s)}
          className="rounded-full border border-dashed border-black/20 px-3 py-1.5 text-sm font-semibold text-neutral-500 transition hover:bg-neutral-100 active:scale-95"
        >
          {showMore ? t("fewerChordsLabel") : t("moreChordsLabel")}
        </button>
        {[
          [" / ", "/", t("chordSeparatorTip")],
          [" - ", "-", t("chordLinkTip")],
        ].map(([text, label, tip]) => (
          <button
            key={label}
            type="button"
            onMouseDown={keep}
            onClick={() => onInsert(text)}
            title={tip}
            className="w-9 rounded-full border border-black/10 bg-white py-1.5 text-sm font-bold text-neutral-600 transition hover:bg-neutral-100 active:scale-95"
          >
            {label}
          </button>
        ))}
      </div>

      <div className="mt-4 flex flex-wrap gap-2">
        {SECTION_LABELS.map((l) => (
          <button
            key={l}
            type="button"
            onMouseDown={keep}
            onClick={() => onInsert(`${l} `)}
            className="rounded-full border border-black/10 px-3 py-1.5 text-sm font-medium text-neutral-700 transition hover:bg-neutral-100 active:scale-95"
          >
            {l}
          </button>
        ))}
      </div>
    </div>
  );
}

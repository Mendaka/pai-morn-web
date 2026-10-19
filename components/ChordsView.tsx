"use client";

import { useMemo, useState } from "react";
import { Grid2x2, Hand, Search, Star, Volume2 } from "lucide-react";
import ChordDiagram from "@/components/ChordDiagram";
import Fretboard from "@/components/Fretboard";
import { useT } from "@/components/LanguageProvider";
import { GUITAR_SHAPES, UKULELE_SHAPES, chordRoot, rootColor, type ChordShape } from "@/lib/chord-shapes";
import { strum } from "@/lib/chord-sound";
import { useInstrument, useLeftHanded, usePinnedChords, useRecentChords } from "@/lib/stored";

type Mode = "chords" | "fretboard" | "quiz";
type Quiz = { answer: string; choices: string[]; selected: string | null };

function newQuiz(shapes: Record<string, ChordShape>): Quiz {
  const names = Object.keys(shapes);
  const answer = names[Math.floor(Math.random() * names.length)];
  const wrong = new Set<string>();
  while (wrong.size < 3) {
    const c = names[Math.floor(Math.random() * names.length)];
    if (c !== answer) wrong.add(c);
  }
  // Fisher-Yates so the right answer isn't always first.
  const choices = [answer, ...wrong];
  for (let i = choices.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [choices[i], choices[j]] = [choices[j], choices[i]];
  }
  return { answer, choices, selected: null };
}

export default function ChordsView() {
  const { t } = useT();
  const { ukulele, set: setInstrument } = useInstrument();
  const { leftHanded, set: setLeftHanded } = useLeftHanded();
  const { pinned, toggle: togglePin } = usePinnedChords();
  const recent = useRecentChords();

  const [mode, setMode] = useState<Mode>("chords");
  const [query, setQuery] = useState("");
  const [cols, setCols] = useState(2); // phones only: 2 -> 3 -> 4 per row
  const [quiz, setQuiz] = useState<Quiz | null>(null);
  const [score, setScore] = useState({ right: 0, total: 0 });

  const shapes = ukulele ? UKULELE_SHAPES : GUITAR_SHAPES;

  const entries = useMemo(() => {
    const q = query.trim().toLowerCase();
    const all = Object.entries(shapes).filter(([name]) => !q || name.toLowerCase().includes(q));
    // Pinned chords first; each group keeps the poster's own order.
    return [...all.filter(([n]) => pinned.has(n)), ...all.filter(([n]) => !pinned.has(n))];
  }, [shapes, query, pinned]);

  function pickInstrument(u: boolean) {
    setInstrument(u);
    // A quiz question drawn from the other instrument's shapes would be stale.
    if (mode === "quiz") setQuiz(newQuiz(u ? UKULELE_SHAPES : GUITAR_SHAPES));
  }
  function pickMode(m: Mode) {
    if (m === "quiz") setQuiz(newQuiz(shapes));
    setMode(m);
  }
  function answer(choice: string) {
    if (!quiz || quiz.selected) return;
    setQuiz({ ...quiz, selected: choice });
    setScore((s) => ({ right: s.right + (choice === quiz.answer ? 1 : 0), total: s.total + 1 }));
  }

  const card = (name: string, shape: ChordShape) => {
    const color = rootColor(chordRoot(name));
    const isPinned = pinned.has(name);
    return (
      <div key={name} translate="no" className="relative">
        <button
          type="button"
          onClick={() => strum(shape, ukulele)}
          aria-label={t("playChord", { name })}
          className="lift-spring group block w-full rounded-3xl border border-black/5 bg-white px-3 pb-4 pt-4 shadow-[0_2px_16px_-8px_rgba(0,0,0,0.15)] transition hover:-translate-y-0.5 hover:shadow-[0_12px_32px_-14px_rgba(0,0,0,0.3)] active:scale-[0.98] active:shadow-[0_2px_10px_-6px_rgba(0,0,0,0.2)]"
        >
          <span className="flex items-center justify-center gap-1.5 px-4">
            <span className="rounded-full px-3 py-1 text-base font-bold" style={{ color, background: `${color}1f` }}>
              {name}
            </span>
            <Volume2 size={15} className="text-neutral-300 transition group-hover:text-neutral-500" />
          </span>
          <ChordDiagram shape={shape} mirrored={leftHanded} dotColor={color} className="mx-auto mt-3 w-4/5 text-neutral-800" label={`${name} chord diagram`} />
        </button>
        <button
          type="button"
          onClick={() => togglePin(name)}
          aria-pressed={isPinned}
          aria-label={isPinned ? t("unpinChord", { name }) : t("pinChord", { name })}
          className="absolute right-1 top-1 flex h-8 w-8 items-center justify-center rounded-full transition hover:bg-black/5"
        >
          <Star size={16} className={isPinned ? "fill-amber-400 text-amber-400" : "text-neutral-300"} />
        </button>
      </div>
    );
  };

  return (
    <div className="mx-auto w-full max-w-5xl px-4 pb-24 pt-8 sm:px-6">
      <h1 className="text-3xl font-extrabold tracking-tight">{t("chordsLabel")}</h1>
      <p className="mt-2 text-neutral-500">{t("chordsIntro")}</p>

      <div className="mt-6 flex flex-wrap items-center gap-3">
        <Segmented
          label={t("viewLabel")}
          value={mode}
          onChange={(v) => pickMode(v as Mode)}
          options={[
            ["chords", t("chordsLabel")],
            ["fretboard", t("fretboardLabel")],
            ["quiz", t("quizLabel")],
          ]}
        />
        {/* the note map is standard-tuning guitar only */}
        {mode !== "fretboard" && (
          <Segmented
            label={t("instrumentLabel")}
            value={ukulele ? "ukulele" : "guitar"}
            onChange={(v) => pickInstrument(v === "ukulele")}
            options={[
              ["guitar", t("instrumentGuitar")],
              ["ukulele", t("instrumentUke")],
            ]}
          />
        )}
        <button
          type="button"
          onClick={() => setLeftHanded(!leftHanded)}
          aria-pressed={leftHanded}
          title={t("leftHandedLabel")}
          aria-label={t("leftHandedLabel")}
          className={`flex h-10 w-11 items-center justify-center rounded-full border transition ${
            leftHanded ? "border-black bg-black text-white" : "border-black/15 text-neutral-700 hover:bg-neutral-50"
          }`}
        >
          <Hand size={17} />
        </button>
      </div>

      {mode === "fretboard" ? (
        <div className="mt-8">
          <Fretboard />
        </div>
      ) : mode === "quiz" && quiz && shapes[quiz.answer] ? (
        <div className="mt-10 flex flex-col items-center">
          <p className="font-semibold text-neutral-500">
            {t("quizScoreLabel")}: {score.right} / {score.total}
          </p>
          <div className="mt-5 w-56 rounded-3xl border border-black/5 bg-white p-5 shadow-[0_2px_24px_-8px_rgba(0,0,0,0.15)]">
            <ChordDiagram shape={shapes[quiz.answer]} mirrored={leftHanded} dotColor="#171717" className="w-full text-neutral-800" label={t("whichChordIsThis")} />
          </div>
          <div className="mt-8 flex flex-wrap justify-center gap-3">
            {quiz.choices.map((c) => {
              const state = !quiz.selected ? "idle" : c === quiz.answer ? "right" : c === quiz.selected ? "wrong" : "idle";
              return (
                <button
                  key={c}
                  type="button"
                  onClick={() => answer(c)}
                  disabled={!!quiz.selected}
                  className={`h-12 min-w-20 rounded-full border px-6 text-base font-bold transition ${
                    state === "right"
                      ? "border-emerald-600 bg-emerald-600 text-white"
                      : state === "wrong"
                        ? "border-rose-600 bg-rose-600 text-white"
                        : "border-black/15 hover:bg-neutral-50 disabled:opacity-50"
                  }`}
                >
                  {c}
                </button>
              );
            })}
          </div>
          {quiz.selected && (
            <button
              type="button"
              onClick={() => setQuiz(newQuiz(shapes))}
              className="mt-8 h-11 rounded-full bg-black px-7 text-sm font-semibold text-white transition hover:scale-[1.03]"
            >
              {t("quizNextLabel")}
            </button>
          )}
        </div>
      ) : (
        <>
          {recent.some((n) => shapes[n]) && (
            <section className="mt-8">
              <h2 className="text-sm font-bold text-neutral-500">{t("recentlyLookedUpChordsLabel")}</h2>
              <div className="chord-grid mt-3" style={{ ["--cols" as string]: 3 }}>
                {recent.filter((n) => shapes[n]).map((n) => card(`${n}`, shapes[n]))}
              </div>
            </section>
          )}

          <div className="mt-8 flex flex-wrap items-center gap-3">
            <label className="relative block w-full max-w-sm">
              <Search size={18} className="pointer-events-none absolute left-4 top-1/2 -translate-y-1/2 text-neutral-400" />
              <input
                className="field-input"
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                placeholder={t("searchChordsHint")}
                aria-label={t("searchChordsHint")}
              />
            </label>
            <button
              type="button"
              onClick={() => setCols((c) => (c >= 4 ? 2 : c + 1))}
              className="flex h-10 items-center gap-2 rounded-full border border-black/15 px-4 text-sm font-semibold sm:hidden"
              aria-label={t("perRowLabel", { n: cols })}
            >
              <Grid2x2 size={16} /> {cols}
            </button>
          </div>

          {entries.length === 0 ? (
            <p className="mt-10 text-neutral-500">{t("noChordsFound")}</p>
          ) : (
            <div className="chord-grid mt-6" style={{ ["--cols" as string]: cols }}>
              {entries.map(([name, shape]) => card(name, shape))}
            </div>
          )}
        </>
      )}
    </div>
  );
}

function Segmented({
  label,
  value,
  onChange,
  options,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  options: [string, string][];
}) {
  return (
    <div role="group" aria-label={label} className="flex rounded-full border border-black/15 p-1 text-sm font-semibold">
      {options.map(([v, text]) => (
        <button
          key={v}
          type="button"
          onClick={() => onChange(v)}
          aria-pressed={value === v}
          className={`rounded-full px-4 py-1.5 transition ${value === v ? "bg-black text-white" : "text-neutral-600 hover:bg-neutral-100"}`}
        >
          {text}
        </button>
      ))}
    </div>
  );
}

"use client";

import { Minus, Plus } from "lucide-react";
import { useT } from "@/components/LanguageProvider";

// Book-wide, not per-song: every song is mounted at once for react-pageflip's
// flip physics (see lib/use-book-window.ts), so per-page settings state isn't
// a good fit here the way it is on the normal reader — one transpose/text-
// size pair applies to the whole book instead. A small local Stepper rather
// than importing SongReader's own (unexported, and that file is intentionally
// never touched for Book Mode — see CLAUDE.md) — this one's deliberately
// simpler (no aria-label plumbing through useT for down/up, just the value).
function Stepper({ label, value, onMinus, onPlus }: { label: string; value: string; onMinus: () => void; onPlus: () => void }) {
  return (
    <div className="flex items-center gap-1.5">
      <span className="text-xs font-medium text-neutral-500">{label}</span>
      <div className="flex items-center rounded-full bg-neutral-100 p-0.5">
        <button type="button" onClick={onMinus} aria-label={`${label} -`} className="flex h-7 w-7 items-center justify-center rounded-full text-neutral-700 transition hover:bg-white hover:shadow">
          <Minus size={13} />
        </button>
        <span className="min-w-10 text-center text-xs font-semibold tabular-nums">{value}</span>
        <button type="button" onClick={onPlus} aria-label={`${label} +`} className="flex h-7 w-7 items-center justify-center rounded-full text-neutral-700 transition hover:bg-white hover:shadow">
          <Plus size={13} />
        </button>
      </div>
    </div>
  );
}

export const MIN_SCALE = 0.8;
export const MAX_SCALE = 1.4;

export default function BookToolbar({
  transpose,
  setTranspose,
  scale,
  setScale,
}: {
  transpose: number;
  setTranspose: (fn: (t: number) => number) => void;
  scale: number;
  setScale: (fn: (s: number) => number) => void;
}) {
  const { t } = useT();
  return (
    <div className="mb-2 flex w-full flex-none items-center justify-center gap-4 rounded-full bg-white/90 px-3 py-1.5 shadow-[0_2px_16px_-8px_rgba(0,0,0,0.25)] backdrop-blur">
      <Stepper
        label={t("keyLabel")}
        value={transpose > 0 ? `+${transpose}` : `${transpose}`}
        onMinus={() => setTranspose((v) => Math.max(-11, v - 1))}
        onPlus={() => setTranspose((v) => Math.min(11, v + 1))}
      />
      <Stepper
        label={t("textSizeLabel")}
        value={`${Math.round(scale * 100)}%`}
        onMinus={() => setScale((v) => Math.max(MIN_SCALE, Math.round((v - 0.1) * 10) / 10))}
        onPlus={() => setScale((v) => Math.min(MAX_SCALE, Math.round((v + 0.1) * 10) / 10))}
      />
    </div>
  );
}

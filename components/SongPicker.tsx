"use client";

import { useMemo, useState } from "react";
import { Check, Plus, Search, X } from "lucide-react";
import { useT } from "@/components/LanguageProvider";
import type { IndexedSong } from "@/lib/songs-index";

// A modal for adding songs to a setlist: search the songbook, tap to add. It
// stays open so several songs can be added in one go.
export default function SongPicker({
  songs,
  chosen,
  onAdd,
  onClose,
  title,
  actionLabel,
}: {
  songs: IndexedSong[] | null;
  chosen: Set<string>;
  onAdd: (id: string) => void;
  onClose: () => void;
  /** Overrides the heading and the per-row button text (default: "Add songs"). */
  title?: string;
  actionLabel?: string;
}) {
  const { t } = useT();
  const [q, setQ] = useState("");

  const matches = useMemo(() => {
    const needle = q.trim().toLowerCase();
    const all = songs ?? [];
    const hit = needle ? all.filter((s) => s.name.toLowerCase().includes(needle) || s.artist.toLowerCase().includes(needle)) : all;
    return hit.slice(0, 60);
  }, [songs, q]);

  return (
    <div className="fixed inset-0 z-[70] flex items-end justify-center bg-black/40 p-0 backdrop-blur-sm sm:items-center sm:p-4" onClick={onClose}>
      <div
        role="dialog"
        aria-modal="true"
        aria-label={title ?? t("addSongsLabel")}
        onClick={(e) => e.stopPropagation()}
        onKeyDown={(e) => e.key === "Escape" && onClose()}
        className="flex max-h-[85vh] w-full max-w-lg flex-col overflow-hidden rounded-t-3xl bg-white shadow-2xl sm:rounded-3xl"
      >
        <div className="flex items-center justify-between gap-3 px-5 pb-3 pt-5">
          <h2 className="text-lg font-bold">{title ?? t("addSongsLabel")}</h2>
          <button type="button" onClick={onClose} aria-label={t("doneLabel")} className="flex h-9 items-center gap-1.5 rounded-full bg-black px-4 text-sm font-semibold text-white">
            {t("doneLabel")}
          </button>
        </div>
        <div className="relative px-5">
          <Search size={18} className="pointer-events-none absolute left-9 top-1/2 -translate-y-1/2 text-neutral-400" />
          <input autoFocus value={q} onChange={(e) => setQ(e.target.value)} placeholder={t("quickSearchHint")} className="field-input" aria-label={t("quickSearchHint")} />
          {q && (
            <button type="button" onClick={() => setQ("")} aria-label={t("clearSearch")} className="absolute right-8 top-1/2 flex h-7 w-7 -translate-y-1/2 items-center justify-center rounded-full text-neutral-400 hover:bg-black/5">
              <X size={15} />
            </button>
          )}
        </div>
        <ul className="mt-3 flex-1 overflow-y-auto px-2 pb-4">
          {songs === null ? (
            <li className="px-5 py-8 text-center text-neutral-400">{t("loadingLabel")}</li>
          ) : matches.length === 0 ? (
            <li className="px-5 py-8 text-center text-neutral-400">{t("songPickerEmpty")}</li>
          ) : (
            matches.map((s) => {
              const inList = chosen.has(s.id);
              return (
                <li key={s.id}>
                  <button
                    type="button"
                    disabled={inList}
                    onClick={() => onAdd(s.id)}
                    className="flex w-full items-center gap-3 rounded-2xl px-3 py-2.5 text-left transition hover:bg-neutral-100 disabled:opacity-60"
                  >
                    <span className="min-w-0 flex-1">
                      <span className="block truncate font-medium text-neutral-900">{s.name}</span>
                      {s.artist && <span className="block truncate text-sm text-neutral-500">{s.artist}</span>}
                    </span>
                    <span className={`flex h-8 shrink-0 items-center gap-1 rounded-full px-3 text-xs font-semibold ${inList ? "bg-emerald-50 text-emerald-700" : "bg-neutral-100 text-neutral-700"}`}>
                      {inList ? <Check size={14} /> : <Plus size={14} />}
                      {inList ? t("inSetlistLabel") : (actionLabel ?? t("addSongsLabel"))}
                    </span>
                  </button>
                </li>
              );
            })
          )}
        </ul>
      </div>
    </div>
  );
}

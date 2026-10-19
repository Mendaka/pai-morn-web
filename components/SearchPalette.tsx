"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { CornerDownLeft, Mic2, Music2, Search, X } from "lucide-react";
import { useT } from "@/components/LanguageProvider";
import { useArtistsIndex, useSongsIndex } from "@/lib/songs-index";

type Hit = { key: string; href: string; title: string; subtitle: string; kind: "song" | "artist"; chip?: string };

const norm = (s: string) => s.normalize("NFC").toLowerCase();
// 0 = starts with the query, 1 = a word starts with it, 2 = contains it, null = no match
function rank(haystack: string, needle: string): number | null {
  const h = norm(haystack);
  if (h.startsWith(needle)) return 0;
  if (h.includes(" " + needle)) return 1;
  return h.includes(needle) ? 2 : null;
}

// Quick search (Ctrl/⌘+K): songs and artists as you type, keyboard-driven.
// Works on the small id -> title index the setlist pages already use, so
// nothing but two tiny JSON files is downloaded (and only once opened).
export default function SearchPalette({ onClose }: { onClose: () => void }) {
  const { t } = useT();
  const router = useRouter();
  const { songs } = useSongsIndex();
  const artists = useArtistsIndex(true);
  const [q, setQ] = useState("");
  const [active, setActive] = useState(0);
  const listRef = useRef<HTMLUListElement>(null);

  const { hits, songCount } = useMemo(() => {
    const needle = norm(q.trim());
    if (!needle) return { hits: [] as Hit[], songCount: 0 };
    const songHits = (songs ?? [])
      .map((s) => ({ s, r: Math.min(...[rank(s.name, needle), rank(s.artist, needle) === null ? null : (rank(s.artist, needle) as number) + 1].filter((x): x is number => x !== null), 9) }))
      .filter((x) => x.r < 9)
      .sort((a, b) => a.r - b.r)
      .slice(0, 8)
      .map<Hit>(({ s }) => ({ key: "s" + s.id, href: `/songbook/song/${s.id}`, title: s.name, subtitle: s.artist, kind: "song", chip: s.key }));
    const artistHits = (artists ?? [])
      .map((a) => ({ a, r: rank(a.name, needle) }))
      .filter((x): x is { a: (typeof x)["a"]; r: number } => x.r !== null)
      .sort((a, b) => a.r - b.r)
      .slice(0, 4)
      .map<Hit>(({ a }) => ({ key: "a" + a.id, href: `/songbook/artist/${a.id}`, title: a.name, subtitle: t("songsCountLabel", { count: a.count }), kind: "artist" }));
    return { hits: [...songHits, ...artistHits], songCount: songHits.length };
  }, [q, songs, artists, t]);

  // keep the highlighted row in view while arrowing through the list
  useEffect(() => {
    listRef.current?.querySelector('[aria-selected="true"]')?.scrollIntoView({ block: "nearest" });
  }, [active]);

  const go = (h: Hit) => {
    onClose();
    router.push(h.href);
  };

  function onKeyDown(e: React.KeyboardEvent) {
    if (e.key === "Escape") return onClose();
    if (!hits.length) return;
    if (e.key === "ArrowDown") {
      e.preventDefault();
      setActive((a) => (a + 1) % hits.length);
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      setActive((a) => (a - 1 + hits.length) % hits.length);
    } else if (e.key === "Enter") {
      e.preventDefault();
      go(hits[Math.min(active, hits.length - 1)]);
    }
  }

  const loading = songs === null && !!q.trim();
  return (
    <div className="fixed inset-0 z-[80] flex items-start justify-center bg-black/40 px-3 pt-[10vh] backdrop-blur-sm" onClick={onClose}>
      <div
        role="dialog"
        aria-modal="true"
        aria-label={t("searchTooltip")}
        onClick={(e) => e.stopPropagation()}
        onKeyDown={onKeyDown}
        className="w-full max-w-xl overflow-hidden rounded-3xl bg-white shadow-[0_30px_80px_-20px_rgba(0,0,0,0.5)]"
      >
        <div className="flex items-center gap-3 border-b border-black/5 px-5">
          <Search size={20} className="shrink-0 text-neutral-400" />
          <input
            autoFocus
            value={q}
            onChange={(e) => {
              setQ(e.target.value);
              setActive(0);
            }}
            placeholder={t("quickSearchHint")}
            aria-label={t("quickSearchHint")}
            role="combobox"
            aria-expanded={hits.length > 0}
            aria-controls="search-results"
            className="h-16 min-w-0 flex-1 bg-transparent text-lg outline-none placeholder:text-neutral-400"
          />
          <button type="button" onClick={onClose} aria-label={t("closeLabel")} className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-neutral-400 hover:bg-neutral-100">
            <X size={17} />
          </button>
        </div>

        <ul id="search-results" ref={listRef} role="listbox" className="max-h-[52vh] overflow-y-auto p-2">
          {!q.trim() ? (
            <li className="px-4 py-10 text-center text-neutral-400">{t("quickSearchPrompt")}</li>
          ) : loading ? (
            <li className="px-4 py-10 text-center text-neutral-400">{t("loadingLabel")}</li>
          ) : hits.length === 0 ? (
            <li className="px-4 py-10 text-center text-neutral-400">
              <p>{t("quickSearchNoResults")}</p>
              <button
                type="button"
                onClick={() => {
                  onClose();
                  router.push("/request-song");
                }}
                className="mt-4 inline-flex items-center gap-2 rounded-full bg-black px-6 py-2.5 text-sm font-semibold text-white transition hover:scale-[1.03]"
              >
                {t("requestSongLabel")}
              </button>
            </li>
          ) : (
            hits.map((h, i) => (
              <li key={h.key} role="presentation">
                {(i === 0 || i === songCount) && (
                  <p className="px-3 pb-1 pt-3 text-xs font-bold uppercase tracking-wider text-neutral-400">{h.kind === "song" ? t("songsTitle") : t("tabArtists")}</p>
                )}
                <a
                  href={h.href}
                  role="option"
                  aria-selected={i === active}
                  onMouseEnter={() => setActive(i)}
                  onClick={(e) => {
                    e.preventDefault();
                    go(h);
                  }}
                  className={`flex items-center gap-3 rounded-2xl px-3 py-2.5 transition-colors ${i === active ? "bg-blue-50" : ""}`}
                >
                  <span className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-xl ${h.kind === "song" ? "bg-indigo-50 text-indigo-600" : "bg-fuchsia-50 text-fuchsia-600"}`}>
                    {h.kind === "song" ? <Music2 size={18} /> : <Mic2 size={18} />}
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="block truncate font-medium text-neutral-900">{h.title}</span>
                    {h.subtitle && <span className="block truncate text-sm text-neutral-500">{h.subtitle}</span>}
                  </span>
                  {h.chip && <span className="shrink-0 rounded-full bg-neutral-100 px-2.5 py-0.5 text-xs font-bold text-neutral-600">{h.chip}</span>}
                  {i === active && <CornerDownLeft size={15} className="shrink-0 text-blue-500" />}
                </a>
              </li>
            ))
          )}
        </ul>
      </div>
    </div>
  );
}

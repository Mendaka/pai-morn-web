"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { Eye, Guitar, Search, X } from "lucide-react";
import ArtistCard, { ArtistAvatar } from "@/components/ArtistCard";
import BandCard from "@/components/BandCard";
import ComposerCard from "@/components/ComposerCard";
import { T, useT } from "@/components/LanguageProvider";
import EditSongButton from "@/components/EditSongButton";
import PlaylistShelf from "@/components/PlaylistShelf";
import Reveal from "@/components/Reveal";
import SongShelf from "@/components/SongShelf";
import { displayArtistName, songEntityIds, type ArtistSummary, type Catalog, type SongSummary } from "@/lib/catalog";
import { composersFrom } from "@/lib/composers";
import type { PlaylistSummary } from "@/lib/playlists";
import { usePinnedChords } from "@/lib/stored";

type Tab = "artists" | "songs" | "composers";
type ArtistEntity =
  | { kind: "artist"; key: string; count: number; artist: ArtistSummary }
  | { kind: "band"; key: string; count: number; name: string };
const PAGE = 30;

export default function SongBrowser({ catalog, playlists }: { catalog: Catalog; playlists: PlaylistSummary[] }) {
  const { songs, artists } = catalog;
  const { t, category: categoryLabel, gender: genderLabel } = useT();
  const [tab, setTab] = useState<Tab>("artists");
  const [q, setQ] = useState("");
  const [category, setCategory] = useState("all");
  const [gender, setGender] = useState("all");
  const [playableOnly, setPlayableOnly] = useState(false);
  const [shown, setShown] = useState(PAGE);
  const { pinned } = usePinnedChords();

  const categories = useMemo(() => countBy(songs, (s) => s.category), [songs]);
  const genders = useMemo(() => countBy(songs, (s) => s.gender), [songs]);

  const filtering = q.trim() !== "" || category !== "all" || gender !== "all" || playableOnly;

  const filteredSongs = useMemo(() => {
    const needle = q.trim().toLowerCase();
    return songs.filter((s) => {
      if (category !== "all" && s.category !== category) return false;
      if (gender !== "all" && s.gender !== gender) return false;
      // A song with zero recognized chords isn't meaningfully "playable" either way,
      // so it's excluded rather than vacuously passing an empty every().
      if (playableOnly && (s.chords.length === 0 || !s.chords.every((c) => pinned.has(c)))) return false;
      if (!needle) return true;
      return (
        s.songName.toLowerCase().includes(needle) ||
        s.band.toLowerCase().includes(needle) ||
        s.artistNames.some((n) => n.toLowerCase().includes(needle))
      );
    });
  }, [songs, q, category, gender, playableOnly, pinned]);

  // Artists tab entries follow the songs that survive the filters, with
  // counts to match — grouped by browsing entity (songEntityIds), not just
  // artistId, so a Band song contributes to its Band's one shared card
  // instead of fragmenting across each of its singers' own cards.
  const filteredArtists = useMemo(() => {
    const counts = new Map<string, number>();
    for (const s of filteredSongs) for (const id of songEntityIds(s)) counts.set(id, (counts.get(id) ?? 0) + 1);
    const entries: ArtistEntity[] = [];
    for (const [id, count] of counts) {
      if (id.startsWith("band:")) {
        entries.push({ kind: "band", key: id, count, name: id.slice(5) });
        continue;
      }
      const artist = artists.find((a) => a.id === id);
      if (artist) entries.push({ kind: "artist", key: id, count, artist });
    }
    return entries.sort((a, b) => b.count - a.count);
  }, [artists, filteredSongs]);

  const filteredComposers = useMemo(() => composersFrom(filteredSongs), [filteredSongs]);

  const newest = useMemo(() => [...songs].sort((a, b) => b.approvedAt - a.approvedAt).slice(0, 10), [songs]);
  const popular = useMemo(() => [...songs].sort((a, b) => b.viewCount - a.viewCount).slice(0, 10), [songs]);

  const reset = () => {
    setQ("");
    setCategory("all");
    setGender("all");
    setPlayableOnly(false);
  };

  return (
    <div>
      <div className="sticky top-[72px] z-30 -mx-4 bg-white/80 px-4 pb-3 pt-3 backdrop-blur-xl sm:mx-0 sm:rounded-3xl sm:px-5">
        <div className="relative">
          <Search className="pointer-events-none absolute left-4 top-1/2 -translate-y-1/2 text-neutral-400" size={20} />
          <input
            type="search"
            value={q}
            onChange={(e) => {
              setQ(e.target.value);
              setShown(PAGE);
            }}
            placeholder={t("songbookSearchHint")}
            className="h-12 w-full rounded-2xl border border-black/10 bg-white pl-12 pr-11 text-base shadow-[0_4px_20px_-10px_rgba(0,0,0,0.25)] outline-none transition focus:border-blue-500 focus:ring-4 focus:ring-blue-500/15"
          />
          {q && (
            <button
              type="button"
              aria-label={t("clearSearch")}
              onClick={() => setQ("")}
              className="absolute right-3 top-1/2 flex h-7 w-7 -translate-y-1/2 items-center justify-center rounded-full text-neutral-400 hover:bg-black/5 hover:text-neutral-700"
            >
              <X size={16} />
            </button>
          )}
        </div>

        <div className="mt-3 flex flex-wrap items-center gap-x-4 gap-y-2">
          <ChipGroup
            value={category}
            onChange={(v) => {
              setCategory(v);
              setShown(PAGE);
            }}
            options={[["all", t("allOption")], ...categories.map(([k, n]): [string, string] => [k, `${categoryLabel(k)} · ${n}`])]}
          />
          <ChipGroup
            value={gender}
            onChange={(v) => {
              setGender(v);
              setShown(PAGE);
            }}
            options={[["all", t("anyVoice")], ...genders.map(([k]): [string, string] => [k, genderLabel(k)])]}
          />
          <button
            type="button"
            onClick={() => setPlayableOnly((v) => !v)}
            disabled={pinned.size === 0}
            aria-pressed={playableOnly}
            title={pinned.size === 0 ? t("pinChordsFirstHint") : undefined}
            className={`flex items-center gap-1.5 rounded-full border px-3.5 py-1.5 text-[13px] font-medium transition disabled:cursor-not-allowed disabled:opacity-40 ${
              playableOnly ? "border-black bg-black text-white" : "border-black/10 bg-white text-neutral-600 hover:border-black/30 hover:text-black"
            }`}
          >
            <Guitar size={14} /> {t("playableFilterLabel")}
          </button>
        </div>
      </div>

      {!filtering && (
        <>
          <Reveal><PlaylistShelf playlists={playlists} /></Reveal>
          <Reveal><SongShelf title={<T k="newestSongsLabel" />} songs={newest} /></Reveal>
          <Reveal><SongShelf title={<T k="popularSongsLabel" />} songs={popular} /></Reveal>
        </>
      )}

      <div className="mt-8 flex items-center justify-between gap-4">
        <div className="inline-flex rounded-full bg-neutral-100 p-1">
          {(["artists", "songs", "composers"] as const).map((name) => (
            <button
              key={name}
              type="button"
              onClick={() => setTab(name)}
              className={`rounded-full px-5 py-2 text-sm font-semibold transition ${
                tab === name ? "bg-black text-white shadow" : "text-neutral-600 hover:text-black"
              }`}
            >
              {name === "artists"
                ? `${t("tabArtists")} · ${filteredArtists.length}`
                : name === "songs"
                  ? `${t("tabAllSongs")} · ${filteredSongs.length}`
                  : `${t("tabComposers")} · ${filteredComposers.length}`}
            </button>
          ))}
        </div>
        {filtering && (
          <button type="button" onClick={reset} className="text-sm font-medium text-blue-600 hover:underline">
            {t("clearFilters")}
          </button>
        )}
      </div>

      {tab === "artists" ? (
        filteredArtists.length ? (
          <Reveal key="artists" stagger className="mt-5 grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5">
            {filteredArtists.map((e, i) =>
              e.kind === "band" ? (
                <BandCard key={e.key} band={{ name: e.name, songCount: e.count }} style={{ ["--i" as string]: i }} />
              ) : (
                <ArtistCard key={e.key} artist={e.artist} count={e.count} style={{ ["--i" as string]: i }} />
              ),
            )}
          </Reveal>
        ) : (
          <Empty />
        )
      ) : tab === "composers" ? (
        filteredComposers.length ? (
          <Reveal key="composers" stagger className="mt-5 grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5">
            {filteredComposers.map((composer, i) => (
              <ComposerCard key={composer.name} composer={composer} style={{ ["--i" as string]: i }} />
            ))}
          </Reveal>
        ) : (
          <Empty />
        )
      ) : filteredSongs.length ? (
        <>
          <Reveal key="songs">
          <ul className="mt-5 divide-y divide-black/5 overflow-hidden rounded-3xl border border-black/5 bg-white shadow-[0_2px_16px_-8px_rgba(0,0,0,0.15)]">
            {filteredSongs.slice(0, shown).map((s) => (
              <SongRow key={s.id} song={s} artists={artists} />
            ))}
          </ul>
          </Reveal>
          {shown < filteredSongs.length && (
            <div className="mt-6 text-center">
              <button
                type="button"
                onClick={() => setShown((n) => n + PAGE)}
                className="rounded-full bg-black px-6 py-2.5 text-sm font-semibold text-white transition hover:scale-[1.03]"
              >
                {t("showMore", { n: filteredSongs.length - shown })}
              </button>
            </div>
          )}
        </>
      ) : (
        <Empty />
      )}
    </div>
  );
}

function countBy(songs: SongSummary[], pick: (s: SongSummary) => string): [string, number][] {
  const m = new Map<string, number>();
  for (const s of songs) {
    const k = pick(s);
    if (k) m.set(k, (m.get(k) ?? 0) + 1);
  }
  return [...m.entries()].sort((a, b) => b[1] - a[1]);
}

function ChipGroup({
  value,
  onChange,
  options,
}: {
  value: string;
  onChange: (v: string) => void;
  options: [string, string][];
}) {
  return (
    <div className="flex flex-wrap gap-1.5">
      {options.map(([key, text]) => (
        <button
          key={key}
          type="button"
          onClick={() => onChange(key)}
          aria-pressed={value === key}
          className={`rounded-full border px-3.5 py-1.5 text-[13px] font-medium transition ${
            value === key
              ? "border-black bg-black text-white"
              : "border-black/10 bg-white text-neutral-600 hover:border-black/30 hover:text-black"
          }`}
        >
          {text}
        </button>
      ))}
    </div>
  );
}

function SongRow({ song, artists }: { song: SongSummary; artists: Catalog["artists"] }) {
  const artist = artists.find((a) => a.id === song.artistIds[0]);
  return (
    <li className="flex items-center transition hover:bg-blue-50/60">
      <Link href={`/songbook/song/${song.id}`} className="flex min-w-0 flex-1 items-center gap-4 px-4 py-3 sm:px-5">
        {artist ? (
          <ArtistAvatar artist={artist} size={44} />
        ) : (
          <div className="h-11 w-11 shrink-0 rounded-full bg-neutral-200" />
        )}
        <div className="min-w-0 flex-1">
          <p className="line-clamp-1 font-semibold text-neutral-900">{song.songName}</p>
          <p className="line-clamp-1 text-sm text-neutral-500">{displayArtistName(song)}</p>
        </div>
        {song.key && (
          <span className="rounded-full bg-blue-50 px-2.5 py-1 text-xs font-bold text-blue-700">
            {song.key}
            {song.keyIsMinor ? "m" : ""}
          </span>
        )}
        <span className="hidden items-center gap-1 text-xs text-neutral-400 sm:flex">
          <Eye size={13} /> {song.viewCount}
        </span>
      </Link>
      <EditSongButton songId={song.id} variant="row" />
    </li>
  );
}

function Empty() {
  const { t } = useT();
  return (
    <div className="mt-10 rounded-3xl border border-dashed border-black/15 p-12 text-center text-neutral-500">
      <p>{t("nothingMatches")}</p>
      <Link
        href="/request-song"
        className="mt-4 inline-flex items-center gap-2 rounded-full bg-black px-6 py-2.5 text-sm font-semibold text-white transition hover:scale-[1.03]"
      >
        {t("requestSongLabel")}
      </Link>
    </div>
  );
}

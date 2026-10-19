import Link from "next/link";
import { Eye, ListMusic, Play } from "lucide-react";
import { SongsCount, T } from "@/components/LanguageProvider";
import { displayArtistName, type SongSummary } from "@/lib/catalog";
import { gradientFor } from "@/lib/palette";

// Public, read-only display of one admin-curated playlist — server-rendered
// (unlike PublicSetlistView, a user's shared setlist) since this is genuine
// editorial content worth indexing, same reasoning as every other public
// catalog page in this app.
export default function PlaylistView({
  title,
  description,
  coverUrl,
  songs,
}: {
  title: string;
  description: string;
  coverUrl: string;
  songs: SongSummary[];
}) {
  return (
    <div className="mx-auto w-full max-w-3xl px-4 pb-24 pt-8 sm:px-6">
      <div className="flex flex-col items-center gap-5 text-center sm:flex-row sm:items-end sm:text-left">
        {coverUrl ? (
          // eslint-disable-next-line @next/next/no-img-element -- the built-in optimizer already can't handle this project's remote hosts (see next.config.ts)
          <img src={coverUrl} alt="" className="h-40 w-40 shrink-0 rounded-3xl object-cover shadow-lg" />
        ) : (
          <div className="flex h-40 w-40 shrink-0 items-center justify-center rounded-3xl text-white shadow-lg" style={{ background: gradientFor(title) }}>
            <ListMusic size={44} />
          </div>
        )}
        <div className="min-w-0">
          <p className="text-xs font-bold uppercase tracking-[0.2em] text-neutral-400">
            <T k="playlistsShelfTitle" />
          </p>
          <h1 className="mt-1 text-3xl font-extrabold tracking-tight sm:text-4xl">{title}</h1>
          {description && <p className="mt-2 text-neutral-600">{description}</p>}
          <p className="mt-2 text-sm text-neutral-500">
            <SongsCount n={songs.length} />
          </p>
        </div>
      </div>

      {songs.length > 0 && (
        <Link
          href={`/songbook/song/${songs[0].id}`}
          className="mx-auto mt-6 flex h-11 w-fit items-center gap-2 rounded-full bg-black px-6 text-sm font-semibold text-white transition hover:scale-[1.03] sm:mx-0"
        >
          <Play size={15} className="fill-current" /> <T k="playLabel" />
        </Link>
      )}

      <ol className="mt-6 space-y-2.5">
        {songs.length === 0 ? (
          <li className="rounded-3xl border border-dashed border-black/10 px-6 py-14 text-center text-neutral-500">
            <T k="noSongsInPlaylistMessage" />
          </li>
        ) : (
          songs.map((song, i) => (
            <li key={song.id}>
              <Link
                href={`/songbook/song/${song.id}`}
                className="flex items-center gap-3 rounded-3xl border border-black/5 bg-white p-3 pr-4 shadow-[0_2px_16px_-8px_rgba(0,0,0,0.15)] transition hover:shadow-[0_8px_28px_-12px_rgba(0,0,0,0.25)]"
              >
                <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-neutral-100 text-xs font-bold text-neutral-500">{i + 1}</span>
                <span className="min-w-0 flex-1">
                  <span className="block truncate font-semibold text-neutral-900">{song.songName}</span>
                  {(song.band || song.artistNames.length > 0) && <span className="block truncate text-sm text-neutral-500">{displayArtistName(song)}</span>}
                </span>
                {song.key && (
                  <span className="shrink-0 rounded-full bg-blue-50 px-2.5 py-1 text-xs font-bold text-blue-700">
                    {song.key}
                    {song.keyIsMinor ? "m" : ""}
                  </span>
                )}
                <span className="hidden shrink-0 items-center gap-1 text-xs text-neutral-400 sm:flex">
                  <Eye size={13} /> {song.viewCount}
                </span>
              </Link>
            </li>
          ))
        )}
      </ol>
    </div>
  );
}

import Link from "next/link";
import { ListMusic } from "lucide-react";
import { SongsCount, T } from "@/components/LanguageProvider";
import type { PlaylistSummary } from "@/lib/playlists";
import { gradientFor } from "@/lib/palette";

// Same horizontally-scrolling shelf as SongShelf, for admin-curated playlists
// (owner: "ให้ไปแสดงเป็นการ์ด...ที่หน้า Songbook บน Newest Songs") — renders
// nothing when there are no published playlists, same as every other
// content-dependent section on this page.
export default function PlaylistShelf({ playlists }: { playlists: PlaylistSummary[] }) {
  if (playlists.length === 0) return null;
  return (
    <section className="mt-10">
      <h2 className="mb-4 text-xl font-bold tracking-tight sm:text-2xl">
        <T k="playlistsShelfTitle" />
      </h2>
      <div className="-mx-4 flex snap-x scroll-pl-4 gap-4 overflow-x-auto px-4 pb-4 [scrollbar-width:none] sm:mx-0 sm:scroll-pl-0 sm:px-0 [&::-webkit-scrollbar]:hidden">
        {playlists.map((p) => (
          <PlaylistCard key={p.id} playlist={p} />
        ))}
      </div>
    </section>
  );
}

function PlaylistCard({ playlist }: { playlist: PlaylistSummary }) {
  return (
    <Link
      href={`/songbook/playlist/${playlist.id}`}
      className="lift-spring w-44 shrink-0 snap-start overflow-hidden rounded-3xl border border-black/5 bg-white shadow-[0_2px_16px_-8px_rgba(0,0,0,0.15)] transition hover:-translate-y-0.5 hover:shadow-[0_12px_32px_-14px_rgba(0,0,0,0.3)] active:scale-[0.98] active:shadow-[0_2px_10px_-6px_rgba(0,0,0,0.2)] sm:w-52"
    >
      {playlist.coverUrl ? (
        // eslint-disable-next-line @next/next/no-img-element -- a small fixed-size cover; the built-in optimizer already can't handle this project's remote hosts (see next.config.ts)
        <img src={playlist.coverUrl} alt="" className="aspect-square w-full object-cover" />
      ) : (
        <div className="flex aspect-square w-full items-center justify-center text-white" style={{ background: gradientFor(playlist.title || playlist.id) }}>
          <ListMusic size={32} />
        </div>
      )}
      <div className="p-3">
        <p className="line-clamp-2 text-sm font-bold leading-tight text-neutral-900">{playlist.title}</p>
        <p className="mt-1 text-xs text-neutral-500">
          <SongsCount n={playlist.songCount} />
        </p>
      </div>
    </Link>
  );
}

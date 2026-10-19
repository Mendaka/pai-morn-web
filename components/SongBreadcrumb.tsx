"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { ChevronRight } from "lucide-react";
import { useT } from "@/components/LanguageProvider";
import { bandHref } from "@/lib/bands";
import { composerHref } from "@/lib/composers";
import type { Song } from "@/lib/songs";

// Artist/Band card / Composer card -> their profile page -> a song: this
// rebuilds that path on the song page so it's easy to go back up. Band takes
// over from Artist whenever the song has one set — same as the SongBook
// Artists tab (see songEntityIds in lib/catalog.ts), a Band song is only
// ever browsable via its Band's card, never its individual artistIds. Artist
// otherwise shows by default whenever the song has one (useful even without
// a referrer); the composer only takes over when explicitly arrived via
// ?from=composer (added to the composer page's song links) since a song's
// artist and composer are both often set and we can only show one crumb.
export default function SongBreadcrumb({ song }: { song: Song }) {
  const from = useSearchParams().get("from");
  const { t } = useT();

  const crumb =
    from === "composer" && song.songwriter
      ? { href: composerHref(song.songwriter), label: song.songwriter }
      : song.band
        ? { href: bandHref(song.band), label: song.band }
        : song.artistIds[0] && song.artist
          ? { href: `/songbook/artist/${song.artistIds[0]}`, label: song.artist }
          : null;
  if (!crumb) return null;

  return (
    <nav aria-label={t("breadcrumbLabel")} className="no-print mb-2 flex min-w-0 items-center gap-1.5 text-sm text-neutral-500">
      <Link href={crumb.href} className="truncate font-semibold text-neutral-700 hover:text-black hover:underline">
        {crumb.label}
      </Link>
      <ChevronRight size={14} className="shrink-0 text-neutral-300" />
      <span className="shrink-0">{t("songsTitle")}</span>
      <ChevronRight size={14} className="shrink-0 text-neutral-300" />
      <span className="truncate font-semibold text-neutral-700">{song.songName}</span>
    </nav>
  );
}

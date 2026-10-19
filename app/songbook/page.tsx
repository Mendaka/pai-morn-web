import type { Metadata } from "next";
import Link from "next/link";
import { BookOpen, ChevronRight } from "lucide-react";
import { T } from "@/components/LanguageProvider";
import SongBrowser from "@/components/SongBrowser";
import { getCatalog } from "@/lib/catalog";
import { getPublishedPlaylists } from "@/lib/playlists";

// Rendered per request (the catalog read is memoised for 60s in lib/catalog.ts and the
// CDN caches the response briefly, see next.config.ts). ISR on Cloud Functions kept
// serving builds-old pages: new approvals never showed until the next deploy.
export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "SongBook",
  description: "Browse guitar chords and lyrics by artist, category and voice.",
  alternates: { canonical: "/songbook" },
};

export default async function SongBookPage() {
  const [catalog, playlists] = await Promise.all([getCatalog(), getPublishedPlaylists()]);

  return (
    <div className="mx-auto w-full max-w-7xl px-4 pb-20 pt-8 sm:px-6">
      <header className="mb-2">
        <h1 className="bg-gradient-to-r from-indigo-600 to-sky-500 bg-clip-text text-4xl font-extrabold tracking-tight text-transparent sm:text-5xl">
          <T k="songbook" />
        </h1>
        <p className="mt-2 text-neutral-500">
          <T k="songbookSubtitle" vars={{ songs: catalog.songs.length, artists: catalog.artists.length }} />
        </p>
      </header>

      <Link
        href="/book"
        className="group mb-8 flex items-center gap-4 rounded-3xl border border-black/5 bg-gradient-to-r from-indigo-600 to-sky-500 px-5 py-4 text-white shadow-[0_8px_30px_-12px_rgba(79,70,229,0.5)] transition hover:scale-[1.01]"
      >
        <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl bg-white/15">
          <BookOpen size={22} />
        </span>
        <span className="min-w-0 flex-1">
          <span className="block font-bold leading-tight">
            <T k="bookModeLabel" />
          </span>
          <span className="block truncate text-sm text-white/80">
            <T k="bookModeSubtitle" />
          </span>
        </span>
        <ChevronRight size={20} className="shrink-0 transition group-hover:translate-x-1" />
      </Link>

      <SongBrowser catalog={catalog} playlists={playlists} />

      <p className="mt-12 rounded-3xl border border-black/5 bg-neutral-50 px-6 py-5 text-center text-neutral-600">
        <T k="cantFindSongPrompt" />{" "}
        <Link href="/request-song" className="font-semibold text-blue-600 hover:underline">
          <T k="requestSongLabel" />
        </Link>
      </p>
    </div>
  );
}

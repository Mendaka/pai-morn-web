import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { Eye, Music2 } from "lucide-react";
import { SongsCount, T } from "@/components/LanguageProvider";
import { ComposerAvatar } from "@/components/ComposerCard";
import Reveal from "@/components/Reveal";
import SongCard from "@/components/SongCard";
import { getCatalog } from "@/lib/catalog";
import { gradientFor } from "@/lib/palette";

export const dynamic = "force-dynamic";

async function loadComposer(rawName: string) {
  const name = decodeURIComponent(rawName).trim();
  if (!name) return null;
  const { songs } = await getCatalog();
  const composerSongs = songs
    .filter((s) => s.songwriter === name)
    .sort((a, b) => b.viewCount - a.viewCount || b.approvedAt - a.approvedAt);
  if (composerSongs.length === 0) return null;
  return { name, songs: composerSongs };
}

export async function generateMetadata(props: PageProps<"/songbook/composer/[name]">): Promise<Metadata> {
  const { name: rawName } = await props.params;
  const data = await loadComposer(rawName);
  if (!data) return { title: "Composer not found" };

  const { name, songs } = data;
  const description = `Guitar chords and lyrics for ${songs.length} song${songs.length === 1 ? "" : "s"} written by ${name}.`;
  return {
    title: name,
    description,
    alternates: { canonical: `/songbook/composer/${encodeURIComponent(name)}` },
    openGraph: {
      title: name,
      description,
      type: "profile",
      url: `/songbook/composer/${encodeURIComponent(name)}`,
      images: [{ url: "/site-card.png", width: 1200, height: 630 }],
    },
    twitter: { card: "summary_large_image", title: name, description, images: ["/site-card.png"] },
  };
}

export default async function ComposerPage(props: PageProps<"/songbook/composer/[name]">) {
  const { name: rawName } = await props.params;
  const data = await loadComposer(rawName);
  if (!data) notFound();
  const { name, songs } = data;
  const totalViews = songs.reduce((sum, s) => sum + s.viewCount, 0);

  const jsonLd = JSON.stringify({
    "@context": "https://schema.org",
    "@type": "Person",
    name,
  }).replace(/</g, "\\u003c");

  return (
    <div className="mx-auto w-full max-w-6xl px-4 pb-20 pt-6 sm:px-6">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: jsonLd }} />

      <header className="relative overflow-hidden rounded-3xl p-7 text-white sm:p-10" style={{ background: gradientFor(name) }}>
        <div className="pointer-events-none absolute -right-20 -top-24 h-72 w-72 rounded-full bg-white/15 blur-3xl" />
        <div className="pointer-events-none absolute -bottom-28 left-1/3 h-64 w-64 rounded-full bg-black/15 blur-3xl" />
        <div className="relative flex flex-col items-center gap-6 text-center sm:flex-row sm:text-left">
          <ComposerAvatar name={name} size={132} className="ring-4 ring-white/70 shadow-2xl" />
          <div className="min-w-0">
            <p className="text-xs font-semibold uppercase tracking-[0.2em] text-white/70">
              <T k="songwriterRole" />
            </p>
            <h1 className="mt-1 text-3xl font-extrabold leading-tight tracking-tight sm:text-5xl">{name}</h1>
            <div className="mt-4 flex flex-wrap justify-center gap-2 text-sm font-medium sm:justify-start">
              <span className="flex items-center gap-1.5 rounded-full bg-white/20 px-3.5 py-1.5 backdrop-blur">
                <Music2 size={15} /> <SongsCount n={songs.length} />
              </span>
              <span className="flex items-center gap-1.5 rounded-full bg-white/20 px-3.5 py-1.5 backdrop-blur">
                <Eye size={15} /> <T k="viewsCount" vars={{ count: totalViews.toLocaleString() }} />
              </span>
            </div>
          </div>
        </div>
      </header>

      <h2 className="mb-5 mt-10 text-2xl font-bold tracking-tight">
        <T k="songsTitle" />
      </h2>
      <Reveal stagger className="grid grid-cols-2 gap-x-4 gap-y-7 sm:grid-cols-3 lg:grid-cols-4">
        {songs.map((s, i) => (
          <SongCard key={s.id} song={s} query="?from=composer" style={{ ["--i" as string]: i }} />
        ))}
      </Reveal>
    </div>
  );
}

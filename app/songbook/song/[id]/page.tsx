import type { Metadata } from "next";
import { notFound } from "next/navigation";
import SongReader from "@/components/SongReader";
import { getApprovedSong } from "@/lib/songs";

// Per request: edits and view counts show up within the CDN's short cache (next.config.ts).
export const dynamic = "force-dynamic";

export async function generateMetadata(
  props: PageProps<"/songbook/song/[id]">,
): Promise<Metadata> {
  const { id } = await props.params;
  const song = await getApprovedSong(id);
  if (!song) return { title: "Song not found" };

  const title = song.artist ? `${song.songName} — ${song.artist}` : song.songName;
  const description = `Chords and lyrics for "${song.songName}"${
    song.artist ? ` by ${song.artist}` : ""
  }${song.key ? `, in the key of ${song.key}${song.keyIsMinor ? "m" : ""}` : ""}.`;

  return {
    title,
    description,
    alternates: { canonical: `/songbook/song/${song.id}` },
    // The 1200x630 share card comes from the songCard Cloud Function (kept as-is,
    // same URL the Flutter site used) — this is what Facebook/Line/Twitter show.
    openGraph: {
      title,
      description,
      type: "website",
      url: `/songbook/song/${song.id}`,
      images: [{ url: `/songbook/song-card/${song.id}.png`, width: 1200, height: 630, alt: title }],
    },
    twitter: { card: "summary_large_image", title, description, images: [`/songbook/song-card/${song.id}.png`] },
  };
}

export default async function SongPage(props: PageProps<"/songbook/song/[id]">) {
  const { id } = await props.params;
  const song = await getApprovedSong(id);
  if (!song) notFound();

  // Structured data crawlers read directly. `<` is escaped so lyric/title
  // text can never close the script tag early.
  const jsonLd = JSON.stringify({
    "@context": "https://schema.org",
    "@type": "MusicComposition",
    name: song.songName,
    ...(song.songwriter ? { composer: { "@type": "Person", name: song.songwriter } } : {}),
    ...(song.category ? { genre: song.category } : {}),
  }).replace(/</g, "\\u003c");

  return (
    <>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: jsonLd }} />
      <SongReader song={song} />
    </>
  );
}

import type { Metadata } from "next";
import { notFound } from "next/navigation";
import PlaylistView from "@/components/PlaylistView";
import { getCatalog } from "@/lib/catalog";
import { getPlaylist } from "@/lib/playlists";
import { SITE_URL } from "@/lib/site";

// Rendered per request, same reasoning as every other catalog-reading page
// (next.config.ts's CDN cache keeps this cheap): a playlist's song list, or
// its published flag, can change at any time from the admin editor.
export const dynamic = "force-dynamic";

export async function generateMetadata(props: PageProps<"/songbook/playlist/[id]">): Promise<Metadata> {
  const { id } = await props.params;
  const playlist = await getPlaylist(id);
  if (!playlist) return { title: "Playlist not found" };

  const description = playlist.description || `A collection of ${playlist.songIds.length} songs on Paimorn.`;
  return {
    title: playlist.title,
    description,
    alternates: { canonical: `/songbook/playlist/${playlist.id}` },
    openGraph: {
      title: playlist.title,
      description,
      type: "website",
      url: `/songbook/playlist/${playlist.id}`,
      images: [{ url: playlist.coverUrl || `${SITE_URL}/site-card.png`, width: playlist.coverUrl ? undefined : 1200, height: playlist.coverUrl ? undefined : 630 }],
    },
  };
}

export default async function PlaylistPage(props: PageProps<"/songbook/playlist/[id]">) {
  const { id } = await props.params;
  const [playlist, { songs }] = await Promise.all([getPlaylist(id), getCatalog()]);
  if (!playlist) notFound();

  const byId = new Map(songs.map((s) => [s.id, s]));
  const rows = playlist.songIds.map((songId) => byId.get(songId)).filter((s) => s !== undefined);

  return <PlaylistView title={playlist.title} description={playlist.description} coverUrl={playlist.coverUrl} songs={rows} />;
}

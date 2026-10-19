import type { Metadata } from "next";
import PlaylistEditorView from "@/components/admin/PlaylistEditorView";

export const metadata: Metadata = { title: "Edit playlist", robots: { index: false } };

export default async function Page(props: PageProps<"/admin/playlists/[id]">) {
  const { id } = await props.params;
  return <PlaylistEditorView playlistId={id} />;
}

import type { Metadata } from "next";
import PublicSetlistView from "@/components/PublicSetlistView";

// Shared with a link, not meant to be found through search.
export const metadata: Metadata = { title: "Setlist", robots: { index: false } };

export default async function SharedSetlistPage(props: PageProps<"/setlists/shared/[uid]/[id]">) {
  const { uid, id } = await props.params;
  return <PublicSetlistView uid={uid} setlistId={id} />;
}

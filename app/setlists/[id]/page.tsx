import type { Metadata } from "next";
import SetlistDetailView from "@/components/SetlistDetailView";

export const metadata: Metadata = { title: "Setlist", robots: { index: false } };

export default async function SetlistPage(props: PageProps<"/setlists/[id]">) {
  const { id } = await props.params;
  return <SetlistDetailView setlistId={id} />;
}

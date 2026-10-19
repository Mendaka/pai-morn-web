import type { Metadata } from "next";
import SetlistsView from "@/components/SetlistsView";

export const metadata: Metadata = { title: "Setlists", robots: { index: false } };

export default function SetlistsPage() {
  return <SetlistsView />;
}

import type { Metadata } from "next";
import MySongsView from "@/components/MySongsView";

export const metadata: Metadata = { title: "My songs", robots: { index: false } };

export default function MySongsPage() {
  return <MySongsView />;
}

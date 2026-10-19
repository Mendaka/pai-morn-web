import type { Metadata } from "next";
import FavoritesView from "@/components/FavoritesView";

export const metadata: Metadata = { title: "Favorites", robots: { index: false } };

export default function FavoritesPage() {
  return <FavoritesView />;
}

import type { Metadata } from "next";
import BookReader from "@/components/BookReader";
import { T } from "@/components/LanguageProvider";
import { getCatalog } from "@/lib/catalog";

// Book mode is entirely client-driven (react-pageflip, windowed lyric
// fetching) — this route just seeds the ordered id/title/artist list, the
// same lightweight shape getCatalog() already provides for every other list
// page (no lyrics fetched here; see lib/use-book-window.ts).
export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Book Mode",
  description: "Flip through every song like a real book — swipe on phone and tablet, or use the buttons on desktop.",
  alternates: { canonical: "/book" },
};

export default async function BookPageRoute() {
  const { songs } = await getCatalog();
  const ordered = [...songs].sort((a, b) => b.approvedAt - a.approvedAt);
  const stubs = ordered.map((s) => ({ id: s.id, songName: s.songName, artistNames: s.artistNames, band: s.band }));

  return (
    <div className="book-page-shell mx-auto w-full max-w-7xl px-4 pb-20 pt-8 sm:px-6">
      <header className="mb-8 text-center">
        <h1 className="bg-gradient-to-r from-indigo-600 to-sky-500 bg-clip-text text-4xl font-extrabold tracking-tight text-transparent sm:text-5xl">
          <T k="bookModeLabel" />
        </h1>
        <p className="mx-auto mt-2 max-w-xl text-neutral-500">
          <T k="bookModeSubtitle" />
        </p>
      </header>
      <BookReader songs={stubs} />
    </div>
  );
}

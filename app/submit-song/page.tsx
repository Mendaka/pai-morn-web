import type { Metadata } from "next";
import { Suspense } from "react";
import SubmitSongView from "@/components/SubmitSongView";
import { getCatalog } from "@/lib/catalog";

export const metadata: Metadata = { title: "Submit a song", robots: { index: false } };
export const dynamic = "force-dynamic";

export default async function SubmitSongPage() {
  // Existing songs feed the form's suggestions (duplicate spotting, band and
  // category spellings) — read once on the server, no client-side scan.
  const { songs } = await getCatalog();
  const options = {
    songs: songs.map((s) => ({ name: s.songName, artist: s.artistNames.join(" & ") })),
    bands: [...new Set(songs.map((s) => s.band).filter(Boolean))],
    categories: [...new Set(songs.map((s) => s.category).filter(Boolean))],
    genders: [...new Set(songs.map((s) => s.gender).filter(Boolean))],
  };
  return (
    // useSearchParams (?edit=) needs Suspense on a statically rendered page.
    <Suspense>
      <SubmitSongView options={options} />
    </Suspense>
  );
}

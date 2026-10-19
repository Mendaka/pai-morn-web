import Link from "next/link";
import { ArrowRight } from "lucide-react";
import { T } from "@/components/LanguageProvider";
import SongCard from "@/components/SongCard";
import type { SongSummary } from "@/lib/catalog";

// Horizontally scrolling row of song cards (snap-scroll, no visible bar).
export default function SongShelf({
  title,
  songs,
  href,
}: {
  title: React.ReactNode;
  songs: SongSummary[];
  href?: string;
}) {
  return (
    <section className="mt-10">
      <div className="mb-4 flex items-end justify-between gap-4">
        <h2 className="text-xl font-bold tracking-tight sm:text-2xl">{title}</h2>
        {href && (
          <Link href={href} className="flex items-center gap-1 text-sm font-semibold text-blue-600 hover:gap-2">
            <T k="seeAll" /> <ArrowRight size={15} />
          </Link>
        )}
      </div>
      <div className="-mx-4 flex snap-x scroll-pl-4 gap-4 overflow-x-auto px-4 pb-4 [scrollbar-width:none] sm:mx-0 sm:scroll-pl-0 sm:px-0 [&::-webkit-scrollbar]:hidden">
        {songs.map((s) => (
          <SongCard key={s.id} song={s} className="w-52 shrink-0 snap-start sm:w-60" />
        ))}
      </div>
    </section>
  );
}

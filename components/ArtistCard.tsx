import Image from "next/image";
import { SongsCount } from "@/components/LanguageProvider";
import Link from "next/link";
import { Mic2 } from "lucide-react";
import type { ArtistSummary } from "@/lib/catalog";
import { gradientFor } from "@/lib/palette";

// A Latin initial for names like "K Soe Lay"; null for everything else.
// Shan names almost all start with the same honorific-style prefix, so an
// "initial" there would make every avatar look identical — those get a mic
// icon instead.
function latinInitial(name: string): string | null {
  const first = name.trim().charAt(0);
  return /^[A-Za-z]$/.test(first) ? first.toUpperCase() : null;
}

export function ArtistAvatar({
  artist,
  size = 72,
  className = "",
}: {
  artist: Pick<ArtistSummary, "id" | "name" | "photoUrl">;
  size?: number;
  className?: string;
}) {
  return (
    <div
      className={`relative shrink-0 overflow-hidden rounded-full ${className}`}
      style={{ width: size, height: size, background: gradientFor(artist.id) }}
    >
      {artist.photoUrl ? (
        <Image src={artist.photoUrl} alt="" fill sizes={`${size}px`} className="object-cover" />
      ) : (
        <span
          className="absolute inset-0 flex items-center justify-center font-bold text-white/95"
          style={{ fontSize: size * 0.42 }}
        >
          {latinInitial(artist.name) ?? <Mic2 size={size * 0.42} strokeWidth={2} />}
        </span>
      )}
    </div>
  );
}

export default function ArtistCard({ artist, count, style }: { artist: ArtistSummary; count?: number; style?: React.CSSProperties }) {
  const songCount = count ?? artist.songCount;
  return (
    <Link
      href={`/songbook/artist/${artist.id}`}
      style={style}
      className="lift-spring group flex flex-col items-center rounded-3xl border border-black/5 bg-neutral-100 p-5 text-center shadow-[0_2px_16px_-8px_rgba(0,0,0,0.15)] transition duration-300 hover:-translate-y-1 hover:shadow-[0_18px_36px_-14px_rgba(37,99,235,0.35)] active:scale-[0.98] active:shadow-[0_2px_10px_-6px_rgba(0,0,0,0.2)]"
    >
      <ArtistAvatar artist={artist} size={84} className="ring-4 ring-white shadow-lg transition duration-300 group-hover:scale-105" />
      <h3 className="mt-3.5 line-clamp-2 min-h-[2.75rem] text-[15px] font-semibold leading-snug text-neutral-900">
        {artist.name}
      </h3>
      <p className="mt-1 text-xs font-medium text-neutral-500">
        <SongsCount n={songCount} />
      </p>
    </Link>
  );
}

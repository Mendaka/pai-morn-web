import Image from "next/image";
import Link from "next/link";
import { Eye, Music2 } from "lucide-react";
import EditSongButton from "@/components/EditSongButton";
import { displayArtistName, type SongSummary } from "@/lib/catalog";
import { gradientFor } from "@/lib/palette";
import { youtubeThumbnail } from "@/lib/youtube";

// Cover = the YouTube thumbnail of the song's linked video; songs without a
// video get a deterministic gradient so they still read as distinct cards.
export default function SongCard({
  song,
  className = "",
  query = "",
  style,
}: {
  song: SongSummary;
  className?: string;
  query?: string;
  style?: React.CSSProperties;
}) {
  return (
    <div className={`relative ${className}`} style={style}>
    <Link href={`/songbook/song/${song.id}${query}`} className="group block rounded-2xl outline-offset-4">
      <div
        className="lift-spring relative aspect-video overflow-hidden rounded-2xl shadow-[0_6px_20px_-8px_rgba(0,0,0,0.35)] transition duration-300 group-hover:-translate-y-0.5 group-hover:shadow-[0_14px_30px_-10px_rgba(0,0,0,0.4)] group-active:scale-[0.98] group-active:shadow-[0_3px_10px_-6px_rgba(0,0,0,0.3)]"
        style={{ background: gradientFor(song.id) }}
      >
        {song.youtubeId ? (
          <Image
            src={youtubeThumbnail(song.youtubeId)}
            alt=""
            fill
            sizes="(min-width: 1024px) 260px, 60vw"
            className="object-cover transition duration-500 group-hover:scale-105"
          />
        ) : (
          <Music2 className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 text-white/70" size={34} />
        )}
        <div className="absolute inset-x-0 bottom-0 h-1/2 bg-gradient-to-t from-black/55 to-transparent" />
        {song.key && (
          <span className="keep-light absolute bottom-2 left-2 rounded-full bg-white/90 px-2 py-0.5 text-[11px] font-bold text-neutral-800">
            {song.key}
            {song.keyIsMinor ? "m" : ""}
          </span>
        )}
        <span className="absolute bottom-2 right-2 flex items-center gap-1 text-[11px] font-medium text-white/90">
          <Eye size={12} /> {song.viewCount}
        </span>
      </div>
      <h3 className="mt-2.5 line-clamp-1 text-[15px] font-semibold leading-snug text-neutral-900">
        {song.songName}
      </h3>
      <p className="line-clamp-1 text-sm text-neutral-500">{displayArtistName(song)}</p>
    </Link>
    <EditSongButton songId={song.id} variant="cover" />
    </div>
  );
}

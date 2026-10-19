import Image from "next/image";
import { UserRound } from "lucide-react";
import { gradientFor } from "@/lib/palette";

// First user-perceived character (a Myanmar/Shan syllable can be a consonant
// plus combining marks, so slice by grapheme rather than by code unit).
function firstGrapheme(name: string): string | null {
  const trimmed = name.trim();
  if (!trimmed) return null;
  const first = new Intl.Segmenter(undefined, { granularity: "grapheme" }).segment(trimmed)[Symbol.iterator]().next().value;
  return first ? first.segment.toUpperCase() : null;
}

export default function UserAvatar({
  uid,
  name,
  photoUrl,
  size = 40,
  className = "",
}: {
  uid: string;
  name: string;
  photoUrl?: string;
  size?: number;
  className?: string;
}) {
  const initial = firstGrapheme(name);
  return (
    <div
      className={`relative shrink-0 overflow-hidden rounded-full ${className}`}
      style={{ width: size, height: size, background: gradientFor(uid) }}
    >
      {photoUrl ? (
        <Image src={photoUrl} alt="" fill sizes={`${size}px`} className="object-cover" />
      ) : (
        <span
          className="absolute inset-0 flex items-center justify-center font-bold text-white"
          style={{ fontSize: size * 0.42 }}
        >
          {initial ?? <UserRound size={size * 0.5} />}
        </span>
      )}
    </div>
  );
}

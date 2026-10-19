import Link from "next/link";
import { PenLine } from "lucide-react";
import { SongsCount } from "@/components/LanguageProvider";
import type { ComposerSummary } from "@/lib/composers";
import { composerHref } from "@/lib/composers";
import { gradientFor } from "@/lib/palette";

export function ComposerAvatar({ name, size = 72, className = "" }: { name: string; size?: number; className?: string }) {
  return (
    <div
      className={`relative flex shrink-0 items-center justify-center overflow-hidden rounded-full text-white/95 ${className}`}
      style={{ width: size, height: size, background: gradientFor(name) }}
    >
      <PenLine size={size * 0.4} strokeWidth={2} />
    </div>
  );
}

export default function ComposerCard({ composer, style }: { composer: ComposerSummary; style?: React.CSSProperties }) {
  return (
    <Link
      href={composerHref(composer.name)}
      style={style}
      className="lift-spring group flex flex-col items-center rounded-3xl border border-black/5 bg-neutral-100 p-5 text-center shadow-[0_2px_16px_-8px_rgba(0,0,0,0.15)] transition duration-300 hover:-translate-y-1 hover:shadow-[0_18px_36px_-14px_rgba(37,99,235,0.35)] active:scale-[0.98] active:shadow-[0_2px_10px_-6px_rgba(0,0,0,0.2)]"
    >
      <ComposerAvatar name={composer.name} size={84} className="ring-4 ring-white shadow-lg transition duration-300 group-hover:scale-105" />
      <h3 className="mt-3.5 line-clamp-2 min-h-[2.75rem] text-[15px] font-semibold leading-snug text-neutral-900">
        {composer.name}
      </h3>
      <p className="mt-1 text-xs font-medium text-neutral-500">
        <SongsCount n={composer.songCount} />
      </p>
    </Link>
  );
}

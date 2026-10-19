"use client";

import { useMemo, useState, useSyncExternalStore } from "react";
import Link from "next/link";
import { Check, Share2 } from "lucide-react";
import { useT } from "@/components/LanguageProvider";
import { SITE_URL } from "@/lib/site";

export type NewSong = { id: string; name: string; artist: string; approvedAt: number };

// "Today" is pinned to a fixed UTC+7 day, not the viewer's timezone — the same
// rule as the dailyUpdateCard / dailyUpdatePreview Cloud Functions, so the
// shared link's preview image and this card always agree on the count.
const DAY_OFFSET_MS = 7 * 3_600_000;
const startOfAppDay = (label: string) => Date.parse(`${label}T00:00:00Z`) - DAY_OFFSET_MS;
const dayLabel = (now: number) => new Date(now + DAY_OFFSET_MS).toISOString().slice(0, 10);


// Home highlight: "New Chords Today", the newest few songs and a Share button.
// Renders nothing until hydrated (the day is the viewer's clock, and the page
// itself is cached ISR HTML), and nothing at all when today has no new songs.
export default function TodaysNewSongs({ songs }: { songs: NewSong[] }) {
  const { t } = useT();
  const day = useSyncExternalStore(
    () => () => {},
    () => dayLabel(Date.now()),
    () => "",
  );
  const [copied, setCopied] = useState(false);

  const today = useMemo(() => {
    if (!day) return [];
    const start = startOfAppDay(day);
    return songs.filter((s) => s.approvedAt >= start).sort((a, b) => b.approvedAt - a.approvedAt);
  }, [songs, day]);

  if (today.length === 0) return null;

  async function share() {
    // ?d=<today> makes the URL new each day so link-preview crawlers re-scrape
    // instead of replaying whatever they cached the first time it was shared.
    // Home for now. The daily preview card (/daily-update, dailyUpdatePreview) still
    // hands real visitors the old Flutter shell, so it can't be linked from this site
    // until that function is made host-aware (see CLAUDE.md).
    const url = `${SITE_URL}/?d=${day}`;
    try {
      if (navigator.share) {
        await navigator.share({ url });
        return;
      }
    } catch (e) {
      if (e instanceof DOMException && e.name === "AbortError") return; // user closed the sheet
    }
    try {
      await navigator.clipboard.writeText(url);
      setCopied(true);
      setTimeout(() => setCopied(false), 2500);
    } catch {
      // clipboard denied: nothing more to do
    }
  }

  return (
    <section className="relative mt-10 overflow-hidden rounded-[2rem] bg-neutral-950 px-6 py-8 text-white sm:px-10">
      <div className="pointer-events-none absolute -left-16 -top-20 h-64 w-64 rounded-full bg-indigo-500/40 blur-3xl" />
      <div className="pointer-events-none absolute -bottom-24 right-0 h-72 w-72 rounded-full bg-sky-500/35 blur-3xl" />
      <div className="pointer-events-none absolute right-1/4 top-0 h-40 w-40 rounded-full bg-fuchsia-500/25 blur-3xl" />
      <div className="relative flex flex-col gap-6 sm:flex-row sm:items-center sm:justify-between">
        <div className="min-w-0">
          <h2 className="text-xl font-extrabold tracking-tight sm:text-2xl">{t("todayNewSongsLabel")}</h2>
          <ul className="mt-3 space-y-1.5">
            {today.map((s) => (
              <li key={s.id} className="truncate">
                <Link href={`/songbook/song/${s.id}`} className="transition hover:text-white/70">
                  {s.artist ? `${s.name} — ${s.artist}` : s.name}
                </Link>
              </li>
            ))}
          </ul>
        </div>
        <button
          type="button"
          onClick={share}
          className="keep-light inline-flex h-12 shrink-0 items-center justify-center gap-2 self-start rounded-full bg-white px-6 text-sm font-bold text-indigo-700 shadow-lg transition hover:scale-[1.04] sm:self-center"
        >
          {copied ? <Check size={17} /> : <Share2 size={17} />}
          {copied ? t("linkCopiedMessage") : t("shareButtonLabel")}
        </button>
      </div>
    </section>
  );
}

"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { doc, getDoc } from "firebase/firestore";
import { ChevronLeft, ChevronRight, ListChecks } from "lucide-react";
import { useAuth } from "@/components/AuthProvider";
import { useT } from "@/components/LanguageProvider";
import { db } from "@/lib/firebase/client";

// When a song is opened from one of the reader's own setlists
// (?setlist=<id>), a strip with Previous / Next through that list's order.
// Read once — a setlist changing under someone mid-song is rare. Anyone who
// can't read the list (not the owner) simply sees no strip.
export default function SetlistNav({ songId }: { songId: string }) {
  const setlistId = useSearchParams().get("setlist");
  const { user } = useAuth();
  const { t } = useT();
  const uid = user?.uid;
  const [list, setList] = useState<{ id: string; name: string; ids: string[] } | null>(null);

  useEffect(() => {
    if (!uid || !setlistId) return;
    let alive = true;
    getDoc(doc(db, "users", uid, "setlists", setlistId))
      .then((snap) => {
        if (!alive || !snap.exists()) return;
        const d = snap.data();
        setList({ id: setlistId, name: typeof d.name === "string" ? d.name : "", ids: Array.isArray(d.songIds) ? d.songIds.filter((x: unknown): x is string => typeof x === "string") : [] });
      })
      .catch(() => {});
    return () => {
      alive = false;
    };
  }, [uid, setlistId]);

  if (!list || list.id !== setlistId) return null;
  const index = list.ids.indexOf(songId);
  if (index === -1) return null;

  const go = (i: number) => `/songbook/song/${list.ids[i]}?setlist=${list.id}`;
  const cls = "flex h-10 items-center gap-1 rounded-full px-4 text-sm font-semibold transition";
  return (
    <nav aria-label={t("setlistNavLabel")} className="no-print mt-5 flex items-center justify-between gap-3 rounded-2xl border border-emerald-600/15 bg-emerald-50 px-3 py-2">
      {index > 0 ? (
        // replace, not push: stepping through a set shouldn't stack ten history entries
        <Link href={go(index - 1)} replace className={`${cls} bg-white text-emerald-700 shadow-sm hover:bg-emerald-100`} aria-label={t("previousSongTooltip")}>
          <ChevronLeft size={18} /> <span className="hidden sm:inline">{t("previousSongTooltip")}</span>
        </Link>
      ) : (
        <span className={`${cls} text-emerald-700/30`}>
          <ChevronLeft size={18} />
        </span>
      )}
      <Link href={`/setlists/${list.id}`} className="flex min-w-0 items-center gap-2 text-sm font-semibold text-emerald-800">
        <ListChecks size={16} className="shrink-0" />
        <span className="truncate">{list.name}</span>
        <span className="shrink-0 font-medium text-emerald-700/70">{t("setlistPosition", { n: index + 1, total: list.ids.length })}</span>
      </Link>
      {index < list.ids.length - 1 ? (
        <Link href={go(index + 1)} replace className={`${cls} bg-white text-emerald-700 shadow-sm hover:bg-emerald-100`} aria-label={t("nextSongTooltip")}>
          <span className="hidden sm:inline">{t("nextSongTooltip")}</span> <ChevronRight size={18} />
        </Link>
      ) : (
        <span className={`${cls} text-emerald-700/30`}>
          <ChevronRight size={18} />
        </span>
      )}
    </nav>
  );
}

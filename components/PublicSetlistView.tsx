"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { doc, getDoc } from "firebase/firestore";
import { ListChecks, Play } from "lucide-react";
import { useT } from "@/components/LanguageProvider";
import { db } from "@/lib/firebase/client";
import { useSongsIndex } from "@/lib/songs-index";

type Loaded = { name: string; ids: string[]; owner: string } | "missing" | null;

// A setlist its owner has shared: readable without an account (firestore.rules
// allows it once the owner sets `public: true`). Read-only — names, play, and
// links into the normal song pages.
export default function PublicSetlistView({ uid, setlistId }: { uid: string; setlistId: string }) {
  const { t } = useT();
  const { byId } = useSongsIndex();
  const [data, setData] = useState<Loaded>(null);

  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const snap = await getDoc(doc(db, "users", uid, "setlists", setlistId));
        // A private setlist is rejected by the rules (permission-denied), which lands in the catch.
        if (!snap.exists() || snap.data().public !== true) return alive && setData("missing");
        const d = snap.data();
        const owner = await getDoc(doc(db, "users", uid)).then((o) => (typeof o.data()?.displayName === "string" ? (o.data()!.displayName as string) : "")).catch(() => "");
        if (alive)
          setData({
            name: typeof d.name === "string" ? d.name : "",
            ids: Array.isArray(d.songIds) ? d.songIds.filter((x: unknown): x is string => typeof x === "string") : [],
            owner,
          });
      } catch {
        if (alive) setData("missing");
      }
    })();
    return () => {
      alive = false;
    };
  }, [uid, setlistId]);

  if (data === null) {
    return (
      <div className="mx-auto max-w-3xl px-4 py-10">
        <div className="h-10 w-64 animate-pulse rounded-xl bg-black/5" />
        <div className="mt-6 h-64 animate-pulse rounded-3xl bg-black/5" />
      </div>
    );
  }
  if (data === "missing") {
    return (
      <div className="mx-auto flex max-w-md flex-col items-center px-4 py-24 text-center">
        <ListChecks size={44} className="text-neutral-300" />
        <p className="mt-4 text-neutral-600">{t("setlistNotFoundMessage")}</p>
        <Link href="/songbook" className="mt-8 flex h-11 items-center rounded-full bg-black px-6 text-sm font-semibold text-white">
          {t("songbook")}
        </Link>
      </div>
    );
  }

  const rows = data.ids.map((id) => ({ id, song: byId.get(id) })).filter((r) => r.song);
  return (
    <div className="mx-auto w-full max-w-3xl px-4 pb-24 pt-8 sm:px-6">
      <h1 className="flex items-center gap-3 text-3xl font-extrabold tracking-tight">
        <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl bg-gradient-to-br from-emerald-500 to-teal-500 text-white shadow-lg">
          <ListChecks size={22} />
        </span>
        <span className="truncate">{data.name}</span>
      </h1>
      {data.owner && (
        <p className="mt-2 text-sm text-neutral-500">
          {t("sharedByLabel")}: {data.owner}
        </p>
      )}
      {rows.length > 0 && (
        <Link
          href={`/songbook/song/${rows[0].id}`}
          className="mt-6 inline-flex h-11 items-center gap-2 rounded-full bg-black px-6 text-sm font-semibold text-white transition hover:scale-[1.03]"
        >
          <Play size={15} className="fill-current" /> {t("playLabel")}
        </Link>
      )}
      <ol className="mt-6 space-y-2.5">
        {rows.length === 0 ? (
          <li className="rounded-3xl border border-dashed border-black/10 px-6 py-14 text-center text-neutral-500">{t("noSongsInSetlistMessage")}</li>
        ) : (
          rows.map(({ id, song }, i) => (
            <li key={id}>
              <Link href={`/songbook/song/${id}`} className="flex items-center gap-3 rounded-3xl border border-black/5 bg-white p-3 pr-4 shadow-[0_2px_16px_-8px_rgba(0,0,0,0.15)] transition hover:shadow-[0_8px_28px_-12px_rgba(0,0,0,0.25)]">
                <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-neutral-100 text-xs font-bold text-neutral-500">{i + 1}</span>
                <span className="min-w-0">
                  <span className="block truncate font-semibold text-neutral-900">{song!.name}</span>
                  {song!.artist && <span className="block truncate text-sm text-neutral-500">{song!.artist}</span>}
                </span>
              </Link>
            </li>
          ))
        )}
      </ol>
    </div>
  );
}

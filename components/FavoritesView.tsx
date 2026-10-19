"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { collection, doc, onSnapshot, orderBy, query } from "firebase/firestore";
import { Heart, Music2 } from "lucide-react";
import FavoriteButton from "@/components/FavoriteButton";
import { useT } from "@/components/LanguageProvider";
import { db } from "@/lib/firebase/client";
import { gradientFor } from "@/lib/palette";
import { useRequireAuth } from "@/lib/use-require-auth";

type Row = { id: string; songName: string; artist: string };

export default function FavoritesView() {
  const user = useRequireAuth("/favorites");
  const { t } = useT();
  const uid = user?.uid;
  const [ids, setIds] = useState<string[] | null>(null);
  const [songs, setSongs] = useState<Record<string, Row | null>>({});

  // Newest-favorited first.
  useEffect(() => {
    if (!uid) return;
    const q = query(collection(db, "users", uid, "favorites"), orderBy("addedAt", "desc"));
    return onSnapshot(q, (snap) => setIds(snap.docs.map((d) => d.id)));
  }, [uid]);

  // One live listener per favorited song; a deleted/unapproved song simply drops out.
  const key = ids?.join(",") ?? "";
  useEffect(() => {
    if (!key) return;
    const unsubs = key.split(",").map((id) =>
      onSnapshot(doc(db, "songs", id), (snap) => {
        const d = snap.data();
        const visible = snap.exists() && d?.status === "approved";
        setSongs((prev) => ({
          ...prev,
          [id]: visible ? { id, songName: String(d?.songName ?? ""), artist: String(d?.artist ?? "") } : null,
        }));
      }),
    );
    return () => unsubs.forEach((u) => u());
  }, [key]);

  const rows = (ids ?? []).map((id) => songs[id]).filter((r): r is Row => !!r);

  return (
    <div className="mx-auto w-full max-w-3xl px-4 pb-20 pt-8 sm:px-6">
      <h1 className="flex items-center gap-3 text-3xl font-extrabold tracking-tight">
        <span className="flex h-11 w-11 items-center justify-center rounded-2xl bg-gradient-to-br from-rose-500 to-pink-500 text-white shadow-lg">
          <Heart size={22} className="fill-current" />
        </span>
        {t("favoritesTitle")}
      </h1>

      <div className="mt-8 space-y-3">
        {ids === null ? (
          [0, 1, 2].map((i) => <div key={i} className="h-20 animate-pulse rounded-3xl bg-black/5" />)
        ) : ids.length === 0 ? (
          <div className="flex flex-col items-center rounded-3xl border border-dashed border-black/10 px-6 py-16 text-center text-neutral-500">
            <Heart size={40} className="text-neutral-300" />
            <p className="mt-4 max-w-xs">{t("noFavoritesYet")}</p>
          </div>
        ) : (
          rows.map((r) => (
            <div
              key={r.id}
              className="flex items-center gap-4 rounded-3xl border border-black/5 bg-white p-3 pr-4 shadow-[0_2px_16px_-8px_rgba(0,0,0,0.15)] transition hover:shadow-[0_8px_28px_-12px_rgba(0,0,0,0.25)]"
            >
              <Link href={`/songbook/song/${r.id}`} className="flex min-w-0 flex-1 items-center gap-4">
                <span
                  className="flex h-14 w-14 shrink-0 items-center justify-center rounded-2xl text-white"
                  style={{ background: gradientFor(r.artist || r.songName) }}
                >
                  <Music2 size={22} />
                </span>
                <span className="min-w-0">
                  <span className="block truncate font-semibold text-neutral-900">{r.songName}</span>
                  {r.artist && <span className="block truncate text-sm text-neutral-500">{r.artist}</span>}
                </span>
              </Link>
              <FavoriteButton songId={r.id} />
            </div>
          ))
        )}
      </div>
    </div>
  );
}

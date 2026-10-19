"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { collection, deleteDoc, doc, onSnapshot, orderBy, query, serverTimestamp, setDoc } from "firebase/firestore";
import { ListMusic, Loader2, Plus, Trash2 } from "lucide-react";
import { useT } from "@/components/LanguageProvider";
import { db } from "@/lib/firebase/client";
import { gradientFor } from "@/lib/palette";

type Row = { id: string; title: string; coverUrl: string; published: boolean; songCount: number };

// Every playlist, published or draft — the public SongBook page only ever
// sees the published ones (lib/playlists.ts's getPublishedPlaylists), same
// draft/live split as songs (status) and the review queue.
export default function PlaylistsAdminView() {
  const { t, songs } = useT();
  const router = useRouter();
  const [rows, setRows] = useState<Row[] | null>(null);
  const [creating, setCreating] = useState(false);

  useEffect(() => {
    return onSnapshot(query(collection(db, "playlists"), orderBy("createdAt", "desc")), (snap) =>
      setRows(
        snap.docs.map((d) => {
          const x = d.data();
          return {
            id: d.id,
            title: typeof x.title === "string" ? x.title : "",
            coverUrl: typeof x.coverUrl === "string" ? x.coverUrl : "",
            published: x.published === true,
            songCount: Array.isArray(x.songIds) ? x.songIds.length : 0,
          };
        }),
      ),
    );
  }, []);

  async function createNew() {
    setCreating(true);
    try {
      const id = doc(collection(db, "playlists")).id;
      await setDoc(doc(db, "playlists", id), {
        title: t("untitledPlaylist"),
        description: "",
        coverUrl: "",
        songIds: [],
        published: false,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
      router.push(`/admin/playlists/${id}`);
    } finally {
      setCreating(false);
    }
  }

  async function remove(id: string) {
    if (!confirm(t("deletePlaylistConfirm"))) return;
    await deleteDoc(doc(db, "playlists", id));
  }

  return (
    <div>
      <div className="flex items-center justify-between gap-3">
        <h1 className="text-2xl font-extrabold tracking-tight">{t("adminPlaylistsLabel")}</h1>
        <button
          type="button"
          onClick={createNew}
          disabled={creating}
          className="flex h-11 shrink-0 items-center gap-2 rounded-full bg-black px-5 text-sm font-semibold text-white transition hover:scale-[1.02] disabled:opacity-50"
        >
          {creating ? <Loader2 size={16} className="animate-spin" /> : <Plus size={16} />}
          {t("newPlaylistButton")}
        </button>
      </div>

      <div className="mt-6 space-y-2">
        {rows === null ? (
          [0, 1].map((i) => <div key={i} className="h-20 animate-pulse rounded-2xl bg-black/5" />)
        ) : rows.length === 0 ? (
          <p className="rounded-3xl border border-dashed border-black/10 px-6 py-10 text-center text-neutral-500">{t("noPlaylistsYet")}</p>
        ) : (
          rows.map((r) => (
            <div key={r.id} className="flex items-center gap-3 rounded-2xl border border-black/5 bg-white p-3 pr-4 shadow-[0_2px_16px_-8px_rgba(0,0,0,0.15)]">
              <button
                type="button"
                onClick={() => router.push(`/admin/playlists/${r.id}`)}
                className="flex min-w-0 flex-1 items-center gap-3 text-left"
              >
                {r.coverUrl ? (
                  // eslint-disable-next-line @next/next/no-img-element -- admin thumbnail, no need for next/image's pipeline here
                  <img src={r.coverUrl} alt="" className="h-14 w-14 shrink-0 rounded-xl object-cover" />
                ) : (
                  <span
                    className="flex h-14 w-14 shrink-0 items-center justify-center rounded-xl text-white"
                    style={{ background: gradientFor(r.title || r.id) }}
                  >
                    <ListMusic size={22} />
                  </span>
                )}
                <span className="min-w-0">
                  <span className="block truncate font-semibold text-neutral-900">{r.title || t("untitledPlaylist")}</span>
                  <span className="mt-0.5 flex items-center gap-2 text-sm text-neutral-500">
                    {songs(r.songCount)}
                    <span
                      className={`rounded-full px-2 py-0.5 text-xs font-semibold ${
                        r.published ? "bg-emerald-50 text-emerald-700" : "bg-neutral-100 text-neutral-600"
                      }`}
                    >
                      {r.published ? t("publishedLabel") : t("draftLabel")}
                    </span>
                  </span>
                </span>
              </button>
              <button
                type="button"
                onClick={() => remove(r.id)}
                aria-label={t("deletePlaylistConfirm")}
                className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-neutral-500 transition hover:bg-red-50 hover:text-red-600"
              >
                <Trash2 size={16} />
              </button>
            </div>
          ))
        )}
      </div>
    </div>
  );
}

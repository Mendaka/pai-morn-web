"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { addDoc, collection, deleteDoc, doc, onSnapshot, orderBy, query, serverTimestamp } from "firebase/firestore";
import { ChevronRight, ListChecks, Plus, Trash2 } from "lucide-react";
import { useT } from "@/components/LanguageProvider";
import { useDialog } from "@/components/useDialog";
import { usePrompt } from "@/components/usePrompt";
import { db } from "@/lib/firebase/client";
import { useRequireAuth } from "@/lib/use-require-auth";

type Row = { id: string; name: string; count: number; isPublic: boolean };

// The signed-in user's own setlists (users/{uid}/setlists): a name plus an
// ordered array of song ids, private unless the owner shared it.
export default function SetlistsView() {
  const user = useRequireAuth("/setlists");
  const uid = user?.uid;
  const { t, songs } = useT();
  const router = useRouter();
  const { ask, dialog } = useDialog();
  const { prompt, promptDialog } = usePrompt();
  const [rows, setRows] = useState<Row[] | null>(null);

  useEffect(() => {
    if (!uid) return;
    const q = query(collection(db, "users", uid, "setlists"), orderBy("updatedAt", "desc"));
    return onSnapshot(q, (snap) =>
      setRows(
        snap.docs.map((d) => {
          const x = d.data();
          return {
            id: d.id,
            name: typeof x.name === "string" ? x.name : "",
            count: Array.isArray(x.songIds) ? x.songIds.length : 0,
            isPublic: x.public === true,
          };
        }),
      ),
    );
  }, [uid]);

  async function create() {
    if (!uid) return;
    const name = await prompt({ title: t("newSetlistTitle"), placeholder: t("setlistNameHint"), confirmLabel: t("saveButton") });
    if (!name) return;
    const ref = await addDoc(collection(db, "users", uid, "setlists"), {
      name,
      songIds: [],
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    router.push(`/setlists/${ref.id}`);
  }

  async function remove(id: string) {
    if (!uid) return;
    const ok = await ask({
      title: t("deleteSetlistConfirmTitle"),
      message: t("deleteSetlistConfirmMessage"),
      actions: [
        { label: t("cancelButton"), value: false },
        { label: t("deleteButton"), value: true, tone: "danger" },
      ],
    });
    if (ok) await deleteDoc(doc(db, "users", uid, "setlists", id)).catch(() => {});
  }

  return (
    <div className="mx-auto w-full max-w-3xl px-4 pb-20 pt-8 sm:px-6">
      <div className="flex items-center justify-between gap-4">
        <h1 className="flex items-center gap-3 text-3xl font-extrabold tracking-tight">
          <span className="flex h-11 w-11 items-center justify-center rounded-2xl bg-gradient-to-br from-emerald-500 to-teal-500 text-white shadow-lg">
            <ListChecks size={22} />
          </span>
          {t("setlistsTitle")}
        </h1>
        <button
          type="button"
          onClick={create}
          className="flex h-11 items-center gap-2 rounded-full bg-black px-5 text-sm font-semibold text-white transition hover:scale-[1.03]"
        >
          <Plus size={16} /> {t("newSetlistTitle")}
        </button>
      </div>

      <div className="mt-8 space-y-3">
        {rows === null ? (
          [0, 1, 2].map((i) => <div key={i} className="h-20 animate-pulse rounded-3xl bg-black/5" />)
        ) : rows.length === 0 ? (
          <div className="flex flex-col items-center rounded-3xl border border-dashed border-black/10 px-6 py-16 text-center text-neutral-500">
            <ListChecks size={40} className="text-neutral-300" />
            <p className="mt-4 max-w-xs">{t("noSetlistsYet")}</p>
          </div>
        ) : (
          rows.map((r) => (
            <div
              key={r.id}
              className="flex items-center gap-2 rounded-3xl border border-black/5 bg-white p-2 pr-3 shadow-[0_2px_16px_-8px_rgba(0,0,0,0.15)] transition hover:shadow-[0_8px_28px_-12px_rgba(0,0,0,0.25)]"
            >
              <Link href={`/setlists/${r.id}`} className="flex min-w-0 flex-1 items-center gap-4 rounded-2xl p-2">
                <span className="flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl bg-emerald-50 text-emerald-600">
                  <ListChecks size={21} />
                </span>
                <span className="min-w-0">
                  <span className="block truncate font-semibold text-neutral-900">{r.name}</span>
                  <span className="block text-sm text-neutral-500">{songs(r.count)}</span>
                </span>
                <ChevronRight size={18} className="ml-auto shrink-0 text-neutral-300" />
              </Link>
              <button
                type="button"
                onClick={() => remove(r.id)}
                aria-label={t("deleteSetlistConfirmTitle")}
                title={t("deleteSetlistConfirmTitle")}
                className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full text-neutral-400 transition hover:bg-red-50 hover:text-red-600"
              >
                <Trash2 size={17} />
              </button>
            </div>
          ))
        )}
      </div>
      {dialog}
      {promptDialog}
    </div>
  );
}

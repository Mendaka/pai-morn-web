"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { collection, deleteDoc, doc, onSnapshot, query, where } from "firebase/firestore";
import { Disc3, PenSquare, Plus, Trash2 } from "lucide-react";
import { useT } from "@/components/LanguageProvider";
import { db } from "@/lib/firebase/client";
import { useRequireAuth } from "@/lib/use-require-auth";

type Status = "approved" | "rejected" | "draft" | "pending";
type Row = {
  id: string;
  songName: string;
  artist: string;
  status: Status;
  rejectionReason: string;
  createdAt: number;
};

const STATUS_STYLE: Record<Status, { label: string; cls: string }> = {
  approved: { label: "statusApproved", cls: "bg-emerald-50 text-emerald-700 ring-emerald-600/20" },
  rejected: { label: "statusRejected", cls: "bg-red-50 text-red-700 ring-red-600/20" },
  draft: { label: "statusDraft", cls: "bg-neutral-100 text-neutral-600 ring-neutral-500/20" },
  pending: { label: "statusPending", cls: "bg-amber-50 text-amber-700 ring-amber-600/20" },
};

const asStatus = (v: unknown): Status => (v === "approved" || v === "rejected" || v === "draft" ? v : "pending");

// Everything the user has ever submitted, whatever its status — so they can
// see what's pending, what got published, and why something was rejected.
export default function MySongsView() {
  const user = useRequireAuth("/my-songs");
  const { t } = useT();
  const uid = user?.uid;
  const [rows, setRows] = useState<Row[] | null>(null);
  const [confirmId, setConfirmId] = useState<string | null>(null);

  useEffect(() => {
    if (!uid) return;
    return onSnapshot(query(collection(db, "songs"), where("authorId", "==", uid)), (snap) => {
      const list = snap.docs.map((d): Row => {
        const x = d.data();
        return {
          id: d.id,
          songName: typeof x.songName === "string" ? x.songName : "",
          artist: typeof x.artist === "string" ? x.artist : "",
          status: asStatus(x.status),
          rejectionReason: typeof x.rejectionReason === "string" ? x.rejectionReason : "",
          createdAt: typeof x.createdAt?.toMillis === "function" ? x.createdAt.toMillis() : 0,
        };
      });
      setRows(list.sort((a, b) => b.createdAt - a.createdAt));
    });
  }, [uid]);

  return (
    <div className="mx-auto w-full max-w-3xl px-4 pb-20 pt-8 sm:px-6">
      <div className="flex items-center justify-between gap-4">
        <h1 className="text-3xl font-extrabold tracking-tight">{t("mySongsTitle")}</h1>
        <Link
          href="/submit-song"
          className="flex h-11 items-center gap-2 rounded-full bg-black px-5 text-sm font-semibold text-white transition hover:scale-[1.03]"
        >
          <Plus size={16} /> {t("submitSongTitle")}
        </Link>
      </div>

      <div className="mt-8 space-y-3">
        {rows === null ? (
          [0, 1, 2].map((i) => <div key={i} className="h-24 animate-pulse rounded-3xl bg-black/5" />)
        ) : rows.length === 0 ? (
          <div className="flex flex-col items-center rounded-3xl border border-dashed border-black/10 px-6 py-16 text-center text-neutral-500">
            <Disc3 size={40} className="text-neutral-300" />
            <p className="mt-4 max-w-xs">{t("noSubmissionsYet")}</p>
          </div>
        ) : (
          rows.map((r) => {
            const s = STATUS_STYLE[r.status];
            // A rejected song is the author's to fix and resend; a draft is
            // theirs to keep editing. An approved one opens its public page. A
            // pending one has NO page yet (the reader only serves approved songs,
            // so linking there gave a 404), so it is shown but not clickable.
            const editable = r.status === "draft" || r.status === "rejected";
            const href = editable ? `/submit-song?edit=${r.id}` : r.status === "approved" ? `/songbook/song/${r.id}` : null;
            const titleBlock = (
              <>
                <span className="block truncate font-semibold text-neutral-900">{r.songName || t("untitledDraft")}</span>
                {r.artist && <span className="block truncate text-sm text-neutral-500">{r.artist}</span>}
              </>
            );
            return (
              <div
                key={r.id}
                className="rounded-3xl border border-black/5 bg-white p-4 shadow-[0_2px_16px_-8px_rgba(0,0,0,0.15)]"
              >
                <div className="flex items-center gap-3">
                  {href ? (
                    <Link href={href} className="min-w-0 flex-1">
                      {titleBlock}
                    </Link>
                  ) : (
                    <div className="min-w-0 flex-1 cursor-default">{titleBlock}</div>
                  )}
                  <span className={`shrink-0 rounded-full px-3 py-1 text-xs font-semibold ring-1 ring-inset ${s.cls}`}>
                    {t(s.label)}
                  </span>
                  {editable && href && (
                    <Link
                      href={href}
                      aria-label={r.status === "draft" ? t("continueEditing") : t("editAndResubmit")}
                      title={r.status === "draft" ? t("continueEditing") : t("editAndResubmit")}
                      className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-neutral-500 transition hover:bg-neutral-100"
                    >
                      <PenSquare size={17} />
                    </Link>
                  )}
                  {r.status === "draft" && (
                    <button
                      type="button"
                      onClick={() => setConfirmId(r.id)}
                      aria-label={t("deleteDraft")}
                      title={t("deleteDraft")}
                      className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-neutral-500 transition hover:bg-red-50 hover:text-red-600"
                    >
                      <Trash2 size={17} />
                    </button>
                  )}
                </div>
                {r.status === "rejected" && r.rejectionReason && (
                  <p className="mt-3 rounded-2xl bg-red-50 px-4 py-2.5 text-sm text-red-700">
                    <span className="font-semibold">{t("reasonLabel")}:</span> {r.rejectionReason}
                  </p>
                )}
              </div>
            );
          })
        )}
      </div>

      {confirmId && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4 backdrop-blur-sm"
          onClick={() => setConfirmId(null)}
        >
          <div
            role="dialog"
            aria-modal="true"
            onClick={(e) => e.stopPropagation()}
            className="w-full max-w-sm rounded-3xl bg-white p-6 shadow-2xl"
          >
            <h2 className="text-lg font-bold">{t("deleteDraftTitle")}</h2>
            <p className="mt-1 text-neutral-500">{t("deleteRequestConfirmMessage")}</p>
            <div className="mt-6 flex justify-end gap-2">
              <button
                type="button"
                onClick={() => setConfirmId(null)}
                className="h-10 rounded-full px-5 text-sm font-medium hover:bg-neutral-100"
              >
                {t("cancelButton")}
              </button>
              <button
                type="button"
                onClick={() => {
                  deleteDoc(doc(db, "songs", confirmId)).catch(() => {});
                  setConfirmId(null);
                }}
                className="h-10 rounded-full bg-red-600 px-5 text-sm font-semibold text-white hover:bg-red-700"
              >
                {t("deleteButton")}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

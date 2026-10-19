"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { collection, doc, increment, onSnapshot, query, serverTimestamp, updateDoc, where, writeBatch, type DocumentData } from "firebase/firestore";
import { Ban, ChevronRight, ClipboardCheck, Loader2, Pencil } from "lucide-react";
import { useT } from "@/components/LanguageProvider";
import LyricLine from "@/components/LyricLine";
import { useDialog } from "@/components/useDialog";
import { db } from "@/lib/firebase/client";

type Pending = { id: string; data: DocumentData; createdAt: number };

// Songs waiting for a decision. Open one to read it with its chords laid out
// exactly as visitors will see them, then approve, reject (with an optional
// reason the submitter sees), edit it first, or block a bad actor.
export default function ReviewQueueView() {
  const { t } = useT();
  const [rows, setRows] = useState<Pending[] | null>(null);
  const [open, setOpen] = useState<Pending | null>(null);

  useEffect(() => {
    return onSnapshot(query(collection(db, "songs"), where("status", "==", "pending")), (snap) =>
      setRows(
        snap.docs
          .map((d) => ({ id: d.id, data: d.data(), createdAt: typeof d.data().createdAt?.toMillis === "function" ? d.data().createdAt.toMillis() : 0 }))
          // oldest first: whoever has waited longest is at the top
          .sort((a, b) => a.createdAt - b.createdAt),
      ),
    );
  }, []);

  // If the open song is decided elsewhere, close the dialog.
  const stillPending = open && rows?.some((r) => r.id === open.id);

  return (
    <div>
      <h1 className="text-3xl font-extrabold tracking-tight">{t("adminReviewQueueLabel")}</h1>
      <ul className="mt-6 space-y-3">
        {rows === null ? (
          [0, 1, 2].map((i) => <li key={i} className="h-20 animate-pulse rounded-3xl bg-black/5" />)
        ) : rows.length === 0 ? (
          <li className="flex flex-col items-center rounded-3xl border border-dashed border-black/10 px-6 py-16 text-center text-neutral-500">
            <ClipboardCheck size={40} className="text-neutral-300" />
            <p className="mt-4">{t("adminNoPendingSongs")}</p>
          </li>
        ) : (
          rows.map((r) => (
            <li key={r.id}>
              <button
                type="button"
                onClick={() => setOpen(r)}
                className="flex w-full items-center gap-4 rounded-3xl border border-black/5 bg-white p-4 text-left shadow-[0_2px_16px_-8px_rgba(0,0,0,0.15)] transition hover:shadow-[0_8px_28px_-12px_rgba(0,0,0,0.25)]"
              >
                <span className="min-w-0 flex-1">
                  <span className="block truncate font-semibold text-neutral-900">{String(r.data.songName ?? "")}</span>
                  <span className="block truncate text-sm text-neutral-500">
                    {String(r.data.artist ?? "")} · {t("adminSubmittedBy", { name: String(r.data.authorName || "?") })}
                  </span>
                </span>
                <ChevronRight size={18} className="shrink-0 text-neutral-300" />
              </button>
            </li>
          ))
        )}
      </ul>
      {open && stillPending && <ReviewDialog song={open} onClose={() => setOpen(null)} />}
    </div>
  );
}

function ReviewDialog({ song, onClose }: { song: Pending; onClose: () => void }) {
  const { t } = useT();
  const { ask, dialog } = useDialog();
  const [reason, setReason] = useState("");
  const [busy, setBusy] = useState(false);
  const d = song.data;
  const authorId = typeof d.authorId === "string" ? d.authorId : "";
  const lyrics: { content?: { type?: string; text?: string }[] }[] = Array.isArray(d.lyrics) ? d.lyrics : [];

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && !busy && onClose();
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [busy, onClose]);

  async function approve() {
    setBusy(true);
    // Approving also bumps the author's approved-song count (their badge).
    const batch = writeBatch(db);
    batch.update(doc(db, "songs", song.id), { status: "approved", approvedAt: serverTimestamp() });
    if (authorId) batch.update(doc(db, "users", authorId), { approvedSongCount: increment(1) });
    await batch.commit().catch(() => setBusy(false));
    onClose();
  }
  async function reject() {
    setBusy(true);
    const text = reason.trim();
    await updateDoc(doc(db, "songs", song.id), { status: "rejected", ...(text ? { rejectionReason: text } : {}) }).catch(() => setBusy(false));
    onClose();
  }
  async function block() {
    const ok = await ask({
      title: t("blockUserConfirmTitle"),
      message: t("blockUserConfirmMessage"),
      actions: [
        { label: t("cancelButton"), value: false },
        { label: t("adminBlock"), value: true, tone: "danger" },
      ],
    });
    if (ok && authorId) await updateDoc(doc(db, "users", authorId), { blocked: true }).catch(() => {});
  }

  return (
    <div className="fixed inset-0 z-[70] flex items-center justify-center bg-black/40 p-3 backdrop-blur-sm sm:p-6" onClick={() => !busy && onClose()}>
      <div role="dialog" aria-modal="true" aria-label={String(d.songName ?? "")} onClick={(e) => e.stopPropagation()} className="flex max-h-[92vh] w-full max-w-3xl flex-col overflow-hidden rounded-3xl bg-white shadow-2xl">
        <div className="border-b border-black/5 px-6 py-5">
          <h2 className="text-xl font-bold">{String(d.songName ?? "")}</h2>
          <p className="mt-1 text-sm text-neutral-500">
            {String(d.artist ?? "")} · {String(d.category || "-")} / {String(d.gender || "-")} · {d.key ? `${d.key}${d.keyIsMinor ? "m" : ""}` : "-"}
          </p>
          <div className="mt-2 flex flex-wrap items-center justify-between gap-2 text-sm">
            <span className="text-neutral-500">{t("adminSubmittedBy", { name: String(d.authorName || "?") })}</span>
            {authorId && (
              <button type="button" onClick={block} disabled={busy} className="inline-flex items-center gap-1.5 rounded-full px-3 py-1 text-xs font-semibold text-red-600 hover:bg-red-50">
                <Ban size={13} /> {t("blockUserButton")}
              </button>
            )}
          </div>
        </div>
        <div className="flex-1 overflow-y-auto px-6 py-5">
          {lyrics.map((line, i) => (
            <LyricLine key={i} content={line.content ?? []} transpose={0} />
          ))}
        </div>
        <div className="border-t border-black/5 px-6 py-4">
          <input value={reason} onChange={(e) => setReason(e.target.value)} placeholder={t("adminReasonHint")} aria-label={t("adminReasonHint")} className="plain-input !py-2.5 text-sm" />
          <div className="mt-3 flex flex-wrap justify-end gap-2">
            <button type="button" onClick={onClose} disabled={busy} className="h-10 rounded-full px-5 text-sm font-medium hover:bg-neutral-100">
              {t("cancelButton")}
            </button>
            <Link href={`/submit-song?edit=${song.id}`} className="flex h-10 items-center gap-1.5 rounded-full border border-black/15 px-5 text-sm font-semibold hover:bg-neutral-50">
              <Pencil size={14} /> {t("editButton")}
            </Link>
            <button type="button" onClick={reject} disabled={busy} className="h-10 rounded-full border border-red-600/30 px-5 text-sm font-semibold text-red-600 hover:bg-red-50 disabled:opacity-50">
              {t("adminReject")}
            </button>
            <button type="button" onClick={approve} disabled={busy} className="flex h-10 items-center gap-2 rounded-full bg-emerald-600 px-6 text-sm font-semibold text-white hover:bg-emerald-700 disabled:opacity-50">
              {busy && <Loader2 size={15} className="animate-spin" />}
              {t("adminApprove")}
            </button>
          </div>
        </div>
      </div>
      {dialog}
    </div>
  );
}

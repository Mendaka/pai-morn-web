"use client";

import { useEffect, useState } from "react";
import { addDoc, arrayRemove, arrayUnion, collection, doc, onSnapshot, orderBy, query, serverTimestamp, updateDoc } from "firebase/firestore";
import { Check, ListPlus, Loader2, Plus, Share2, TriangleAlert } from "lucide-react";
import { useAuth } from "@/components/AuthProvider";
import { useT } from "@/components/LanguageProvider";
import { usePrompt } from "@/components/usePrompt";
import { db } from "@/lib/firebase/client";

const btn =
  "no-print flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-neutral-100 text-neutral-700 transition hover:bg-neutral-200";

// The round icon buttons under the song title: share, add to a setlist (signed
// in only) and report a problem.
export default function ReaderActions({ songId, songName }: { songId: string; songName: string }) {
  const { t } = useT();
  const { user } = useAuth();
  const [setlistOpen, setSetlistOpen] = useState(false);
  const [reportOpen, setReportOpen] = useState(false);
  const [toast, setToast] = useState<string | null>(null);

  useEffect(() => {
    if (!toast) return;
    const id = setTimeout(() => setToast(null), 2500);
    return () => clearTimeout(id);
  }, [toast]);

  async function share() {
    const url = `${location.origin}/songbook/song/${songId}`;
    try {
      // The browser's native share sheet where there is one (phones: Line,
      // Messenger, ...); otherwise fall back to copying the link.
      if (navigator.share) {
        await navigator.share({ title: songName, url });
        return;
      }
    } catch (e) {
      if (e instanceof DOMException && e.name === "AbortError") return; // the person dismissed the sheet
    }
    await navigator.clipboard.writeText(url).catch(() => {});
    setToast(t("linkCopiedMessage"));
  }

  return (
    <>
      <div className="flex items-center gap-2">
        <button type="button" onClick={share} aria-label={t("shareSongLabel")} title={t("shareSongLabel")} className={btn}>
          <Share2 size={18} />
        </button>
        {user && (
          <button type="button" onClick={() => setSetlistOpen(true)} aria-label={t("addToSetlistTitle")} title={t("addToSetlistTitle")} className={btn}>
            <ListPlus size={19} />
          </button>
        )}
        <button type="button" onClick={() => setReportOpen(true)} aria-label={t("reportIssueTooltip")} title={t("reportIssueTooltip")} className={btn}>
          <TriangleAlert size={18} />
        </button>
      </div>

      {setlistOpen && user && <AddToSetlistDialog uid={user.uid} songId={songId} onClose={() => setSetlistOpen(false)} />}
      {reportOpen && (
        <ReportDialog
          songId={songId}
          songName={songName}
          onClose={() => setReportOpen(false)}
          onSent={() => {
            setReportOpen(false);
            setToast(t("reportIssueSuccessMessage"));
          }}
        />
      )}
      {toast && (
        <div role="status" className="no-print fixed bottom-24 left-1/2 z-[80] -translate-x-1/2 rounded-full bg-neutral-900 px-5 py-3 text-sm font-medium text-white shadow-xl md:bottom-8">
          {toast}
        </div>
      )}
    </>
  );
}

function Modal({ label, onClose, children }: { label: string; onClose: () => void; children: React.ReactNode }) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [onClose]);
  return (
    <div className="no-print fixed inset-0 z-[70] flex items-center justify-center bg-black/40 p-4 backdrop-blur-sm" onClick={onClose}>
      <div role="dialog" aria-modal="true" aria-label={label} onClick={(e) => e.stopPropagation()} className="max-h-[85vh] w-full max-w-sm overflow-y-auto rounded-3xl bg-white p-6 text-neutral-900 shadow-2xl">
        {children}
      </div>
    </div>
  );
}

type SetlistRow = { id: string; name: string; has: boolean };

// Tick a setlist to add this song, untick to remove it — changes apply as you
// tick, like the Flutter dialog.
function AddToSetlistDialog({ uid, songId, onClose }: { uid: string; songId: string; onClose: () => void }) {
  const { t } = useT();
  const { prompt, promptDialog } = usePrompt();
  const [rows, setRows] = useState<SetlistRow[] | null>(null);

  useEffect(() => {
    const q = query(collection(db, "users", uid, "setlists"), orderBy("updatedAt", "desc"));
    return onSnapshot(q, (snap) =>
      setRows(
        snap.docs.map((d) => ({
          id: d.id,
          name: typeof d.data().name === "string" ? d.data().name : "",
          has: Array.isArray(d.data().songIds) && d.data().songIds.includes(songId),
        })),
      ),
    );
  }, [uid, songId]);

  const toggle = (row: SetlistRow) =>
    updateDoc(doc(db, "users", uid, "setlists", row.id), {
      songIds: row.has ? arrayRemove(songId) : arrayUnion(songId),
      updatedAt: serverTimestamp(),
    }).catch(() => {});

  async function createNew() {
    const name = await prompt({ title: t("newSetlistTitle"), placeholder: t("setlistNameHint"), confirmLabel: t("saveButton") });
    if (name) {
      await addDoc(collection(db, "users", uid, "setlists"), { name, songIds: [songId], createdAt: serverTimestamp(), updatedAt: serverTimestamp() }).catch(() => {});
    }
  }

  return (
    <Modal label={t("addToSetlistTitle")} onClose={onClose}>
      <h2 className="text-lg font-bold">{t("addToSetlistTitle")}</h2>
      <ul className="mt-4 space-y-1">
        {rows === null ? (
          <li className="flex justify-center py-6 text-neutral-400">
            <Loader2 className="animate-spin" />
          </li>
        ) : (
          rows.map((r) => (
            <li key={r.id}>
              <button type="button" onClick={() => toggle(r)} role="checkbox" aria-checked={r.has} className="flex w-full items-center gap-3 rounded-2xl px-3 py-2.5 text-left transition hover:bg-neutral-100">
                <span className={`flex h-6 w-6 shrink-0 items-center justify-center rounded-md border-2 ${r.has ? "border-blue-600 bg-blue-600 text-white" : "border-neutral-300"}`}>{r.has && <Check size={15} strokeWidth={3} />}</span>
                <span className="truncate">{r.name}</span>
              </button>
            </li>
          ))
        )}
        <li>
          <button type="button" onClick={createNew} className="flex w-full items-center gap-3 rounded-2xl px-3 py-2.5 text-left font-medium text-blue-600 transition hover:bg-blue-50">
            <Plus size={18} /> {t("createNewSetlistLabel").replace(/^\+\s*/, "")}
          </button>
        </li>
      </ul>
      <div className="mt-4 flex justify-end">
        <button type="button" onClick={onClose} className="h-10 rounded-full bg-black px-6 text-sm font-semibold text-white hover:bg-neutral-800">
          {t("doneLabel")}
        </button>
      </div>
      {promptDialog}
    </Modal>
  );
}

const ISSUE_TYPES = [
  ["wrongChords", "issueTypeWrongChords"],
  ["wrongLyrics", "issueTypeWrongLyrics"],
  ["other", "issueTypeOther"],
] as const;

// Anyone (signed in or not) can report a wrong chord or lyric; admins triage
// the reports (songIssueReports, see firestore.rules for the exact shape).
// Description is required (changed 2026-10-14) — the owner found the issue
// type alone, without a description, often isn't enough to tell what's
// actually wrong with a song. Enforced client-side (disabled submit button)
// and server-side (firestore.rules requires description.size() > 0).
function ReportDialog({ songId, songName, onClose, onSent }: { songId: string; songName: string; onClose: () => void; onSent: () => void }) {
  const { t } = useT();
  const [type, setType] = useState<(typeof ISSUE_TYPES)[number][0]>("wrongChords");
  const [text, setText] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(false);

  async function send() {
    if (!text.trim()) return;
    setBusy(true);
    setError(false);
    try {
      await addDoc(collection(db, "songIssueReports"), {
        songId,
        songName,
        issueType: type,
        description: text.trim(),
        resolved: false,
        createdAt: serverTimestamp(),
      });
      onSent();
    } catch {
      setError(true);
      setBusy(false);
    }
  }

  return (
    <Modal label={t("reportIssueTitle")} onClose={onClose}>
      <h2 className="text-lg font-bold">{t("reportIssueTitle")}</h2>
      <fieldset className="mt-4">
        <legend className="text-sm font-semibold text-neutral-700">{t("issueTypeLabel")}</legend>
        <div className="mt-2 space-y-1">
          {ISSUE_TYPES.map(([value, key]) => (
            <label key={value} className="flex cursor-pointer items-center gap-3 rounded-2xl px-3 py-2 hover:bg-neutral-100">
              <input type="radio" name="issueType" value={value} checked={type === value} onChange={() => setType(value)} className="h-4 w-4 accent-black" />
              <span>{t(key)}</span>
            </label>
          ))}
        </div>
      </fieldset>
      <textarea value={text} onChange={(e) => setText(e.target.value)} maxLength={1500} rows={3} placeholder={t("issueDescriptionHint")} aria-label={t("issueDescriptionHint")} className="plain-input mt-3 resize-none" />
      {error && (
        <p role="alert" className="mt-3 rounded-xl bg-red-50 px-4 py-2.5 text-sm text-red-700">
          {t("reportIssueFailed")}
        </p>
      )}
      <div className="mt-5 flex justify-end gap-2">
        <button type="button" onClick={onClose} className="h-10 rounded-full px-5 text-sm font-medium hover:bg-neutral-100">
          {t("cancelButton")}
        </button>
        <button type="button" onClick={send} disabled={busy || !text.trim()} className="flex h-10 items-center gap-2 rounded-full bg-black px-5 text-sm font-semibold text-white hover:bg-neutral-800 disabled:opacity-60">
          {busy && <Loader2 size={15} className="animate-spin" />}
          {t("submitReportButton")}
        </button>
      </div>
    </Modal>
  );
}

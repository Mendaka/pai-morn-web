"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { arrayUnion, deleteDoc, doc, onSnapshot, serverTimestamp, updateDoc } from "firebase/firestore";
import { ArrowDown, ArrowLeft, ArrowUp, GripVertical, Link2, ListChecks, Pencil, Play, Plus, Share2, Trash2, X } from "lucide-react";
import { useT } from "@/components/LanguageProvider";
import SongPicker from "@/components/SongPicker";
import { useDialog } from "@/components/useDialog";
import { usePrompt } from "@/components/usePrompt";
import { db } from "@/lib/firebase/client";
import { useSongsIndex } from "@/lib/songs-index";
import { useRequireAuth } from "@/lib/use-require-auth";

type Setlist = { name: string; ids: string[]; isPublic: boolean };

// One of the owner's setlists: play it through, reorder by dragging (or the
// arrow buttons), add and remove songs, rename, delete, share as a link.
export default function SetlistDetailView({ setlistId }: { setlistId: string }) {
  const user = useRequireAuth(`/setlists/${setlistId}`);
  const uid = user?.uid;
  const { t } = useT();
  const router = useRouter();
  const { ask, dialog } = useDialog();
  const { prompt, promptDialog } = usePrompt();
  const { songs, byId } = useSongsIndex();

  const [state, setState] = useState<Setlist | "missing" | null>(null);
  const [order, setOrder] = useState<string[]>([]);
  const [pickerOpen, setPickerOpen] = useState(false);
  const [shareUrl, setShareUrl] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);
  // The row being dragged: a ref so drop always sees it, plus state for the faded look.
  const dragRef = useRef<number | null>(null);
  const [dragging, setDragging] = useState<number | null>(null);

  const ref = uid ? doc(db, "users", uid, "setlists", setlistId) : null;

  useEffect(() => {
    if (!uid) return;
    return onSnapshot(doc(db, "users", uid, "setlists", setlistId), (snap) => {
      if (!snap.exists()) return setState("missing");
      const d = snap.data();
      const ids: string[] = Array.isArray(d.songIds) ? d.songIds.filter((x: unknown): x is string => typeof x === "string") : [];
      setState({ name: typeof d.name === "string" ? d.name : "", ids, isPublic: d.public === true });
      setOrder(ids);
    });
  }, [uid, setlistId]);

  useEffect(() => {
    if (state === "missing") router.replace("/setlists");
  }, [state, router]);

  if (!uid || state === null || state === "missing") {
    return (
      <div className="mx-auto max-w-3xl px-4 py-10">
        <div className="h-10 w-64 animate-pulse rounded-xl bg-black/5" />
        <div className="mt-6 h-64 animate-pulse rounded-3xl bg-black/5" />
      </div>
    );
  }

  const persist = (ids: string[]) => {
    setOrder(ids);
    if (ref) updateDoc(ref, { songIds: ids, updatedAt: serverTimestamp() }).catch(() => {});
  };
  const move = (from: number, to: number) => {
    if (to < 0 || to >= order.length || from === to) return;
    const next = [...order];
    next.splice(to, 0, next.splice(from, 1)[0]);
    persist(next);
  };

  // Songs the index doesn't know (removed, or not approved) stay out of the list.
  const visible = order.map((id, index) => ({ id, index, song: byId.get(id) })).filter((r) => r.song || songs === null);
  const firstPlayable = order.find((id) => byId.has(id));

  async function rename() {
    if (!ref || state === null || state === "missing") return;
    const name = await prompt({ title: t("renameSetlistTitle"), initial: state.name, placeholder: t("setlistNameHint"), confirmLabel: t("saveButton") });
    if (name) updateDoc(ref, { name, updatedAt: serverTimestamp() }).catch(() => {});
  }

  async function share() {
    if (!ref || state === null || state === "missing") return;
    if (!state.isPublic) await updateDoc(ref, { public: true, updatedAt: serverTimestamp() }).catch(() => {});
    setCopied(false);
    setShareUrl(`${location.origin}/setlists/shared/${uid}/${setlistId}`);
  }
  async function stopSharing() {
    if (ref) await updateDoc(ref, { public: false, updatedAt: serverTimestamp() }).catch(() => {});
    setShareUrl(null);
  }
  async function copyLink() {
    if (!shareUrl) return;
    await navigator.clipboard.writeText(shareUrl).catch(() => {});
    setCopied(true);
  }

  async function remove() {
    const ok = await ask({
      title: t("deleteSetlistConfirmTitle"),
      message: t("deleteSetlistConfirmMessage"),
      actions: [
        { label: t("cancelButton"), value: false },
        { label: t("deleteButton"), value: true, tone: "danger" },
      ],
    });
    if (ok && ref) {
      await deleteDoc(ref).catch(() => {});
      router.replace("/setlists");
    }
  }

  const iconBtn = "flex h-10 w-10 items-center justify-center rounded-full text-neutral-600 transition hover:bg-black/5";

  return (
    <div className="mx-auto w-full max-w-3xl px-4 pb-24 pt-6 sm:px-6">
      <Link href="/setlists" className="inline-flex items-center gap-1.5 text-sm font-medium text-neutral-500 hover:text-black">
        <ArrowLeft size={16} /> {t("setlistsTitle")}
      </Link>

      <div className="mt-3 flex items-start justify-between gap-4">
        <h1 className="flex min-w-0 items-center gap-3 text-3xl font-extrabold tracking-tight">
          <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl bg-gradient-to-br from-emerald-500 to-teal-500 text-white shadow-lg">
            <ListChecks size={22} />
          </span>
          <span className="truncate">{state.name}</span>
        </h1>
        <div className="flex shrink-0 items-center">
          <button type="button" onClick={share} aria-label={t("shareSetlistTitle")} title={t("shareSetlistTitle")} className={`${iconBtn} ${state.isPublic ? "text-blue-600" : ""}`}>
            <Share2 size={18} />
          </button>
          <button type="button" onClick={rename} aria-label={t("renameSetlistTitle")} title={t("renameSetlistTitle")} className={iconBtn}>
            <Pencil size={18} />
          </button>
          <button type="button" onClick={remove} aria-label={t("deleteSetlistConfirmTitle")} title={t("deleteSetlistConfirmTitle")} className={`${iconBtn} hover:!bg-red-50 hover:!text-red-600`}>
            <Trash2 size={18} />
          </button>
        </div>
      </div>

      <div className="mt-6 flex flex-wrap gap-3">
        {firstPlayable && (
          <Link
            href={`/songbook/song/${firstPlayable}?setlist=${setlistId}`}
            className="flex h-11 items-center gap-2 rounded-full bg-black px-6 text-sm font-semibold text-white transition hover:scale-[1.03]"
          >
            <Play size={15} className="fill-current" /> {t("playLabel")}
          </Link>
        )}
        <button
          type="button"
          onClick={() => setPickerOpen(true)}
          className="flex h-11 items-center gap-2 rounded-full border border-black/15 px-5 text-sm font-semibold transition hover:bg-neutral-50"
        >
          <Plus size={16} /> {t("addSongsLabel")}
        </button>
      </div>

      <ol className="mt-6 space-y-2.5">
        {visible.length === 0 ? (
          <li className="flex flex-col items-center rounded-3xl border border-dashed border-black/10 px-6 py-14 text-center text-neutral-500">
            <ListChecks size={38} className="text-neutral-300" />
            <p className="mt-3">{t("noSongsInSetlistMessage")}</p>
          </li>
        ) : (
          visible.map(({ id, index, song }) => (
            <li
              key={id}
              draggable
              onDragStart={() => {
                dragRef.current = index;
                setDragging(index);
              }}
              onDragOver={(e) => e.preventDefault()}
              onDrop={() => {
                if (dragRef.current !== null) move(dragRef.current, index);
                dragRef.current = null;
                setDragging(null);
              }}
              onDragEnd={() => {
                dragRef.current = null;
                setDragging(null);
              }}
              className={`flex items-center gap-2 rounded-3xl border border-black/5 bg-white p-2 pr-2 shadow-[0_2px_16px_-8px_rgba(0,0,0,0.15)] transition ${dragging === index ? "opacity-40" : ""}`}
            >
              <span title={t("dragToReorderLabel")} className="hidden h-10 w-7 shrink-0 cursor-grab items-center justify-center text-neutral-300 sm:flex">
                <GripVertical size={18} />
              </span>
              <Link href={`/songbook/song/${id}?setlist=${setlistId}`} className="flex min-w-0 flex-1 items-center gap-3 rounded-2xl p-2">
                <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-neutral-100 text-xs font-bold text-neutral-500">{index + 1}</span>
                <span className="min-w-0">
                  <span className="block truncate font-semibold text-neutral-900">{song?.name ?? "…"}</span>
                  {song?.artist && <span className="block truncate text-sm text-neutral-500">{song.artist}</span>}
                </span>
              </Link>
              <button type="button" onClick={() => move(index, index - 1)} disabled={index === 0} aria-label={t("moveUpLabel")} title={t("moveUpLabel")} className={`${iconBtn} !h-9 !w-9 disabled:opacity-25`}>
                <ArrowUp size={16} />
              </button>
              <button type="button" onClick={() => move(index, index + 1)} disabled={index === order.length - 1} aria-label={t("moveDownLabel")} title={t("moveDownLabel")} className={`${iconBtn} !h-9 !w-9 disabled:opacity-25`}>
                <ArrowDown size={16} />
              </button>
              <button
                type="button"
                onClick={() => persist(order.filter((x) => x !== id))}
                aria-label={t("removeFromSetlistLabel")}
                title={t("removeFromSetlistLabel")}
                className={`${iconBtn} !h-9 !w-9 hover:!bg-red-50 hover:!text-red-600`}
              >
                <X size={17} />
              </button>
            </li>
          ))
        )}
      </ol>

      {pickerOpen && (
        <SongPicker
          songs={songs}
          chosen={new Set(order)}
          onAdd={(id) => ref && updateDoc(ref, { songIds: arrayUnion(id), updatedAt: serverTimestamp() }).catch(() => {})}
          onClose={() => setPickerOpen(false)}
        />
      )}

      {shareUrl && (
        <div className="fixed inset-0 z-[70] flex items-center justify-center bg-black/40 p-4 backdrop-blur-sm" onClick={() => setShareUrl(null)}>
          <div role="dialog" aria-modal="true" aria-label={t("shareSetlistTitle")} onClick={(e) => e.stopPropagation()} className="w-full max-w-md rounded-3xl bg-white p-6 shadow-2xl">
            <h2 className="flex items-center gap-2 text-lg font-bold">
              <Link2 size={18} /> {t("shareSetlistTitle")}
            </h2>
            <p className="mt-1 text-sm text-neutral-500">{t("shareSetlistNote")}</p>
            <input readOnly value={shareUrl} onFocus={(e) => e.currentTarget.select()} aria-label={t("copyLinkLabel")} className="plain-input mt-4 text-sm" />
            <div className="mt-6 flex flex-wrap justify-end gap-2">
              <button type="button" onClick={stopSharing} className="h-10 rounded-full px-5 text-sm font-medium text-red-600 hover:bg-red-50">
                {t("stopSharingLabel")}
              </button>
              <button type="button" onClick={copyLink} className="h-10 rounded-full bg-black px-5 text-sm font-semibold text-white hover:bg-neutral-800">
                {copied ? t("linkCopiedMessage") : t("copyLinkLabel")}
              </button>
            </div>
          </div>
        </div>
      )}
      {dialog}
      {promptDialog}
    </div>
  );
}

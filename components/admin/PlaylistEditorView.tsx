"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { deleteDoc, doc, onSnapshot, serverTimestamp, updateDoc } from "firebase/firestore";
import { ArrowDown, ArrowLeft, ArrowUp, Camera, Loader2, ListMusic, Plus, Trash2, X } from "lucide-react";
import { useAuth } from "@/components/AuthProvider";
import { useT } from "@/components/LanguageProvider";
import SongPicker from "@/components/SongPicker";
import { db } from "@/lib/firebase/client";
import { resizeImageForUpload } from "@/lib/image-resize";
import { gradientFor } from "@/lib/palette";
import { useSongsIndex } from "@/lib/songs-index";

type PlaylistDoc = { title: string; description: string; coverUrl: string; songIds: string[]; published: boolean };

// Same contract as EditArtistDialog's photo upload: resize in the browser,
// post to the uploadPlaylistCover Cloud Function (admin-checked server-side,
// writes via the Admin SDK — see functions/index.js and storage.rules).
async function uploadCover(playlistId: string, file: File, idToken: string): Promise<void> {
  const blob = await resizeImageForUpload(file, 800);
  const base64 = await new Promise<string>((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result).split(",")[1] ?? "");
    reader.onerror = () => reject(reader.error);
    reader.readAsDataURL(blob);
  });
  const res = await fetch(`${process.env.NEXT_PUBLIC_API_BASE ?? ""}/api/upload-playlist-cover`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${idToken}` },
    body: JSON.stringify({ playlistId, imageBase64: base64 }),
  });
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error(body.error || `Upload failed (${res.status})`);
  }
}

export default function PlaylistEditorView({ playlistId }: { playlistId: string }) {
  const { t } = useT();
  const { user } = useAuth();
  const router = useRouter();
  const { songs, byId } = useSongsIndex();

  const [state, setState] = useState<PlaylistDoc | "missing" | null>(null);
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [saving, setSaving] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [uploadError, setUploadError] = useState<string | null>(null);
  const [pickerOpen, setPickerOpen] = useState(false);
  const fileRef = useRef<HTMLInputElement>(null);

  const ref = doc(db, "playlists", playlistId);

  useEffect(() => {
    return onSnapshot(ref, (snap) => {
      if (!snap.exists()) return setState("missing");
      const d = snap.data();
      const loaded: PlaylistDoc = {
        title: typeof d.title === "string" ? d.title : "",
        description: typeof d.description === "string" ? d.description : "",
        coverUrl: typeof d.coverUrl === "string" ? d.coverUrl : "",
        songIds: Array.isArray(d.songIds) ? d.songIds.filter((x: unknown): x is string => typeof x === "string") : [],
        published: d.published === true,
      };
      setState(loaded);
      setTitle(loaded.title);
      setDescription(loaded.description);
    });
    // `ref` is a fresh object each render (doc() isn't memoised) but always
    // points at the same path for a given playlistId — depend on that instead.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [playlistId]);

  useEffect(() => {
    if (state === "missing") router.replace("/admin/playlists");
  }, [state, router]);

  if (state === null || state === "missing") {
    return (
      <div>
        <div className="h-8 w-48 animate-pulse rounded-xl bg-black/5" />
        <div className="mt-6 h-64 animate-pulse rounded-3xl bg-black/5" />
      </div>
    );
  }

  // A fresh `const` narrows to PlaylistDoc for the rest of this render,
  // including the closures declared below — `state` itself doesn't reliably
  // stay narrowed inside those (a TS limitation with reassignable bindings).
  const playlist = state;
  const dirty = title !== playlist.title || description !== playlist.description;
  const order = playlist.songIds;
  const rows = order.map((id, index) => ({ id, index, song: byId.get(id) }));

  async function saveText() {
    setSaving(true);
    try {
      await updateDoc(ref, { title: title.trim(), description: description.trim(), updatedAt: serverTimestamp() });
    } finally {
      setSaving(false);
    }
  }

  function persistOrder(next: string[]) {
    updateDoc(ref, { songIds: next, updatedAt: serverTimestamp() }).catch(() => {});
  }
  function move(from: number, to: number) {
    if (to < 0 || to >= order.length || from === to) return;
    const next = [...order];
    next.splice(to, 0, next.splice(from, 1)[0]);
    persistOrder(next);
  }
  function removeSong(id: string) {
    persistOrder(order.filter((x) => x !== id));
  }
  function addSong(id: string) {
    if (!order.includes(id)) persistOrder([...order, id]);
  }

  function togglePublished() {
    updateDoc(ref, { published: !playlist.published, updatedAt: serverTimestamp() }).catch(() => {});
  }

  async function onPickCover(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    e.target.value = "";
    if (!file || !user) return;
    setUploading(true);
    setUploadError(null);
    try {
      await uploadCover(playlistId, file, await user.getIdToken());
    } catch (err) {
      setUploadError(err instanceof Error && err.message ? err.message : t("adminPhotoFailed"));
    } finally {
      setUploading(false);
    }
  }

  async function removePlaylist() {
    if (!confirm(t("deletePlaylistConfirm"))) return;
    await deleteDoc(ref);
    router.replace("/admin/playlists");
  }

  const iconBtn = "flex h-9 w-9 items-center justify-center rounded-full text-neutral-600 transition hover:bg-black/5 disabled:opacity-25";

  return (
    <div className="max-w-2xl">
      <Link href="/admin/playlists" className="inline-flex items-center gap-1.5 text-sm font-medium text-neutral-500 hover:text-black">
        <ArrowLeft size={16} /> {t("adminPlaylistsLabel")}
      </Link>

      <div className="mt-4 flex items-start gap-4 rounded-3xl border border-black/5 bg-white p-5 shadow-[0_2px_16px_-8px_rgba(0,0,0,0.15)]">
        <div className="relative shrink-0">
          {playlist.coverUrl ? (
            // eslint-disable-next-line @next/next/no-img-element -- admin preview, no need for next/image's pipeline here
            <img src={playlist.coverUrl} alt="" className="h-24 w-24 rounded-2xl object-cover" />
          ) : (
            <span className="flex h-24 w-24 items-center justify-center rounded-2xl text-white" style={{ background: gradientFor(title || playlistId) }}>
              <ListMusic size={30} />
            </span>
          )}
          {uploading && (
            <span className="absolute inset-0 flex items-center justify-center rounded-2xl bg-black/50 text-white">
              <Loader2 className="animate-spin" />
            </span>
          )}
          <input ref={fileRef} type="file" accept="image/*" hidden onChange={onPickCover} />
          <button
            type="button"
            onClick={() => fileRef.current?.click()}
            disabled={uploading}
            className="absolute -bottom-2 -right-2 flex h-8 w-8 items-center justify-center rounded-full border-2 border-white bg-black text-white shadow"
            aria-label={t(playlist.coverUrl ? "adminChangePhoto" : "adminUploadPhoto")}
            title={t(playlist.coverUrl ? "adminChangePhoto" : "adminUploadPhoto")}
          >
            <Camera size={14} />
          </button>
        </div>

        <div className="min-w-0 flex-1 space-y-3">
          <label className="block">
            <span className="mb-1 block text-sm font-semibold text-neutral-700">{t("playlistTitleLabel")}</span>
            <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder={t("playlistTitlePlaceholder")} className="plain-input" />
          </label>
          <label className="block">
            <span className="mb-1 block text-sm font-semibold text-neutral-700">{t("playlistDescriptionLabel")}</span>
            <textarea value={description} onChange={(e) => setDescription(e.target.value)} rows={2} className="plain-input resize-none" />
          </label>
          <div className="flex flex-wrap items-center gap-3">
            <button
              type="button"
              onClick={saveText}
              disabled={!dirty || saving}
              className="flex h-10 items-center gap-2 rounded-full bg-black px-5 text-sm font-semibold text-white transition disabled:opacity-40"
            >
              {saving ? <Loader2 size={14} className="animate-spin" /> : null}
              {t("saveButton")}
            </button>
            <span
              className={`rounded-full px-3 py-1.5 text-xs font-semibold ${
                playlist.published ? "bg-emerald-50 text-emerald-700" : "bg-neutral-100 text-neutral-600"
              }`}
            >
              {playlist.published ? t("publishedLabel") : t("draftLabel")}
            </span>
            <button
              type="button"
              onClick={togglePublished}
              aria-pressed={playlist.published}
              className={`flex h-10 items-center gap-1.5 rounded-full px-4 text-sm font-semibold transition ${
                playlist.published ? "bg-neutral-100 text-neutral-700 hover:bg-neutral-200" : "bg-emerald-600 text-white hover:bg-emerald-700"
              }`}
            >
              {playlist.published ? t("unpublishButton") : t("publishButton")}
            </button>
            <button
              type="button"
              onClick={removePlaylist}
              className="ml-auto flex h-10 items-center gap-1.5 rounded-full px-3 text-sm font-medium text-neutral-500 transition hover:bg-red-50 hover:text-red-600"
            >
              <Trash2 size={15} /> {t("deleteButton")}
            </button>
          </div>
          {uploadError && (
            <p role="alert" className="rounded-xl bg-red-50 px-4 py-2 text-sm font-medium text-red-700">
              {uploadError}
            </p>
          )}
        </div>
      </div>

      <div className="mt-6 flex items-center justify-between">
        <h2 className="text-lg font-bold">{t("playlistSongsLabel")}</h2>
        <button
          type="button"
          onClick={() => setPickerOpen(true)}
          className="flex h-10 items-center gap-2 rounded-full border border-black/15 px-4 text-sm font-semibold transition hover:bg-neutral-50"
        >
          <Plus size={15} /> {t("addSongsLabel")}
        </button>
      </div>

      <ol className="mt-4 space-y-2">
        {rows.length === 0 ? (
          <li className="rounded-3xl border border-dashed border-black/10 px-6 py-12 text-center text-neutral-500">{t("noSongsInPlaylistMessage")}</li>
        ) : (
          rows.map(({ id, index, song }) => (
            <li key={id} className="flex items-center gap-2 rounded-2xl border border-black/5 bg-white p-2 pr-3 shadow-[0_2px_12px_-8px_rgba(0,0,0,0.15)]">
              <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-neutral-100 text-xs font-bold text-neutral-500">{index + 1}</span>
              <span className="min-w-0 flex-1">
                <span className="block truncate font-semibold text-neutral-900">{song?.name ?? "…"}</span>
                {song?.artist && <span className="block truncate text-sm text-neutral-500">{song.artist}</span>}
              </span>
              <button type="button" onClick={() => move(index, index - 1)} disabled={index === 0} aria-label={t("moveUpLabel")} title={t("moveUpLabel")} className={iconBtn}>
                <ArrowUp size={15} />
              </button>
              <button type="button" onClick={() => move(index, index + 1)} disabled={index === order.length - 1} aria-label={t("moveDownLabel")} title={t("moveDownLabel")} className={iconBtn}>
                <ArrowDown size={15} />
              </button>
              <button type="button" onClick={() => removeSong(id)} aria-label={t("removeSongLabel")} title={t("removeSongLabel")} className={`${iconBtn} hover:!bg-red-50 hover:!text-red-600`}>
                <X size={16} />
              </button>
            </li>
          ))
        )}
      </ol>

      {pickerOpen && (
        <SongPicker
          songs={songs}
          chosen={new Set(order)}
          onAdd={addSong}
          onClose={() => setPickerOpen(false)}
          title={t("playlistSongsLabel")}
        />
      )}
    </div>
  );
}

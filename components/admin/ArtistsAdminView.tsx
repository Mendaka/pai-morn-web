"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { collection, doc, onSnapshot, orderBy, query, updateDoc } from "firebase/firestore";
import { Camera, Loader2, Pencil, Search, X } from "lucide-react";
import { ArtistAvatar } from "@/components/ArtistCard";
import { useAuth } from "@/components/AuthProvider";
import { useT } from "@/components/LanguageProvider";
import { db } from "@/lib/firebase/client";
import { resizeImageForUpload } from "@/lib/image-resize";

type Artist = { id: string; name: string; bio: string; photoUrl: string };

// The artists collection: search, edit an artist's bio, and upload their photo.
export default function ArtistsAdminView() {
  const { t } = useT();
  const [rows, setRows] = useState<Artist[] | null>(null);
  const [q, setQ] = useState("");
  const [editing, setEditing] = useState<string | null>(null);

  useEffect(() => {
    return onSnapshot(query(collection(db, "artists"), orderBy("name")), (snap) =>
      setRows(
        snap.docs.map((d) => {
          const x = d.data();
          return {
            id: d.id,
            name: typeof x.name === "string" ? x.name : "",
            bio: typeof x.bio === "string" ? x.bio : "",
            photoUrl: typeof x.photoUrl === "string" ? x.photoUrl.trim() : "",
          };
        }),
      ),
    );
  }, []);

  const shown = useMemo(() => {
    const needle = q.trim().toLowerCase();
    return (rows ?? []).filter((a) => !needle || a.name.toLowerCase().includes(needle));
  }, [rows, q]);
  // Read from the live list, so the dialog shows the photo the moment an upload lands.
  const current = rows?.find((a) => a.id === editing) ?? null;

  return (
    <div>
      <h1 className="text-3xl font-extrabold tracking-tight">{t("tabArtists")}</h1>
      <label className="relative mt-5 block max-w-md">
        <Search size={18} className="pointer-events-none absolute left-4 top-1/2 -translate-y-1/2 text-neutral-400" />
        <input value={q} onChange={(e) => setQ(e.target.value)} placeholder={t("adminSearchArtist")} aria-label={t("adminSearchArtist")} className="field-input" />
      </label>

      <ul className="mt-6 space-y-2.5">
        {rows === null ? (
          [0, 1, 2, 3].map((i) => <li key={i} className="h-20 animate-pulse rounded-3xl bg-black/5" />)
        ) : shown.length === 0 ? (
          <li className="rounded-3xl border border-dashed border-black/10 px-6 py-14 text-center text-neutral-500">{t("adminNoArtists")}</li>
        ) : (
          shown.map((a) => (
            <li key={a.id} data-artist={a.name} className="flex items-center gap-4 rounded-3xl border border-black/5 bg-white p-3 pr-4 shadow-[0_2px_16px_-8px_rgba(0,0,0,0.15)]">
              <ArtistAvatar artist={{ id: a.id, name: a.name, photoUrl: a.photoUrl }} size={52} />
              <div className="min-w-0 flex-1">
                <p className="truncate font-semibold text-neutral-900">{a.name}</p>
                <p className="line-clamp-1 text-sm text-neutral-500">{a.bio || t("adminNoBio")}</p>
              </div>
              <button type="button" onClick={() => setEditing(a.id)} aria-label={`${t("adminEditArtist")}: ${a.name}`} title={t("adminEditArtist")} className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full text-neutral-500 transition hover:bg-neutral-100">
                <Pencil size={17} />
              </button>
            </li>
          ))
        )}
      </ul>
      {current && <EditArtistDialog artist={current} onClose={() => setEditing(null)} />}
    </div>
  );
}

// Same contract as the Flutter admin: the photo is resized in the browser and
// posted to the uploadArtistPhoto Cloud Function, which checks the caller is an
// admin and does the Storage write server-side (see functions/index.js).
async function uploadPhoto(artistId: string, file: File, idToken: string): Promise<void> {
  const blob = await resizeImageForUpload(file);
  const base64 = await new Promise<string>((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result).split(",")[1] ?? "");
    reader.onerror = () => reject(reader.error);
    reader.readAsDataURL(blob);
  });
  const res = await fetch(`${process.env.NEXT_PUBLIC_API_BASE ?? ""}/api/upload-artist-photo`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${idToken}` },
    body: JSON.stringify({ artistId, imageBase64: base64 }),
  });
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error(body.error || `Upload failed (${res.status})`);
  }
}

function EditArtistDialog({ artist, onClose }: { artist: Artist; onClose: () => void }) {
  const { t } = useT();
  const { user } = useAuth();
  const [bio, setBio] = useState(artist.bio);
  const [saving, setSaving] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);

  async function onPick(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    e.target.value = "";
    if (!file || !user) return;
    setUploading(true);
    setError(null);
    try {
      await uploadPhoto(artist.id, file, await user.getIdToken());
    } catch (err) {
      setError(err instanceof Error && err.message ? err.message : t("adminPhotoFailed"));
    } finally {
      setUploading(false);
    }
  }

  async function save() {
    setSaving(true);
    setError(null);
    try {
      await updateDoc(doc(db, "artists", artist.id), { bio: bio.trim() });
      onClose();
    } catch {
      setError(t("profileNameSaveFailed"));
      setSaving(false);
    }
  }

  return (
    <div className="fixed inset-0 z-[70] flex items-center justify-center bg-black/40 p-4 backdrop-blur-sm" onClick={onClose}>
      <div role="dialog" aria-modal="true" aria-label={t("adminEditArtist")} onClick={(e) => e.stopPropagation()} onKeyDown={(e) => e.key === "Escape" && onClose()} className="w-full max-w-md rounded-3xl bg-white p-6 shadow-2xl">
        <div className="flex items-center justify-between">
          <h2 className="truncate text-lg font-bold">{artist.name}</h2>
          <button type="button" onClick={onClose} aria-label={t("closeLabel")} className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-neutral-500 hover:bg-neutral-100">
            <X size={18} />
          </button>
        </div>
        <div className="mt-5 flex flex-col items-center">
          <div className="relative">
            <ArtistAvatar artist={artist} size={104} />
            {uploading && (
              <span className="absolute inset-0 flex items-center justify-center rounded-full bg-black/50 text-white">
                <Loader2 className="animate-spin" />
              </span>
            )}
          </div>
          <input ref={fileRef} type="file" accept="image/*" hidden onChange={onPick} />
          <button type="button" onClick={() => fileRef.current?.click()} disabled={uploading} className="mt-3 inline-flex items-center gap-2 rounded-full border border-black/15 px-4 py-2 text-sm font-semibold transition hover:bg-neutral-50 disabled:opacity-50">
            <Camera size={15} /> {artist.photoUrl ? t("adminChangePhoto") : t("adminUploadPhoto")}
          </button>
        </div>
        <label className="mt-5 block">
          <span className="mb-1.5 block text-sm font-semibold text-neutral-700">{t("adminBioLabel")}</span>
          <textarea value={bio} onChange={(e) => setBio(e.target.value)} rows={5} className="plain-input resize-none" />
        </label>
        {error && (
          <p role="alert" className="mt-3 rounded-xl bg-red-50 px-4 py-2.5 text-sm font-medium text-red-700">
            {error}
          </p>
        )}
        <div className="mt-5 flex justify-end gap-2">
          <button type="button" onClick={onClose} className="h-10 rounded-full px-5 text-sm font-medium hover:bg-neutral-100">
            {t("cancelButton")}
          </button>
          <button type="button" onClick={save} disabled={saving || uploading} className="h-10 rounded-full bg-black px-6 text-sm font-semibold text-white hover:bg-neutral-800 disabled:opacity-50">
            {saving ? t("adminSaving") : t("saveButton")}
          </button>
        </div>
      </div>
    </div>
  );
}

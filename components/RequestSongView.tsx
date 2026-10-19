"use client";

import { useState } from "react";
import Image from "next/image";
import Link from "next/link";
import { collection, doc, serverTimestamp, writeBatch } from "firebase/firestore";
import { CheckCircle2, ImageIcon, Loader2, ThumbsUp, X } from "lucide-react";
import { useAuth } from "@/components/AuthProvider";
import { useT } from "@/components/LanguageProvider";
import { db } from "@/lib/firebase/client";

// Simple, deliberately permissive format check — just enough to reject an
// obvious mistake (a pasted YouTube link, plain text) without rejecting any
// real-world email address.
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const LYRICS_MIN_LENGTH = 200;

// "Can't work out the chords? Send the song and lyrics and we'll add them."
// Open to everyone, no account needed. The requester's contact goes into a
// private subdocument only an admin can read; the public request holds just
// the link and the lyrics (see firestore.rules).
//
// Email + Facebook are two separate required fields (not one free-text
// "contact" field) and lyrics has a minimum length — added 2026-10-14 after
// the owner found requests with a YouTube link pasted into the old contact
// field, with no real way to reply, and others too short to be real lyrics.
export default function RequestSongView() {
  const { t } = useT();
  const { user } = useAuth();
  const [link, setLink] = useState("");
  const [lyrics, setLyrics] = useState("");
  const [email, setEmail] = useState("");
  const [facebook, setFacebook] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState(false);
  const [showExample, setShowExample] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!link.trim() || !lyrics.trim() || !email.trim() || !facebook.trim()) return setError(t("requestSongPleaseFillFields"));
    if (!EMAIL_RE.test(email.trim())) return setError(t("requestSongInvalidEmailMessage"));
    if (lyrics.trim().length < LYRICS_MIN_LENGTH) return setError(t("requestSongLyricsTooShortMessage"));
    setBusy(true);
    setError(null);
    try {
      const ref = doc(collection(db, "songRequests"));
      const createdAt = serverTimestamp();
      const batch = writeBatch(db);
      batch.set(ref, { songLink: link.trim(), lyrics: lyrics.trim(), voteCount: 0, createdAt });
      // requesterUid only when signed in, so a fulfilled request can notify them.
      batch.set(doc(ref, "private", "info"), {
        email: email.trim(),
        facebookLink: facebook.trim(),
        createdAt,
        ...(user ? { requesterUid: user.uid } : {}),
      });
      await batch.commit();
      setDone(true);
    } catch {
      setError(t("postFailedMessage"));
    } finally {
      setBusy(false);
    }
  }

  if (done) {
    return (
      <div className="mx-auto flex max-w-md flex-col items-center px-4 py-24 text-center">
        <span className="flex h-20 w-20 items-center justify-center rounded-full bg-emerald-50 text-emerald-600">
          <CheckCircle2 size={40} />
        </span>
        <p className="mt-6 text-lg font-semibold text-neutral-800">{t("requestSongSuccessMessage")}</p>
        <Link href="/song-requests/vote" className="mt-8 flex h-11 items-center gap-2 rounded-full bg-black px-6 text-sm font-semibold text-white">
          <ThumbsUp size={16} /> {t("voteSongRequestsTitle")}
        </Link>
      </div>
    );
  }

  return (
    <div className="mx-auto w-full max-w-xl px-4 pb-24 pt-8 sm:px-6">
      <h1 className="text-3xl font-extrabold tracking-tight">{t("requestSongLabel")}</h1>
      <p className="mt-3 leading-relaxed text-neutral-600">{t("requestSongIntro")}</p>
      <Link href="/song-requests/vote" className="mt-4 inline-flex items-center gap-2 rounded-full border border-black/15 px-5 py-2.5 text-sm font-semibold transition hover:bg-neutral-50">
        <ThumbsUp size={15} /> {t("voteSongRequestsTitle")}
      </Link>

      <form onSubmit={submit} noValidate className="mt-8 space-y-5">
        <label className="block">
          <span className="mb-1.5 block text-sm font-semibold text-neutral-700">{t("requestSongLinkLabel")}</span>
          <input value={link} onChange={(e) => setLink(e.target.value)} maxLength={1999} inputMode="url" className="plain-input" />
        </label>

        <div>
          <label className="block">
            <span className="mb-1.5 block text-sm font-semibold text-neutral-700">{t("requestSongLyricsLabel")}</span>
            <textarea value={lyrics} onChange={(e) => setLyrics(e.target.value)} maxLength={19999} rows={10} placeholder={t("requestSongLyricsHint")} className="plain-input resize-y" />
          </label>
          <button type="button" onClick={() => setShowExample(true)} className="mt-2 inline-flex items-center gap-1.5 text-sm font-medium text-blue-600 hover:underline">
            <ImageIcon size={15} /> {t("viewExampleLabel")}
          </button>
        </div>

        <label className="block">
          <span className="mb-1.5 block text-sm font-semibold text-neutral-700">{t("requestSongEmailLabel")}</span>
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            maxLength={254}
            inputMode="email"
            placeholder={t("requestSongEmailHint")}
            className="plain-input"
          />
        </label>

        <label className="block">
          <span className="mb-1.5 block text-sm font-semibold text-neutral-700">{t("requestSongFacebookLabel")}</span>
          <input
            value={facebook}
            onChange={(e) => setFacebook(e.target.value)}
            maxLength={499}
            inputMode="url"
            placeholder={t("requestSongFacebookHint")}
            className="plain-input"
          />
        </label>

        {error && (
          <p role="alert" className="rounded-xl bg-red-50 px-4 py-3 text-sm font-medium text-red-700">
            {error}
          </p>
        )}
        <button type="submit" disabled={busy} className="flex h-12 w-full items-center justify-center gap-2 rounded-2xl bg-black font-bold text-white shadow-lg transition hover:scale-[1.01] disabled:opacity-60">
          {busy && <Loader2 size={18} className="animate-spin" />}
          {t("requestSongSubmitButton")}
        </button>
      </form>

      {showExample && (
        <div className="fixed inset-0 z-[70] flex items-center justify-center bg-black/60 p-4 backdrop-blur-sm" onClick={() => setShowExample(false)}>
          <div role="dialog" aria-modal="true" aria-label={t("viewExampleLabel")} onClick={(e) => e.stopPropagation()} onKeyDown={(e) => e.key === "Escape" && setShowExample(false)} className="relative max-h-[90vh] max-w-[26rem] overflow-auto rounded-2xl bg-white shadow-2xl">
            <button type="button" onClick={() => setShowExample(false)} autoFocus aria-label={t("closeLabel")} className="absolute right-2 top-2 z-10 flex h-9 w-9 items-center justify-center rounded-full bg-black/60 text-white">
              <X size={18} />
            </button>
            <Image src="/images/request-example.png" alt={t("requestExampleAlt")} width={840} height={1400} className="h-auto w-full" />
          </div>
        </div>
      )}
    </div>
  );
}

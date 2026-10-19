"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { collection, deleteDoc, doc, onSnapshot, orderBy, query, serverTimestamp, setDoc } from "firebase/firestore";
import { CheckCircle2, ExternalLink, ListMusic, Plus, ThumbsUp } from "lucide-react";
import { useAuth } from "@/components/AuthProvider";
import { useT } from "@/components/LanguageProvider";
import { db } from "@/lib/firebase/client";

type Request = { id: string; songLink: string; lyrics: string; voteCount: number; fulfilledSongId: string };

// Everyone's song requests, most-voted first. Voting needs an account (one
// person, one vote per request).
export default function VoteRequestsView() {
  const { t } = useT();
  const [rows, setRows] = useState<Request[] | null>(null);

  useEffect(() => {
    const q = query(collection(db, "songRequests"), orderBy("voteCount", "desc"));
    return onSnapshot(q, (snap) =>
      setRows(
        snap.docs.map((d) => {
          const x = d.data();
          return {
            id: d.id,
            songLink: typeof x.songLink === "string" ? x.songLink : "",
            lyrics: typeof x.lyrics === "string" ? x.lyrics : "",
            voteCount: typeof x.voteCount === "number" ? x.voteCount : 0,
            fulfilledSongId: x.status === "fulfilled" && typeof x.fulfilledSongId === "string" ? x.fulfilledSongId : "",
          };
        }),
      ),
    );
  }, []);

  return (
    <div className="mx-auto w-full max-w-3xl px-4 pb-24 pt-8 sm:px-6">
      <div className="flex items-center justify-between gap-4">
        <h1 className="text-3xl font-extrabold tracking-tight">{t("voteSongRequestsTitle")}</h1>
        <Link href="/request-song" className="flex h-11 shrink-0 items-center gap-2 rounded-full bg-black px-5 text-sm font-semibold text-white transition hover:scale-[1.03]">
          <Plus size={16} /> {t("newRequestButton")}
        </Link>
      </div>
      <p className="mt-2 text-neutral-500">{t("requestSongVoteIntro")}</p>

      <ul className="mt-8 space-y-3">
        {rows === null ? (
          [0, 1, 2].map((i) => <li key={i} className="h-28 animate-pulse rounded-3xl bg-black/5" />)
        ) : rows.length === 0 ? (
          <li className="flex flex-col items-center rounded-3xl border border-dashed border-black/10 px-6 py-16 text-center text-neutral-500">
            <ListMusic size={40} className="text-neutral-300" />
            <p className="mt-4 max-w-xs">{t("noSongRequestsYet")}</p>
          </li>
        ) : (
          rows.map((r) => (
            <li key={r.id} className="flex gap-4 rounded-3xl border border-black/5 bg-white p-4 shadow-[0_2px_16px_-8px_rgba(0,0,0,0.15)]">
              <VoteButton requestId={r.id} count={r.voteCount} />
              <div className="min-w-0 flex-1">
                <a href={safeHref(r.songLink)} target="_blank" rel="noopener noreferrer" className="flex items-center gap-1.5 truncate font-semibold text-blue-600 hover:underline">
                  <ExternalLink size={14} className="shrink-0" />
                  <span className="truncate">{r.songLink}</span>
                </a>
                <p className="mt-1.5 line-clamp-3 whitespace-pre-line text-sm text-neutral-600">{preview(r.lyrics)}</p>
                {r.fulfilledSongId && (
                  <Link href={`/songbook/song/${r.fulfilledSongId}`} className="mt-2 inline-flex items-center gap-1.5 rounded-full bg-emerald-50 px-3 py-1 text-xs font-semibold text-emerald-700">
                    <CheckCircle2 size={13} /> {t("requestFulfilledLabel")}
                  </Link>
                )}
              </div>
            </li>
          ))
        )}
      </ul>
    </div>
  );
}

// Only http(s) links are followed — a request is user-submitted text.
function safeHref(link: string): string {
  return /^https?:\/\//i.test(link.trim()) ? link.trim() : `https://${link.trim()}`.replace(/^https:\/\/(javascript|data):/i, "#");
}

function preview(lyrics: string): string {
  const chars = Array.from(lyrics);
  return chars.length > 140 ? chars.slice(0, 140).join("") + "…" : lyrics;
}

function VoteButton({ requestId, count }: { requestId: string; count: number }) {
  const { t } = useT();
  const { user } = useAuth();
  const uid = user?.uid;
  const [voted, setVoted] = useState(false);

  useEffect(() => {
    if (!uid) return;
    return onSnapshot(doc(db, "songRequests", requestId, "votes", uid), (s) => setVoted(s.exists()));
  }, [uid, requestId]);

  const box = "flex w-14 shrink-0 flex-col items-center justify-center gap-0.5 rounded-2xl py-2 text-sm font-bold";
  if (!uid) {
    return (
      <Link href="/login?next=/song-requests/vote" title={t("loginToVoteMessage")} aria-label={t("loginToVoteMessage")} className={`${box} bg-neutral-100 text-neutral-500 transition hover:bg-neutral-200`}>
        <ThumbsUp size={18} />
        {count}
      </Link>
    );
  }
  const ref = doc(db, "songRequests", requestId, "votes", uid);
  return (
    <button
      type="button"
      onClick={() => (voted ? deleteDoc(ref) : setDoc(ref, { createdAt: serverTimestamp() })).catch(() => {})}
      aria-pressed={voted}
      aria-label={voted ? t("removeVoteLabel") : t("voteLabel")}
      title={voted ? t("removeVoteLabel") : t("voteLabel")}
      className={`${box} transition ${voted ? "bg-blue-600 text-white shadow-md" : "bg-neutral-100 text-neutral-600 hover:bg-blue-50 hover:text-blue-600"}`}
    >
      <ThumbsUp size={18} className={voted ? "fill-current" : ""} />
      {count}
    </button>
  );
}

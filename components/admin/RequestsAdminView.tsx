"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { collection, deleteDoc, doc, getDoc, onSnapshot, orderBy, query, updateDoc } from "firebase/firestore";
import { CheckCircle2, ChevronDown, Link2, Mail, ThumbsUp, Trash2 } from "lucide-react";
import { useLang } from "@/components/admin/useLang";
import { useT } from "@/components/LanguageProvider";
import SongPicker from "@/components/SongPicker";
import { useDialog } from "@/components/useDialog";
import { db } from "@/lib/firebase/client";
import { formatDate } from "@/lib/format";
import { useSongsIndex } from "@/lib/songs-index";

type Req = { id: string; songLink: string; lyrics: string; votes: number; createdAt: Date | null; fulfilledId: string; fulfilledName: string; fulfilled: boolean };

const href = (link: string) => (/^https?:\/\//i.test(link.trim()) ? link.trim() : `https://${link.trim()}`);

// Song requests, oldest first (first come, first served). The requester's
// contact lives in a private subdocument that only admins can read.
export default function RequestsAdminView() {
  const { t } = useT();
  const lang = useLang();
  const { ask, dialog } = useDialog();
  const { songs } = useSongsIndex();
  const [rows, setRows] = useState<Req[] | null>(null);
  const [picking, setPicking] = useState<string | null>(null);

  useEffect(() => {
    return onSnapshot(query(collection(db, "songRequests"), orderBy("createdAt", "asc")), (snap) =>
      setRows(
        snap.docs.map((d) => {
          const x = d.data();
          return {
            id: d.id,
            songLink: typeof x.songLink === "string" ? x.songLink : "",
            lyrics: typeof x.lyrics === "string" ? x.lyrics : "",
            votes: typeof x.voteCount === "number" ? x.voteCount : 0,
            createdAt: typeof x.createdAt?.toDate === "function" ? x.createdAt.toDate() : null,
            fulfilledId: typeof x.fulfilledSongId === "string" ? x.fulfilledSongId : "",
            fulfilledName: typeof x.fulfilledSongName === "string" ? x.fulfilledSongName : "",
            fulfilled: x.status === "fulfilled",
          };
        }),
      ),
    );
  }, []);

  async function remove(id: string) {
    const ok = await ask({
      title: t("deleteRequestConfirmTitle"),
      message: t("deleteRequestConfirmMessage"),
      actions: [
        { label: t("cancelButton"), value: false },
        { label: t("deleteLabel"), value: true, tone: "danger" },
      ],
    });
    if (!ok) return;
    // The private contact goes first, then the request itself.
    await deleteDoc(doc(db, "songRequests", id, "private", "info")).catch(() => {});
    await deleteDoc(doc(db, "songRequests", id)).catch(() => {});
  }

  return (
    <div>
      <h1 className="text-3xl font-extrabold tracking-tight">{t("adminSongRequestsLabel")}</h1>
      <ul className="mt-6 space-y-3">
        {rows === null ? (
          [0, 1, 2].map((i) => <li key={i} className="h-32 animate-pulse rounded-3xl bg-black/5" />)
        ) : rows.length === 0 ? (
          <li className="rounded-3xl border border-dashed border-black/10 px-6 py-16 text-center text-neutral-500">{t("noSongRequestsYet")}</li>
        ) : (
          rows.map((r, i) => (
            <RequestCard key={r.id} index={i} r={r} lang={lang} onFulfil={() => setPicking(r.id)} onDelete={() => remove(r.id)} />
          ))
        )}
      </ul>

      {picking && (
        <SongPicker
          songs={songs}
          chosen={new Set()}
          title={t("adminPickSongTitle")}
          actionLabel={t("adminPickSongAction")}
          onAdd={async (songId) => {
            const song = songs?.find((s) => s.id === songId);
            await updateDoc(doc(db, "songRequests", picking), { status: "fulfilled", fulfilledSongId: songId, fulfilledSongName: song?.name ?? "" }).catch(() => {});
            setPicking(null);
          }}
          onClose={() => setPicking(null)}
        />
      )}
      {dialog}
    </div>
  );
}

function RequestCard({ r, index, lang, onFulfil, onDelete }: { r: Req; index: number; lang: ReturnType<typeof useLang>; onFulfil: () => void; onDelete: () => void }) {
  const { t } = useT();
  const [email, setEmail] = useState("");
  const [facebook, setFacebook] = useState("");
  const [expanded, setExpanded] = useState(false);

  useEffect(() => {
    let alive = true;
    getDoc(doc(db, "songRequests", r.id, "private", "info"))
      .then((s) => {
        if (!alive) return;
        const data = s.data();
        // `contact` is the pre-2026-10-14 shape — still read for requests
        // submitted before the email/Facebook split, so old entries in the
        // admin queue don't just go blank.
        const legacy = typeof data?.contact === "string" ? data.contact : "";
        setEmail(typeof data?.email === "string" ? data.email : legacy.includes("@") ? legacy : "");
        setFacebook(typeof data?.facebookLink === "string" ? data.facebookLink : !legacy.includes("@") ? legacy : "");
      })
      .catch(() => {});
    return () => {
      alive = false;
    };
  }, [r.id]);

  return (
    <li className="rounded-3xl border border-black/5 bg-white p-5 shadow-[0_2px_16px_-8px_rgba(0,0,0,0.15)]">
      <div className="flex items-center gap-3">
        <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-neutral-100 text-sm font-bold text-neutral-500">{index + 1}</span>
        <span className="flex items-center gap-1.5 text-sm font-semibold text-neutral-700">
          <ThumbsUp size={14} /> {t("adminVotesCount", { count: r.votes })}
        </span>
        {r.createdAt && <span className="text-sm text-neutral-400">{formatDate(r.createdAt, lang)}</span>}
        <span className="ml-auto flex items-center gap-1">
          {!r.fulfilled && (
            <button type="button" onClick={onFulfil} aria-label={t("adminMarkFulfilled")} title={t("adminMarkFulfilled")} className="flex h-9 w-9 items-center justify-center rounded-full text-emerald-600 transition hover:bg-emerald-50">
              <CheckCircle2 size={18} />
            </button>
          )}
          <button type="button" onClick={onDelete} aria-label={t("deleteLabel")} title={t("deleteLabel")} className="flex h-9 w-9 items-center justify-center rounded-full text-neutral-400 transition hover:bg-red-50 hover:text-red-600">
            <Trash2 size={17} />
          </button>
        </span>
      </div>

      {r.fulfilled && (
        <p className="mt-3">
          <Link href={r.fulfilledId ? `/songbook/song/${r.fulfilledId}` : "#"} className="inline-flex items-center gap-1.5 rounded-full bg-emerald-50 px-3 py-1 text-sm font-semibold text-emerald-700">
            <CheckCircle2 size={14} /> {t("adminFulfilledSong", { name: r.fulfilledName })}
          </Link>
        </p>
      )}

      <a href={href(r.songLink)} target="_blank" rel="noopener noreferrer" className="mt-3 flex items-center gap-2 truncate text-sm font-medium text-blue-600 hover:underline">
        <Link2 size={15} className="shrink-0" /> <span className="truncate">{r.songLink}</span>
      </a>
      {email && (
        <a href={`mailto:${email}`} className="mt-1.5 flex items-center gap-2 truncate text-sm font-medium text-blue-600 hover:underline">
          <Mail size={15} className="shrink-0" /> <span className="truncate">{email}</span>
        </a>
      )}
      {facebook && (
        <a href={href(facebook)} target="_blank" rel="noopener noreferrer" className="mt-1.5 flex items-center gap-2 truncate text-sm font-medium text-blue-600 hover:underline">
          <Link2 size={15} className="shrink-0" /> <span className="truncate">{facebook}</span>
        </a>
      )}
      <button type="button" onClick={() => setExpanded((e) => !e)} aria-expanded={expanded} aria-label={t("adminExpandLyrics")} className="mt-3 block w-full text-left">
        <span className={`block whitespace-pre-line text-sm text-neutral-700 ${expanded ? "" : "line-clamp-3"}`}>{r.lyrics}</span>
        <ChevronDown size={16} className={`mt-1 text-neutral-400 transition ${expanded ? "rotate-180" : ""}`} />
      </button>
    </li>
  );
}

"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { collection, deleteDoc, doc, onSnapshot, orderBy, query, updateDoc } from "firebase/firestore";
import { AlertTriangle, CheckCircle2, ExternalLink, Trash2 } from "lucide-react";
import { useLang } from "@/components/admin/useLang";
import { useT } from "@/components/LanguageProvider";
import { useDialog } from "@/components/useDialog";
import { db } from "@/lib/firebase/client";
import { formatDate } from "@/lib/format";

type Report = { id: string; songId: string; songName: string; type: string; description: string; resolved: boolean; createdAt: Date | null };

const TYPE_KEYS: Record<string, string> = {
  wrongChords: "issueTypeWrongChords",
  wrongLyrics: "issueTypeWrongLyrics",
  other: "issueTypeOther",
};

// "This song's chords/lyrics look wrong" reports from the reader, oldest first.
export default function IssuesAdminView() {
  const { t } = useT();
  const lang = useLang();
  const { ask, dialog } = useDialog();
  const [rows, setRows] = useState<Report[] | null>(null);

  useEffect(() => {
    return onSnapshot(query(collection(db, "songIssueReports"), orderBy("createdAt", "asc")), (snap) =>
      setRows(
        snap.docs.map((d) => {
          const x = d.data();
          return {
            id: d.id,
            songId: typeof x.songId === "string" ? x.songId : "",
            songName: typeof x.songName === "string" ? x.songName : "",
            type: typeof x.issueType === "string" ? x.issueType : "other",
            description: typeof x.description === "string" ? x.description : "",
            resolved: x.resolved === true,
            createdAt: typeof x.createdAt?.toDate === "function" ? x.createdAt.toDate() : null,
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
    if (ok) await deleteDoc(doc(db, "songIssueReports", id)).catch(() => {});
  }

  return (
    <div>
      <h1 className="text-3xl font-extrabold tracking-tight">{t("adminIssueReportsLabel")}</h1>
      <ul className="mt-6 space-y-3">
        {rows === null ? (
          [0, 1, 2].map((i) => <li key={i} className="h-28 animate-pulse rounded-3xl bg-black/5" />)
        ) : rows.length === 0 ? (
          <li className="flex flex-col items-center rounded-3xl border border-dashed border-black/10 px-6 py-16 text-center text-neutral-500">
            <AlertTriangle size={40} className="text-neutral-300" />
            <p className="mt-4">{t("noIssueReportsYet")}</p>
          </li>
        ) : (
          rows.map((r) => (
            <li key={r.id} className={`rounded-3xl border border-black/5 bg-white p-5 shadow-[0_2px_16px_-8px_rgba(0,0,0,0.15)] ${r.resolved ? "opacity-60" : ""}`}>
              <div className="flex items-start justify-between gap-3">
                <div className="min-w-0">
                  {r.songId ? (
                    <Link href={`/songbook/song/${r.songId}`} className="inline-flex max-w-full items-center gap-1.5 font-semibold text-blue-600 hover:underline">
                      <span className="truncate">{r.songName || r.songId}</span> <ExternalLink size={14} className="shrink-0" />
                    </Link>
                  ) : (
                    <span className="font-semibold">{r.songName}</span>
                  )}
                  <div className="mt-1.5 flex flex-wrap items-center gap-2 text-sm">
                    <span className="rounded-full bg-amber-50 px-3 py-0.5 text-xs font-semibold text-amber-700">{t(TYPE_KEYS[r.type] ?? "issueTypeOther")}</span>
                    {r.createdAt && <span className="text-neutral-400">{formatDate(r.createdAt, lang)}</span>}
                  </div>
                </div>
                <button type="button" onClick={() => remove(r.id)} aria-label={t("deleteLabel")} title={t("deleteLabel")} className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-neutral-400 transition hover:bg-red-50 hover:text-red-600">
                  <Trash2 size={17} />
                </button>
              </div>
              {r.description && <p className="mt-3 whitespace-pre-line text-sm text-neutral-700">{r.description}</p>}
              <div className="mt-4">
                {r.resolved ? (
                  <span className="inline-flex items-center gap-1.5 rounded-full bg-emerald-50 px-3 py-1 text-xs font-semibold text-emerald-700">
                    <CheckCircle2 size={13} /> {t("resolvedLabel")}
                  </span>
                ) : (
                  <button type="button" onClick={() => updateDoc(doc(db, "songIssueReports", r.id), { resolved: true }).catch(() => {})} className="inline-flex items-center gap-1.5 rounded-full border border-emerald-600/30 px-4 py-1.5 text-sm font-semibold text-emerald-700 transition hover:bg-emerald-50">
                    <CheckCircle2 size={15} /> {t("markResolvedLabel")}
                  </button>
                )}
              </div>
            </li>
          ))
        )}
      </ul>
      {dialog}
    </div>
  );
}

"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { doc, getDoc } from "firebase/firestore";
import { useAuth } from "@/components/AuthProvider";
import { useT } from "@/components/LanguageProvider";
import SongEditor, { type EditorInitial, type EditorOptions } from "@/components/SongEditor";
import { db } from "@/lib/firebase/client";
import { useRequireAuth } from "@/lib/use-require-auth";

type Load = { state: "loading" } | { state: "denied" } | { state: "ready"; initial: EditorInitial | null };

// /submit-song            -> a new submission
// /submit-song?edit=<id>  -> the author's own draft / rejected song, or (for
//                            an admin) any song, opened pre-filled.
export default function SubmitSongView({ options }: { options: EditorOptions }) {
  const editId = useSearchParams().get("edit");
  const user = useRequireAuth(editId ? `/submit-song?edit=${editId}` : "/submit-song");
  const { profile, isAdmin } = useAuth();
  const { t } = useT();
  const uid = user?.uid;
  // The load result is tagged with the id it was loaded for, so a stale
  // result is never shown for a different ?edit= value.
  const [loaded, setLoaded] = useState<{ id: string; result: Load } | null>(null);

  useEffect(() => {
    if (!uid || !editId) return;
    let cancelled = false;
    getDoc(doc(db, "songs", editId))
      .then((snap) => {
        if (cancelled) return;
        const data = snap.data();
        let result: Load = { state: "denied" };
        if (snap.exists() && data) {
          const own = data.authorId === uid;
          // Authors may reopen their own draft or rejected song; an admin can
          // edit and release anything. Everything else is read-only.
          if (own && data.status === "draft") result = { state: "ready", initial: { id: snap.id, mode: "draft", data } };
          else if (own && data.status === "rejected") result = { state: "ready", initial: { id: snap.id, mode: "resubmit", data } };
          else if (isAdmin) result = { state: "ready", initial: { id: snap.id, mode: "admin", data } };
        }
        setLoaded({ id: editId, result });
      })
      .catch(() => !cancelled && setLoaded({ id: editId, result: { state: "denied" } }));
    return () => {
      cancelled = true;
    };
  }, [uid, editId, isAdmin]);

  if (!user || !profile) return <Skeleton />;

  if (profile.isBlocked) {
    return <Notice title={t("submissionsUnavailableTitle")} body={t("submissionsUnavailableBody")} />;
  }

  if (!editId) return <SongEditor key="new" options={options} initial={null} />;

  const result = loaded?.id === editId ? loaded.result : { state: "loading" as const };
  if (result.state === "loading") return <Skeleton />;
  if (result.state === "denied") {
    return <Notice title={t("songOpenFailedTitle")} body={t("songOpenFailedBody")} />;
  }
  return <SongEditor key={editId} options={options} initial={result.initial} />;
}

function Skeleton() {
  return (
    <div className="mx-auto max-w-6xl px-4 py-10">
      <div className="h-10 w-56 animate-pulse rounded-xl bg-black/5" />
      <div className="mt-6 h-72 animate-pulse rounded-3xl bg-black/5" />
    </div>
  );
}

function Notice({ title, body }: { title: string; body: string }) {
  const { t } = useT();
  return (
    <div className="mx-auto flex max-w-md flex-col items-center px-4 py-24 text-center">
      <h1 className="text-2xl font-extrabold tracking-tight">{title}</h1>
      <p className="mt-2 text-neutral-500">{body}</p>
      <Link href="/my-songs" className="mt-8 flex h-11 items-center rounded-full bg-black px-6 text-sm font-semibold text-white">
        {t("mySongsTitle")}
      </Link>
    </div>
  );
}

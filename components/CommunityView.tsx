"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  getCountFromServer,
  limit,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  where,
} from "firebase/firestore";
import { Crown, Loader2, MessageCircle, Plus, Star, Trash2, X } from "lucide-react";
import { useAuth } from "@/components/AuthProvider";
import { useT } from "@/components/LanguageProvider";
import UserAvatar from "@/components/UserAvatar";
import { useDialog } from "@/components/useDialog";
import { badgeColor, badgeTier } from "@/lib/badge";
import { db } from "@/lib/firebase/client";
import { formatDate } from "@/lib/format";
import { gradientFor } from "@/lib/palette";

type Thread = { id: string; title: string; body: string; authorId: string; authorName: string; createdAt: Date | null };
type Contributor = { id: string; name: string; photoUrl: string; count: number };
type Tab = "threads" | "top";

// Discussions (threads with comments) and the Top Contributors leaderboard.
// Anyone can read; posting needs an account (and not to be blocked).
export default function CommunityView() {
  const { t, lang } = useT();
  const { user, isAdmin, status } = useAuth();
  const router = useRouter();
  const { ask, dialog } = useDialog();
  const [tab, setTab] = useState<Tab>("threads");
  const [threads, setThreads] = useState<Thread[] | null>(null);
  const [people, setPeople] = useState<Contributor[] | null>(null);
  const [composing, setComposing] = useState(false);

  useEffect(() => {
    const q = query(collection(db, "communityThreads"), orderBy("createdAt", "desc"), limit(100));
    return onSnapshot(q, (snap) =>
      setThreads(
        snap.docs.map((d) => {
          const x = d.data();
          return {
            id: d.id,
            title: typeof x.title === "string" ? x.title : "",
            body: typeof x.body === "string" ? x.body : "",
            authorId: typeof x.authorId === "string" ? x.authorId : "",
            authorName: typeof x.authorName === "string" ? x.authorName : "",
            createdAt: typeof x.createdAt?.toDate === "function" ? x.createdAt.toDate() : null,
          };
        }),
      ),
    );
  }, []);

  useEffect(() => {
    if (tab !== "top" || people) return;
    const q = query(collection(db, "users"), where("approvedSongCount", ">", 0), orderBy("approvedSongCount", "desc"), limit(50));
    return onSnapshot(q, (snap) =>
      setPeople(
        snap.docs.map((d) => ({
          id: d.id,
          name: typeof d.data().displayName === "string" ? d.data().displayName : "",
          photoUrl: typeof d.data().photoUrl === "string" ? d.data().photoUrl : "",
          count: typeof d.data().approvedSongCount === "number" ? d.data().approvedSongCount : 0,
        })),
      ),
    );
  }, [tab, people]);

  function startThread() {
    if (status !== "signedIn") return router.push("/login?next=/community");
    setComposing(true);
  }

  async function remove(id: string) {
    const ok = await ask({
      title: t("deletePostConfirmTitle"),
      message: t("deletePostConfirmMessage"),
      actions: [
        { label: t("cancelButton"), value: false },
        { label: t("deleteLabel"), value: true, tone: "danger" },
      ],
    });
    if (ok) await deleteDoc(doc(db, "communityThreads", id)).catch(() => {});
  }

  return (
    <div className="mx-auto w-full max-w-3xl px-4 pb-24 pt-8 sm:px-6">
      <div className="flex items-center justify-between gap-4">
        <h1 className="text-3xl font-extrabold tracking-tight">{t("communityLabel")}</h1>
        <button
          type="button"
          onClick={startThread}
          className="flex h-11 items-center gap-2 rounded-full bg-black px-5 text-sm font-semibold text-white transition hover:scale-[1.03]"
        >
          <Plus size={16} /> {t("newThreadButton")}
        </button>
      </div>

      <div role="tablist" className="mt-6 inline-flex rounded-full bg-neutral-100 p-1">
        {(
          [
            ["threads", "discussionsTabLabel"],
            ["top", "topContributorsTabLabel"],
          ] as const
        ).map(([id, key]) => (
          <button
            key={id}
            type="button"
            role="tab"
            aria-selected={tab === id}
            onClick={() => setTab(id)}
            className={`rounded-full px-5 py-2 text-sm font-semibold transition ${tab === id ? "bg-black text-white shadow" : "text-neutral-600 hover:text-black"}`}
          >
            {t(key)}
          </button>
        ))}
      </div>

      {tab === "threads" ? (
        <div className="mt-6 space-y-3">
          {threads === null ? (
            [0, 1, 2].map((i) => <div key={i} className="h-32 animate-pulse rounded-3xl bg-black/5" />)
          ) : threads.length === 0 ? (
            <Empty icon={<MessageCircle size={40} />} text={t("noThreadsYetMessage")} />
          ) : (
            threads.map((th) => {
              const canDelete = isAdmin || (!!user && user.uid === th.authorId);
              const color = gradientFor(th.authorName || "?");
              return (
                <article key={th.id} className="group relative overflow-hidden rounded-3xl border border-black/5 bg-white shadow-[0_2px_16px_-8px_rgba(0,0,0,0.15)] transition hover:shadow-[0_10px_30px_-12px_rgba(0,0,0,0.25)]">
                  <span className="absolute inset-y-0 left-0 w-1.5" style={{ background: color }} />
                  <Link href={`/community/thread/${th.id}`} className="block p-5 pl-6">
                    <div className="flex items-start gap-3 pr-10">
                      <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full font-bold text-white" style={{ background: color }}>
                        {Array.from(th.authorName.trim())[0]?.toUpperCase() ?? "?"}
                      </span>
                      <div className="min-w-0">
                        <h2 className="truncate text-[17px] font-bold text-neutral-900">{th.title}</h2>
                        <p className="text-xs text-neutral-500">
                          {th.authorName}
                          {th.createdAt && ` · ${formatDate(th.createdAt, lang)}`}
                        </p>
                      </div>
                    </div>
                    <p className="mt-3 line-clamp-2 whitespace-pre-line text-neutral-600">{th.body}</p>
                    <CommentCount threadId={th.id} />
                  </Link>
                  {canDelete && (
                    <button
                      type="button"
                      onClick={() => remove(th.id)}
                      aria-label={t("deleteLabel")}
                      title={t("deleteLabel")}
                      className="absolute right-3 top-3 flex h-9 w-9 items-center justify-center rounded-full text-neutral-400 transition hover:bg-red-50 hover:text-red-600"
                    >
                      <Trash2 size={17} />
                    </button>
                  )}
                </article>
              );
            })
          )}
        </div>
      ) : (
        <ol className="mt-6 space-y-2.5">
          {people === null ? (
            [0, 1, 2].map((i) => <li key={i} className="h-20 animate-pulse rounded-3xl bg-black/5" />)
          ) : people.length === 0 ? (
            <li>
              <Empty icon={<Crown size={40} />} text={t("noContributorsYetMessage")} />
            </li>
          ) : (
            people.map((p, i) => {
              const tier = badgeTier(p.count);
              const c = badgeColor(tier);
              return (
                <li key={p.id} className="flex items-center gap-4 rounded-3xl border border-black/5 bg-white p-3 pr-5 shadow-[0_2px_16px_-8px_rgba(0,0,0,0.15)]">
                  <span className={`flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-sm font-extrabold ${i < 3 ? "bg-amber-100 text-amber-700" : "bg-neutral-100 text-neutral-500"}`}>{i + 1}</span>
                  <UserAvatar uid={p.id} name={p.name} photoUrl={p.photoUrl} size={44} />
                  <span className="min-w-0 flex-1">
                    <span className="flex items-center gap-1.5 font-semibold text-neutral-900">
                      <span className="truncate">{p.name || "—"}</span>
                      {tier > 0 && c && <Star size={14} fill={c} stroke="none" className="shrink-0" />}
                    </span>
                  </span>
                  <span className="shrink-0 text-sm font-medium text-neutral-500">{songsLabel(t, lang, p.count)}</span>
                </li>
              );
            })
          )}
        </ol>
      )}

      {composing && <NewThreadDialog onClose={() => setComposing(false)} />}
      {dialog}
    </div>
  );
}

function songsLabel(t: (k: string, v?: Record<string, string | number>) => string, lang: string, n: number) {
  return t(n === 1 && lang === "en" ? "songCountLabelSingular" : "songsCountLabel", { count: n });
}

function Empty({ icon, text }: { icon: React.ReactNode; text: string }) {
  return (
    <div className="flex flex-col items-center rounded-3xl border border-dashed border-black/10 px-6 py-16 text-center text-neutral-500">
      <span className="text-neutral-300">{icon}</span>
      <p className="mt-4 max-w-xs">{text}</p>
    </div>
  );
}

// "N comments" — one cheap aggregate count per card, not the comments themselves.
function CommentCount({ threadId }: { threadId: string }) {
  const { t, lang } = useT();
  const [n, setN] = useState<number | null>(null);
  useEffect(() => {
    let alive = true;
    getCountFromServer(collection(db, "communityThreads", threadId, "comments"))
      .then((s) => alive && setN(s.data().count))
      .catch(() => {});
    return () => {
      alive = false;
    };
  }, [threadId]);
  if (n === null) return <div className="mt-3 h-4" />;
  return (
    <p className="mt-3 flex items-center gap-1.5 text-xs font-medium text-neutral-500">
      <MessageCircle size={14} /> {n === 1 && lang === "en" ? t("commentCountOne") : t("commentCount", { count: n })}
    </p>
  );
}

function NewThreadDialog({ onClose }: { onClose: () => void }) {
  const { t } = useT();
  const { user, profile } = useAuth();
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function post() {
    if (!user || !title.trim() || !body.trim()) return setError(t("pleaseFillAllFields"));
    setBusy(true);
    setError(null);
    try {
      await addDoc(collection(db, "communityThreads"), {
        title: title.trim(),
        body: body.trim(),
        authorId: user.uid,
        authorName: profile?.displayName || user.displayName || "",
        createdAt: serverTimestamp(),
      });
      onClose();
    } catch {
      setError(t("postFailedMessage"));
      setBusy(false);
    }
  }

  return (
    <div className="fixed inset-0 z-[70] flex items-center justify-center bg-black/40 p-4 backdrop-blur-sm" onClick={onClose}>
      <div role="dialog" aria-modal="true" aria-label={t("newThreadButton")} onClick={(e) => e.stopPropagation()} onKeyDown={(e) => e.key === "Escape" && onClose()} className="w-full max-w-lg rounded-3xl bg-white p-6 shadow-2xl">
        <div className="flex items-center justify-between">
          <h2 className="text-lg font-bold">{t("newThreadButton")}</h2>
          <button type="button" onClick={onClose} aria-label={t("closeLabel")} className="flex h-9 w-9 items-center justify-center rounded-full text-neutral-500 hover:bg-neutral-100">
            <X size={18} />
          </button>
        </div>
        <input autoFocus value={title} onChange={(e) => setTitle(e.target.value)} maxLength={199} placeholder={t("newThreadTitleHint")} aria-label={t("newThreadTitleHint")} className="plain-input mt-4" />
        <textarea value={body} onChange={(e) => setBody(e.target.value)} maxLength={4999} rows={6} placeholder={t("newThreadBodyHint")} aria-label={t("newThreadBodyHint")} className="plain-input mt-3 resize-none" />
        {error && (
          <p role="alert" className="mt-3 rounded-xl bg-red-50 px-4 py-2.5 text-sm font-medium text-red-700">
            {error}
          </p>
        )}
        <div className="mt-5 flex justify-end gap-2">
          <button type="button" onClick={onClose} className="h-10 rounded-full px-5 text-sm font-medium hover:bg-neutral-100">
            {t("cancelButton")}
          </button>
          <button type="button" onClick={post} disabled={busy} className="flex h-10 items-center gap-2 rounded-full bg-black px-6 text-sm font-semibold text-white hover:bg-neutral-800 disabled:opacity-60">
            {busy && <Loader2 size={15} className="animate-spin" />}
            {t("postButton")}
          </button>
        </div>
      </div>
    </div>
  );
}

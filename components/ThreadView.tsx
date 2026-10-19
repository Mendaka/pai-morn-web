"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
} from "firebase/firestore";
import { ArrowLeft, CornerUpLeft, Heart, Loader2, MessageCircle, Pencil, Send, Trash2, X } from "lucide-react";
import { useAuth } from "@/components/AuthProvider";
import { useT } from "@/components/LanguageProvider";
import { useDialog } from "@/components/useDialog";
import { db } from "@/lib/firebase/client";
import { formatDate } from "@/lib/format";
import { gradientFor } from "@/lib/palette";

type Thread = { title: string; body: string; authorId: string; authorName: string; createdAt: Date | null };
type Comment = {
  id: string;
  body: string;
  authorId: string;
  authorName: string;
  createdAt: Date | null;
  edited: boolean;
  likeCount: number;
  replyToAuthorName: string;
  replyToSnippet: string;
};
type ReplyTarget = { id: string; authorName: string; snippet: string };

const monogram = (name: string) => Array.from(name.trim())[0]?.toUpperCase() ?? "?";
// A reply quotes the first 60 characters (by code point, so Shan/Burmese
// syllables aren't cut through the middle of a code unit).
const snippetOf = (body: string) => {
  const chars = Array.from(body);
  return chars.length > 60 ? chars.slice(0, 60).join("") + "…" : body;
};

export default function ThreadView({ threadId }: { threadId: string }) {
  const { t, lang } = useT();
  const { user, profile, isAdmin, status } = useAuth();
  const router = useRouter();
  const { ask, dialog } = useDialog();
  const [thread, setThread] = useState<Thread | "missing" | null>(null);
  const [comments, setComments] = useState<Comment[] | null>(null);
  const [reply, setReply] = useState<ReplyTarget | null>(null);
  const [text, setText] = useState("");
  const [posting, setPosting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const composerRef = useRef<HTMLTextAreaElement>(null);

  useEffect(() => {
    return onSnapshot(doc(db, "communityThreads", threadId), (snap) => {
      if (!snap.exists()) return setThread("missing");
      const x = snap.data();
      setThread({
        title: typeof x.title === "string" ? x.title : "",
        body: typeof x.body === "string" ? x.body : "",
        authorId: typeof x.authorId === "string" ? x.authorId : "",
        authorName: typeof x.authorName === "string" ? x.authorName : "",
        createdAt: typeof x.createdAt?.toDate === "function" ? x.createdAt.toDate() : null,
      });
    });
  }, [threadId]);

  useEffect(() => {
    const q = query(collection(db, "communityThreads", threadId, "comments"), orderBy("createdAt", "asc"));
    return onSnapshot(q, (snap) =>
      setComments(
        snap.docs.map((d) => {
          const x = d.data();
          return {
            id: d.id,
            body: typeof x.body === "string" ? x.body : "",
            authorId: typeof x.authorId === "string" ? x.authorId : "",
            authorName: typeof x.authorName === "string" ? x.authorName : "",
            createdAt: typeof x.createdAt?.toDate === "function" ? x.createdAt.toDate() : null,
            edited: !!x.editedAt,
            likeCount: typeof x.likeCount === "number" ? x.likeCount : 0,
            replyToAuthorName: typeof x.replyToAuthorName === "string" ? x.replyToAuthorName : "",
            replyToSnippet: typeof x.replyToSnippet === "string" ? x.replyToSnippet : "",
          };
        }),
      ),
    );
  }, [threadId]);

  async function post() {
    const body = text.trim();
    if (!user || !body) return;
    setPosting(true);
    setError(null);
    try {
      await addDoc(collection(db, "communityThreads", threadId, "comments"), {
        body,
        authorId: user.uid,
        authorName: profile?.displayName || user.displayName || "",
        createdAt: serverTimestamp(),
        ...(reply ? { replyToCommentId: reply.id, replyToAuthorName: reply.authorName, replyToSnippet: reply.snippet } : {}),
      });
      setText("");
      setReply(null);
    } catch {
      setError(t("postFailedMessage"));
    } finally {
      setPosting(false);
    }
  }

  async function removeComment(id: string) {
    const ok = await ask({
      title: t("deletePostConfirmTitle"),
      message: t("deletePostConfirmMessage"),
      actions: [
        { label: t("cancelButton"), value: false },
        { label: t("deleteLabel"), value: true, tone: "danger" },
      ],
    });
    if (ok) await deleteDoc(doc(db, "communityThreads", threadId, "comments", id)).catch(() => {});
  }

  if (thread === "missing") {
    return (
      <div className="mx-auto flex max-w-md flex-col items-center px-4 py-24 text-center">
        <MessageCircle size={44} className="text-neutral-300" />
        <p className="mt-4 text-neutral-600">{t("threadNotFound")}</p>
        <Link href="/community" className="mt-8 flex h-11 items-center rounded-full bg-black px-6 text-sm font-semibold text-white">
          {t("communityLabel")}
        </Link>
      </div>
    );
  }
  if (!thread) {
    return (
      <div className="mx-auto max-w-3xl px-4 py-10">
        <div className="h-10 w-2/3 animate-pulse rounded-xl bg-black/5" />
        <div className="mt-6 h-40 animate-pulse rounded-3xl bg-black/5" />
      </div>
    );
  }

  const color = gradientFor(thread.authorName || "?");
  return (
    <div className="mx-auto w-full max-w-3xl px-4 pb-32 pt-6 sm:px-6">
      <Link href="/community" className="inline-flex items-center gap-1.5 text-sm font-medium text-neutral-500 hover:text-black">
        <ArrowLeft size={16} /> {t("backToCommunity")}
      </Link>

      <article className="mt-4 rounded-3xl border border-black/5 bg-white p-6 shadow-[0_2px_24px_-8px_rgba(0,0,0,0.12)] sm:p-8">
        <div className="flex items-center gap-3">
          <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full font-bold text-white" style={{ background: color }}>
            {monogram(thread.authorName)}
          </span>
          <p className="text-sm text-neutral-500">
            <span className="font-semibold text-neutral-800">{thread.authorName}</span>
            {thread.createdAt && ` · ${formatDate(thread.createdAt, lang)}`}
          </p>
        </div>
        <h1 className="mt-4 text-2xl font-extrabold leading-snug tracking-tight sm:text-3xl">{thread.title}</h1>
        <p className="mt-3 whitespace-pre-line leading-relaxed text-neutral-700">{thread.body}</p>
      </article>

      <ul className="mt-6 space-y-3">
        {comments === null ? (
          <li className="h-24 animate-pulse rounded-3xl bg-black/5" />
        ) : comments.length === 0 ? (
          <li className="rounded-3xl border border-dashed border-black/10 px-6 py-10 text-center text-neutral-500">{t("noCommentsYetMessage")}</li>
        ) : (
          comments.map((c) => (
            <CommentItem
              key={c.id}
              threadId={threadId}
              comment={c}
              canDelete={isAdmin || user?.uid === c.authorId}
              canEdit={user?.uid === c.authorId}
              onDelete={() => removeComment(c.id)}
              onReply={() => {
                if (status !== "signedIn") return router.push(`/login?next=${encodeURIComponent(`/community/thread/${threadId}`)}`);
                setReply({ id: c.id, authorName: c.authorName, snippet: snippetOf(c.body) });
                composerRef.current?.focus();
              }}
            />
          ))
        )}
      </ul>

      {/* composer, pinned to the bottom of the viewport */}
      <div className="fixed inset-x-0 bottom-16 z-30 border-t border-black/5 bg-white/90 px-4 py-3 backdrop-blur-xl md:bottom-0">
        <div className="mx-auto max-w-3xl">
          {status !== "signedIn" ? (
            <Link href={`/login?next=${encodeURIComponent(`/community/thread/${threadId}`)}`} className="block rounded-2xl bg-neutral-100 px-5 py-3 text-center text-sm font-semibold text-neutral-700 transition hover:bg-neutral-200">
              {t("loginToPostMessage")}
            </Link>
          ) : (
            <>
              {reply && (
                <div className="mb-2 flex items-center gap-2 rounded-xl bg-blue-50 px-3 py-1.5 text-sm text-blue-800">
                  <CornerUpLeft size={14} className="shrink-0" />
                  <span className="min-w-0 flex-1 truncate">
                    {t("replyingToLabel")} {reply.authorName}
                    {reply.snippet && `: ${reply.snippet}`}
                  </span>
                  <button type="button" onClick={() => setReply(null)} aria-label={t("cancelReplyLabel")} title={t("cancelReplyLabel")} className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full hover:bg-blue-100">
                    <X size={14} />
                  </button>
                </div>
              )}
              {error && (
                <p role="alert" className="mb-2 text-sm font-medium text-red-600">
                  {error}
                </p>
              )}
              <div className="flex items-end gap-2">
                <textarea
                  ref={composerRef}
                  value={text}
                  onChange={(e) => setText(e.target.value)}
                  maxLength={2999}
                  rows={1}
                  placeholder={t("commentHint")}
                  aria-label={t("commentHint")}
                  className="plain-input max-h-32 min-h-11 flex-1 resize-none !py-2.5"
                />
                <button type="button" onClick={post} disabled={posting || !text.trim()} aria-label={t("postButton")} title={t("postButton")} className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-black text-white transition hover:scale-105 disabled:opacity-40">
                  {posting ? <Loader2 size={18} className="animate-spin" /> : <Send size={18} />}
                </button>
              </div>
            </>
          )}
        </div>
      </div>
      {dialog}
    </div>
  );
}

function CommentItem({
  threadId,
  comment: c,
  canDelete,
  canEdit,
  onDelete,
  onReply,
}: {
  threadId: string;
  comment: Comment;
  canDelete: boolean;
  canEdit: boolean;
  onDelete: () => void;
  onReply: () => void;
}) {
  const { t, lang } = useT();
  const { user } = useAuth();
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState(c.body);
  const [saving, setSaving] = useState(false);
  const [liked, setLiked] = useState(false);
  const color = gradientFor(c.authorName || "?");
  const uid = user?.uid;

  // A like is just the existence of comments/{id}/likes/{myUid}; the shown
  // total is a counter a Cloud Function keeps on the comment itself.
  useEffect(() => {
    if (!uid) return;
    return onSnapshot(doc(db, "communityThreads", threadId, "comments", c.id, "likes", uid), (s) => setLiked(s.exists()));
  }, [uid, threadId, c.id]);

  function toggleLike() {
    if (!uid) return;
    const ref = doc(db, "communityThreads", threadId, "comments", c.id, "likes", uid);
    if (liked) deleteDoc(ref).catch(() => {});
    else setDoc(ref, { createdAt: serverTimestamp() }).catch(() => {});
  }

  async function save() {
    const body = draft.trim();
    if (!body) return;
    setSaving(true);
    try {
      await updateDoc(doc(db, "communityThreads", threadId, "comments", c.id), { body, editedAt: serverTimestamp() });
      setEditing(false);
    } finally {
      setSaving(false);
    }
  }

  return (
    <li id={`c-${c.id}`} className="rounded-3xl border border-black/5 bg-white p-4 shadow-[0_2px_16px_-8px_rgba(0,0,0,0.12)] sm:p-5">
      <div className="flex items-start gap-3">
        <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-sm font-bold text-white" style={{ background: color }}>
          {monogram(c.authorName)}
        </span>
        <div className="min-w-0 flex-1">
          <p className="text-sm text-neutral-500">
            <span className="font-semibold text-neutral-800">{c.authorName}</span>
            {c.createdAt && ` · ${formatDate(c.createdAt, lang)}`}
            {c.edited && <span className="ml-1.5 text-xs text-neutral-400">{t("editedLabel")}</span>}
          </p>

          {c.replyToAuthorName && (
            <p className="mt-2 flex items-start gap-1.5 rounded-xl border-l-4 border-blue-300 bg-blue-50 px-3 py-1.5 text-sm text-blue-900/80">
              <CornerUpLeft size={13} className="mt-1 shrink-0" />
              <span className="line-clamp-2">
                {t("replyingToLabel")} {c.replyToAuthorName}
                {c.replyToSnippet && `: ${c.replyToSnippet}`}
              </span>
            </p>
          )}

          {editing ? (
            <div className="mt-2">
              <textarea value={draft} onChange={(e) => setDraft(e.target.value)} maxLength={2999} rows={3} aria-label={t("editButton")} className="plain-input resize-none" />
              <div className="mt-2 flex justify-end gap-2">
                <button type="button" onClick={() => { setEditing(false); setDraft(c.body); }} className="h-9 rounded-full px-4 text-sm font-medium hover:bg-neutral-100">
                  {t("cancelButton")}
                </button>
                <button type="button" onClick={save} disabled={saving} className="h-9 rounded-full bg-black px-5 text-sm font-semibold text-white hover:bg-neutral-800 disabled:opacity-60">
                  {t("saveButton")}
                </button>
              </div>
            </div>
          ) : (
            <p className="mt-1.5 whitespace-pre-line leading-relaxed text-neutral-800">{c.body}</p>
          )}

          {!editing && (
            <div className="mt-3 flex items-center gap-1 text-sm">
              <button
                type="button"
                onClick={toggleLike}
                disabled={!uid}
                aria-pressed={liked}
                aria-label={liked ? t("unlikeLabel") : t("likeLabel")}
                title={liked ? t("unlikeLabel") : t("likeLabel")}
                className={`flex h-8 items-center gap-1.5 rounded-full px-3 font-medium transition hover:bg-rose-50 disabled:cursor-default disabled:hover:bg-transparent ${liked ? "text-rose-500" : "text-neutral-500"}`}
              >
                <Heart size={16} className={liked ? "fill-current" : ""} /> {c.likeCount}
              </button>
              <button type="button" onClick={onReply} className="flex h-8 items-center gap-1.5 rounded-full px-3 font-medium text-neutral-500 transition hover:bg-neutral-100">
                <CornerUpLeft size={15} /> {t("replyButton")}
              </button>
              {canEdit && (
                <button type="button" onClick={() => setEditing(true)} aria-label={t("editButton")} title={t("editButton")} className="flex h-8 w-8 items-center justify-center rounded-full text-neutral-400 transition hover:bg-neutral-100 hover:text-neutral-700">
                  <Pencil size={15} />
                </button>
              )}
              {canDelete && (
                <button type="button" onClick={onDelete} aria-label={t("deleteLabel")} title={t("deleteLabel")} className="flex h-8 w-8 items-center justify-center rounded-full text-neutral-400 transition hover:bg-red-50 hover:text-red-600">
                  <Trash2 size={15} />
                </button>
              )}
            </div>
          )}
        </div>
      </div>
    </li>
  );
}

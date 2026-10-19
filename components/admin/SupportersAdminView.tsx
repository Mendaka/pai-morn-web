"use client";

import { useEffect, useState } from "react";
import { collection, deleteDoc, doc, onSnapshot, orderBy, query, serverTimestamp, setDoc } from "firebase/firestore";
import { Loader2, Plus, Trash2 } from "lucide-react";
import { useT } from "@/components/LanguageProvider";
import { db } from "@/lib/firebase/client";

type Supporter = { id: string; name: string; message: string };

// Neither PromptPay nor a bare PayPal.me link gives this app a payment
// webhook, so there's no automatic way to know a donation happened — this is
// a manual roster: an admin types in a name after actually seeing the
// payment land (bank app / PayPal), and it appears on the public /support
// page. See firestore.rules: read is public, write is admin-only.
export default function SupportersAdminView() {
  const { t } = useT();
  const [rows, setRows] = useState<Supporter[] | null>(null);
  const [name, setName] = useState("");
  const [message, setMessage] = useState("");
  const [saving, setSaving] = useState(false);
  const [deletingId, setDeletingId] = useState<string | null>(null);

  useEffect(() => {
    return onSnapshot(query(collection(db, "supporters"), orderBy("createdAt", "desc")), (snap) =>
      setRows(
        snap.docs.map((d) => {
          const x = d.data();
          return { id: d.id, name: typeof x.name === "string" ? x.name : "", message: typeof x.message === "string" ? x.message : "" };
        }),
      ),
    );
  }, []);

  async function add() {
    const trimmed = name.trim();
    if (!trimmed) return;
    setSaving(true);
    try {
      const id = doc(collection(db, "supporters")).id;
      await setDoc(doc(db, "supporters", id), { name: trimmed, message: message.trim(), createdAt: serverTimestamp() });
      setName("");
      setMessage("");
    } finally {
      setSaving(false);
    }
  }

  async function remove(id: string) {
    if (!confirm(t("deleteSupporterConfirm"))) return;
    setDeletingId(id);
    try {
      await deleteDoc(doc(db, "supporters", id));
    } finally {
      setDeletingId(null);
    }
  }

  return (
    <div>
      <h1 className="text-2xl font-extrabold tracking-tight">{t("adminSupportersLabel")}</h1>

      <div className="mt-6 flex flex-wrap items-end gap-3 rounded-3xl border border-black/5 bg-white p-5 shadow-[0_2px_16px_-8px_rgba(0,0,0,0.15)]">
        <label className="min-w-40 flex-1">
          <span className="mb-1.5 block text-sm font-medium text-neutral-700">{t("supporterNameLabel")}</span>
          <input
            className="plain-input"
            value={name}
            placeholder={t("supporterNamePlaceholder")}
            onChange={(e) => setName(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && add()}
          />
        </label>
        <label className="min-w-52 flex-[2]">
          <span className="mb-1.5 block text-sm font-medium text-neutral-700">{t("supporterMessageLabel")}</span>
          <input
            className="plain-input"
            value={message}
            onChange={(e) => setMessage(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && add()}
          />
        </label>
        <button
          type="button"
          onClick={add}
          disabled={saving || !name.trim()}
          className="flex h-12 shrink-0 items-center gap-2 rounded-full bg-black px-6 text-sm font-semibold text-white transition hover:scale-[1.02] disabled:opacity-40"
        >
          {saving ? <Loader2 size={16} className="animate-spin" /> : <Plus size={16} />}
          {t("addSupporterButton")}
        </button>
      </div>

      <div className="mt-6 space-y-2">
        {rows === null ? (
          [0, 1].map((i) => <div key={i} className="h-16 animate-pulse rounded-2xl bg-black/5" />)
        ) : rows.length === 0 ? (
          <p className="rounded-3xl border border-dashed border-black/10 px-6 py-10 text-center text-neutral-500">{t("noSupportersYet")}</p>
        ) : (
          rows.map((r) => (
            <div key={r.id} className="flex items-center gap-3 rounded-2xl border border-black/5 bg-white px-4 py-3 shadow-[0_2px_12px_-8px_rgba(0,0,0,0.15)]">
              <div className="min-w-0 flex-1">
                <p className="truncate font-semibold text-neutral-900">{r.name}</p>
                {r.message && <p className="truncate text-sm text-neutral-500">{r.message}</p>}
              </div>
              <button
                type="button"
                onClick={() => remove(r.id)}
                disabled={deletingId === r.id}
                aria-label={t("deleteSupporterConfirm")}
                className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-neutral-500 transition hover:bg-red-50 hover:text-red-600 disabled:opacity-40"
              >
                {deletingId === r.id ? <Loader2 size={16} className="animate-spin" /> : <Trash2 size={16} />}
              </button>
            </div>
          ))
        )}
      </div>
    </div>
  );
}

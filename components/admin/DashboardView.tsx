"use client";

import { useEffect, useMemo, useState } from "react";
import { collection, doc, getCountFromServer, onSnapshot, query, updateDoc, where } from "firebase/firestore";
import { Ban, CheckCircle2, Disc3, Hourglass, Loader2, Search, ShieldCheck, Star, Users, XCircle } from "lucide-react";
import { useAuth } from "@/components/AuthProvider";
import { useT } from "@/components/LanguageProvider";
import UserAvatar from "@/components/UserAvatar";
import { useDialog } from "@/components/useDialog";
import { badgeColor, badgeTier } from "@/lib/badge";
import { backfillBlankDisplayNames } from "@/lib/auto-name";
import { db } from "@/lib/firebase/client";

type UserRow = { id: string; name: string; photoUrl: string; approved: number; isAdmin: boolean; blocked: boolean };

const num = (v: unknown) => (typeof v === "number" ? v : 0);

// Site overview (counts) and the user table: how much each person has
// submitted, and the moderation actions (block, grant/revoke admin).
export default function DashboardView() {
  const { t } = useT();
  const { user: me } = useAuth();
  const { ask, dialog } = useDialog();
  const [counts, setCounts] = useState<number[] | null>(null);
  const [users, setUsers] = useState<UserRow[] | null>(null);
  const [pending, setPending] = useState<Record<string, number>>({});
  const [rejected, setRejected] = useState<Record<string, number>>({});
  const [q, setQ] = useState("");
  const [fixingNames, setFixingNames] = useState(false);

  useEffect(() => {
    let alive = true;
    const c = (x: Parameters<typeof getCountFromServer>[0]) => getCountFromServer(x).then((s) => s.data().count).catch(() => 0);
    const songs = collection(db, "songs");
    Promise.all([
      c(collection(db, "users")),
      c(query(songs, where("status", "==", "approved"))),
      c(query(songs, where("status", "==", "pending"))),
      c(query(songs, where("status", "==", "rejected"))),
      c(collection(db, "artists")),
      c(query(collection(db, "users"), where("blocked", "==", true))),
    ]).then((r) => alive && setCounts(r));
    return () => {
      alive = false;
    };
  }, []);

  useEffect(() => {
    const unsubUsers = onSnapshot(collection(db, "users"), (snap) =>
      setUsers(
        snap.docs.map((d) => {
          const x = d.data();
          return {
            id: d.id,
            name: typeof x.displayName === "string" ? x.displayName : "",
            photoUrl: typeof x.photoUrl === "string" ? x.photoUrl : "",
            approved: num(x.approvedSongCount),
            isAdmin: x.isAdmin === true,
            blocked: x.blocked === true,
          };
        }),
      ),
    );
    // Only the small pending / rejected sets, not every song with its lyrics.
    const tally = (status: string, set: (r: Record<string, number>) => void) =>
      onSnapshot(query(collection(db, "songs"), where("status", "==", status)), (snap) => {
        const by: Record<string, number> = {};
        for (const d of snap.docs) {
          const a = d.data().authorId;
          if (typeof a === "string") by[a] = (by[a] ?? 0) + 1;
        }
        set(by);
      });
    const unsubP = tally("pending", setPending);
    const unsubR = tally("rejected", setRejected);
    return () => {
      unsubUsers();
      unsubP();
      unsubR();
    };
  }, []);

  const rows = useMemo(() => {
    const needle = q.trim().toLowerCase();
    return (users ?? [])
      .filter((u) => !needle || u.name.toLowerCase().includes(needle))
      .sort((a, b) => b.approved - a.approved || a.name.localeCompare(b.name));
  }, [users, q]);

  // Dormant accounts that never got a name and haven't signed back in since
  // (a signed-in user's own client self-heals this the moment they do — see
  // AuthProvider's ensureName — so this only ever catches accounts nobody is
  // actively using).
  const blankNameIds = useMemo(() => (users ?? []).filter((u) => !u.name.trim()).map((u) => u.id), [users]);

  async function fixMissingNames() {
    const ok = await ask({
      title: t("assignAutoNamesTitle"),
      message: t("assignAutoNamesMessage", { n: blankNameIds.length }),
      actions: [
        { label: t("cancelButton"), value: false },
        { label: t("confirmLabel"), value: true, tone: "primary" },
      ],
    });
    if (!ok) return;
    setFixingNames(true);
    try {
      await backfillBlankDisplayNames(blankNameIds);
    } finally {
      setFixingNames(false);
    }
  }

  async function toggle(u: UserRow, field: "blocked" | "isAdmin") {
    const on = field === "blocked" ? !u.blocked : !u.isAdmin;
    const [title, message] =
      field === "blocked"
        ? on
          ? [t("blockUserConfirmTitle"), t("blockUserConfirmMessage")]
          : [t("adminUnblockTitle"), t("adminUnblockMessage")]
        : on
          ? [t("adminGrantTitle"), t("adminGrantMessage")]
          : [t("adminRevokeTitle"), t("adminRevokeMessage")];
    const ok = await ask({
      title,
      message,
      actions: [
        { label: t("cancelButton"), value: false },
        { label: t("confirmLabel"), value: true, tone: "primary" },
      ],
    });
    if (ok) await updateDoc(doc(db, "users", u.id), { [field]: on }).catch(() => {});
  }

  const stats = [
    { icon: Users, label: t("adminStatUsers"), tone: "from-indigo-500 to-blue-500" },
    { icon: CheckCircle2, label: t("approvedSongsLabel"), tone: "from-emerald-500 to-teal-500" },
    { icon: Hourglass, label: t("adminStatPending"), tone: "from-amber-400 to-orange-500" },
    { icon: XCircle, label: t("statusRejected"), tone: "from-rose-500 to-red-500" },
    { icon: Disc3, label: t("tabArtists"), tone: "from-fuchsia-500 to-pink-500" },
    { icon: Ban, label: t("adminStatBlocked"), tone: "from-neutral-600 to-neutral-800" },
  ];

  return (
    <div>
      <h1 className="text-3xl font-extrabold tracking-tight">{t("adminDashboardLabel")}</h1>
      <p className="mt-1 text-neutral-500">{t("adminDashboardSubtitle")}</p>

      <div className="mt-6 grid grid-cols-2 gap-3 sm:grid-cols-3 xl:grid-cols-6">
        {stats.map((s, i) => (
          <div key={s.label} className="rounded-3xl border border-black/5 bg-white p-4 shadow-[0_2px_16px_-8px_rgba(0,0,0,0.15)]">
            <span className={`flex h-10 w-10 items-center justify-center rounded-2xl bg-gradient-to-br text-white shadow ${s.tone}`}>
              <s.icon size={19} />
            </span>
            <p data-testid={`stat-${i}`} className="mt-3 text-2xl font-extrabold tabular-nums">
              {counts ? counts[i].toLocaleString() : "…"}
            </p>
            <p className="text-xs text-neutral-500">{s.label}</p>
          </div>
        ))}
      </div>

      <div className="mt-10 flex flex-wrap items-center justify-between gap-3">
        <h2 className="text-xl font-bold">{t("adminUsersHeading")}</h2>
        <div className="flex flex-wrap items-center gap-2">
          {blankNameIds.length > 0 && (
            <button
              type="button"
              onClick={fixMissingNames}
              disabled={fixingNames}
              className="flex h-10 items-center gap-1.5 rounded-full border border-black/10 px-4 text-sm font-semibold transition hover:bg-neutral-100 disabled:opacity-50"
            >
              {fixingNames && <Loader2 size={14} className="animate-spin" />}
              {t("assignAutoNamesButton", { n: blankNameIds.length })}
            </button>
          )}
          <label className="relative block w-full max-w-xs">
            <Search size={17} className="pointer-events-none absolute left-4 top-1/2 -translate-y-1/2 text-neutral-400" />
            <input value={q} onChange={(e) => setQ(e.target.value)} placeholder={t("adminSearchUsers")} aria-label={t("adminSearchUsers")} className="field-input !h-10 text-sm" />
          </label>
        </div>
      </div>

      <div className="mt-4 overflow-x-auto rounded-3xl border border-black/5 bg-white shadow-[0_2px_16px_-8px_rgba(0,0,0,0.15)]">
        <table className="w-full min-w-[46rem] text-left text-sm">
          <thead className="border-b border-black/5 text-xs uppercase tracking-wide text-neutral-400">
            <tr>
              {["adminColName", "adminColBadge", "statusApproved", "adminColPending", "statusRejected", "adminColStatus", "adminColActions"].map((k) => (
                <th key={k} className="px-4 py-3 font-semibold">
                  {t(k)}
                </th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-black/5">
            {users === null ? (
              <tr>
                <td colSpan={7} className="px-4 py-10 text-center text-neutral-400">
                  …
                </td>
              </tr>
            ) : (
              rows.map((u) => {
                const tier = badgeTier(u.approved);
                const c = badgeColor(tier);
                const self = u.id === me?.uid;
                return (
                  <tr key={u.id} data-user={u.name} className="align-middle">
                    <td className="px-4 py-3">
                      <span className="flex items-center gap-3">
                        <UserAvatar uid={u.id} name={u.name} photoUrl={u.photoUrl} size={34} />
                        <span className="font-semibold text-neutral-900">{u.name || "—"}</span>
                      </span>
                    </td>
                    <td className="px-4 py-3">{tier > 0 && c ? <Star size={16} fill={c} stroke="none" /> : "—"}</td>
                    <td className="px-4 py-3 tabular-nums">{u.approved}</td>
                    <td className="px-4 py-3 tabular-nums">{pending[u.id] ?? 0}</td>
                    <td className="px-4 py-3 tabular-nums">{rejected[u.id] ?? 0}</td>
                    <td className="px-4 py-3">
                      <span className="flex flex-wrap gap-1.5">
                        {u.isAdmin && (
                          <span className="inline-flex items-center gap-1 rounded-full bg-indigo-50 px-2.5 py-0.5 text-xs font-semibold text-indigo-700">
                            <ShieldCheck size={12} /> {t("adminLabel")}
                          </span>
                        )}
                        {u.blocked && (
                          <span className="inline-flex items-center gap-1 rounded-full bg-red-50 px-2.5 py-0.5 text-xs font-semibold text-red-700">
                            <Ban size={12} /> {t("adminBlockedChip")}
                          </span>
                        )}
                      </span>
                    </td>
                    <td className="px-4 py-3">
                      {self ? (
                        <span className="text-neutral-300">—</span>
                      ) : (
                        <span className="flex flex-wrap gap-1.5">
                          <button type="button" onClick={() => toggle(u, "blocked")} className="rounded-full border border-black/10 px-3 py-1 text-xs font-semibold transition hover:bg-neutral-100">
                            {u.blocked ? t("adminUnblock") : t("adminBlock")}
                          </button>
                          <button type="button" onClick={() => toggle(u, "isAdmin")} className="rounded-full border border-black/10 px-3 py-1 text-xs font-semibold transition hover:bg-neutral-100">
                            {u.isAdmin ? t("adminRevokeAdmin") : t("adminMakeAdmin")}
                          </button>
                        </span>
                      )}
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>
      {dialog}
    </div>
  );
}

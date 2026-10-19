"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { doc, updateDoc } from "firebase/firestore";
import { getDownloadURL, ref, uploadBytes } from "firebase/storage";
import { Camera, CalendarDays, Check, Flame, Loader2, Music2, Pencil, Star, Trophy, X } from "lucide-react";
import { useAuth } from "@/components/AuthProvider";
import { useT } from "@/components/LanguageProvider";
import UserAvatar from "@/components/UserAvatar";
import { badgeColor, badgeLabel, badgeTier, nextTier, TIER_THRESHOLDS } from "@/lib/badge";
import { db, storage } from "@/lib/firebase/client";
import { resizeImageForUpload } from "@/lib/image-resize";

const TIER_STEPS = [
  { label: "Bronze", color: "#CD7F32", target: TIER_THRESHOLDS[0]! },
  { label: "Silver", color: "#A8A9AD", target: TIER_THRESHOLDS[1]! },
  { label: "Gold", color: "#E8B800", target: TIER_THRESHOLDS[2]! },
];

export default function ProfileView() {
  const { status, user, profile } = useAuth();
  const { t, lang } = useT();
  const router = useRouter();
  const startInEdit = useSearchParams().get("edit") === "1";

  const [editing, setEditing] = useState(startInEdit);
  const [nameDraft, setNameDraft] = useState("");
  const [savingName, setSavingName] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (status === "signedOut") router.replace("/login?next=/profile");
  }, [status, router]);

  if (status !== "signedIn" || !user) {
    return (
      <div className="mx-auto max-w-3xl px-4 py-16">
        <div className="h-72 animate-pulse rounded-[2rem] bg-black/5" />
      </div>
    );
  }

  const name = profile?.displayName ?? "";
  const count = profile?.approvedSongCount ?? 0;
  const tier = badgeTier(count);
  const tierColor = badgeColor(tier);
  const upcoming = nextTier(count);
  // 0..100 along start -> bronze -> silver -> gold: whole steps done, plus how far into the current one.
  const lower = tier > 0 ? TIER_THRESHOLDS[tier - 1]! : 0;
  const journey = upcoming ? Math.round(((tier + Math.max(0, count - lower) / (upcoming.target - lower)) / 3) * 100) : 100;

  async function saveName() {
    const trimmed = nameDraft.trim();
    if (!trimmed) return setError(t("profileNameEmpty"));
    if (!user) return;
    setSavingName(true);
    setError(null);
    try {
      await updateDoc(doc(db, "users", user.uid), { displayName: trimmed });
      setEditing(false);
    } catch {
      setError(t("profileNameSaveFailed"));
    } finally {
      setSavingName(false);
    }
  }

  async function onPhotoChosen(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    e.target.value = ""; // allow re-picking the same file later
    if (!file || !user) return;
    setUploading(true);
    setError(null);
    try {
      const blob = await resizeImageForUpload(file);
      const photoRef = ref(storage, `profile_photos/${user.uid}`);
      await uploadBytes(photoRef, blob, { contentType: "image/jpeg" });
      const url = await getDownloadURL(photoRef);
      await updateDoc(doc(db, "users", user.uid), { photoUrl: url });
    } catch (err) {
      setError(err instanceof Error && err.message ? err.message : t("photoUploadFailed"));
    } finally {
      setUploading(false);
    }
  }

  return (
    <div className="mx-auto w-full max-w-3xl px-4 pb-20 pt-6 sm:px-6">
      <header className="relative overflow-hidden rounded-[2rem] bg-gradient-to-br from-blue-600 via-indigo-600 to-pink-700 p-7 text-white shadow-[0_30px_70px_-30px_rgba(79,70,229,0.7)] sm:p-10">
        <div className="pointer-events-none absolute -right-16 -top-20 h-72 w-72 rounded-full bg-white/15 blur-3xl" />
        <div className="pointer-events-none absolute -bottom-28 left-10 h-64 w-64 rounded-full bg-fuchsia-400/25 blur-3xl" />

        <div className="relative flex flex-col items-center gap-6 text-center sm:flex-row sm:text-left">
          <div className="relative">
            <div className="rounded-full p-1.5 shadow-2xl" style={{ background: tierColor ?? "rgba(255,255,255,0.65)" }}>
              <UserAvatar uid={user.uid} name={name} photoUrl={profile?.photoUrl} size={116} className="ring-4 ring-white" />
            </div>
            {uploading && (
              <div className="absolute inset-0 flex items-center justify-center rounded-full bg-black/50">
                <Loader2 className="animate-spin" />
              </div>
            )}
            <button
              type="button"
              onClick={() => fileRef.current?.click()}
              disabled={uploading}
              aria-label={t("changePhotoLabel")}
              className="absolute -bottom-1 -right-1 flex h-10 w-10 items-center justify-center rounded-full bg-white text-neutral-800 shadow-lg transition hover:scale-110 disabled:opacity-60"
            >
              <Camera size={18} />
            </button>
            <input ref={fileRef} type="file" accept="image/*" hidden onChange={onPhotoChosen} />
          </div>

          <div className="min-w-0 flex-1">
            {editing ? (
              <div className="flex items-center gap-2">
                <input
                  autoFocus
                  value={nameDraft}
                  onChange={(e) => setNameDraft(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === "Enter") saveName();
                    if (e.key === "Escape") setEditing(false);
                  }}
                  maxLength={60}
                  aria-label={t("displayName")}
                  className="h-12 min-w-0 flex-1 rounded-2xl border border-white/30 bg-white/15 px-4 text-xl font-bold text-white outline-none backdrop-blur placeholder:text-white/50 focus:border-white"
                />
                <button
                  type="button"
                  onClick={saveName}
                  disabled={savingName}
                  aria-label={t("saveButton")}
                  className="flex h-12 w-12 items-center justify-center rounded-2xl bg-white text-emerald-600 shadow-lg transition hover:scale-105 disabled:opacity-60"
                >
                  {savingName ? <Loader2 size={20} className="animate-spin" /> : <Check size={22} />}
                </button>
                <button
                  type="button"
                  onClick={() => setEditing(false)}
                  aria-label={t("cancelButton")}
                  className="flex h-12 w-12 items-center justify-center rounded-2xl bg-white/15 backdrop-blur transition hover:bg-white/25"
                >
                  <X size={20} />
                </button>
              </div>
            ) : (
              <div className="flex items-center justify-center gap-2 sm:justify-start">
                <h1 className="line-clamp-2 text-3xl font-extrabold leading-tight tracking-tight sm:text-4xl">
                  {name || t("setYourName")}
                </h1>
                <button
                  type="button"
                  onClick={() => {
                    setNameDraft(name);
                    setEditing(true);
                  }}
                  aria-label={t("changeProfileNameLabel")}
                  className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-white/15 backdrop-blur transition hover:bg-white/25"
                >
                  <Pencil size={16} />
                </button>
              </div>
            )}

            <div className="mt-4 flex flex-wrap justify-center gap-2 text-sm font-medium sm:justify-start">
              {tier > 0 && (
                <span className="flex items-center gap-1.5 rounded-full bg-white/20 px-3.5 py-1.5 backdrop-blur">
                  <Star size={14} fill={tierColor ?? "currentColor"} stroke="none" /> {t("contributorBadge", { tier: t("badge" + badgeLabel(tier)) })}
                </span>
              )}
              {profile?.createdAt && (
                <span className="flex items-center gap-1.5 rounded-full bg-white/20 px-3.5 py-1.5 backdrop-blur">
                  <CalendarDays size={14} /> {t("joinedLabel")}{" "}
                  {profile.createdAt.toLocaleDateString(lang === "mm" ? "my" : lang, { month: "short", year: "numeric" })}
                </span>
              )}
            </div>
          </div>
        </div>
      </header>

      {error && (
        <p role="alert" className="mt-4 rounded-2xl bg-red-50 px-5 py-3.5 text-sm font-medium text-red-700">
          {error}
        </p>
      )}

      <div className="mt-5 grid grid-cols-3 gap-3 sm:gap-4">
        <Stat icon={Music2} value={count} label={t("approvedSongsLabel")} tone="from-blue-500 to-indigo-500" />
        <Stat icon={Flame} value={profile?.currentStreak ?? 0} label={t("dayStreakLabel")} tone="from-orange-500 to-rose-500" />
        <Stat icon={Trophy} value={profile?.longestStreak ?? 0} label={t("longestStreakLabel")} tone="from-amber-400 to-orange-500" />
      </div>

      <section className="mt-4 rounded-3xl border border-black/5 bg-white p-5 shadow-[0_2px_16px_-8px_rgba(0,0,0,0.15)] sm:p-6">
        <div className="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1">
          <h2 className="font-bold text-neutral-900">{t("contributorBadgeTitle")}</h2>
          <span className="text-sm text-neutral-500">
            {upcoming
              ? upcoming.remaining === 1 && lang === "en"
                ? t("moreToNextTierOne", { tier: t("badge" + upcoming.label) })
                : t("moreToNextTier", { n: upcoming.remaining, tier: t("badge" + upcoming.label) })
              : t("topTierReached")}
          </span>
        </div>

        {/* start -> bronze -> silver -> gold, evenly spaced; the fill runs to the songs' place inside the current step */}
        <div className="px-6 pb-9 pt-8 sm:px-8">
          <div className="relative h-2.5 rounded-full bg-neutral-100">
            <div
              className="h-full rounded-full bg-gradient-to-r from-blue-500 to-pink-500 transition-all duration-700"
              style={{ width: `${journey}%` }}
            />
            {TIER_STEPS.map((step, i) => {
              const reached = tier >= i + 1;
              const isNext = tier === i;
              return (
                <div key={step.label} className="absolute top-1/2" style={{ left: `${((i + 1) / 3) * 100}%` }}>
                  <div
                    className={`flex h-9 w-9 -translate-x-1/2 -translate-y-1/2 items-center justify-center rounded-full border-2 transition ${
                      reached ? "border-white text-white shadow-lg" : isNext ? "border-neutral-300 bg-white text-neutral-400 ring-4 ring-blue-500/15" : "border-neutral-200 bg-white text-neutral-300"
                    }`}
                    style={reached ? { background: step.color } : undefined}
                  >
                    <Star size={16} fill={reached ? "currentColor" : "none"} />
                  </div>
                  <p className={`absolute left-1/2 top-6 -translate-x-1/2 whitespace-nowrap text-center text-xs font-semibold ${reached ? "text-neutral-800" : "text-neutral-400"}`}>
                    {t("badge" + step.label)}
                    <span className="block font-medium text-neutral-400">{step.target}</span>
                  </p>
                </div>
              );
            })}
          </div>
        </div>
      </section>
    </div>
  );
}

function Stat({
  icon: Icon,
  value,
  label,
  tone,
}: {
  icon: typeof Music2;
  value: number;
  label: string;
  tone: string;
}) {
  return (
    <div className="relative overflow-hidden rounded-3xl border border-black/5 bg-white p-4 shadow-[0_2px_16px_-8px_rgba(0,0,0,0.15)] sm:p-5">
      <span className={`flex h-10 w-10 items-center justify-center rounded-2xl bg-gradient-to-br ${tone} text-white shadow-lg sm:h-11 sm:w-11`}>
        <Icon size={19} />
      </span>
      <p className="mt-3 text-2xl font-extrabold tabular-nums tracking-tight sm:mt-4 sm:text-3xl">{value.toLocaleString()}</p>
      <p className="mt-0.5 text-xs leading-snug text-neutral-500 sm:text-sm">{label}</p>
    </div>
  );
}

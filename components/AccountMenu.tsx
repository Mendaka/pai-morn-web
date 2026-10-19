"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { LogIn, LogOut, PenLine, Star } from "lucide-react";
import { useAuth } from "@/components/AuthProvider";
import { useT } from "@/components/LanguageProvider";
import UserAvatar from "@/components/UserAvatar";
import { badgeColor, badgeLabel, badgeTier } from "@/lib/badge";
import { ACCOUNT_LINKS } from "@/lib/nav";

// Navbar's right-hand account slot: a "Sign in" pill when signed out, an
// avatar with a dropdown when signed in.
export default function AccountMenu() {
  const { status, user, profile, isAdmin, editMode, toggleEditMode, signOut } = useAuth();
  const { t } = useT();
  // "Open" is remembered together with the page it was opened on, so any
  // navigation closes the menu by itself — no effect needed to reset it.
  const [openPath, setOpenPath] = useState<string | null>(null);
  const rootRef = useRef<HTMLDivElement>(null);
  const pathname = usePathname();
  const open = openPath === pathname;
  const setOpen = (v: boolean) => setOpenPath(v ? pathname : null);

  // Close on outside click and Escape.
  useEffect(() => {
    if (!open) return;
    const onPointer = (e: PointerEvent) => {
      if (!rootRef.current?.contains(e.target as Node)) setOpenPath(null);
    };
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && setOpenPath(null);
    document.addEventListener("pointerdown", onPointer);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("pointerdown", onPointer);
      document.removeEventListener("keydown", onKey);
    };
  }, [open]);

  if (status === "loading") {
    return <div aria-hidden className="ml-1 h-10 w-10 animate-pulse rounded-full bg-black/10" />;
  }

  if (status === "signedOut" || !user) {
    const next = pathname && pathname !== "/" && !pathname.startsWith("/login") ? `?next=${encodeURIComponent(pathname)}` : "";
    return (
      <Link
        href={`/login${next}`}
        className="lift-spring ml-1 flex h-9 items-center gap-2 rounded-xl bg-black px-2.5 text-sm font-semibold text-white transition hover:-translate-y-0.5 hover:bg-neutral-800 hover:shadow-md active:translate-y-0 active:scale-95 sm:h-10 sm:px-4"
      >
        <LogIn size={16} /> <span className="hidden sm:inline">{t("login")}</span>
      </Link>
    );
  }

  const name = profile?.displayName || user.displayName || "Account";
  const tier = badgeTier(profile?.approvedSongCount ?? 0);
  const tierColor = badgeColor(tier);

  return (
    <div ref={rootRef} className="relative ml-1">
      <button
        type="button"
        onClick={() => setOpen(!open)}
        aria-haspopup="menu"
        aria-expanded={open}
        aria-label={t("accountMenuLabel")}
        className="lift-spring block rounded-full ring-2 ring-transparent transition hover:scale-105 hover:ring-black/15 focus-visible:ring-blue-500 active:scale-95"
      >
        <UserAvatar uid={user.uid} name={name} photoUrl={profile?.photoUrl} size={40} />
      </button>

      {open && (
        <div
          role="menu"
          className="absolute right-0 top-[calc(100%+10px)] z-50 w-64 overflow-hidden rounded-2xl border border-black/10 bg-white p-1.5 shadow-[0_20px_50px_-15px_rgba(0,0,0,0.35)]"
        >
          <div className="flex items-center gap-3 rounded-xl px-3 py-3">
            <UserAvatar uid={user.uid} name={name} photoUrl={profile?.photoUrl} size={44} />
            <div className="min-w-0">
              <p className="line-clamp-1 font-semibold text-neutral-900">{name}</p>
              {tier > 0 ? (
                <p className="flex items-center gap-1 text-xs font-medium text-neutral-500">
                  <Star size={12} fill={tierColor ?? "currentColor"} stroke="none" /> {t("contributorBadge", { tier: t("badge" + badgeLabel(tier)) })}
                </p>
              ) : (
                <p className="text-xs text-neutral-400">{t("memberLabel")}</p>
              )}
            </div>
          </div>
          <div className="my-1 h-px bg-black/5" />

          {ACCOUNT_LINKS.map((l) => (
            <Link
              key={l.href}
              href={l.href}
              role="menuitem"
              className="block rounded-xl px-3 py-2.5 text-[15px] text-neutral-700 transition hover:bg-neutral-100"
            >
              {t(l.key)}
            </Link>
          ))}

          {isAdmin && (
            // Stays open on click (unlike the links) so the switch visibly flips.
            <button
              type="button"
              role="menuitemcheckbox"
              aria-checked={editMode}
              onClick={toggleEditMode}
              className="flex w-full items-center gap-2 rounded-xl px-3 py-2.5 text-left text-[15px] text-neutral-700 transition hover:bg-neutral-100"
            >
              <PenLine size={16} />
              <span className="flex-1">{t("editModeLabel")}</span>
              <span className={`relative h-5 w-9 rounded-full transition ${editMode ? "bg-blue-600" : "bg-neutral-300"}`}>
                <span className={`absolute top-0.5 h-4 w-4 rounded-full bg-white shadow transition-all ${editMode ? "left-[18px]" : "left-0.5"}`} />
              </span>
            </button>
          )}

          {isAdmin && (
            <Link
              href="/admin"
              role="menuitem"
              className="block rounded-xl px-3 py-2.5 text-[15px] font-medium text-indigo-700 transition hover:bg-indigo-50"
            >
              {t("adminPanelLabel")}
            </Link>
          )}

          <div className="my-1 h-px bg-black/5" />
          <button
            type="button"
            role="menuitem"
            onClick={() => {
              setOpen(false);
              signOut();
            }}
            className="flex w-full items-center gap-2 rounded-xl px-3 py-2.5 text-left text-[15px] text-red-600 transition hover:bg-red-50"
          >
            <LogOut size={16} /> {t("logout")}
          </button>
        </div>
      )}
    </div>
  );
}

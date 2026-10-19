"use client";

import { useEffect } from "react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { AlertTriangle, ClipboardCheck, Disc3, Gauge, HeartHandshake, ListMusic, Mail, ShieldAlert, ShoppingBag } from "lucide-react";
import { useAuth } from "@/components/AuthProvider";
import { useT } from "@/components/LanguageProvider";

const SECTIONS = [
  { href: "/admin", key: "adminDashboardLabel", short: "adminDashboardLabel", icon: Gauge, match: (p: string) => p === "/admin" },
  { href: "/admin/review", key: "adminReviewQueueLabel", short: "adminReviewQueueLabel", icon: ClipboardCheck, match: (p: string) => p.startsWith("/admin/review") },
  { href: "/admin/requests", key: "adminSongRequestsLabel", short: "adminRequestsShort", icon: Mail, match: (p: string) => p.startsWith("/admin/requests") },
  { href: "/admin/issues", key: "adminIssueReportsLabel", short: "adminIssuesShort", icon: AlertTriangle, match: (p: string) => p.startsWith("/admin/issues") },
  { href: "/admin/artists", key: "tabArtists", short: "tabArtists", icon: Disc3, match: (p: string) => p.startsWith("/admin/artists") },
  { href: "/admin/playlists", key: "adminPlaylistsLabel", short: "adminPlaylistsLabel", icon: ListMusic, match: (p: string) => p.startsWith("/admin/playlists") },
  { href: "/admin/supporters", key: "adminSupportersLabel", short: "adminSupportersShort", icon: HeartHandshake, match: (p: string) => p.startsWith("/admin/supporters") },
  { href: "/admin/shop", key: "adminShopLabel", short: "adminShopLabel", icon: ShoppingBag, match: (p: string) => p.startsWith("/admin/shop") },
] as const;

// Frame for every /admin page: a sidebar on wide screens, a scrolling tab bar
// on narrow ones, and the gate. The gate is only a courtesy — what actually
// protects the data is firestore.rules (every admin write is checked against
// users/{uid}.isAdmin server-side) — but it keeps everyone else out of the UI.
export default function AdminShell({ children }: { children: React.ReactNode }) {
  const { t } = useT();
  const { status, isAdmin, profile } = useAuth();
  const pathname = usePathname();
  const router = useRouter();

  useEffect(() => {
    if (status === "signedOut") router.replace(`/login?next=${encodeURIComponent(pathname)}`);
  }, [status, pathname, router]);

  // Signed in but the profile (which holds isAdmin) hasn't arrived yet.
  if (status === "loading" || (status === "signedIn" && !profile)) {
    return (
      <div className="mx-auto max-w-6xl px-4 py-10">
        <div className="h-10 w-56 animate-pulse rounded-xl bg-black/5" />
        <div className="mt-6 h-64 animate-pulse rounded-3xl bg-black/5" />
      </div>
    );
  }
  if (status === "signedOut") return null;
  if (!isAdmin) {
    return (
      <div className="mx-auto flex max-w-md flex-col items-center px-4 py-24 text-center">
        <span className="flex h-16 w-16 items-center justify-center rounded-full bg-red-50 text-red-500">
          <ShieldAlert size={30} />
        </span>
        <h1 className="mt-5 text-2xl font-extrabold tracking-tight">{t("adminNotAuthorizedTitle")}</h1>
        <p className="mt-2 text-neutral-500">{t("adminNotAuthorizedBody")}</p>
        <Link href="/" className="mt-8 flex h-11 items-center rounded-full bg-black px-6 text-sm font-semibold text-white">
          {t("home")}
        </Link>
      </div>
    );
  }

  return (
    <div className="mx-auto flex w-full max-w-[90rem] flex-col gap-6 px-4 pb-24 pt-6 sm:px-6 lg:flex-row lg:gap-8">
      <nav aria-label={t("adminSectionsLabel")} className="lg:sticky lg:top-20 lg:w-56 lg:shrink-0 lg:self-start">
        <p className="mb-3 hidden px-3 text-xs font-bold uppercase tracking-[0.18em] text-neutral-400 lg:block">{t("adminPanelLabel")}</p>
        <ul className="flex gap-1.5 overflow-x-auto pb-1 lg:flex-col lg:overflow-visible lg:pb-0 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
          {SECTIONS.map((s) => {
            const active = s.match(pathname);
            return (
              <li key={s.href} className="shrink-0">
                <Link
                  href={s.href}
                  aria-current={active ? "page" : undefined}
                  className={`flex items-center gap-2.5 rounded-full px-4 py-2.5 text-sm font-semibold transition lg:rounded-2xl ${
                    active ? "bg-black text-white shadow" : "text-neutral-600 hover:bg-neutral-100"
                  }`}
                >
                  <s.icon size={17} />
                  <span className="lg:hidden">{t(s.short)}</span>
                  <span className="hidden lg:inline">{t(s.key)}</span>
                </Link>
              </li>
            );
          })}
        </ul>
      </nav>
      <div className="min-w-0 flex-1">{children}</div>
    </div>
  );
}

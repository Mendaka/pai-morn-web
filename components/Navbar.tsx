"use client";

import { useEffect, useState, useSyncExternalStore } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { Plus, Search } from "lucide-react";
import AccountMenu from "@/components/AccountMenu";
import BrandName from "@/components/BrandName";
import LanguageMenu from "@/components/LanguageMenu";
import { useT } from "@/components/LanguageProvider";
import SearchPalette from "@/components/SearchPalette";
import ThemeToggle from "@/components/ThemeToggle";
import { NAV_ITEMS } from "@/lib/nav";
import { registerServiceWorker } from "@/lib/register-service-worker";

// Floating pill navbar. Wide screens: logo, links, a search field that opens
// the quick-search palette, a "Submit" button, language and account. Phones
// drop the text links (the bottom tab bar, MobileBottomNav, takes over) and the
// search field becomes an icon. Ctrl/⌘+K opens search from anywhere.
export default function Navbar() {
  const pathname = usePathname();
  const { t } = useT();
  const [searching, setSearching] = useState(false);
  // Server and first client render say "not a Mac"; the real answer applies after hydration.
  const mac = useSyncExternalStore(
    () => () => {},
    () => /mac|iphone|ipad/i.test(navigator.platform),
    () => false,
  );

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "k") {
        e.preventDefault();
        setSearching(true);
      }
    };
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, []);

  // Navbar renders on every page, so this is as good a "the app shell is up" hook
  // as any — see lib/register-service-worker.ts for why it isn't a bare import.
  useEffect(() => {
    registerServiceWorker();
  }, []);

  const shortcut = mac ? "⌘K" : "Ctrl K";

  return (
    <header className="sticky top-0 z-40 border-b border-black/[0.07] bg-white/80 backdrop-blur-xl">
      <nav className="mx-auto flex h-16 max-w-[1600px] items-center gap-3 px-4 sm:px-6 lg:gap-6">
        <Link href="/" className="lift-spring text-[28px] leading-none text-black transition hover:scale-105 active:scale-95">
          <BrandName />
        </Link>

        <ul className="hidden h-full items-stretch md:flex lg:ml-2">
          {NAV_ITEMS.map((item) => {
            const active = item.match(pathname);
            return (
              <li key={item.href} className="h-full">
                <Link
                  href={item.href}
                  aria-current={active ? "page" : undefined}
                  className={`lift-spring relative flex h-full items-center px-2 text-[14px] font-semibold transition-all duration-200 active:scale-95 lg:px-3.5 lg:text-[15px] ${
                    active ? "-translate-y-px text-black" : "text-neutral-500 hover:-translate-y-px hover:text-black"
                  }`}
                >
                  {t(item.key)}
                  <span
                    className={`absolute inset-x-2 -bottom-px h-[3px] origin-bottom rounded-t-full bg-black transition-transform duration-300 lg:inset-x-3 ${
                      active ? "scale-100" : "scale-0"
                    }`}
                  />
                </Link>
              </li>
            );
          })}
        </ul>

        {/* the search "field": a button that opens the palette */}
        <button
          type="button"
          onClick={() => setSearching(true)}
          aria-label={t("searchTooltip")}
          className="lift-spring mx-auto hidden h-10 w-full max-w-sm items-center gap-2.5 rounded-xl bg-neutral-100 px-4 text-left text-[15px] text-neutral-500 ring-1 ring-inset ring-transparent transition hover:bg-neutral-200/70 hover:ring-black/10 active:scale-[0.98] xl:flex"
        >
          <Search size={17} className="shrink-0" />
          <span className="min-w-0 flex-1 truncate">{t("quickSearchHint")}</span>
          <kbd className="shrink-0 rounded-md bg-white px-1.5 py-0.5 font-sans text-[11px] font-semibold text-neutral-500 shadow-sm ring-1 ring-black/10">{shortcut}</kbd>
        </button>

        <div className="ml-auto flex items-center gap-0.5 text-black sm:gap-1 xl:ml-0">
          <button
            type="button"
            onClick={() => setSearching(true)}
            aria-label={t("searchTooltip")}
            title={`${t("searchTooltip")} (${shortcut})`}
            className="lift-spring flex h-9 w-9 items-center justify-center rounded-xl transition hover:bg-black/5 active:scale-90 sm:h-10 sm:w-10 xl:hidden"
          >
            <Search size={20} />
          </button>
          <Link
            href="/submit-song"
            title={t("submitSongTitle")}
            aria-label={t("submitSongTitle")}
            className="lift-spring flex h-9 items-center gap-1.5 rounded-xl bg-gradient-to-r from-indigo-600 to-blue-500 px-2.5 text-sm font-semibold text-white shadow-md shadow-indigo-500/25 transition hover:-translate-y-0.5 hover:scale-[1.04] hover:shadow-lg hover:shadow-indigo-500/40 active:translate-y-0 active:scale-[0.96] active:shadow-sm sm:h-10 sm:px-3 lg:px-4"
          >
            <Plus size={17} strokeWidth={2.6} />
            <span className="hidden lg:inline">{t("submitButton")}</span>
          </Link>
          <ThemeToggle />
          <LanguageMenu />
          <AccountMenu />
        </div>
      </nav>
      {searching && <SearchPalette onClose={() => setSearching(false)} />}
    </header>
  );
}

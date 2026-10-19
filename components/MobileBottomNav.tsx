"use client";

import { useLayoutEffect, useRef, useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { BookOpen, Gauge, Guitar, Home, Users } from "lucide-react";
import { useT } from "@/components/LanguageProvider";
import { NAV_ITEMS } from "@/lib/nav";

const ICONS: Record<string, React.ReactNode> = {
  "/": <Home size={22} />,
  "/songbook": <BookOpen size={22} />,
  "/tuner": <Gauge size={22} />,
  "/chords": <Guitar size={22} />,
  "/community": <Users size={22} />,
};

// Icon-only bottom tab bar for phone-width screens (Flutter's
// MobileBottomNav). Used to be a plain solid-black circle jumping between
// icons with no transition at all (matching the look the Flutter bar
// settled on after ITS OWN gradient/animated version was deliberately
// removed at some earlier point — that history predates this file and isn't
// otherwise recorded here). Owner asked for a "3D" feel here specifically
// (2026-10-01, after seeing a flashier Next.js site on YouTube) — added a
// sliding pill indicator that glides to the active tab (a raised platform,
// not just a color swap) with the active icon lifting up off it, using
// nothing heavier than CSS transforms/transitions (no WebGL/Three.js —
// this is a small, frequently-rendered nav element, not a hero section).
export default function MobileBottomNav() {
  const pathname = usePathname();
  const { t } = useT();
  const activeIndex = NAV_ITEMS.findIndex((item) => item.match(pathname));

  // Measures the active tab's real pixel center and drives the pill with
  // `transform: translate3d(...)` instead of animating `left` directly.
  // `left` is a layout property — animating it forces the browser to
  // recompute geometry on every single frame of the 320ms transition (a
  // reflow, not just a repaint), which is exactly what was making this bar
  // feel janky on real phones (owner: "หน้าจอโทรศัพค่อนข้างหน่วงพอสมควร
  // โดยเฉพาะปุ่ม navbar"). `transform` is GPU-composited and skips layout
  // entirely, which is why this is the standard technique for a sliding-tab
  // indicator rather than the percentage-based `left` this started as.
  const listRef = useRef<HTMLUListElement>(null);
  const itemRefs = useRef<(HTMLLIElement | null)[]>([]);
  const [pillX, setPillX] = useState<number | null>(null);

  useLayoutEffect(() => {
    const list = listRef.current;
    const el = itemRefs.current[activeIndex];
    if (!list || !el) return;
    const measure = () => {
      const listRect = list.getBoundingClientRect();
      const elRect = el.getBoundingClientRect();
      setPillX(elRect.left - listRect.left + elRect.width / 2);
    };
    measure();
    // The row's own width (and so every slot's pixel center) changes on
    // rotation/resize — re-measure rather than let the pill drift stale.
    window.addEventListener("resize", measure);
    return () => window.removeEventListener("resize", measure);
  }, [activeIndex]);

  return (
    <nav
      aria-label={t("primaryNavLabel")}
      className="fixed inset-x-0 bottom-0 z-40 border-t border-black/10 bg-[#f4f8fc] pb-[env(safe-area-inset-bottom)] md:hidden"
    >
      <ul ref={listRef} className="relative mx-auto flex h-16 max-w-md items-center justify-around">
        {pillX !== null && (
          <span
            aria-hidden
            className="mobile-nav-pill pointer-events-none absolute left-0 h-11 w-11 rounded-full bg-gradient-to-b from-neutral-700 to-black shadow-[0_8px_18px_-6px_rgba(0,0,0,0.6)]"
            style={{ transform: `translate3d(${pillX - 22}px, 0, 0)` }}
          />
        )}
        {NAV_ITEMS.map((item, i) => {
          const active = item.match(pathname);
          return (
            <li key={item.href} ref={(el) => { itemRefs.current[i] = el; }} className="relative z-10">
              <Link
                href={item.href}
                aria-label={t(item.key)}
                aria-current={active ? "page" : undefined}
                className={`mobile-nav-icon flex h-11 w-11 items-center justify-center rounded-full transition-transform duration-300 active:scale-90 ${
                  active ? "-translate-y-1 text-white" : "text-neutral-500"
                }`}
              >
                {ICONS[item.href]}
              </Link>
            </li>
          );
        })}
      </ul>
    </nav>
  );
}

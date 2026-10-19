"use client";

import dynamic from "next/dynamic";
import { useCallback, useEffect, useMemo, useRef, useState, useSyncExternalStore } from "react";
import { ChevronLeft, ChevronRight } from "lucide-react";
import BookPage from "@/components/BookPage";
import BookToolbar from "@/components/BookToolbar";
import { useT } from "@/components/LanguageProvider";
import { displayArtistName } from "@/lib/catalog";
import { useBookWindow } from "@/lib/use-book-window";

// react-pageflip touches the DOM directly on mount (same reason any
// canvas/DOM-owning widget in this codebase is client-only) — Server
// Components can't render it.
const HTMLFlipBook = dynamic(() => import("react-pageflip"), { ssr: false });

// The library's own .d.ts leaves the flip event payload typed `any` — this is
// the actual shape (confirmed against page-flip's source, EventObject.ts's
// `{data, object}`: the "flip" event's data is the new page index).
type FlipWidgetEvent = { data: number };

// No existing hook for this anywhere in the codebase (every other animation
// here is a CSS-only prefers-reduced-motion override) — book mode needs a
// JS-level answer since reduced motion means skipping react-pageflip
// entirely, not just disabling a CSS transition.
function usePrefersReducedMotion(): boolean {
  return useSyncExternalStore(
    () => () => {},
    () => window.matchMedia("(prefers-reduced-motion: reduce)").matches,
    () => false,
  );
}

// Same one-shot-read convention as usePrefersReducedMotion above (this
// codebase doesn't live-track a resize across the breakpoint for either —
// an acceptable simplification since crossing it after mount is rare, e.g.
// a desktop window resize, not a real device's normal use).
function useIsMobile(): boolean {
  return useSyncExternalStore(
    () => () => {},
    () => window.matchMedia("(max-width: 767px)").matches,
    () => false,
  );
}

// react-pageflip's "stretch" size mode still preserves the fixed width/height
// RATIO given to it (confirmed in page-flip's own source, Render.ts's
// calculateBoundsRect: pageHeight = pageWidth / (setting.width/setting.height))
// — it fills the container's width, then derives height from that ratio, only
// falling back to the container's real height as a ceiling if the ratio
// would overflow it. With the desktop-tuned 420/700 ratio that ceiling is
// exactly what kept kicking in on phones (a portrait ratio taller than most
// phones' own available height below the Navbar), leaving a blank gap under
// the page — see the book-full media query in globals.css, which reclaims
// the chrome around the book but can't fix a ratio mismatch on its own.
// Measuring the actual frame and feeding its exact pixel size back in as
// width/height/min/max makes the library's own ratio equal the container's
// ratio, which (per that same formula) resolves to an exact edge-to-edge
// fit with no leftover margin in either dimension.
//
// This only works because react-pageflip reads these props once, at
// construction (confirmed in its source: `new PageFlip(...)` is guarded by
// `!pageFlip.current`, never re-run when props change) — so sizes are
// rounded to a coarse 8px grid to avoid a remount on every trivial resize
// jitter (e.g. a mobile browser's address bar hiding on scroll), while a
// real orientation change still crosses that grid and gets a correctly
// re-fitted instance via the `key` this feeds in BookReader below.
function useMobileFrameSize(active: boolean): [(el: HTMLDivElement | null) => void, { width: number; height: number } | null] {
  const [size, setSize] = useState<{ width: number; height: number } | null>(null);
  const observerRef = useRef<ResizeObserver | null>(null);
  const setRef = useCallback(
    (el: HTMLDivElement | null) => {
      observerRef.current?.disconnect();
      observerRef.current = null;
      if (!el || !active) return;
      const round = (n: number) => Math.max(8, Math.round(n / 8) * 8);
      const update = () => setSize({ width: round(el.clientWidth), height: round(el.clientHeight) });
      update();
      observerRef.current = new ResizeObserver(update);
      observerRef.current.observe(el);
    },
    [active],
  );
  useEffect(() => () => observerRef.current?.disconnect(), []);
  return [setRef, size];
}

export type BookSongStub = { id: string; songName: string; artistNames: string[]; band: string };

const navBtn = "flex h-11 items-center gap-1.5 rounded-full bg-white px-5 text-sm font-semibold text-neutral-700 shadow-[0_2px_16px_-8px_rgba(0,0,0,0.25)] transition hover:bg-neutral-50 disabled:opacity-30 disabled:hover:bg-white";

// Phones: Book Mode takes the whole screen below the Navbar (owner: "เต็มจอ
// ไปเลยเหลือไว้แค่ navbar พอ" — the screen is small enough that the page
// heading, Footer and MobileBottomNav were all wasted space). Same technique
// as SongReader's "Full" toggle (documentElement.classList + a paired
// globals.css block, here html.book-full) but always on for as long as the
// real flip-book view is mounted, not a user-facing toggle. Skipped for the
// reduced-motion fallback below: that view's card doesn't stretch to fill
// the freed-up space (it's a fixed aspect-[3/4] box), so hiding chrome there
// would just leave blank space rather than a genuinely fuller page. Desktop
// is unaffected either way since every book-full rule is gated to below the
// md breakpoint.
function useBookFullScreen(enabled: boolean) {
  useEffect(() => {
    if (!enabled) return;
    document.documentElement.classList.add("book-full");
    return () => document.documentElement.classList.remove("book-full");
  }, [enabled]);
}

export default function BookReader({ songs }: { songs: BookSongStub[] }) {
  const { t } = useT();
  // eslint-disable-next-line react-hooks/exhaustive-deps -- `songs` is the server-seeded list for this page's whole lifetime; re-deriving only when its length changes avoids a new array (and a window reset) on every render.
  const ids = useMemo(() => songs.map((s) => s.id), [songs.length]);
  const { getSong, onPageChange } = useBookWindow(ids);
  const [index, setIndex] = useState(0);
  // Book-wide, not per-song (see BookToolbar's own comment for why).
  const [transpose, setTranspose] = useState(0);
  const [scale, setScale] = useState(1);
  const reducedMotion = usePrefersReducedMotion();
  const isMobile = useIsMobile();
  useBookFullScreen(!reducedMotion);
  const [frameRef, mobileSize] = useMobileFrameSize(!reducedMotion && isMobile);
  const fillMobile = isMobile && mobileSize !== null;

  const setPage = useCallback(
    (next: number) => {
      const clamped = Math.max(0, Math.min(songs.length - 1, next));
      setIndex(clamped);
      onPageChange(clamped);
    },
    [songs.length, onPageChange],
  );

  if (songs.length === 0) return null;

  if (reducedMotion) {
    const song = songs[index];
    return (
      <div className="mx-auto w-full max-w-2xl">
        <BookToolbar transpose={transpose} setTranspose={setTranspose} scale={scale} setScale={setScale} />
        <div className="aspect-[3/4] overflow-hidden rounded-2xl border border-black/10 shadow-xl">
          <BookPage title={song.songName} artist={displayArtistName(song)} song={getSong(song.id)} transpose={transpose} scale={scale} />
        </div>
        <div className="mt-5 flex items-center justify-between">
          <button type="button" onClick={() => setPage(index - 1)} disabled={index === 0} className={navBtn}>
            <ChevronLeft size={18} /> {t("previousSongTooltip")}
          </button>
          <span className="text-sm font-medium tabular-nums text-neutral-500">
            {index + 1} / {songs.length}
          </span>
          <button type="button" onClick={() => setPage(index + 1)} disabled={index === songs.length - 1} className={navBtn}>
            {t("nextSongTooltip")} <ChevronRight size={18} />
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="book-page-frame mx-auto flex w-full max-w-5xl flex-col items-center">
      <BookToolbar transpose={transpose} setTranspose={setTranspose} scale={scale} setScale={setScale} />
      {/* frameRef (not the outer div above) is what useMobileFrameSize measures
          — it excludes the toolbar's own height, since that toolbar takes real
          space out of the flex column too. Measuring the outer div instead
          would tell the flip-book it has more room than it actually does,
          overflowing by exactly the toolbar's height. */}
      <div ref={frameRef} className="book-flip-slot flex w-full flex-1 flex-col items-center">
        {/* On mobile, wait for the first real measurement before mounting the
            flip-book at all — react-pageflip only reads width/height once, at
            construction (see useMobileFrameSize above), so mounting it early
            with a placeholder size would lock in the wrong ratio for good. */}
        {isMobile && !mobileSize ? (
          <div className="w-full flex-1" aria-hidden />
        ) : (
          <HTMLFlipBook
            key={fillMobile ? `m-${mobileSize.width}x${mobileSize.height}` : "desktop"}
            width={fillMobile ? mobileSize.width : 420}
            height={fillMobile ? mobileSize.height : 700}
            size="stretch"
            minWidth={fillMobile ? mobileSize.width : 300}
            maxWidth={fillMobile ? mobileSize.width : 650}
            minHeight={fillMobile ? mobileSize.height : 440}
            maxHeight={fillMobile ? mobileSize.height : 1100}
            showCover={false}
            drawShadow
            flippingTime={700}
            usePortrait
            startZIndex={0}
            autoSize
            maxShadowOpacity={0.5}
            mobileScrollSupport
            clickEventForward
            useMouseEvents
            swipeDistance={20}
            showPageCorners
            disableFlipByClick
            startPage={0}
            className="book-flip"
            style={{}}
            onFlip={(e: FlipWidgetEvent) => setPage(e.data)}
          >
            {songs.map((s) => (
              <BookPage key={s.id} title={s.songName} artist={displayArtistName(s)} song={getSong(s.id)} transpose={transpose} scale={scale} />
            ))}
          </HTMLFlipBook>
        )}
      </div>

      {/* No Prev/Next buttons here (unlike the reduced-motion fallback below,
          which has no other way to turn a page): react-pageflip's own corner
          drag already does it, and dropping the button row frees up the
          vertical space it took for more of the actual page. Hidden on
          mobile full-screen (globals.css) along with everything else that
          isn't the book itself. */}
      <p className="mt-3 text-sm font-medium tabular-nums text-neutral-500">
        {index + 1} / {songs.length}
      </p>
    </div>
  );
}

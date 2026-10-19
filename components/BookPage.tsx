"use client";

import { forwardRef } from "react";
import LyricLine from "@/components/LyricLine";
import type { Song } from "@/lib/songs";

// Book mode's page keeps a fixed frame (react-pageflip needs that for the
// flip physics), but its content is a PLAIN scrolling pane, same idea as the
// normal reader — no shrink-to-fit, no hiding repeated chords, no multi-
// column reflow. Those were all in service of "make every song fit one
// screen with no scrolling," which turned out not to be worth the tradeoffs
// (some songs still didn't fit, and the compromises to get there didn't feel
// right) — see CLAUDE.md's 2026-10-07/08 entries for the abandoned attempts.
// The book still *feels* like a book (the flip transition between songs), a
// long song just reads exactly like it already does on the normal reader.
// `scale` (from BookToolbar, book-wide rather than per-page — every page is
// mounted at once for the flip physics, so per-song settings aren't a good
// fit here) multiplies this base, same idea as the reader's own text-size
// control but tuned smaller since a book page's frame is tighter.
const BASE_LYRIC_REM = 0.95;

type BookPageProps = {
  title: string;
  artist: string;
  song?: Song;
  transpose: number;
  scale: number;
};

// react-pageflip clones each child into its own page element and needs a
// real DOM node at the root — forwardRef so the library can attach it.
// `song` is undefined until lib/use-book-window.ts's window reaches this
// page: title/artist (from the cheap catalog list) render immediately, the
// lyrics area shows a plain shimmer placeholder until then.
//
// This root div IS the scroll container (not a nested flex child) —
// react-pageflip sets its own inline `position`/`height`/`display` on
// whatever element the ref points to (confirmed by inspecting it live: it
// overrides `display` to `block`, which silently broke an earlier version of
// this component that relied on `flex`/`flex-1` here to bound a scrollable
// inner div — that inner div just rendered at its full natural content
// height instead of being clipped, so nothing was ever scrollable, only
// clippable). Scrolling directly on this root, whose height react-pageflip
// DOES set correctly regardless of `display`, sidesteps that fight entirely.
//
// The `--lyric-size` variable, though, can't live on THIS same root: page-
// flip's HTMLPage.ts sets `this.element.style.cssText = newStyle` on it
// wholesale (confirmed in its source) to manage position/z-index during a
// flip — a full replace, not a merge, silently discarding any custom
// property React had set there. That's why text-size changes had no visible
// effect when first wired up: the variable never survived past that
// overwrite, and every page was silently rendering at LyricLine's *fallback*
// size (var(--lyric-size, 1.0625rem) in globals.css — the reader's default,
// not BookPage's own smaller BASE_LYRIC_REM). Setting it one level down, on
// an inner div page-flip never touches, lets it actually reach LyricLine via
// normal CSS custom-property inheritance.
const BookPage = forwardRef<HTMLDivElement, BookPageProps>(function BookPage({ title, artist, song, transpose, scale }, ref) {
  return (
    <div
      ref={ref}
      onCopy={(e) => e.preventDefault()}
      onCut={(e) => e.preventDefault()}
      onContextMenu={(e) => e.preventDefault()}
      onDragStart={(e) => e.preventDefault()}
      className="book-page no-copy h-full w-full overflow-y-auto bg-[#fffdf8] px-5 py-6 sm:px-8 sm:py-9"
    >
      <div style={{ ["--lyric-size" as string]: `${BASE_LYRIC_REM * scale}rem` }}>
        <h2 className="line-clamp-2 text-lg font-bold leading-snug text-neutral-900 sm:text-xl">{title}</h2>
        {artist && <p className="mb-3 mt-0.5 line-clamp-1 text-sm text-neutral-500">{artist}</p>}
        {song ? (
          song.lyrics.map((line, i) => <LyricLine key={i} content={line.content} transpose={transpose} />)
        ) : (
          <div className="mt-3 space-y-3" aria-hidden>
            {[...Array(6)].map((_, i) => (
              <div key={i} className="book-page-skeleton-line h-3.5 rounded-full bg-black/[0.06]" style={{ width: `${70 - i * 6}%` }} />
            ))}
          </div>
        )}
      </div>
    </div>
  );
});

export default BookPage;

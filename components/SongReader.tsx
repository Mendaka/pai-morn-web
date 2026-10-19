"use client";

import { Suspense, useEffect, useMemo, useRef, useState } from "react";
import { ArrowUpToLine, Camera, CameraOff, ChevronDown, Columns3, Eye, Guitar, Minus, Pause, PenLine, Play, Plus, Printer, RotateCcw, SlidersHorizontal, Timer, UserRound, Users, TextWrap, Maximize, Minimize } from "lucide-react";
import ChordDialog from "@/components/ChordDialog";
import ChordDiagram from "@/components/ChordDiagram";
import { suggestCapo, uniqueChords } from "@/lib/capo";
import { transposeChord } from "@/lib/chords";
import { lookupChordShape, type ChordShape } from "@/lib/chord-shapes";
import { useInstrument, useLeftHanded } from "@/lib/stored";
import ReaderActions from "@/components/ReaderActions";
import SetlistNav from "@/components/SetlistNav";
import SongBreadcrumb from "@/components/SongBreadcrumb";
import { recordSongView } from "@/lib/record-views";
import { useT } from "@/components/LanguageProvider";
import FavoriteButton from "@/components/FavoriteButton";
import LyricLine from "@/components/LyricLine";
import YoutubeMiniPlayer from "@/components/YoutubeMiniPlayer";
import { extractYoutubeVideoId } from "@/lib/youtube";
import EditSongButton from "@/components/EditSongButton";
import { mergeForCompact, splitIntoSections } from "@/lib/lyrics";
import { useMetronome } from "@/lib/use-metronome";
import { DEFAULT_SPEED, MAX_SPEED, MIN_SPEED, useAutoScroll } from "@/lib/use-auto-scroll";
import type { Song } from "@/lib/songs";

const MIN_SCALE = 0.8;
const MAX_SCALE = 1.7;
const SPEED_STEP = 5;

export default function SongReader({ song }: { song: Song }) {
  const [transpose, setTranspose] = useState(0);
  const [scale, setScale] = useState(1);
  const [chordOpen, setChordOpen] = useState<string | null>(null);
  const [playerOpen, setPlayerOpen] = useState(false);
  const [speed, setSpeed] = useState(DEFAULT_SPEED);
  const scroller = useAutoScroll(speed);
  const metronome = useMetronome();
  const [compact, setCompact] = useState(false);
  // Desktop-only "section cards" view (2026-10-07, owner: "ดูเนื้อเพลงแบบ
  // แนวนอน...แต่ละตอนทำแสดงเป็นแบบ Row" — each Intro/Verse/Chorus section as
  // its own card, laid out left-to-right instead of stacked top-to-bottom).
  // Deliberately NOT trying to force every section (or the whole song) to
  // fit on screen with no scrolling at all — that exact ask for Book Mode
  // earlier this project turned out not to work for arbitrary-length songs,
  // and the owner agreed up front here that both axes can scroll when a
  // song doesn't fit: horizontally across many sections, and vertically
  // within one long section's own card.
  const [horizontalView, setHorizontalView] = useState(false);
  // Defaults on; the toggle in the pinned bar below is for someone who finds
  // the floating chord column in the way, not an opt-in feature.
  const [chordsVisible, setChordsVisible] = useState(true);
  // Phones: the control panel is folded away by default so the lyrics get the screen.
  const [controlsOpen, setControlsOpen] = useState(false);
  // "Full": the browser's fullscreen with only the lyrics on screen (navbar,
  // headers and controls hidden by the reader-full class, see globals.css).
  // Browsers without the Fullscreen API (iPhone Safari) still get the
  // chrome-free view, just not the OS-level fullscreen.
  const [full, setFull] = useState(false);
  useEffect(() => {
    document.documentElement.classList.toggle("reader-full", full);
  }, [full]);
  useEffect(() => {
    // Esc / the browser's own exit gesture leaves fullscreen without our button.
    const onChange = () => {
      if (!document.fullscreenElement) setFull(false);
    };
    document.addEventListener("fullscreenchange", onChange);
    return () => {
      document.removeEventListener("fullscreenchange", onChange);
      document.documentElement.classList.remove("reader-full");
      if (document.fullscreenElement) void document.exitFullscreen();
    };
  }, []);
  function toggleFull() {
    if (full) {
      setFull(false);
      if (document.fullscreenElement) void document.exitFullscreen();
      return;
    }
    setFull(true);
    void document.documentElement.requestFullscreen?.().catch(() => {});
  }

  // Faint front-camera feed behind the lyrics, phone only (owner: filming
  // themselves playing guitar along with the lyrics for TikTok/Facebook —
  // "เราดีดกีตาร์ตามเพลง ให้หน้าเราไปอยู่พื้นหลังเนื้อเพลงจางๆเหมือนลายน้ำ").
  // Deliberately NOT an in-app screen recorder: `getDisplayMedia` (the only
  // way a web page can record its own screen) isn't available to web pages
  // at all on iOS Safari, and is a clunky pick-a-tab flow even where it
  // does work — this just renders the live feed as a CSS layer behind the
  // text, and the owner records the result with their phone's own native
  // screen recorder (every modern iPhone/Android has one), which is
  // reliable everywhere instead of fighting browser support gaps.
  const [cameraStatus, setCameraStatus] = useState<"idle" | "on" | "denied">("idle");
  const cameraVideoRef = useRef<HTMLVideoElement>(null);
  const cameraStreamRef = useRef<MediaStream | null>(null);
  useEffect(
    () => () => {
      cameraStreamRef.current?.getTracks().forEach((t) => t.stop());
    },
    [],
  );
  // The <video> element only mounts once cameraStatus flips to "on" (see
  // render below), so the ref isn't live yet at the point toggleCamera()
  // gets the stream — attach it here instead, once the element exists.
  useEffect(() => {
    if (cameraStatus === "on" && cameraVideoRef.current && cameraStreamRef.current) {
      cameraVideoRef.current.srcObject = cameraStreamRef.current;
    }
  }, [cameraStatus]);
  async function toggleCamera() {
    if (cameraStatus === "on") {
      cameraStreamRef.current?.getTracks().forEach((t) => t.stop());
      cameraStreamRef.current = null;
      setCameraStatus("idle");
      return;
    }
    try {
      cameraStreamRef.current = await navigator.mediaDevices.getUserMedia({ video: { facingMode: "user" }, audio: false });
      setCameraStatus("on");
    } catch {
      // Permission denied, no camera, or an insecure context — one shared
      // message covers all of them, same convention as TunerView's mic gate.
      setCameraStatus("denied");
    }
  }
  const rows = useMemo(() => (compact ? mergeForCompact(song.lyrics) : song.lyrics), [compact, song.lyrics]);
  // Sectioning always runs against the song's own blank-line boundaries, not
  // `rows` — compact mode already merges short lines together for the
  // normal vertical view, and re-splitting ITS output back into sections
  // would fight that merge instead of complementing it. A song with no
  // blank lines anywhere comes back as a single one-element array (the
  // whole song as one section) rather than empty, matching the fallback
  // `splitIntoSections` itself documents.
  const sections = useMemo(() => splitIntoSections(song.lyrics), [song.lyrics]);
  const counted = useRef<string | null>(null);
  useEffect(() => {
    if (counted.current === song.id) return;
    counted.current = song.id;
    recordSongView(song.id);
  }, [song.id]);
  const videoId = song.youtubeLink ? extractYoutubeVideoId(song.youtubeLink) : null;
  const { t, category: categoryLabel } = useT();

  const { ukulele } = useInstrument();
  const { leftHanded } = useLeftHanded();
  // One entry per distinct chord in the (transposed) song, in first-appearance order.
  const backdrop = useMemo(() => {
    const seen = new Set<string>();
    const out: { name: string; shape: ChordShape }[] = [];
    for (const line of song.lyrics)
      for (const token of line.content ?? []) {
        if (token.type !== "chord" || !token.text) continue;
        const name = transposeChord(token.text, transpose);
        if (seen.has(name)) continue;
        seen.add(name);
        const shape = lookupChordShape(name, ukulele);
        if (shape) out.push({ name, shape });
      }
    return out;
  }, [song.lyrics, transpose, ukulele]);

  // Capo suggestion is derived from the song's own (untransposed) chords — moving
  // the capo is a substitute for the Key stepper above, not stackable with it, so
  // it only ever offers to set `transpose` to `-fret`, never combines with it.
  const originalChords = useMemo(() => uniqueChords(song.lyrics), [song.lyrics]);
  const capo = useMemo(() => suggestCapo(originalChords), [originalChords]);
  const capoApplied = capo !== null && transpose === -capo.fret;

  const changed = transpose !== 0 || scale !== 1;
  const category = song.category ? categoryLabel(song.category.toLowerCase()) : "";

  return (
    <article
      className={`mx-auto w-full px-4 pb-16 pt-4 transition-[max-width] duration-300 sm:px-6 sm:pt-6 ${
        horizontalView ? "max-w-none" : "max-w-3xl"
      }`}
    >
      {/* Faint selfie-camera background, toggled by the Camera button below.
          Fixed to the viewport (not scoped to the lyrics card) and sized to
          the exact strip between the top Navbar and MobileBottomNav (both
          h-16/64px, confirmed in their own source) — owner: "อยากให้เต็มจอ
          ระหว่าง appbar กับ navbar" (wants it filling the full screen
          between the top and bottom bars, not just inside the lyrics card).
          Stays put while the lyrics scroll past it, same idea as a fixed
          wallpaper behind scrolling content. `z-0` keeps it under every
          other piece of real UI (the pinned play bar is `z-30`, both navs
          are `z-40`) without needing to touch any of their own z-index.
          Mirrored (a front camera shown un-mirrored looks backwards to the
          person looking at their own phone). `playsInline` + `muted` are
          required for iOS Safari to play a live stream inline at all, not
          just a nicety here. The lyrics card's own background goes
          semi-transparent + blurred while this is on (see its className
          below) so the feed actually shows through instead of being hidden
          behind an opaque white card. */}
      {cameraStatus === "on" && (
        <video
          ref={cameraVideoRef}
          aria-hidden
          autoPlay
          muted
          playsInline
          className="no-print pointer-events-none fixed inset-x-0 top-16 z-0 scale-x-[-1] object-contain opacity-70 md:hidden"
          // `<video>` is a replaced element — with `height: auto` (the
          // default), fixed-positioned replaced elements size themselves
          // from their OWN intrinsic aspect ratio even when both `top` and
          // `bottom` are set, they don't stretch to fill the gap between
          // them the way a plain block box would (confirmed empirically:
          // the element rendered far shorter than the available strip,
          // matching the camera's native ~4:3 feed instead). An explicit
          // `height` sidesteps that entirely — `object-contain` then fits
          // the actual video pixels within this real, full-strip box,
          // letterboxing instead of under-filling it.
          style={{ height: "calc(100dvh - 8rem - env(safe-area-inset-bottom))" }}
        />
      )}

      {/* useSearchParams (?setlist=, ?from=) needs Suspense on a statically rendered page */}
      <Suspense fallback={null}>
        <SongBreadcrumb song={song} />
        <SetlistNav songId={song.id} />
      </Suspense>

      {/* Key / text size / metronome / compact / full / reset / print. Scrolls away
          with the page (only the play bar below is pinned); phones fold it away. */}
      <div data-keep-scrolling className="no-print rounded-2xl border border-black/5 bg-white shadow-[0_2px_16px_-8px_rgba(0,0,0,0.15)]">
        <button
          type="button"
          onClick={() => setControlsOpen((o) => !o)}
          aria-expanded={controlsOpen}
          className="flex h-11 w-full items-center gap-2 px-4 text-sm font-semibold text-neutral-700 md:hidden"
        >
          <SlidersHorizontal size={16} /> {t("settingsLabel")}
          <ChevronDown size={16} className={`ml-auto transition-transform ${controlsOpen ? "rotate-180" : ""}`} />
        </button>
        <div
          className={`${controlsOpen ? "flex" : "hidden"} flex-wrap items-center justify-center gap-x-5 gap-y-2 border-t border-black/5 px-4 py-2.5 md:flex md:border-t-0`}
        >
          <Stepper
            label={t("keyLabel")}
            value={transpose > 0 ? `+${transpose}` : `${transpose}`}
            onMinus={() => setTranspose((t) => Math.max(-11, t - 1))}
            onPlus={() => setTranspose((t) => Math.min(11, t + 1))}
          />
          <Stepper
            label={t("textSizeLabel")}
            value={`${Math.round(scale * 100)}%`}
            onMinus={() => setScale((s) => Math.max(MIN_SCALE, Math.round((s - 0.1) * 10) / 10))}
            onPlus={() => setScale((s) => Math.min(MAX_SCALE, Math.round((s + 0.1) * 10) / 10))}
          />
          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={() => metronome.setEnabled(!metronome.enabled)}
              aria-pressed={metronome.enabled}
              className={`flex h-9 items-center gap-1.5 rounded-full px-3.5 text-sm font-semibold transition ${
                metronome.enabled ? "bg-blue-600 text-white" : "bg-neutral-100 text-neutral-700 hover:bg-neutral-200"
              }`}
            >
              <Timer size={15} /> {t("metronomeLabel")}
            </button>
            <div className="flex items-center rounded-full bg-neutral-100 p-0.5">
              <button
                type="button"
                onClick={() => metronome.changeBpm(-1)}
                aria-label={`${t("metronomeLabel")} ${t("downLabel")}`}
                className="flex h-8 w-8 items-center justify-center rounded-full text-neutral-700 transition hover:bg-white hover:shadow"
              >
                <Minus size={16} />
              </button>
              <span className="min-w-9 text-center text-sm font-semibold tabular-nums" aria-live="polite">{metronome.bpm}</span>
              <button
                type="button"
                onClick={() => metronome.changeBpm(1)}
                aria-label={`${t("metronomeLabel")} ${t("upLabel")}`}
                className="flex h-8 w-8 items-center justify-center rounded-full text-neutral-700 transition hover:bg-white hover:shadow"
              >
                <Plus size={16} />
              </button>
            </div>
          </div>
          <button
            type="button"
            onClick={() => setCompact((c) => !c)}
            aria-pressed={compact}
            title={t("compactHint")}
            className={`flex h-9 items-center gap-1.5 rounded-full px-3.5 text-sm font-semibold transition ${
              compact ? "bg-blue-600 text-white" : "bg-neutral-100 text-neutral-700 hover:bg-neutral-200"
            }`}
          >
            <TextWrap size={15} /> {t("compactLabel")}
          </button>
          <div className="flex items-center gap-1">
            <button
              type="button"
              onClick={toggleFull}
              className="flex h-9 items-center gap-1.5 rounded-full px-3 text-sm font-medium text-neutral-600 transition hover:bg-black/5"
            >
              <Maximize size={15} /> {t("fullViewLabel")}
            </button>
            <button
              type="button"
              onClick={() => {
                metronome.setEnabled(false);
                setTranspose(0);
                setScale(1);
              }}
              disabled={!changed}
              className="flex h-9 items-center gap-1.5 rounded-full px-3 text-sm font-medium text-neutral-600 transition hover:bg-black/5 disabled:opacity-30"
            >
              <RotateCcw size={15} /> {t("resetLabel")}
            </button>
            <button
              type="button"
              onClick={() => window.print()}
              className="flex h-9 items-center gap-1.5 rounded-full px-3 text-sm font-medium text-neutral-600 transition hover:bg-black/5"
            >
              <Printer size={15} /> {t("printLabel")}
            </button>
          </div>
        </div>
      </div>

      {/* The one pinned element: play / speed / stop, so auto-scroll can always be
          paused or re-timed however far down the song is. */}
      <div
        data-keep-scrolling
        className="no-print sticky top-[68px] z-30 mt-2 flex items-center gap-2 rounded-2xl border border-black/5 bg-white/90 px-2 py-1.5 shadow-[0_8px_30px_-12px_rgba(0,0,0,0.25)] backdrop-blur-xl"
      >
        <button
          type="button"
          onClick={scroller.toggle}
          aria-pressed={scroller.running}
          aria-label={t("autoScrollLabel")}
          title={t("autoScrollLabel")}
          className={`flex h-9 w-9 shrink-0 items-center justify-center rounded-full transition ${
            scroller.running ? "bg-blue-600 text-white" : "bg-neutral-100 text-neutral-700 hover:bg-neutral-200"
          }`}
        >
          {scroller.running ? <Pause size={16} className="fill-current" /> : <Play size={16} className="fill-current" />}
        </button>
        <div className="mx-1 flex shrink-0 items-center gap-1 rounded-full bg-neutral-100 p-0.5">
          <button
            type="button"
            onClick={() => setSpeed((s) => Math.max(MIN_SPEED, s - SPEED_STEP))}
            aria-label={`${t("scrollSpeedLabel")} ${t("downLabel")}`}
            className="flex h-8 w-8 items-center justify-center rounded-full text-neutral-700 transition hover:bg-white hover:shadow"
          >
            <Minus size={16} />
          </button>
          <span className="w-8 text-center text-sm font-semibold tabular-nums text-neutral-700" aria-live="polite">
            {speed}
          </span>
          <button
            type="button"
            onClick={() => setSpeed((s) => Math.min(MAX_SPEED, s + SPEED_STEP))}
            aria-label={`${t("scrollSpeedLabel")} ${t("upLabel")}`}
            className="flex h-8 w-8 items-center justify-center rounded-full text-neutral-700 transition hover:bg-white hover:shadow"
          >
            <Plus size={16} />
          </button>
        </div>
        <button
          type="button"
          onClick={scroller.reset}
          aria-label={t("scrollToTopLabel")}
          title={t("scrollToTopLabel")}
          className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-neutral-600 transition hover:bg-black/5"
        >
          <ArrowUpToLine size={17} />
        </button>
        {backdrop.length > 0 && (
          <button
            type="button"
            onClick={() => setChordsVisible((v) => !v)}
            aria-pressed={chordsVisible}
            aria-label={t("chordColumnLabel")}
            title={t("chordColumnLabel")}
            className={`flex h-9 w-9 shrink-0 items-center justify-center rounded-full transition ${
              chordsVisible ? "bg-blue-600 text-white" : "bg-neutral-100 text-neutral-700 hover:bg-neutral-200"
            }`}
          >
            <Guitar size={16} />
          </button>
        )}
        {/* Desktop only — sections side-by-side needs real screen width a
            phone doesn't have (see the useState comment above for why this
            exists at all, and why it's allowed to scroll both axes rather
            than forcing every section to fit). */}
        {sections.length > 1 && (
          <button
            type="button"
            onClick={() => setHorizontalView((v) => !v)}
            aria-pressed={horizontalView}
            aria-label={t("horizontalViewLabel")}
            title={t("horizontalViewLabel")}
            className={`hidden h-9 w-9 shrink-0 items-center justify-center rounded-full transition md:flex ${
              horizontalView ? "bg-blue-600 text-white" : "bg-neutral-100 text-neutral-700 hover:bg-neutral-200"
            }`}
          >
            <Columns3 size={16} />
          </button>
        )}
        {/* Phones only — filming yourself with the lyrics on screen is a
            selfie-camera, hold-the-phone-up behavior; nobody films a laptop
            webcam this way. */}
        <button
          type="button"
          onClick={toggleCamera}
          aria-pressed={cameraStatus === "on"}
          aria-label={t("cameraWatermarkLabel")}
          title={t("cameraWatermarkLabel")}
          className={`flex h-9 w-9 shrink-0 items-center justify-center rounded-full transition md:hidden ${
            cameraStatus === "on" ? "bg-blue-600 text-white" : "bg-neutral-100 text-neutral-700 hover:bg-neutral-200"
          }`}
        >
          {cameraStatus === "on" ? <Camera size={16} /> : <CameraOff size={16} />}
        </button>
      </div>
      {cameraStatus === "denied" && (
        <p role="alert" className="no-print mt-2 text-xs font-medium text-red-600 md:hidden">
          {t("cameraPermissionDeniedMessage")}
        </p>
      )}

      {/* Not part of the song sheet: the buttons, and the key / category / views. */}
      <div className="no-print mt-3 flex flex-wrap items-center gap-2">
        <FavoriteButton songId={song.id} />
        {videoId && (
          <button
            type="button"
            onClick={() => setPlayerOpen((o) => !o)}
            aria-pressed={playerOpen}
            className="inline-flex h-10 items-center gap-2 rounded-full bg-neutral-100 px-4 text-sm font-semibold text-neutral-800 transition hover:bg-neutral-200"
          >
            <Play size={15} className="fill-current" /> {t("listenOriginalTooltip")}
          </button>
        )}
        <ReaderActions songId={song.id} songName={song.songName} />
        <EditSongButton songId={song.id} variant="pill" />
        <p className="ml-auto flex flex-wrap items-center gap-x-3 gap-y-0.5 text-sm text-neutral-500">
          {song.key && (
            <span>
              Key {song.key}
              {song.keyIsMinor ? "m" : ""}
            </span>
          )}
          {category && <span>{category}</span>}
          <span className="flex items-center gap-1">
            <Eye size={13} /> {song.viewCount.toLocaleString()}
          </span>
        </p>
      </div>

      {/* Only shown when a capo would trade the song's own chords for the classic
          open-shape set — a strict win (easier fingering), so it's worth surfacing
          even though most songs don't qualify. */}
      {capo && (
        <div className="no-print mt-2 flex flex-wrap items-center gap-x-3 gap-y-2 rounded-2xl border border-amber-200 bg-amber-50 px-4 py-2.5 text-sm text-amber-900">
          <Guitar size={16} className="shrink-0" aria-hidden />
          <span>
            <span className="font-semibold">{t(capoApplied ? "capoAppliedLabel" : "capoSuggestionLabel", { fret: capo.fret })}</span>{" "}
            <span className="font-mono font-semibold">{capo.shapes.join(" ")}</span>
          </span>
          <button
            type="button"
            onClick={() => setTranspose(capoApplied ? 0 : -capo.fret)}
            className={`ml-auto shrink-0 rounded-full px-3.5 py-1.5 text-xs font-semibold transition ${
              capoApplied ? "bg-white text-amber-900 hover:bg-amber-100" : "bg-amber-600 text-white hover:bg-amber-700"
            }`}
          >
            {t(capoApplied ? "capoUndoButton" : "capoApplyButton")}
          </button>
        </div>
      )}

      {/* Chord reference strip: horizontal, above the lyrics card, ONLY in
          Section view (2026-10-08, owner: "ลายจับคอร์ดทำเป็นแนวนอน...อยู่
          นอกพื้นที่เพลงดีไหม", then correcting a misread of that once it
          shipped: "ผมหมายถึงเฉพาะดูแนวนอนครับ ถ้าไม่กดดูแบบแนวนอน ลายคอร์ด
          อยู่ชิดขวาและตั้งลอยเหมือนเดิมไม่ต้องทำอะไรเลย" — this was only ever
          meant to apply inside Section view; the normal single-column view
          keeps its original sticky right-side column, untouched below). Own
          horizontal scroll if there are more chords than fit, rather than
          wrapping — keeps the strip's height predictable regardless of
          chord count. */}
      {horizontalView && backdrop.length > 0 && chordsVisible && (
        <div className="no-print mt-2 flex items-center gap-3 overflow-x-auto rounded-2xl border border-black/5 bg-white px-4 py-3 shadow-[0_2px_16px_-8px_rgba(0,0,0,0.15)]">
          {backdrop.map(({ name, shape }) => (
            <div key={name} className="flex shrink-0 flex-col items-center text-[color:var(--chord)]">
              <ChordDiagram shape={shape} mirrored={leftHanded} dotColor="currentColor" className="h-12 w-12 sm:h-14 sm:w-14" />
              <span className="text-[10px] font-bold sm:text-[11px]">{name}</span>
            </div>
          ))}
        </div>
      )}

      {/* Grid-stacks the lyrics card and the (normal-view-only) floating
          chord column in the same cell, same reasoning as always: the card
          needs `overflow-hidden`, which would break `position: sticky` on
          anything nested inside it, so the column lives as a grid-stacked
          sibling instead. In Section view there's no second item in this
          cell at all, so `grid-cols-1` with one child is harmless — no need
          for a second, parallel non-grid code path just for that case. */}
      <div className="mt-2 grid grid-cols-1">
      <section
        aria-label={t("lyricsAndChordsLabel")}
        // Deters casual copying: no selection, copy/cut, right-click or drag.
        onCopy={(e) => e.preventDefault()}
        onCut={(e) => e.preventDefault()}
        onContextMenu={(e) => e.preventDefault()}
        onDragStart={(e) => e.preventDefault()}
        style={{ ["--lyric-size" as string]: `${1.0625 * scale}rem`, gridArea: "1 / 1" }}
        className={`no-copy relative overflow-hidden rounded-3xl border border-black/5 px-4 py-4 shadow-[0_2px_24px_-8px_rgba(0,0,0,0.12)] sm:px-9 sm:py-8 ${
          cameraStatus === "on" ? "bg-white/55 backdrop-blur-[2px]" : "bg-white"
          }`}
        >
          {/* Contributor watermark, centered behind the whole sheet — attributes this
              entry to whichever site user submitted it (not the song's own credited
              songwriter, shown separately above) and deters copy/screenshotting (same
              intent as the no-copy handlers above). Only shown when a submitter name
              is actually on record — a blank name isn't worth watermarking. Faint
              enough to never compete with the lyrics, tilted like a normal document
              watermark. `section` already clips overflow, so the rotated box can't
              widen it. */}
          {song.authorName && (
            <div aria-hidden className="no-print pointer-events-none absolute inset-0 flex items-center justify-center">
              <div className="-rotate-[25deg] whitespace-nowrap text-black/[0.06]" style={{ fontSize: "clamp(2rem, 12vw, 6rem)" }}>
                {song.authorName}
              </div>
            </div>
          )}

          {/* Title, songwriter and singer are the first lines of the song sheet itself
              (as in the original site), not a separate header: same card, same
              text-size scaling as the lyrics below. These two labels used to be
              hardcoded Shan ("တႅမ်ႈ"/"ႁွင်ႉ") regardless of interface language —
              changed 2026-10-14 so English/Thai/Burmese readers see their own
              language here too, same as everywhere else on the site. */}
          <div className="mb-3 md:pr-20">
            <h1 className="font-bold leading-snug text-neutral-900" style={{ fontSize: "calc(var(--lyric-size) * 1.45)" }}>
              {song.songName}
            </h1>
            <p className="mt-1 flex items-start gap-2 leading-relaxed text-neutral-600" style={{ fontSize: "var(--lyric-size)" }}>
              <PenLine size="0.95em" className="mt-[0.4em] shrink-0 opacity-70" aria-hidden />
              <span>
                {t("songReaderComposerLabel")} -{song.songwriter ? ` ${song.songwriter}` : ""}
              </span>
            </p>
            {song.artist && (
              <p className="flex items-start gap-2 leading-relaxed text-neutral-600" style={{ fontSize: "var(--lyric-size)" }}>
                <UserRound size="0.95em" className="mt-[0.4em] shrink-0 opacity-70" aria-hidden />
                <span>
                  {t("songReaderArtistLabel")} - {song.artist}
                </span>
              </p>
            )}
            {song.band && (
              <p className="flex items-start gap-2 leading-relaxed text-neutral-600" style={{ fontSize: "var(--lyric-size)" }}>
                <Users size="0.95em" className="mt-[0.4em] shrink-0 opacity-70" aria-hidden />
                <span>
                  {t("songReaderBandLabel")} - {song.band}
                </span>
              </p>
            )}
          </div>

          {song.lyrics.length === 0 ? (
            <p className="text-neutral-500">{t("noLyrics")}</p>
          ) : horizontalView ? (
            // Each section (split at the author's own blank-line gaps, see
            // splitIntoSections) is its own card in a left-to-right row.
            // Deliberately two independent scroll axes instead of forcing
            // anything to fit: `overflow-x-auto` on the row for "more
            // sections than fit the screen width", `overflow-y-auto` +
            // `max-h-[80vh]` on each card for "this one section is long" —
            // Book Mode already proved that forcing arbitrary-length content
            // into a fixed space with no scroll at all doesn't hold up once
            // a real song is longer than the compromise allows.
            //
            // Cards are elastic (`flex-[1_1_22rem]`), not a fixed width —
            // with few sections and a wide monitor, a fixed small width
            // (what this started as) just left most of the screen as dead
            // space (owner: "ทำไมจำกัดพื้นที่แค่นั้นจอกว้างจะตาย"). `22rem`
            // is a floor, not a cap: cards grow to fill whatever room is
            // actually available, and only once that floor is violated by
            // having many sections does the row start truly needing its own
            // horizontal scroll instead of just fitting more loosely.
            <div className="no-copy -mx-1 flex gap-4 overflow-x-auto px-1 pb-2">
              {sections.map((sectionLines, i) => (
                <div
                  key={i}
                  className="max-h-[80vh] min-w-[22rem] flex-[1_1_22rem] overflow-y-auto rounded-2xl border border-black/5 bg-neutral-50/80 p-4"
                >
                  {sectionLines.map((line, j) => (
                    <LyricLine key={j} content={line.content ?? []} transpose={transpose} onChordClick={setChordOpen} />
                  ))}
                </div>
              ))}
            </div>
          ) : (
            rows.map((line, i) => (
              <LyricLine key={i} content={line.content ?? []} transpose={transpose} onChordClick={setChordOpen} />
            ))
          )}
        </section>

        {/* Floating chord reference column: normal (non-Section) view only
            — sticky (travels with the page while scrolling, but never past
            the end of the lyrics above, since it's positioned within this
            grid cell's own height). `top` clears the pinned play/speed bar
            (sticky at 68px + its own height). */}
        {!horizontalView && backdrop.length > 0 && chordsVisible && (
          <div aria-hidden style={{ gridArea: "1 / 1" }} className="no-print pointer-events-none justify-self-end">
            <div className="sticky top-32 flex flex-col items-center gap-1.5 px-2 py-4 text-[color:var(--chord)] sm:gap-2.5 sm:px-4">
              {backdrop.map(({ name, shape }) => (
                <div key={name} className="flex flex-col items-center">
                  <ChordDiagram shape={shape} mirrored={leftHanded} dotColor="currentColor" className="h-10 w-10 sm:h-16 sm:w-16" />
                  <span className="text-[10px] font-bold sm:text-[13px]">{name}</span>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>
      {full && (
        <div data-keep-scrolling className="fixed right-4 top-4 z-50 flex items-center gap-2 print:hidden">
          <button
            type="button"
            onClick={scroller.toggle}
            aria-pressed={scroller.running}
            aria-label={t("autoScrollLabel")}
            title={t("autoScrollLabel")}
            className={`flex h-11 w-11 items-center justify-center rounded-full shadow-lg backdrop-blur transition ${
              scroller.running ? "bg-blue-600 text-white" : "bg-white/90 text-neutral-800"
            }`}
          >
            {scroller.running ? <Pause size={18} className="fill-current" /> : <Play size={18} className="fill-current" />}
          </button>
          <button
            type="button"
            onClick={toggleFull}
            aria-label={t("exitFullViewLabel")}
            title={t("exitFullViewLabel")}
            className="flex h-11 w-11 items-center justify-center rounded-full bg-white/90 text-neutral-800 shadow-lg backdrop-blur transition hover:scale-105"
          >
            <Minimize size={18} />
          </button>
        </div>
      )}
      {playerOpen && videoId && <YoutubeMiniPlayer videoId={videoId} onClose={() => setPlayerOpen(false)} />}
      {chordOpen && <ChordDialog chord={chordOpen} onClose={() => setChordOpen(null)} />}
    </article>
  );
}

function Stepper({
  label,
  value,
  onMinus,
  onPlus,
}: {
  label: string;
  value: string;
  onMinus: () => void;
  onPlus: () => void;
}) {
  const { t } = useT();
  return (
    <div className="flex items-center gap-2">
      <span className="text-sm font-medium text-neutral-500">{label}</span>
      <div className="flex items-center rounded-full bg-neutral-100 p-0.5">
        <button
          type="button"
          onClick={onMinus}
          aria-label={`${label} ${t("downLabel")}`}
          className="flex h-8 w-8 items-center justify-center rounded-full text-neutral-700 transition hover:bg-white hover:shadow"
        >
          <Minus size={16} />
        </button>
        <span className="min-w-12 text-center text-sm font-semibold tabular-nums">{value}</span>
        <button
          type="button"
          onClick={onPlus}
          aria-label={`${label} ${t("upLabel")}`}
          className="flex h-8 w-8 items-center justify-center rounded-full text-neutral-700 transition hover:bg-white hover:shadow"
        >
          <Plus size={16} />
        </button>
      </div>
    </div>
  );
}

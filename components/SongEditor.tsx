"use client";

import { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState, useSyncExternalStore } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  collection,
  deleteField,
  doc,
  getDocs,
  increment,
  limit,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
  type DocumentData,
} from "firebase/firestore";
import { CheckCircle2, ClipboardPaste, Copy, Guitar, Loader2, Plus, X } from "lucide-react";
import { useAuth } from "@/components/AuthProvider";
import { useT } from "@/components/LanguageProvider";
import ChordPanel from "@/components/ChordPanel";
import LyricLine from "@/components/LyricLine";
import SuggestInput, { type Suggestion } from "@/components/SuggestInput";
import { useDialog } from "@/components/useDialog";
import { CHROMATIC_ROOTS } from "@/lib/diatonic";
import { db } from "@/lib/firebase/client";
import {
  PRESET_CATEGORIES,
  PRESET_GENDERS,
  normalizeCategory,
  normalizeGender,
} from "@/lib/labels";
import { lyricsBlockToText, parseLyricsBlock } from "@/lib/lyrics-parser";

// Mobile browsers keep `fixed`/`100vh` positioned against the full LAYOUT
// viewport, not the visible one — when the keyboard is open, the phone's
// software keyboard overlays the bottom of that layout without the browser
// reflowing anything, so a `fixed inset-0` bottom sheet's lower portion
// (exactly where the chord chips live, since the sheet is bottom-anchored)
// ends up sitting underneath it (owner: "แป้นพิมพ์ขึ้นมาบังปุ่มคอร์ดตลอด
// เลยครับ"). `window.visualViewport` is the one API that reports the ACTUAL
// visible viewport, keyboard included — `innerHeight - vv.height -
// vv.offsetTop` is exactly the height currently covered (0 with no
// keyboard), which the sheet below uses as a margin to float itself above
// the keyboard instead of dismissing it (keeping the keyboard open means no
// jarring hide/show flicker on every single chord tap).
function useKeyboardInset(): number {
  return useSyncExternalStore(
    (onChange) => {
      const vv = window.visualViewport;
      if (!vv) return () => {};
      vv.addEventListener("resize", onChange);
      vv.addEventListener("scroll", onChange);
      return () => {
        vv.removeEventListener("resize", onChange);
        vv.removeEventListener("scroll", onChange);
      };
    },
    () => {
      const vv = window.visualViewport;
      if (!vv) return 0;
      return Math.max(0, Math.round(window.innerHeight - vv.height - vv.offsetTop));
    },
    () => 0,
  );
}

export type EditorOptions = {
  songs: { name: string; artist: string }[];
  bands: string[];
  categories: string[];
  genders: string[];
};

// new: brand-new submission. draft: the author continuing their own draft.
// resubmit: the author fixing a rejected song. admin: an admin editing and
// releasing (approving) any song.
export type EditorMode = "new" | "draft" | "resubmit" | "admin";
export type EditorInitial = { id: string; mode: Exclude<EditorMode, "new">; data: DocumentData };

type ArtistRow = { key: number; text: string; id: string | null };
type Pick = { value: string; other: boolean };
type Form = {
  artists: ArtistRow[];
  songwriter: string;
  band: string;
  songName: string;
  youtube: string;
  category: Pick;
  gender: Pick;
  root: string;
  minor: boolean;
  lyrics: string;
};

const OTHER = "__other__";
let rowKey = 0;
const newRow = (text = "", id: string | null = null): ArtistRow => ({ key: ++rowKey, text, id });
const s = (v: unknown) => (typeof v === "string" ? v : "");

function initialForm(data?: DocumentData): Form {
  const base: Form = {
    artists: [newRow()],
    songwriter: "",
    band: "",
    songName: "",
    youtube: "",
    category: { value: "", other: false },
    gender: { value: "", other: false },
    root: "C",
    minor: false,
    lyrics: "",
  };
  if (!data) return base;

  // Parallel artistNames/artistIds arrays, falling back to the old single
  // artist/artistId pair. A blank id means "never resolved" (a draft saved
  // before an artist was picked) — treat it as null so it gets resolved.
  const names: string[] = Array.isArray(data.artistNames) ? data.artistNames.map(s) : [];
  const ids: string[] = Array.isArray(data.artistIds) ? data.artistIds.map(s) : [];
  const artists = names.length
    ? names.map((n, i) => newRow(n, ids[i] || null))
    : [newRow(s(data.artist), s(data.artistId) || null)];

  return {
    artists,
    songwriter: s(data.songwriter),
    band: s(data.band),
    songName: s(data.songName),
    youtube: s(data.youtubeLink),
    category: { value: s(data.category), other: false },
    gender: { value: s(data.gender), other: false },
    // Both spellings of every accidental are now valid picker values (see
    // lib/diatonic.ts) — a saved key is used as-is (sharp stays sharp, flat
    // stays flat) as long as it's one the picker actually offers.
    root: (CHROMATIC_ROOTS as readonly string[]).includes(s(data.key)) ? s(data.key) : "C",
    minor: data.keyIsMinor === true,
    lyrics: lyricsBlockToText(Array.isArray(data.lyrics) ? data.lyrics : []),
  };
}

export default function SongEditor({
  options,
  initial,
}: {
  options: EditorOptions;
  initial: EditorInitial | null;
}) {
  const { user, profile } = useAuth();
  const router = useRouter();
  const { ask, dialog } = useDialog();
  const { t, category: categoryLabel, gender: genderLabel } = useT();
  const mode: EditorMode = initial?.mode ?? "new";

  const [form, setForm] = useState<Form>(() => initialForm(initial?.data));
  const [dirty, setDirty] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [draftSaving, setDraftSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [done, setDone] = useState(false);
  const [sheetOpen, setSheetOpen] = useState(false);
  const keyboardInset = useKeyboardInset();
  // Set once a draft exists as a real doc, so later "Save draft" taps update
  // that same doc instead of creating a new one each time.
  const draftId = useRef<string | null>(mode === "draft" ? initial!.id : null);

  const update = useCallback((patch: Partial<Form>) => {
    setForm((f) => ({ ...f, ...patch }));
    setDirty(true);
    setNotice(null);
  }, []);

  // ---- leave-page guard -------------------------------------------------
  const dirtyRef = useRef(false);
  const leaveMessage = useRef("");
  useEffect(() => {
    leaveMessage.current = t("unsavedChangesMessage");
  }, [t]);
  useEffect(() => {
    dirtyRef.current = dirty;
  }, [dirty]);
  useEffect(() => {
    const onBeforeUnload = (e: BeforeUnloadEvent) => {
      if (!dirtyRef.current) return;
      e.preventDefault();
      e.returnValue = "";
    };
    // In-app links: Next's client-side navigation doesn't fire beforeunload.
    const onClick = (e: MouseEvent) => {
      if (!dirtyRef.current || e.defaultPrevented || e.button !== 0 || e.metaKey || e.ctrlKey) return;
      const a = (e.target as HTMLElement).closest?.("a[href]") as HTMLAnchorElement | null;
      if (!a || a.target === "_blank" || a.origin !== location.origin) return;
      if (!window.confirm(leaveMessage.current)) {
        e.preventDefault();
        e.stopPropagation();
      }
    };
    window.addEventListener("beforeunload", onBeforeUnload);
    document.addEventListener("click", onClick, true);
    return () => {
      window.removeEventListener("beforeunload", onBeforeUnload);
      document.removeEventListener("click", onClick, true);
    };
  }, []);

  // ---- lyrics textarea: insert at caret ---------------------------------
  const taRef = useRef<HTMLTextAreaElement>(null);
  const touched = useRef(false); // has the field ever had the caret?
  const caret = useRef<number | null>(null);

  const insert = useCallback(
    (text: string) => {
      const ta = taRef.current;
      const v = form.lyrics;
      const start = ta && touched.current ? ta.selectionStart : v.length;
      const end = ta && touched.current ? ta.selectionEnd : v.length;
      caret.current = start + text.length;
      update({ lyrics: v.slice(0, start) + text + v.slice(end) });
    },
    [form.lyrics, update],
  );

  useLayoutEffect(() => {
    const ta = taRef.current;
    if (ta && caret.current !== null) {
      ta.focus({ preventScroll: true });
      ta.setSelectionRange(caret.current, caret.current);
      caret.current = null;
    }
  }, [form.lyrics]);

  async function copyLyrics() {
    const ta = taRef.current;
    const sel = ta && ta.selectionStart !== ta.selectionEnd ? form.lyrics.slice(ta.selectionStart, ta.selectionEnd) : "";
    const text = sel || form.lyrics;
    if (!text) return;
    await navigator.clipboard.writeText(text).catch(() => {});
    setNotice(sel ? t("copiedSelectionMessage") : t("copiedAllMessage"));
  }
  async function pasteLyrics() {
    const text = await navigator.clipboard.readText().catch(() => "");
    if (text) insert(text);
  }

  // Auto-grow the textarea with its content (no inner scrollbar).
  useLayoutEffect(() => {
    const ta = taRef.current;
    if (!ta) return;
    ta.style.height = "auto";
    ta.style.height = `${Math.max(ta.scrollHeight, 320)}px`;
  }, [form.lyrics]);

  const previewLines = useMemo(() => parseLyricsBlock(form.lyrics), [form.lyrics]);

  // ---- suggestions ------------------------------------------------------
  const q = (v: string) => v.trim().toLowerCase();
  const songSuggestions: Suggestion[] = useMemo(() => {
    const t = q(form.songName);
    if (!t) return [];
    return options.songs
      .filter((x) => x.name.toLowerCase().includes(t))
      .slice(0, 8)
      .map((x, i) => ({
        key: `${x.name}-${i}`,
        title: x.name,
        subtitle: x.artist || undefined,
        pick: () => update({ songName: x.name }),
      }));
  }, [form.songName, options.songs, update]);

  const bandSuggestions: Suggestion[] = useMemo(() => {
    const t = q(form.band);
    if (!t) return [];
    return options.bands
      .filter((b) => b.toLowerCase().includes(t))
      .sort()
      .slice(0, 8)
      .map((b) => ({ key: b, title: b, pick: () => update({ band: b }) }));
  }, [form.band, options.bands, update]);

  // ---- save paths -------------------------------------------------------
  const activeArtists = form.artists.filter((a) => a.text.trim() !== "");

  const picked = (p: Pick, normalize: (v: string) => string): string | null => {
    const v = p.value.trim();
    return v ? normalize(v) : null;
  };

  const fields = (extra: { artistIds: string[] }) => {
    const names = activeArtists.map((a) => a.text.trim());
    return {
      songName: form.songName.trim(),
      songNameLower: form.songName.trim().toLowerCase(),
      // Joined for the display-only "artist" field the rest of the site reads.
      artist: names.join(" & "),
      artistIds: extra.artistIds,
      artistNames: names,
      band: form.band.trim(),
      songwriter: form.songwriter.trim(),
      youtubeLink: form.youtube.trim(),
      category: picked(form.category, normalizeCategory),
      gender: picked(form.gender, normalizeGender),
      key: form.root,
      keyIsMinor: form.minor,
      lyrics: parseLyricsBlock(form.lyrics),
    };
  };

  // Typed name -> artistId, creating artists/{id} if needed. An exact match
  // that wasn't picked from the list asks whether to reuse it. null = cancelled.
  async function resolveArtist(row: ArtistRow): Promise<string | null> {
    if (row.id) return row.id;
    const name = row.text.trim();
    const existing = await getDocs(
      query(collection(db, "artists"), where("nameLower", "==", name.toLowerCase()), limit(1)),
    );
    if (!existing.empty) {
      const choice = await ask({
        title: t("artistExistsTitle"),
        message: `"${name}" ${t("artistExistsMessage")}`,
        actions: [
          { label: t("createNewAnyway"), value: "new" as const },
          { label: t("useExistingArtist"), value: "existing" as const, tone: "primary" },
        ],
      });
      if (choice === null) return null;
      if (choice === "existing") return existing.docs[0].id;
    }
    const ref = doc(collection(db, "artists"));
    await setDoc(ref, {
      name,
      nameLower: name.toLowerCase(),
      createdAt: serverTimestamp(),
      createdBy: user?.uid ?? null,
    });
    return ref.id;
  }

  async function confirmDuplicate(artistIds: string[], songNameLower: string): Promise<boolean> {
    if (artistIds.length === 0) return true;
    // status != draft so the query is provably safe against other people's
    // private drafts (see firestore.rules).
    const dup = await getDocs(
      query(
        collection(db, "songs"),
        where("artistIds", "array-contains-any", artistIds.slice(0, 10)),
        where("songNameLower", "==", songNameLower),
        where("status", "!=", "draft"),
        limit(initial ? 5 : 1),
      ),
    );
    // When editing, the song is naturally its own "duplicate" — ignore it.
    if (dup.docs.filter((d) => d.id !== initial?.id).length === 0) return true;
    const proceed = await ask({
      title: t("duplicateSongTitle"),
      message: t("duplicateSongMessage"),
      actions: [
        { label: t("cancelButton"), value: false },
        { label: t("continueButton"), value: true, tone: "primary" },
      ],
    });
    return proceed === true;
  }

  async function submit() {
    setError(null);
    if (
      activeArtists.length === 0 ||
      !form.songName.trim() ||
      !form.lyrics.trim() ||
      !form.category.value.trim() ||
      !form.gender.value.trim()
    ) {
      setError(t("pleaseFillRequiredFields"));
      return;
    }
    // The author can't edit a submission once it's sent, so this is their
    // one chance to double-check. Skipped for an admin releasing a song.
    if (mode !== "admin") {
      const ready = await ask({
        title: t("confirmSubmitTitle"),
        message: t("confirmSubmitMessage"),
        actions: [
          { label: t("cancelButton"), value: false },
          { label: t("confirmSubmitButton"), value: true, tone: "primary" },
        ],
      });
      if (!ready) return;
    }

    setSubmitting(true);
    try {
      // Sequential, so the "artist may exist" dialog never stacks.
      const artistIds: string[] = [];
      for (const row of activeArtists) {
        const id = await resolveArtist(row);
        if (id === null) return;
        artistIds.push(id);
      }
      if (!(await confirmDuplicate(artistIds, form.songName.trim().toLowerCase()))) return;

      const data = fields({ artistIds });
      const authorName = profile?.displayName ?? "";

      if (mode === "admin") {
        // Save and release: always ends approved. approvedAt / the author's
        // approvedSongCount only move the first time it becomes approved.
        const wasApproved = initial!.data.status === "approved";
        const batch = writeBatch(db);
        batch.update(doc(db, "songs", initial!.id), {
          ...data,
          status: "approved",
          ...(wasApproved ? {} : { approvedAt: serverTimestamp() }),
        });
        const authorId = s(initial!.data.authorId);
        if (!wasApproved && authorId) batch.update(doc(db, "users", authorId), { approvedSongCount: increment(1) });
        await batch.commit();
      } else if (mode === "resubmit") {
        // Author fixing a rejected song: back to pending, old reason cleared.
        await updateDoc(doc(db, "songs", initial!.id), {
          ...data,
          status: "pending",
          rejectionReason: deleteField(),
        });
      } else if (mode === "draft") {
        // First real submission of a draft: full overwrite in the shape of a
        // fresh submission, createdAt reset to now (it sorts "Latest Songs").
        await setDoc(doc(db, "songs", initial!.id), {
          ...data,
          status: "pending",
          authorId: user?.uid ?? null,
          authorName,
          createdAt: serverTimestamp(),
        });
      } else {
        const ref = draftId.current ? doc(db, "songs", draftId.current) : doc(collection(db, "songs"));
        await setDoc(ref, {
          ...data,
          status: "pending",
          authorId: user?.uid ?? null,
          authorName,
          createdAt: serverTimestamp(),
        });
      }

      dirtyRef.current = false;
      setDirty(false);
      if (mode === "new") setDone(true);
      else if (mode === "admin") router.back();
      else router.push("/my-songs");
    } catch {
      setError(t("submitFailed"));
    } finally {
      setSubmitting(false);
    }
  }

  // Save draft: skips artist resolution and duplicate checks on purpose — a
  // draft may be nowhere near done and shouldn't create artists or nag. That
  // validation happens when it's really submitted. Can be saved blank.
  async function saveDraft() {
    setDraftSaving(true);
    setError(null);
    try {
      const names = activeArtists.map((a) => a.text.trim());
      const data = {
        ...fields({ artistIds: activeArtists.map((a) => a.id ?? "") }),
        artist: names.join(" & "),
        status: "draft",
        authorId: user?.uid ?? null,
        authorName: profile?.displayName ?? "",
      };
      if (draftId.current) {
        await updateDoc(doc(db, "songs", draftId.current), data);
      } else {
        const ref = doc(collection(db, "songs"));
        await setDoc(ref, { ...data, createdAt: serverTimestamp() });
        draftId.current = ref.id;
      }
      dirtyRef.current = false;
      setDirty(false);
      setNotice(t("draftSavedMessage"));
    } catch {
      setError(t("draftFailed"));
    } finally {
      setDraftSaving(false);
    }
  }

  // ---- render -----------------------------------------------------------
  if (done) {
    return (
      <div className="mx-auto flex max-w-md flex-col items-center px-4 py-20 text-center">
        <span className="flex h-20 w-20 items-center justify-center rounded-full bg-emerald-50 text-emerald-600">
          <CheckCircle2 size={40} />
        </span>
        <h1 className="mt-6 text-2xl font-extrabold tracking-tight">{t("songSubmittedTitle")}</h1>
        <p className="mt-2 text-neutral-500">{t("songSubmittedBody")}</p>
        <div className="mt-8 flex gap-3">
          <button
            type="button"
            onClick={() => {
              draftId.current = null;
              setForm(initialForm());
              setDone(false);
            }}
            className="h-11 rounded-full border border-black/10 px-6 text-sm font-semibold hover:bg-neutral-50"
          >
            {t("submitAnother")}
          </button>
          <Link href="/my-songs" className="flex h-11 items-center rounded-full bg-black px-6 text-sm font-semibold text-white">
            {t("mySongsTitle")}
          </Link>
        </div>
      </div>
    );
  }

  const title =
    mode === "new"
      ? t("submitSongTitle")
      : mode === "admin"
        ? t("editSongTitle")
        : mode === "draft"
          ? t("continueDraftTitle")
          : t("fixResubmitTitle");
  const canDraft = mode === "new" || mode === "draft";
  const submitLabel = mode === "admin" ? t("releaseSongButton") : mode === "resubmit" ? t("resubmitButton") : t("submitButton");

  const pickerOptions = (base: readonly string[], extra: string[], current: string) =>
    Array.from(new Set([...base, ...extra, ...(current ? [current] : [])])).sort();

  return (
    <div className="mx-auto w-full max-w-[860px] px-4 pb-32 pt-8 sm:px-6">
      <h1 className="text-3xl font-extrabold tracking-tight">{title}</h1>
      {mode === "resubmit" && initial?.data.rejectionReason && (
        <p className="mt-4 rounded-2xl bg-red-50 px-5 py-3.5 text-sm text-red-700">
          <span className="font-semibold">{t("whyRejected")}:</span> {s(initial.data.rejectionReason)}
        </p>
      )}

      {/* details */}
      <section className="mt-6 rounded-3xl border border-black/5 bg-white p-5 shadow-[0_2px_24px_-8px_rgba(0,0,0,0.12)] sm:p-7">
        <div className="space-y-5">
          <div className="space-y-3">
            {form.artists.map((row, i) => (
              <ArtistField
                key={row.key}
                row={row}
                required={i === 0}
                onChange={(patch) =>
                  update({ artists: form.artists.map((r) => (r.key === row.key ? { ...r, ...patch } : r)) })
                }
                onRemove={
                  form.artists.length > 1
                    ? () => update({ artists: form.artists.filter((r) => r.key !== row.key) })
                    : undefined
                }
              />
            ))}
            <button
              type="button"
              onClick={() => update({ artists: [...form.artists, newRow()] })}
              className="flex items-center gap-1.5 rounded-full px-3 py-1.5 text-sm font-medium text-neutral-600 hover:bg-neutral-100"
            >
              <Plus size={16} /> {t("addArtistButton").replace(/^\+\s*/, "")}
            </button>
          </div>

          {/* order matches the original form: artist, composer, song name, then the rest */}
          <Text label={t("songwriterLabel")} value={form.songwriter} onChange={(v) => update({ songwriter: v })} />
          <SuggestInput
            label={t("songNameLabel")}
            required
            value={form.songName}
            onChange={(v) => update({ songName: v })}
            suggestions={songSuggestions}
          />
          <SuggestInput
            label={t("bandLabel")}
            value={form.band}
            onChange={(v) => update({ band: v })}
            suggestions={bandSuggestions}
          />
          <Text
            label={t("youtubeLinkLabel")}
            value={form.youtube}
            placeholder={t("youtubeLinkHint")}
            onChange={(v) => update({ youtube: v })}
          />

          <PickerField
            label={t("categoryLabel")}
            required
            optionLabel={categoryLabel}
            values={pickerOptions(PRESET_CATEGORIES, options.categories, form.category.value)}
            pick={form.category}
            onChange={(p) => update({ category: p })}
          />
          <PickerField
            label={t("genderLabel")}
            required
            optionLabel={genderLabel}
            values={pickerOptions(PRESET_GENDERS, options.genders, form.gender.value)}
            pick={form.gender}
            onChange={(p) => update({ gender: p })}
          />
        </div>
      </section>

      {/* The wrapper is the pinned panel's range: it stays under the navbar while the
          lyrics are being written and scrolls away after them (so it never covers the
          save buttons). Phones open the panel from the floating button, below. */}
      <div>
      <section className="sticky top-[68px] z-20 mt-6 hidden rounded-3xl border border-black/5 bg-white p-5 shadow-[0_8px_30px_-12px_rgba(0,0,0,0.25)] lg:block">
        <ChordPanel
          root={form.root}
          minor={form.minor}
          onRoot={(r) => update({ root: r })}
          onMinor={(m) => update({ minor: m })}
          onInsert={insert}
        />
      </section>

      {/* lyrics, with the live preview right under it */}
      <section className="mt-6 rounded-3xl border border-black/5 bg-white p-5 shadow-[0_2px_24px_-8px_rgba(0,0,0,0.12)] sm:p-7">
        <div className="flex items-center justify-between">
          <h2 className="font-bold">
            {t("lyricsLabel")} <span className="text-rose-500">*</span>
          </h2>
          <div className="flex gap-1">
            <button type="button" onClick={copyLyrics} className="flex h-9 items-center gap-1.5 rounded-full px-3 text-sm font-medium text-neutral-600 hover:bg-neutral-100">
              <Copy size={15} /> {t("copyButton")}
            </button>
            <button type="button" onClick={pasteLyrics} className="flex h-9 items-center gap-1.5 rounded-full px-3 text-sm font-medium text-neutral-600 hover:bg-neutral-100">
              <ClipboardPaste size={15} /> {t("pasteButton")}
            </button>
          </div>
        </div>
        <textarea
          ref={taRef}
          translate="no"
          value={form.lyrics}
          onChange={(e) => update({ lyrics: e.target.value })}
          onFocus={() => (touched.current = true)}
          placeholder={t("lyricsHint")}
          spellCheck={false}
          className="plain-input mt-3 resize-none font-mono text-[15px] leading-7"
          style={{ minHeight: 320 }}
        />
        <p className="mt-2 text-xs text-neutral-400">
          {t("lyricsBracketHint")}
        </p>

        <h2 className="mt-7 font-bold">{t("previewLabel")}</h2>
        <div className="mt-3 rounded-2xl border border-black/[0.08] bg-black/[0.03] p-4">
          {form.lyrics.trim() === "" ? (
            <p className="text-sm text-neutral-400">{t("previewEmpty")}</p>
          ) : (
            previewLines.map((line, i) => <LyricLine key={i} content={line.content} transpose={0} />)
          )}
        </div>
      </section>
      </div>

      {/* actions */}
      <div className="mt-8 flex flex-col gap-3">
        {error && (
          <p role="alert" className="rounded-2xl bg-red-50 px-5 py-3.5 text-sm font-medium text-red-700">
            {error}
          </p>
        )}
        {notice && <p role="status" className="text-sm font-medium text-emerald-600">{notice}</p>}
        <div className="flex gap-3">
          {canDraft && (
            <button
              type="button"
              onClick={saveDraft}
              disabled={draftSaving || submitting}
              className="flex h-12 flex-1 items-center justify-center rounded-full border border-black/15 font-semibold transition hover:bg-neutral-50 disabled:opacity-50"
            >
              {draftSaving ? <Loader2 size={18} className="animate-spin" /> : t("saveDraftButton")}
            </button>
          )}
          <button
            type="button"
            onClick={submit}
            disabled={submitting || draftSaving}
            className="flex h-12 flex-1 items-center justify-center rounded-full bg-black font-semibold text-white transition hover:scale-[1.01] disabled:opacity-50"
          >
            {submitting ? <Loader2 size={18} className="animate-spin" /> : submitLabel}
          </button>
        </div>
      </div>

      {/* phones: chord panel lives in a bottom sheet, closing itself on
          every insert on purpose — chords go at different points scattered
          through the lyrics (not one after another), so the author needs
          the sheet out of the way to tap a new caret position before the
          next one. (A same-turn detour: briefly tried leaving it open
          across inserts, on the theory that closing+reopening was itself
          what made the keyboard feel like it was fighting the sheet — owner
          caught the real problem: with it always open, there's no way to
          reach the lyrics text underneath to reposition the caret at all.
          Reverted.) */}
      {/* The floating button that REOPENS the sheet for the next chord was
          the actual thing getting covered, not the sheet itself (owner:
          "แป้นพิมพ์...มาบังปุ่มแผง ผมก็ต้องกดกลับ...ทุกครั้งผมลงคอร์ด") —
          each insert closes the sheet and refocuses the lyrics field, the
          keyboard reappears, and this button's `fixed` position (previously
          a static bottom-24) sat right where the keyboard now covers it,
          same root cause as the sheet's own fix. `keyboardInset` pushes it
          up the same way. */}
      <button
        type="button"
        onClick={() => setSheetOpen(true)}
        aria-label={t("chordsAndKey")}
        style={{ bottom: 96 + keyboardInset }}
        className="fixed right-4 z-40 flex h-14 w-14 items-center justify-center rounded-full bg-blue-600 text-white shadow-xl transition active:scale-95 lg:hidden"
      >
        <Guitar size={24} />
      </button>
      {sheetOpen && (
        <div className="fixed inset-0 z-[60] flex items-end bg-black/40 lg:hidden" onClick={() => setSheetOpen(false)}>
          <div
            role="dialog"
            aria-label={t("chordsAndKey")}
            onClick={(e) => e.stopPropagation()}
            className="max-h-[80vh] w-full overflow-y-auto rounded-t-3xl bg-white p-5 pb-8 shadow-2xl"
            style={{ marginBottom: keyboardInset }}
          >
            <div className="mx-auto mb-4 h-1.5 w-10 rounded-full bg-neutral-200" />
            <ChordPanel
              root={form.root}
              minor={form.minor}
              onRoot={(r) => update({ root: r })}
              onMinor={(m) => update({ minor: m })}
              onInsert={(t) => {
                insert(t);
                setSheetOpen(false);
              }}
            />
          </div>
        </div>
      )}
      {dialog}
    </div>
  );
}

function Text({
  label,
  value,
  onChange,
  placeholder,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
}) {
  return (
    <label className="block">
      <span className="mb-1.5 block text-sm font-medium text-neutral-700">{label}</span>
      <input className="plain-input" value={value} placeholder={placeholder} onChange={(e) => onChange(e.target.value)} />
    </label>
  );
}

// A select of known values plus "Other…", which reveals a free-text field.
function PickerField({
  label,
  optionLabel,
  values,
  pick,
  onChange,
  required,
}: {
  label: string;
  optionLabel: (v: string) => string;
  values: string[];
  pick: Pick;
  onChange: (p: Pick) => void;
  required?: boolean;
}) {
  const { t } = useT();
  return (
    <div>
      <label className="block">
        <span className="mb-1.5 block text-sm font-medium text-neutral-700">
          {label}
          {required && <span className="text-rose-500"> *</span>}
        </span>
        <select
          className="plain-input"
          value={pick.other ? OTHER : pick.value}
          onChange={(e) =>
            e.target.value === OTHER ? onChange({ value: "", other: true }) : onChange({ value: e.target.value, other: false })
          }
        >
          <option value="">—</option>
          {values.map((v) => (
            <option key={v} value={v}>
              {optionLabel(v)}
            </option>
          ))}
          <option value={OTHER}>{t("otherEllipsis")}</option>
        </select>
      </label>
      {pick.other && (
        <input
          className="plain-input mt-2"
          value={pick.value}
          onChange={(e) => onChange({ value: e.target.value, other: true })}
          placeholder={t("otherOption")}
          aria-label={`${t("otherOption")} — ${label}`}
          autoFocus
        />
      )}
    </div>
  );
}

// One artist row with a debounced prefix search over artists/. Typing clears
// the resolved id (it's re-resolved on submit); picking a suggestion sets it.
function ArtistField({
  row,
  required,
  onChange,
  onRemove,
}: {
  row: ArtistRow;
  required: boolean;
  onChange: (patch: Partial<ArtistRow>) => void;
  onRemove?: () => void;
}) {
  const { t } = useT();
  const [matches, setMatches] = useState<{ id: string; name: string }[]>([]);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => () => void (timer.current && clearTimeout(timer.current)), []);

  function onText(text: string) {
    onChange({ text, id: null });
    if (timer.current) clearTimeout(timer.current);
    const prefix = text.trim().toLowerCase();
    if (!prefix) return setMatches([]);
    timer.current = setTimeout(async () => {
      const snap = await getDocs(
        query(
          collection(db, "artists"),
          where("nameLower", ">=", prefix),
          where("nameLower", "<", prefix + ""),
          limit(8),
        ),
      ).catch(() => null);
      if (snap) setMatches(snap.docs.map((d) => ({ id: d.id, name: s(d.data().name) })));
    }, 300);
  }

  return (
    <SuggestInput
      label={t("artistLabel")}
      required={required}
      value={row.text}
      onChange={onText}
      suggestions={matches.map((m) => ({
        key: m.id,
        title: m.name,
        pick: () => {
          onChange({ text: m.name, id: m.id });
          setMatches([]);
        },
      }))}
      right={
        onRemove && (
          <button
            type="button"
            onClick={onRemove}
            aria-label={t("removeArtist")}
            className="mt-7 flex h-11 w-11 shrink-0 items-center justify-center rounded-full text-neutral-500 hover:bg-neutral-100"
          >
            <X size={18} />
          </button>
        )
      }
    />
  );
}

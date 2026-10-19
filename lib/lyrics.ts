import { transposeChord } from "./chords";

// Stored Firestore shape (songs/{id}.lyrics) — must stay exactly this, the
// Flutter app and every existing song depend on it:
//   [{ content: [{ type: "chord" | "lyric", text: string }, ...] }, ...]
export type LyricToken = { type?: string; text?: string };
export type LyricLineData = { content: LyricToken[] };

// A bar/beat separator or half-step chord link authored as plain text
// between two chord brackets ("Intro- [F]/[F]", "[C]-[C#]") parses to a
// lyric-type token that's just "/" or "-" (or a run of either).
const SEPARATOR_PATTERN = /^[/-]+$/;

// Leading section-label vocabulary — same as the Flutter submit form's
// quick-insert chips. Shan/Thai lyrics never start with a run of a-z
// letters, so this can't misfire on real sung text.
const SECTION_LABEL_KEYWORDS = new Set(["key", "intro", "verse", "chorus", "bridge", "solo", "outro"]);
const LEADING_WORD_PATTERN = /^([a-zA-Z]+)/;

function isSectionLabelText(trimmed: string): boolean {
  const match = LEADING_WORD_PATTERN.exec(trimmed);
  return match !== null && SECTION_LABEL_KEYWORDS.has(match[1].toLowerCase());
}

/** One rendered piece of an "inline" (label / chord-only) line, in authored order. */
export type InlineToken = { text: string; isChord: boolean };

/** A chord (or bar separator promoted into the chord row) anchored above the start of a segment. */
export type Anchor = { text: string; isChord: boolean };

/** A run of lyric text starting at a chord's character offset. */
export type Segment = { text: string; anchors: Anchor[] };

export type LineModel =
  | { kind: "inline"; tokens: InlineToken[] }
  | { kind: "aligned"; segments: Segment[]; hasAnchors: boolean };

/**
 * Port of buildLyricLine's data half (lib/widget/lyric_line_view.dart).
 *
 * Chords are never spliced into the lyric text — the lyric is reconstructed
 * whole, and each chord remembers the character offset it was authored at.
 * Lines with no real lyric text (chord-only intro/solo lines) or that start
 * with a section-label keyword ("Key D") fall back to a single inline row in
 * original token order instead, since stacking a chord above a label reads
 * oddly.
 */
export function buildLineModel(content: LyricToken[], transposeSteps: number): LineModel {
  let lyricText = "";
  const entries: { offset: number; anchor: Anchor }[] = [];

  for (const item of content) {
    const rawText = item.text ?? "";
    if (item.type === "chord") {
      entries.push({
        offset: lyricText.length,
        anchor: { text: transposeChord(rawText, transposeSteps), isChord: true },
      });
    } else if (SEPARATOR_PATTERN.test(rawText.trim())) {
      // Real spaces on both sides (not just padding) so the glyph doesn't
      // visually merge with a neighbouring chord's dotted underline.
      entries.push({
        offset: lyricText.length,
        anchor: { text: ` ${rawText.trim()} `, isChord: false },
      });
    } else {
      lyricText += rawText;
    }
  }

  const trimmed = lyricText.trim();
  if (trimmed === "" || isSectionLabelText(trimmed)) {
    const tokens: InlineToken[] = [];
    for (const item of content) {
      const rawText = item.text ?? "";
      if (item.type === "chord") {
        tokens.push({ text: transposeChord(rawText, transposeSteps), isChord: true });
        continue;
      }
      const t = rawText.trim();
      if (t === "") continue;
      // No padding spaces here (unlike the aligned anchor case below): this
      // row is a flex row (.lyric-inline, globals.css) whose own `gap`
      // already spaces every token evenly, chord or separator alike — adding
      // real spaces on top of that gap was what pushed "/" and "-" noticeably
      // further from their neighbouring chords than the chords sit from
      // each other.
      tokens.push({ text: t, isChord: false });
    }
    return { kind: "inline", tokens };
  }

  // Offsets are non-decreasing (built in authored order), so consecutive
  // chords at the same offset simply share one segment's anchor list.
  const segments: Segment[] = [];
  if (entries.length === 0 || entries[0].offset > 0) {
    const end = entries.length ? entries[0].offset : lyricText.length;
    segments.push({ text: lyricText.slice(0, end), anchors: [] });
  }
  let i = 0;
  while (i < entries.length) {
    const offset = entries[i].offset;
    const anchors: Anchor[] = [];
    while (i < entries.length && entries[i].offset === offset) {
      anchors.push(entries[i].anchor);
      i++;
    }
    const next = i < entries.length ? entries[i].offset : lyricText.length;
    segments.push({ text: lyricText.slice(offset, next), anchors });
  }

  return { kind: "aligned", segments, hasAnchors: entries.length > 0 };
}

/**
 * True for a line that's a label or pure chord progression ("Key D", "Intro",
 * "Verse 1", a bare chord row) — anything with no real sung text. Port of
 * isStandaloneLabelLine (lyric_line_view.dart).
 */
export function isStandaloneLabelLine(content: LyricToken[]): boolean {
  let text = "";
  for (const item of content) {
    if (item.type === "chord") continue;
    const raw = item.text ?? "";
    if (SEPARATOR_PATTERN.test(raw.trim())) continue;
    text += raw;
  }
  const trimmed = text.trim();
  return trimmed === "" || isSectionLabelText(trimmed);
}

// Compact mode packs short lines together until a row holds this many chords.
const COMPACT_CHORD_TARGET = 3;

/**
 * "Compact" layout (port of _mergeLyricsForCompact): consecutive short lyric
 * lines are merged into one row until it has `COMPACT_CHORD_TARGET` chords, so a
 * song with a couple of chords per line doesn't leave every row mostly empty.
 * Label / chord-only lines never merge with their neighbours (otherwise "Key"
 * would swallow the whole intro after it).
 */
export function mergeForCompact(lines: LyricLineData[]): LyricLineData[] {
  const rows: LyricLineData[] = [];
  let current: LyricToken[] = [];
  let chords = 0;
  for (const line of lines) {
    const content = line.content ?? [];
    if (isStandaloneLabelLine(content)) {
      if (current.length) {
        rows.push({ content: current });
        current = [];
        chords = 0;
      }
      rows.push({ content });
      continue;
    }
    // A space between merged lines so their last and first words don't fuse.
    current = current.length ? [...current, { type: "lyric", text: " " }, ...content] : content;
    chords += content.filter((t) => t.type === "chord").length;
    if (chords >= COMPACT_CHORD_TARGET) {
      rows.push({ content: current });
      current = [];
      chords = 0;
    }
  }
  if (current.length) rows.push({ content: current });
  return rows;
}

/**
 * Splits a song's lines into sections at blank-line boundaries (the gap an
 * author leaves between Intro/Verse 1/Chorus/... — the same blank
 * `{content: []}` entries the `.lyric-inline` min-height fix above makes
 * visible again), the blank lines themselves being the separators. Used by
 * SongReader.tsx's desktop-only horizontal/section view.
 *
 * A raw blank-line-delimited group with no real sung lyrics anywhere in it
 * (every line a section label or bare chord row, per `isStandaloneLabelLine`
 * below) doesn't get a card of its own — it merges into a neighbouring
 * section instead (2026-10-07, owner: "ชื่อเพลง key intro verse1 ให้อยู่
 * การ์ดเดียวกัน Solo outro ให้อยู่กับตอนไหนตอนนึงก็ได้ เช่น outro ต้องอยู่
 * กับตอนสุดท้าย"): a leading label-only group (Key/Intro before the first
 * verse) merges FORWARD into the first real section; any other label-only
 * group (a standalone Solo or Outro block) merges BACKWARD into whichever
 * real section came right before it — which is exactly how a trailing
 * Outro ends up attached to the last section, with no special-casing for
 * "last" needed beyond that general rule. A song with no blank lines at all
 * (never used the convention) or with no real lyrics anywhere (the whole
 * song is label/chord-only) still comes back as one section holding
 * everything, rather than silently losing content.
 */
export function splitIntoSections(lines: LyricLineData[]): LyricLineData[][] {
  const raw: LyricLineData[][] = [];
  let current: LyricLineData[] = [];
  for (const line of lines) {
    if ((line.content ?? []).length === 0) {
      if (current.length) {
        raw.push(current);
        current = [];
      }
      continue;
    }
    current.push(line);
  }
  if (current.length) raw.push(current);

  const isLabelOnlyGroup = (group: LyricLineData[]) => group.every((l) => isStandaloneLabelLine(l.content ?? []));

  const sections: LyricLineData[][] = [];
  let leadingLabel: LyricLineData[] = [];
  for (const group of raw) {
    if (isLabelOnlyGroup(group)) {
      if (sections.length === 0) {
        leadingLabel = [...leadingLabel, ...group];
      } else {
        sections[sections.length - 1] = [...sections[sections.length - 1], ...group];
      }
      continue;
    }
    sections.push(leadingLabel.length ? [...leadingLabel, ...group] : group);
    leadingLabel = [];
  }
  if (sections.length === 0 && leadingLabel.length) sections.push(leadingLabel);

  return sections;
}

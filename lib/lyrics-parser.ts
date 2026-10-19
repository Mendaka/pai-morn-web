import type { LyricLineData, LyricToken } from "@/lib/lyrics";

// Port of lib/utils/lyrics_parser.dart — the editor's bracket syntax
// (`[Am]หวังว่า[C]คงจะดี`) to and from the stored
// `lyrics: [{content: [{type, text}]}]` shape.

/** One line of bracket text → tokens. Anything in [...] is a chord, the rest is lyric. */
export function parseLyricsLine(line: string): { type: "chord" | "lyric"; text: string }[] {
  const result: { type: "chord" | "lyric"; text: string }[] = [];
  const bracket = /\[([^\]]+)\]/g;
  let lastEnd = 0;
  for (let m = bracket.exec(line); m; m = bracket.exec(line)) {
    if (m.index > lastEnd) result.push({ type: "lyric", text: line.slice(lastEnd, m.index) });
    result.push({ type: "chord", text: m[1] });
    lastEnd = m.index + m[0].length;
  }
  if (lastEnd < line.length) result.push({ type: "lyric", text: line.slice(lastEnd) });
  return result;
}

export function parseLyricsBlock(block: string): { content: { type: "chord" | "lyric"; text: string }[] }[] {
  return block.split("\n").map((line) => ({ content: parseLyricsLine(line) }));
}

/** The inverse: stored lyrics back to editable bracket text. */
export function lyricsBlockToText(lyrics: LyricLineData[]): string {
  return lyrics
    .map((line) =>
      (line.content ?? [])
        .map((t: LyricToken) => (t.type === "chord" ? `[${t.text ?? ""}]` : (t.text ?? "")))
        .join(""),
    )
    .join("\n");
}

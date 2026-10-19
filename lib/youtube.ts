// Port of lib/utils/youtube_link.dart: pulls the video id out of any
// standard YouTube link a submitter might paste (watch?v=, youtu.be/,
// embed/, shorts/). Returns null for anything else so "no playable link"
// and "couldn't parse it" are treated the same.
export function extractYoutubeVideoId(url: string): string | null {
  const trimmed = url.trim();
  if (!trimmed) return null;

  let parsed: URL;
  try {
    parsed = new URL(trimmed);
  } catch {
    return null;
  }

  const host = parsed.hostname.toLowerCase();
  const segments = parsed.pathname.split("/").filter(Boolean);

  if (host.includes("youtu.be")) return segments[0] ?? null;
  if (host.includes("youtube.com")) {
    for (const marker of ["embed", "shorts"]) {
      const i = segments.indexOf(marker);
      if (i !== -1 && i + 1 < segments.length) return segments[i + 1];
    }
    return parsed.searchParams.get("v");
  }
  return null;
}

export const youtubeThumbnail = (videoId: string) =>
  `https://img.youtube.com/vi/${videoId}/mqdefault.jpg`;

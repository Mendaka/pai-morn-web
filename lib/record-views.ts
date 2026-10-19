// Port of song_view_recorder.dart / site_view_recorder.dart: fire-and-forget
// POSTs to the recordSongView / recordSiteView Cloud Functions. A lost count is
// never worth an error, so nothing here throws or is awaited.
//
// OFF unless NEXT_PUBLIC_RECORD_VIEWS=1 (see .env.example) so local browsing,
// previews and automated tests can't inflate the live numbers.
const enabled = process.env.NEXT_PUBLIC_RECORD_VIEWS === "1";
const base = process.env.NEXT_PUBLIC_API_BASE ?? "";

function post(path: string, body?: unknown) {
  if (!enabled) return;
  fetch(`${base}${path}`, {
    method: "POST",
    headers: body ? { "Content-Type": "application/json" } : undefined,
    body: body ? JSON.stringify(body) : "",
    keepalive: true,
  }).catch(() => {});
}

export const recordSongView = (songId: string) => post("/api/record-song-view", { songId });

let siteRecorded = false;
/** Once per real page load, not per client-side navigation. */
export function recordSiteViewOnce() {
  if (siteRecorded) return;
  siteRecorded = true;
  post("/api/record-site-view");
}

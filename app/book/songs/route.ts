import { getApprovedSongsByIds } from "@/lib/songs";

// Book mode's batch-lyrics endpoint: `?ids=a,b,c`. Capped server-side so a
// crafted request can't force one huge Firestore read — lib/use-book-window.ts
// never asks for more than one window's worth at a time anyway.
const MAX_IDS = 40;

export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  const ids = new URL(request.url).searchParams.get("ids");
  if (!ids) return Response.json([]);
  const list = ids.split(",").map((s) => s.trim()).filter(Boolean).slice(0, MAX_IDS);
  const songs = await getApprovedSongsByIds(list);
  return Response.json(songs);
}

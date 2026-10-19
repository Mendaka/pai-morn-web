import { displayArtistName, getCatalog } from "@/lib/catalog";

// A small id -> title/artist index of every approved song, for the setlist
// pages (naming the songs in a list, and the "add songs" picker) — so the
// browser doesn't have to download every song's full lyrics to do that.
export const dynamic = "force-dynamic";

export async function GET() {
  const { songs } = await getCatalog();
  const body = songs.map((s) => ({ id: s.id, name: s.songName, artist: displayArtistName(s), key: s.key ? s.key + (s.keyIsMinor ? "m" : "") : "" }));
  return Response.json(body);
}

import { getCatalog } from "@/lib/catalog";

// Companion to /songs-index.json: every artist that has at least one approved
// song (id, name, song count) — for the search palette.
export const dynamic = "force-dynamic";

export async function GET() {
  const { artists } = await getCatalog();
  return Response.json(artists.map((a) => ({ id: a.id, name: a.name, count: a.songCount })));
}

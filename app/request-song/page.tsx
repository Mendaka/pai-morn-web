import type { Metadata } from "next";
import RequestSongView from "@/components/RequestSongView";

export const metadata: Metadata = {
  title: "Request a Song",
  description: "Can't work out a song's chords? Send us the song and lyrics and we'll add the chords for you.",
};

export default function RequestSongPage() {
  return <RequestSongView />;
}

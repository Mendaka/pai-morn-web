import type { Metadata } from "next";
import ChordsView from "@/components/ChordsView";

export const metadata: Metadata = {
  title: "Chords",
  description: "Guitar and ukulele chord diagrams — look up any finger position, hear it strummed, or test yourself with the chord quiz.",
};

export default function ChordsPage() {
  return <ChordsView />;
}

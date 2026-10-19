import type { Metadata } from "next";
import AboutView from "@/components/AboutView";

export const metadata: Metadata = {
  title: "About",
  description: "Paimorn (ပၢႆးမွၼ်း) is a community songbook of guitar chords and lyrics, built by and for Shan music lovers.",
};

export default function AboutPage() {
  return <AboutView />;
}

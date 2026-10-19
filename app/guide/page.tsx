import type { Metadata } from "next";
import GuideView from "@/components/GuideView";

export const metadata: Metadata = { title: "Guide", description: "A quick tour of everything you can do on Paimorn." };

export default function GuidePage() {
  return <GuideView />;
}

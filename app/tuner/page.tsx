import type { Metadata } from "next";
import TunerView from "@/components/TunerView";

export const metadata: Metadata = {
  title: "Guitar Tuner",
  description: "Tune your guitar in the browser with your microphone, or tap a string to hear its reference pitch.",
};

export default function TunerPage() {
  return <TunerView />;
}

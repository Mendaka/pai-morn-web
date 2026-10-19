import type { Metadata } from "next";
import SupportView from "@/components/SupportView";

export const metadata: Metadata = {
  title: "Support",
  description: "Paimorn is free and ad-free — an optional way to help cover hosting costs.",
};

export default function SupportPage() {
  return <SupportView />;
}

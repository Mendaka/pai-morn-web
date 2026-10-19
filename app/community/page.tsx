import type { Metadata } from "next";
import CommunityView from "@/components/CommunityView";

export const metadata: Metadata = {
  title: "Community",
  description: "Discussions from Paimorn's community of players, and the top song contributors.",
};

export default function CommunityPage() {
  return <CommunityView />;
}

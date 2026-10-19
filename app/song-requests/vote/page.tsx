import type { Metadata } from "next";
import VoteRequestsView from "@/components/VoteRequestsView";

export const metadata: Metadata = { title: "Vote on song requests" };

export default function VoteRequestsPage() {
  return <VoteRequestsView />;
}

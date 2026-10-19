import type { Metadata } from "next";
import ThreadView from "@/components/ThreadView";

export const metadata: Metadata = { title: "Discussion" };

export default async function ThreadPage(props: PageProps<"/community/thread/[id]">) {
  const { id } = await props.params;
  return <ThreadView threadId={id} />;
}

import type { Metadata } from "next";
import { Suspense } from "react";
import ProfileView from "@/components/ProfileView";

export const metadata: Metadata = {
  title: "Profile",
  robots: { index: false },
};

export default function ProfilePage() {
  return (
    // useSearchParams (?edit=1 opens the name editor) needs Suspense here.
    <Suspense>
      <ProfileView />
    </Suspense>
  );
}

"use client";

import { Suspense, useEffect } from "react";
import { usePathname, useSearchParams } from "next/navigation";
import { logPageView } from "@/lib/analytics";

function TrackPageViews() {
  // useSearchParams needs a Suspense boundary on a statically rendered page —
  // same reason SetlistNav is wrapped in SongReader.tsx.
  const pathname = usePathname();
  const searchParams = useSearchParams();
  useEffect(() => {
    const query = searchParams.toString();
    logPageView(query ? `${pathname}?${query}` : pathname);
  }, [pathname, searchParams]);
  return null;
}

// Mounted once in the root layout, next to SiteViewRecorder. Fires a Google
// Analytics page_view on the initial load AND on every client-side route
// change (Next.js never reloads the page for those, so GA's own automatic
// pageview alone would only ever see the very first one).
export default function AnalyticsTracker() {
  return (
    <Suspense fallback={null}>
      <TrackPageViews />
    </Suspense>
  );
}

import { getAnalytics, isSupported, logEvent, type Analytics } from "firebase/analytics";
import app from "@/lib/firebase/client";

// Same gate lib/record-views.ts uses ("this is the real live deployment, not a
// dev/preview/test run") — one flag for "count this traffic as real" everywhere,
// so a local `next dev` or a test run never pollutes the live Google Analytics
// numbers either. Set only in the real deploy (see deploy/deploy.ps1).
const enabled = process.env.NEXT_PUBLIC_RECORD_VIEWS === "1";

// getAnalytics() throws in environments without IndexedDB/cookies (some
// in-app browsers, Safari private mode) — isSupported() checks first, and the
// result is cached so every page view doesn't re-run the check.
let analyticsPromise: Promise<Analytics | null> | null = null;
function getAnalyticsInstance(): Promise<Analytics | null> {
  if (!enabled) return Promise.resolve(null);
  if (!analyticsPromise) {
    analyticsPromise = isSupported()
      .then((ok) => (ok ? getAnalytics(app) : null))
      .catch(() => null);
  }
  return analyticsPromise;
}

/**
 * Reports one page view to Google Analytics (the project's existing GA4
 * property, same one linked to the Flutter app's Firebase config). The
 * Analytics SDK's own auto-collected page_view only fires once, on the first
 * script load — Next.js's client-side route changes never reload the page, so
 * every navigation after the first needs its own explicit event or GA's
 * Realtime report undercounts which pages people are actually on.
 */
export function logPageView(path: string): void {
  void getAnalyticsInstance().then((analytics) => {
    if (!analytics) return;
    logEvent(analytics, "page_view", {
      page_path: path,
      page_location: typeof window !== "undefined" ? window.location.href : undefined,
      page_title: typeof document !== "undefined" ? document.title : undefined,
    });
  });
}

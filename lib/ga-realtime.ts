import { cache } from "react";
import { GoogleAuth } from "google-auth-library";

// Server-only: reads the GA4 Data API's Realtime report for the Home page's
// live-visitor widget. Credentials are a Viewer-only service account
// ("ga-widget-reader", granted access 2026-09-24) — never exposed to the
// client, never NEXT_PUBLIC_. Any failure (missing env vars, API hiccup,
// revoked access) just hides the widget rather than breaking the Home page.

// GA4's Realtime API has no region/province dimension (confirmed against the
// live API: "Field region is not a valid dimension" — only the non-realtime
// Reporting API has one). "city" is the finest-grained realtime dimension
// available, and often lands on the same name as a Thai province anyway
// since provinces are commonly named after their capital. GA doesn't always
// resolve it though — city can legitimately come back blank for a given
// visitor even when country is known, so `city` is optional per location.
export type LiveVisitors = { total: number; locations: { city: string | null; country: string; count: number }[] };

let authClient: GoogleAuth | null = null;
function getAuthClient(): GoogleAuth | null {
  const email = process.env.GA_SERVICE_ACCOUNT_EMAIL;
  const key = process.env.GA_SERVICE_ACCOUNT_PRIVATE_KEY;
  if (!email || !key) return null;
  if (!authClient) {
    authClient = new GoogleAuth({
      credentials: { client_email: email, private_key: key.replace(/\\n/g, "\n") },
      scopes: ["https://www.googleapis.com/auth/analytics.readonly"],
    });
  }
  return authClient;
}

type RealtimeRow = { dimensionValues?: { value?: string }[]; metricValues?: { value?: string }[] };

export const getLiveVisitors = cache(async (): Promise<LiveVisitors | null> => {
  const propertyId = process.env.GA_PROPERTY_ID;
  const auth = getAuthClient();
  if (!propertyId || !auth) return null;
  try {
    const client = await auth.getClient();
    const res = await client.request<{ rows?: RealtimeRow[] }>({
      url: `https://analyticsdata.googleapis.com/v1beta/properties/${propertyId}:runRealtimeReport`,
      method: "POST",
      data: { dimensions: [{ name: "country" }, { name: "city" }], metrics: [{ name: "activeUsers" }] },
    });
    const rows = res.data.rows ?? [];
    const locations = rows
      .map((r) => {
        const country = r.dimensionValues?.[0]?.value ?? "";
        const city = r.dimensionValues?.[1]?.value ?? "";
        return { country, city: city && city !== "(not set)" ? city : null, count: Number(r.metricValues?.[0]?.value ?? 0) };
      })
      .filter((l) => l.country && l.count > 0)
      .sort((a, b) => b.count - a.count);
    const total = locations.reduce((sum, l) => sum + l.count, 0);
    return { total, locations };
  } catch {
    return null;
  }
});

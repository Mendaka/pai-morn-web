import { cache } from "react";
import { doc, getDoc } from "firebase/firestore";
import { serverDb } from "@/lib/firebase/server";

// stats/siteViews.count — bumped by the existing recordSiteView Cloud
// Function; public-read per firestore.rules. Best effort: a failed read
// just hides the number rather than breaking the page.
export const getSiteViews = cache(async (): Promise<number | null> => {
  try {
    const snap = await getDoc(doc(serverDb, "stats", "siteViews"));
    const count = snap.data()?.count;
    return typeof count === "number" ? count : null;
  } catch {
    return null;
  }
});

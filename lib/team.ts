import { cache } from "react";
import { collection, getDocs } from "firebase/firestore";
import { serverDb } from "@/lib/firebase/server";

// The About page's "Team": admins lead as developers, everyone else with at
// least one approved song follows, ranked by how much they've added. users/
// docs are public-read (author names and badges show next to songs), and
// nothing here goes beyond what's already public. Read on the server so the
// page doesn't pull the whole users collection into every visitor's browser.
export type TeamMember = {
  uid: string;
  name: string;
  photoUrl: string;
  count: number;
  role: "developer" | "contributor";
};

export const getTeam = cache(async (): Promise<TeamMember[]> => {
  try {
    const snap = await getDocs(collection(serverDb, "users"));
    const members: TeamMember[] = [];
    for (const doc of snap.docs) {
      const d = doc.data();
      const name = typeof d.displayName === "string" ? d.displayName.trim() : "";
      if (!name) continue;
      const count = typeof d.approvedSongCount === "number" ? d.approvedSongCount : 0;
      const photoUrl = typeof d.photoUrl === "string" ? d.photoUrl : "";
      if (d.isAdmin === true) members.push({ uid: doc.id, name, photoUrl, count, role: "developer" });
      else if (count > 0) members.push({ uid: doc.id, name, photoUrl, count, role: "contributor" });
    }
    const devs = members.filter((m) => m.role === "developer").sort((a, b) => a.name.localeCompare(b.name));
    const contributors = members.filter((m) => m.role === "contributor").sort((a, b) => b.count - a.count);
    return [...devs, ...contributors];
  } catch {
    return []; // best effort: the page still reads fine without the team
  }
});

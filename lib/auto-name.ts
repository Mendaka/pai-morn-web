import { collection, doc, getDocs, query, updateDoc, where } from "firebase/firestore";
import { db } from "@/lib/firebase/client";

const PREFIX = "PM-"; // Paimorn

/**
 * The highest "PM-001"-style number currently in use, or 0 if none.
 * `` is the standard Firestore prefix-range sentinel (a private-use
 * code point after every normal character) — without it the upper bound
 * would be PREFIX itself, an empty (self-contradictory) range that always
 * matches zero documents.
 */
async function highestAutoNameNumber(): Promise<number> {
  let highest = 0;
  const snap = await getDocs(
    query(collection(db, "users"), where("displayName", ">=", PREFIX), where("displayName", "<", PREFIX + "")),
  );
  for (const d of snap.docs) {
    const m = /^PM-(\d+)$/.exec(String(d.data().displayName ?? ""));
    if (m) highest = Math.max(highest, Number(m[1]));
  }
  return highest;
}

/**
 * The next free "PM-001"-style name: one more than the highest PM number in
 * use. users/ docs are public-read and a range query on one field needs no
 * index. There is no server-side counter (that would need a Cloud Function or
 * rules change), so two people registering in the same instant could receive
 * the same number — harmless, since display names aren't unique keys.
 */
export async function nextAutoName(): Promise<string> {
  let highest: number;
  try {
    highest = await highestAutoNameNumber();
  } catch {
    // Offline or blocked: fall back to a random suffix rather than failing signup.
    highest = Math.floor(Math.random() * 900) + 100;
  }
  return `${PREFIX}${String(highest + 1).padStart(3, "0")}`;
}

/**
 * Admin-only: give every listed user (expected to all currently have a blank
 * displayName) the next free "PM-001"-style name, one after another so none
 * collide. Fixes dormant accounts that never got a name and haven't signed
 * back in since — a signed-in user's own client self-heals this automatically
 * (see AuthProvider's ensureName), but that never runs for an account nobody
 * is actively using. Requires isAdmin (firestore.rules: admins may edit any
 * user's displayName; a non-admin's write here would just fail).
 */
export async function backfillBlankDisplayNames(userIds: string[]): Promise<void> {
  let highest = await highestAutoNameNumber();
  for (const id of userIds) {
    highest += 1;
    await updateDoc(doc(db, "users", id), { displayName: `${PREFIX}${String(highest).padStart(3, "0")}` });
  }
}

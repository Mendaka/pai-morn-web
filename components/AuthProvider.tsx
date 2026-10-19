"use client";

import { createContext, useCallback, useContext, useEffect, useMemo, useState } from "react";
import {
  createUserWithEmailAndPassword,
  onAuthStateChanged,
  sendPasswordResetEmail,
  signInWithEmailAndPassword,
  signOut as firebaseSignOut,
  updateProfile,
  type User,
} from "firebase/auth";
import { doc, onSnapshot, runTransaction, serverTimestamp, setDoc, updateDoc, type DocumentData } from "firebase/firestore";
import { auth, db } from "@/lib/firebase/client";
import { friendlyAuthError } from "@/lib/auth-errors";
import { nextAutoName } from "@/lib/auto-name";

// Port of lib/auth/auth_provider.dart. While signed in, a *live* listener
// (not a one-shot read) sits on users/{uid}, so a badge tier or admin flag
// changes on screen the moment it changes in Firestore.

export type UserProfile = {
  displayName: string;
  photoUrl: string;
  isAdmin: boolean;
  isBlocked: boolean;
  approvedSongCount: number;
  currentStreak: number;
  longestStreak: number;
  createdAt: Date | null;
};

export type AuthStatus = "loading" | "signedOut" | "signedIn";

type AuthContextValue = {
  status: AuthStatus;
  user: User | null;
  /** null until the first server snapshot of users/{uid} arrives. */
  profile: UserProfile | null;
  isAdmin: boolean;
  isBlocked: boolean;
  /** Admin-only "Edit Mode": shows edit pencils on songs. Per session, and only while signed in as an admin. */
  editMode: boolean;
  toggleEditMode: () => void;
  /** All three return null on success, or a human-readable error message. */
  signIn: (email: string, password: string) => Promise<string | null>;
  register: (email: string, password: string, displayName: string) => Promise<string | null>;
  resetPassword: (email: string) => Promise<string | null>;
  signOut: () => Promise<void>;
};

const AuthContext = createContext<AuthContextValue | null>(null);

function parseProfile(d: DocumentData): UserProfile {
  const num = (v: unknown) => (typeof v === "number" ? v : 0);
  return {
    displayName: typeof d.displayName === "string" ? d.displayName : "",
    photoUrl: typeof d.photoUrl === "string" ? d.photoUrl : "",
    isAdmin: d.isAdmin === true,
    isBlocked: d.blocked === true,
    approvedSongCount: num(d.approvedSongCount),
    currentStreak: num(d.currentStreak),
    longestStreak: num(d.longestStreak),
    createdAt: typeof d.createdAt?.toDate === "function" ? d.createdAt.toDate() : null,
  };
}

// "YYYY-MM-DD" in *this device's* local date, and a day-count between two
// such dates that's immune to DST (compares UTC midnights of the same y/m/d).
function localDateString(d: Date): string {
  const p = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}
function daysBetween(fromIso: string, to: Date): number {
  const [y, m, d] = fromIso.split("-").map(Number);
  const from = Date.UTC(y, m - 1, d);
  const today = Date.UTC(to.getFullYear(), to.getMonth(), to.getDate());
  return Math.round((today - from) / 86_400_000);
}

// A "days in a row" counter, computed and written client-side from this
// device's local date (no Cloud Function — "the app was opened" isn't a
// Firestore write to hook). Trusted at the same level as displayName in
// firestore.rules: a cosmetic number, not worth server-side validation.
function maybeUpdateStreak(uid: string, data: DocumentData) {
  const now = new Date();
  const lastActive = typeof data.lastActiveDate === "string" ? data.lastActiveDate : null;
  const current = typeof data.currentStreak === "number" ? data.currentStreak : 0;
  const longest = typeof data.longestStreak === "number" ? data.longestStreak : 0;

  let next: number;
  if (!lastActive) {
    next = 1;
  } else {
    const days = daysBetween(lastActive, now);
    if (days === 0) return; // already counted today
    next = days === 1 ? current + 1 : 1; // consecutive day, else streak broken
  }

  updateDoc(doc(db, "users", uid), {
    currentStreak: next,
    longestStreak: Math.max(next, longest),
    lastActiveDate: localDateString(now),
  }).catch(() => {});
}

// True while register() is mid-flight. createUser signs the new user in
// immediately, so the doc listener below can see "no profile yet" a moment
// before register() has written it — self-healing then would race the real
// write and could leave a blank displayName behind.
let registering = false;

// Accounts that ended up with no name (the Flutter app's self-heal used to
// overwrite a fresh signup's name with a blank one) get the next "PM-001" name.
// One attempt per uid per page load, so a failure can never loop.
const naming = new Set<string>();
async function ensureName(u: User): Promise<void> {
  if (naming.has(u.uid)) return;
  naming.add(u.uid);
  try {
    const name = await nextAutoName();
    await updateDoc(doc(db, "users", u.uid), { displayName: name });
    await updateProfile(u, { displayName: name }).catch(() => {});
  } catch {
    // Best effort: they can still set a name on their profile.
  }
}

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [status, setStatus] = useState<AuthStatus>("loading");
  const [user, setUser] = useState<User | null>(null);
  const [profile, setProfile] = useState<UserProfile | null>(null);
  // Which uid turned Edit Mode on — so it switches itself off for a different
  // (or signed-out) user instead of needing a reset step.
  const [editFor, setEditFor] = useState<string | null>(null);

  useEffect(() => {
    let unsubscribeDoc: (() => void) | null = null;
    // Runs the streak check at most once per sign-in session — not on every
    // live snapshot, including the one our own streak write triggers.
    let streakChecked = false;

    const unsubscribeAuth = onAuthStateChanged(auth, (u) => {
      unsubscribeDoc?.();
      unsubscribeDoc = null;
      streakChecked = false;
      setUser(u);
      setProfile(null);

      if (!u) {
        setStatus("signedOut");
        return;
      }
      setStatus("signedIn");

      unsubscribeDoc = onSnapshot(doc(db, "users", u.uid), (snap) => {
        if (!snap.exists()) {
          // Only self-heal on a SERVER-confirmed absence. A cache-only
          // snapshot can say "doesn't exist" just because this device's
          // local cache hasn't synced the doc yet — acting on that once
          // overwrote a real, long-standing account (isAdmin included) with
          // blank defaults in the Flutter app. The server snapshot follows
          // shortly and corrects things, so waiting loses nothing.
          if (snap.metadata.fromCache || registering) return;
          // Repairs a rare race from register(): the profile-doc write can
          // run before the new user's ID token is recognized and fail
          // permission-denied, leaving a working account with no profile.
          // A transaction reads from the server, so if the doc has appeared
          // in the meantime (register() writing it) we leave it alone rather
          // than overwriting the real displayName with a blank one.
          const ref = doc(db, "users", u.uid);
          runTransaction(db, async (tx) => {
            if ((await tx.get(ref)).exists()) return;
            tx.set(ref, {
              displayName: u.displayName ?? "",
              isAdmin: false,
              approvedSongCount: 0,
              createdAt: serverTimestamp(),
            });
          }).catch(() => {});
          return;
        }
        const data = snap.data();
        const named = typeof data.displayName === "string" && data.displayName.trim() !== "";
        if (!named && !registering && !snap.metadata.fromCache) void ensureName(u);
        setProfile(parseProfile(data));
        if (!streakChecked) {
          streakChecked = true;
          maybeUpdateStreak(u.uid, data);
        }
      });
    });

    return () => {
      unsubscribeAuth();
      unsubscribeDoc?.();
    };
  }, []);

  const signIn = useCallback(async (email: string, password: string) => {
    try {
      await signInWithEmailAndPassword(auth, email.trim(), password);
      return null;
    } catch (e) {
      return friendlyAuthError(e);
    }
  }, []);

  const register = useCallback(async (email: string, password: string, displayName: string) => {
    registering = true;
    try {
      const cred = await createUserWithEmailAndPassword(auth, email.trim(), password);
      // A blank name is fine: the account gets the next PM-001 style name.
      const name = displayName.trim() || (await nextAutoName());
      // Deliberately no email field: this doc is publicly readable (author
      // names/badges appear next to songs) and Firebase Auth already owns
      // the address — no reason to expose it a second time via Firestore.
      await setDoc(doc(db, "users", cred.user.uid), {
        displayName: name,
        isAdmin: false,
        approvedSongCount: 0,
        createdAt: serverTimestamp(),
      });
      // Also on the Auth record, so the self-heal above has a name to use.
      await updateProfile(cred.user, { displayName: name }).catch(() => {});
      return null;
    } catch (e) {
      return friendlyAuthError(e);
    } finally {
      registering = false;
    }
  }, []);

  // Firebase deliberately doesn't say whether the email has an account, so
  // success here only means the request went through.
  const resetPassword = useCallback(async (email: string) => {
    try {
      await sendPasswordResetEmail(auth, email.trim());
      return null;
    } catch (e) {
      return friendlyAuthError(e);
    }
  }, []);

  const signOut = useCallback(() => firebaseSignOut(auth), []);
  const uid = user?.uid ?? null;
  const toggleEditMode = useCallback(() => setEditFor((cur) => (uid && cur !== uid ? uid : null)), [uid]);

  const value = useMemo<AuthContextValue>(
    () => ({
      status,
      user,
      profile,
      isAdmin: profile?.isAdmin === true,
      isBlocked: profile?.isBlocked === true,
      editMode: profile?.isAdmin === true && uid !== null && editFor === uid,
      toggleEditMode,
      signIn,
      register,
      resetPassword,
      signOut,
    }),
    [status, user, profile, uid, editFor, toggleEditMode, signIn, register, resetPassword, signOut],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used inside <AuthProvider>");
  return ctx;
}

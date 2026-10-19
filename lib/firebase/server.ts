import { getApps, initializeApp, type FirebaseOptions } from "firebase/app";
import { initializeFirestore } from "firebase/firestore";

// Server-side Firestore access for SSR pages (song reader, songbook,
// artist profile, home, sitemap) — these only ever need PUBLIC data
// (approved songs, artists), which firestore.rules already allows an
// unauthenticated read for (only `status == 'draft'` is restricted), so
// the plain client SDK works here without any admin/service-account
// credential to manage. Server code must still filter to
// `status == 'approved'` itself where that matters for what's shown
// publicly (rules alone permit reading pending/rejected too) — matching
// the same app-level privacy gate the old `songPreview` Cloud Function
// enforced on top of Admin SDK access.
//
// Firestore's default network transport doesn't work out of the box in a
// plain Node.js server process (no `XMLHttpRequest`/streaming the way a
// browser has) — `experimentalAutoDetectLongPolling` makes it fall back to
// long-polling automatically wherever streaming isn't available, which is
// exactly this case. A separate `initializeFirestore` call (not the same
// `getFirestore(app)` used client-side) is required to pass this option.
//
// This is a deliberate scope-reduction from the plan's original
// `firebase-admin`-for-everything idea: Admin SDK needs a service-account
// key (or GCP-attached credentials, which only exist once actually
// deployed to a Cloud Function) to authenticate at all, which is real
// credential-handling overhead not worth taking on before it's actually
// needed. Revisit with firebase-admin once a screen needs privileged
// access rules alone can't grant (the admin dashboard's full song list
// across every status, for instance) — see the migration plan's Phase
// 2/3 admin work.
const firebaseConfig: FirebaseOptions = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
};

const serverAppName = "server";
const serverApp = getApps().find((a) => a.name === serverAppName) ?? initializeApp(firebaseConfig, serverAppName);

export const serverDb = initializeFirestore(serverApp, {
  experimentalAutoDetectLongPolling: true,
});

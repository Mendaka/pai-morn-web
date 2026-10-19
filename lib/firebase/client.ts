import { getApps, initializeApp, type FirebaseOptions } from "firebase/app";
import { connectAuthEmulator, getAuth } from "firebase/auth";
import { connectFirestoreEmulator, getFirestore } from "firebase/firestore";
import { getStorage } from "firebase/storage";

// Same Firebase project the existing Flutter app (lib/main.dart) already
// uses — this is a frontend swap, not a new backend, so every value here
// must match FirebaseOptions there exactly.
const firebaseConfig: FirebaseOptions = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
  measurementId: process.env.NEXT_PUBLIC_FIREBASE_MEASUREMENT_ID,
};

// Next.js can re-evaluate this module multiple times per process (HMR,
// multiple client bundles); `getApps()` guards the same
// already-initialized-app crash Flutter's own `Firebase.initializeApp`
// would otherwise hit too.
const fresh = getApps().length === 0;
const app = fresh ? initializeApp(firebaseConfig) : getApps()[0]!;

export const auth = getAuth(app);
export const db = getFirestore(app);
export const storage = getStorage(app);

// Testing only: NEXT_PUBLIC_USE_EMULATORS=1 points the browser at the local
// Firebase emulators (see .emulator/), so tests can create accounts, threads,
// requests... using the project's real security rules without touching the
// live database. Never set in a real build.
if (fresh && process.env.NEXT_PUBLIC_USE_EMULATORS === "1") {
  connectAuthEmulator(auth, "http://127.0.0.1:9099", { disableWarnings: true });
  connectFirestoreEmulator(db, "127.0.0.1", 8080);
}
export default app;

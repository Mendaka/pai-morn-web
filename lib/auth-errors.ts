import { FirebaseError } from "firebase/app";

// Firebase's own messages read like "Firebase: Error (auth/invalid-credential)."
// — map the codes people actually hit to an i18n key (see lib/i18n) whose text
// a person can act on. Callers translate it with t().
export function friendlyAuthError(e: unknown): string {
  const code = e instanceof FirebaseError ? e.code : "";
  switch (code) {
    case "auth/invalid-credential":
    case "auth/wrong-password":
    case "auth/user-not-found":
    case "auth/invalid-login-credentials":
      return "authErrInvalidCredentials";
    case "auth/invalid-email":
      return "authErrInvalidEmail";
    case "auth/email-already-in-use":
      return "authErrEmailInUse";
    case "auth/weak-password":
      return "authErrWeakPassword";
    case "auth/too-many-requests":
      return "authErrTooMany";
    case "auth/network-request-failed":
      return "authErrNetwork";
    case "auth/user-disabled":
      return "authErrDisabled";
    default:
      return "authErrGeneric";
  }
}

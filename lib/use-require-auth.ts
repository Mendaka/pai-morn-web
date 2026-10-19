"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/components/AuthProvider";

/**
 * For account-only pages: bounces a signed-out visitor to the login page
 * (which sends them back to `path` afterwards). Returns the signed-in user, or
 * null while auth is still loading / redirecting — render a skeleton for null.
 */
export function useRequireAuth(path: string) {
  const { status, user } = useAuth();
  const router = useRouter();
  useEffect(() => {
    if (status === "signedOut") router.replace(`/login?next=${encodeURIComponent(path)}`);
  }, [status, path, router]);
  return status === "signedIn" ? user : null;
}

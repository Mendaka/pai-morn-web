import type { Metadata } from "next";
import { Suspense } from "react";
import LoginForm from "@/components/LoginForm";

export const metadata: Metadata = {
  title: "Sign in",
  robots: { index: false },
};

export default function LoginPage() {
  return (
    <div className="mx-auto w-full px-4 py-8 sm:px-6 sm:py-14">
      {/* useSearchParams (for ?next=) needs a Suspense boundary on a static page */}
      <Suspense>
        <LoginForm />
      </Suspense>
    </div>
  );
}

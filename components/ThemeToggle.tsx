"use client";

import { useEffect } from "react";
import { Moon, Sun } from "lucide-react";
import { useT } from "@/components/LanguageProvider";
import { useStored, writeStored } from "@/lib/stored";

const KEY = "pm.theme";

// Light / dark switch for the navbar. The choice lives in localStorage
// (device-local, like the Flutter app's theme pref) and is applied as a `dark`
// class on <html>; the inline script in app/layout.tsx applies it before first
// paint so a dark visitor never sees a white flash. Light unless chosen.
export default function ThemeToggle() {
  const { t } = useT();
  const dark = useStored(KEY) === "dark";

  useEffect(() => {
    document.documentElement.classList.toggle("dark", dark);
  }, [dark]);

  return (
    <button
      type="button"
      onClick={() => writeStored(KEY, dark ? "light" : "dark")}
      aria-label={t("themeToggleLabel")}
      title={t("themeToggleLabel")}
      className="lift-spring flex h-9 w-9 items-center justify-center rounded-xl transition hover:bg-black/5 active:scale-90 sm:h-10 sm:w-10"
    >
      {/* key = icon swap replays the little spin-in */}
      <span key={dark ? "moon" : "sun"} className="theme-icon flex">
        {dark ? <Moon size={19} /> : <Sun size={19} />}
      </span>
    </button>
  );
}

"use client";

import { createContext, useCallback, useContext, useEffect, useMemo, useState } from "react";
import { isLang, htmlLang, loadDict, translate, type Dict, type Lang, type Vars } from "@/lib/i18n";
import { categoryKey, displayLabel, genderKey } from "@/lib/labels";
import { useStored, writeStored } from "@/lib/stored";

type LanguageContextValue = {
  lang: Lang;
  setLang: (lang: Lang) => void;
  t: (key: string, vars?: Vars) => string;
  /** Label for a preset category/gender value, or the value itself for free text. */
  category: (value: string) => string;
  gender: (value: string) => string;
  /** "12 songs" — the singular form only exists in English, like the Flutter app. */
  songs: (count: number) => string;
};

const LanguageContext = createContext<LanguageContextValue | null>(null);

// The chosen language is a device-local preference (like the Flutter app's
// shared_preferences). The server and the first client render use English, so
// hydration always matches; the saved language applies right after.
export function LanguageProvider({ children }: { children: React.ReactNode }) {
  const stored = useStored("pm.lang");
  const lang: Lang = isLang(stored) ? stored : "en";
  const [loaded, setLoaded] = useState<{ lang: Lang; dict: Dict } | null>(null);

  useEffect(() => {
    if (lang === "en") return;
    let cancelled = false;
    loadDict(lang).then((dict) => {
      if (!cancelled) setLoaded({ lang, dict });
    });
    return () => {
      cancelled = true;
    };
  }, [lang]);

  useEffect(() => {
    document.documentElement.lang = htmlLang(lang);
  }, [lang]);

  // Until the chosen language has loaded, English shows (never raw keys).
  const dict = lang !== "en" && loaded?.lang === lang ? loaded.dict : null;

  const t = useCallback((key: string, vars?: Vars) => translate(dict, key, vars), [dict]);
  const setLang = useCallback((next: Lang) => writeStored("pm.lang", next), []);
  const value = useMemo<LanguageContextValue>(() => {
    const label = (key: string | null, raw: string) => (key ? t(key) : displayLabel({}, raw));
    return {
      lang,
      setLang,
      t,
      category: (v) => label(categoryKey(v), v),
      gender: (v) => label(genderKey(v), v),
      songs: (n) => t(n === 1 && lang === "en" ? "songCountLabelSingular" : "songsCountLabel", { count: n }),
    };
  }, [lang, setLang, t]);

  return <LanguageContext.Provider value={value}>{children}</LanguageContext.Provider>;
}

export function useT(): LanguageContextValue {
  const ctx = useContext(LanguageContext);
  if (!ctx) throw new Error("useT must be used inside <LanguageProvider>");
  return ctx;
}

/** Inline translated text — lets server components show translated strings. */
export function T({ k, vars }: { k: string; vars?: Vars }) {
  return <>{useT().t(k, vars)}</>;
}

/** "12 songs" — usable from server components. */
export function SongsCount({ n }: { n: number }) {
  return <>{useT().songs(n)}</>;
}

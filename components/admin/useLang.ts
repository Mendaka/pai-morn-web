"use client";

import { useT } from "@/components/LanguageProvider";
import type { Lang } from "@/lib/i18n";

/** The current UI language code (for date formatting etc.). */
export function useLang(): Lang {
  return useT().lang;
}

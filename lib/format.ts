import type { Lang } from "@/lib/i18n";

/** A short local date ("19 Sep 2026") in the reader's language. */
export function formatDate(date: Date, lang: Lang): string {
  // Browsers have no Shan locale data (and Burmese month names would be wrong for Shan), so Shan falls back to English.
  const locale = lang === "mm" ? "my" : lang === "shn" ? "en" : lang;
  try {
    return date.toLocaleDateString(locale, { day: "numeric", month: "short", year: "numeric" });
  } catch {
    return date.toLocaleDateString("en", { day: "numeric", month: "short", year: "numeric" });
  }
}

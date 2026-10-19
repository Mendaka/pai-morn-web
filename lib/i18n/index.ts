import en from "./en.json";

// UI translations, extracted from the Flutter app's l10n.dart (same keys, same
// text) so both apps stay in step. English is bundled; the other languages are
// loaded on demand when someone picks them. A key missing from a language
// falls back to English, then to the key itself.

export type Lang = "en" | "th" | "shn" | "mm";
export type Dict = Record<string, string>;

export const LANGUAGES: { code: Lang; label: string }[] = [
  { code: "en", label: "English" },
  { code: "th", label: "ภาษาไทย" },
  { code: "shn", label: "ၽႃႇသႃႇတႆး" },
  { code: "mm", label: "မြန်မာဘာသာ" },
];

export const isLang = (v: unknown): v is Lang => v === "en" || v === "th" || v === "shn" || v === "mm";

export const EN = en as Dict;

export function loadDict(lang: Lang): Promise<Dict> {
  switch (lang) {
    case "th":
      return import("./th.json").then((m) => m.default as Dict);
    case "shn":
      return import("./shn.json").then((m) => m.default as Dict);
    case "mm":
      return import("./mm.json").then((m) => m.default as Dict);
    default:
      return Promise.resolve(EN);
  }
}

export type Vars = Record<string, string | number>;

/** Looks up `key` in `dict` (falling back to English), filling `{name}` placeholders. */
export function translate(dict: Dict | null, key: string, vars?: Vars): string {
  const text = dict?.[key] ?? EN[key] ?? key;
  return vars ? text.replace(/\{(\w+)\}/g, (m, name: string) => (name in vars ? String(vars[name]) : m)) : text;
}

/** The HTML lang code for a UI language (Burmese is "my", not "mm"). */
export const htmlLang = (lang: Lang): string => (lang === "mm" ? "my" : lang);

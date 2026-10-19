// Stable Firestore values for the preset categories / genders (ports of
// category_labels.dart and gender_labels.dart). Stored instead of display
// text so a song stays grouped correctly whatever language it's viewed in.
// Anything else is free text typed via "Other" and displays as-is.

export const PRESET_CATEGORIES = ["dhamma", "tradition", "love", "politics", "life", "duet", "band", "school"] as const;
export const PRESET_GENDERS = ["male", "female", "duet"] as const;

export const CATEGORY_LABELS: Record<string, string> = {
  dhamma: "Dhamma",
  tradition: "Tradition",
  love: "Love",
  politics: "Politics",
  life: "Life",
  duet: "Duet",
  band: "Band",
  school: "School",
};
export const GENDER_LABELS: Record<string, string> = { male: "Male", female: "Female", duet: "Duet" };

// Raw Shan text saved before the presets existed. Applied at save time so
// retyping one via "Other" doesn't bring back an untranslatable duplicate.
const LEGACY_CATEGORY: Record<string, string> = {
  "တၢင်းႁၵ်ႉ": "love",
  "ၵၢၼ်မိူင်း": "politics",
  "ၽဝႃႉ": "life",
};
const LEGACY_GENDER: Record<string, string> = {
  "ၵူၼ်းၸၢႆး": "male",
  "ၼၢင်းယိင်း": "female",
};

export const normalizeCategory = (v: string): string => LEGACY_CATEGORY[v] ?? v;
export const normalizeGender = (v: string): string => LEGACY_GENDER[v] ?? v;

export const displayLabel = (map: Record<string, string>, key: string): string =>
  map[key] ?? key.charAt(0).toUpperCase() + key.slice(1);

/** i18n key for a preset category/gender ("love" -> "categoryLove"), or null for free text. */
export const categoryKey = (v: string): string | null =>
  (PRESET_CATEGORIES as readonly string[]).includes(v) ? "category" + v.charAt(0).toUpperCase() + v.slice(1) : null;
export const genderKey = (v: string): string | null =>
  (PRESET_GENDERS as readonly string[]).includes(v) ? "gender" + v.charAt(0).toUpperCase() + v.slice(1) : null;

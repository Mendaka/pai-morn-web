import 'package:pai_morn_web/l10n/l10n.dart';

/// Stable Firestore values for the "preset" categories — stored instead of
/// display text so a song's category stays grouped/filtered correctly no
/// matter what language was active when it was submitted or is later
/// viewed. Any other category is still free text typed via "Other" in
/// SubmitSongScreen and has no translation — categoryDisplayLabel returns it
/// unchanged.
const String categoryDhamma = 'dhamma';
const String categoryTradition = 'tradition';
const String categoryLove = 'love';
const String categoryPolitics = 'politics';
const String categoryLife = 'life';
const Set<String> presetCategories = {
  categoryDhamma,
  categoryTradition,
  categoryLove,
  categoryPolitics,
  categoryLife,
};

String categoryDisplayLabel(String value, String language) {
  switch (value) {
    case categoryDhamma:
      return AppTranslations.getText('categoryDhamma', language);
    case categoryTradition:
      return AppTranslations.getText('categoryTradition', language);
    case categoryLove:
      return AppTranslations.getText('categoryLove', language);
    case categoryPolitics:
      return AppTranslations.getText('categoryPolitics', language);
    case categoryLife:
      return AppTranslations.getText('categoryLife', language);
    default:
      return value;
  }
}

// Raw Shan text a submitter typed/picked before these presets existed —
// stored directly as the category value, so it never translated with the
// site's language. Maps each known old raw value straight to its stable
// key. Applied at save time (see SubmitSongScreen) so retyping one of these
// via "Other" out of habit doesn't reintroduce an untranslatable duplicate
// option, and defensively wherever category values are scanned live off
// existing docs for display (a stray already-saved doc still normalizes
// correctly even before any migration catches up with it).
const Map<String, String> _legacyRawCategoryValues = {
  'တၢင်းႁၵ်ႉ': categoryLove,
  'ၵၢၼ်မိူင်း': categoryPolitics,
  'ၽဝႃႉ': categoryLife,
};

String? normalizeCategoryValue(String? value) {
  if (value == null) return null;
  return _legacyRawCategoryValues[value] ?? value;
}

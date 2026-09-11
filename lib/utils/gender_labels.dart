import 'package:pai_morn_web/l10n/l10n.dart';

/// Stable Firestore values for the Gender picker — stored instead of
/// display text so a song's gender stays filterable/displayable correctly
/// no matter what language was active when it was submitted or is later
/// viewed. Mirrors category_labels.dart's categoryDhamma/categoryTradition
/// scheme exactly, including the same freeform "Other" escape hatch in
/// SubmitSongScreen for anything outside these two — genderDisplayLabel's
/// default case returns that free text unchanged, same as
/// categoryDisplayLabel does.
const String genderMale = 'male';
const String genderFemale = 'female';
const Set<String> presetGenders = {genderMale, genderFemale};

String genderDisplayLabel(String value, String language) {
  switch (value) {
    case genderMale:
      return AppTranslations.getText('genderMale', language);
    case genderFemale:
      return AppTranslations.getText('genderFemale', language);
    default:
      return value;
  }
}

// Raw Shan text a submitter typed/picked before these presets existed —
// stored directly as the gender value, so it never translated with the
// site's language. A one-time production migration converted every
// existing doc, but the freeform "Other" field can still reintroduce one of
// these exact strings (e.g. someone retyping it from habit), so this is
// applied at save time too (see SubmitSongScreen) — same rationale as
// category_labels.dart's normalizeCategoryValue.
const Map<String, String> _legacyRawGenderValues = {
  'ၵူၼ်းၸၢႆး': genderMale,
  'ၼၢင်းယိင်း': genderFemale,
};

String? normalizeGenderValue(String? value) {
  if (value == null) return null;
  return _legacyRawGenderValues[value] ?? value;
}

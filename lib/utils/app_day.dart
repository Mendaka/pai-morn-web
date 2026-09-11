/// "Today" pinned to a fixed UTC+7 day boundary (roughly Thailand/Indochina
/// time, this app's primary audience region) rather than each viewer's own
/// device timezone. The `dailyUpdateCard`/`dailyUpdatePreview` Cloud
/// Functions (functions/index.js) use the exact same offset/truncation
/// logic — keeping both sides in agreement is the whole point, so a viewer
/// in a different timezone and the shared Facebook image never disagree on
/// how many songs count as "today" right around midnight.
const _appDayOffset = Duration(hours: 7);

DateTime startOfAppDayUtc([DateTime? now]) {
  final shifted = (now ?? DateTime.now()).toUtc().add(_appDayOffset);
  final startShifted = DateTime.utc(shifted.year, shifted.month, shifted.day);
  return startShifted.subtract(_appDayOffset);
}

/// The current app-day's calendar date as "YYYY-MM-DD", in this same fixed
/// UTC+7 boundary — used to make a daily-changing shared link genuinely
/// different each day (see todays_new_songs_card.dart and
/// dailyUpdatePreview in functions/index.js, which has an identical JS
/// version of this same helper). Link-preview crawlers (Facebook, LINE,
/// ...) cache aggressively per exact URL, often for weeks, and don't
/// respect this app's own Cache-Control headers the way a browser does —
/// without a date embedded in the URL, everyone who opens a link shared on
/// day 1 keeps seeing day 1's snapshot forever, however often the
/// underlying count changes.
String appDayLabel([DateTime? now]) {
  final shifted = (now ?? DateTime.now()).toUtc().add(_appDayOffset);
  return '${shifted.year.toString().padLeft(4, '0')}-'
      '${shifted.month.toString().padLeft(2, '0')}-'
      '${shifted.day.toString().padLeft(2, '0')}';
}

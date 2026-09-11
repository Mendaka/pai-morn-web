import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether chord diagrams should be drawn/looked up as guitar or ukulele
/// shapes — one global, device-local preference (shared_preferences, same
/// persistence mechanism as theme/language) rather than a per-page toggle,
/// so switching it on the Chords reference page also changes the faint
/// chord-diagram background on the song reader and the tap-a-chord popup,
/// instead of the three surfaces disagreeing with each other.
class InstrumentModeProvider extends ChangeNotifier {
  static const _prefsKey = 'instrument_is_ukulele';

  bool _isUkulele = false;
  bool get isUkulele => _isUkulele;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _isUkulele = prefs.getBool(_prefsKey) ?? false;
    notifyListeners();
  }

  Future<void> toggle() async {
    _isUkulele = !_isUkulele;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, _isUkulele);
  }
}

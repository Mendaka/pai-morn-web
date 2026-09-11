import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  String _currentLanguage = 'en';

  LocaleProvider() {
    _loadLanguage();
  }

  String get currentLanguage => _currentLanguage;

  void changeLanguage(String languageCode) async {
    _currentLanguage = languageCode;
    notifyListeners(); // เรียกใช้ notifyListeners() เพื่อให้ UI อัปเดต
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('languageCode', languageCode);
  }

  Future<void> _loadLanguage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _currentLanguage = prefs.getString('languageCode') ?? 'en';
    notifyListeners();
  }
}

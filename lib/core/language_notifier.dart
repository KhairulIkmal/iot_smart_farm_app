import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton ChangeNotifier that holds the current app language code.
///
/// Usage:
///   await LanguageNotifier.instance.init();   // call once in main()
///   LanguageNotifier.instance.setLanguage('ms');
class LanguageNotifier extends ChangeNotifier {
  LanguageNotifier._();
  static final LanguageNotifier instance = LanguageNotifier._();

  String _languageCode = 'en';
  String get languageCode => _languageCode;

  /// Load the saved language from SharedPreferences. Call once in main().
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _languageCode = prefs.getString('language') ?? 'en';
    notifyListeners();
  }

  /// Persist and broadcast a language change.
  Future<void> setLanguage(String code) async {
    if (_languageCode == code) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', code);
    _languageCode = code;
    notifyListeners();
  }
}

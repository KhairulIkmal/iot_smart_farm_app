import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton ChangeNotifier that holds the current ThemeMode.
///
/// Usage:
///   await ThemeNotifier.instance.init();   // call once in main()
///   ThemeNotifier.instance.setTheme(ThemeMode.light);
class ThemeNotifier extends ChangeNotifier {
  ThemeNotifier._();
  static final ThemeNotifier instance = ThemeNotifier._();

  ThemeMode _mode = ThemeMode.dark;
  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  /// Load saved theme preference. Call once in main().
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('theme_mode') ?? 'dark';
    _mode = saved == 'light' ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  /// Persist and broadcast a theme change.
  Future<void> setTheme(ThemeMode mode) async {
    if (_mode == mode) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode == ThemeMode.light ? 'light' : 'dark');
    _mode = mode;
    notifyListeners();
  }

  void toggle() {
    setTheme(isDark ? ThemeMode.light : ThemeMode.dark);
  }
}

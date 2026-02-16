import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> loadThemeMode() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String saved = prefs.getString(_themeModeKey) ?? 'light';
    _themeMode = saved == 'dark' ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> toggleThemeMode() async {
    await setThemeMode(isDarkMode ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _themeModeKey,
      mode == ThemeMode.dark ? 'dark' : 'light',
    );
    notifyListeners();
  }
}

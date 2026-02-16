import 'package:shared_preferences/shared_preferences.dart';

class OnboardingHelper {
  static const String _key = 'hasSeenOnboarding';

  static Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  static Future<void> setSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}

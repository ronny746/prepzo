import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The student's Light / Dark / System choice, saved on the device.
/// Light is the default until they pick something else in Settings.
class ThemeController {
  ThemeController._();

  static const _prefsKey = 'app_theme_mode';

  /// Dark mode is switched off for now: the app always uses the light theme
  /// and Settings hides the App Theme option. Set to true to bring it back.
  static const bool darkModeEnabled = false;

  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.light);

  static ThemeMode parse(String? value) {
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }

  static String label(ThemeMode value) {
    switch (value) {
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System default';
      case ThemeMode.light:
        return 'Light';
    }
  }

  static Future<void> load() async {
    if (!darkModeEnabled) {
      mode.value = ThemeMode.light;
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      mode.value = parse(prefs.getString(_prefsKey));
    } catch (_) {
      mode.value = ThemeMode.light;
    }
  }

  static Future<void> set(ThemeMode value) async {
    if (!darkModeEnabled) return;
    mode.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, value.name);
    } catch (_) {
      // The choice still applies for this run.
    }
  }
}

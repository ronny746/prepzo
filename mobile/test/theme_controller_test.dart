import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lms/core/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('light is the default when nothing is saved', () async {
    SharedPreferences.setMockInitialValues({});
    await ThemeController.load();
    expect(ThemeController.mode.value, ThemeMode.light);
  });

  test('while dark mode is switched off the app stays light', () async {
    SharedPreferences.setMockInitialValues({'app_theme_mode': 'dark'});
    await ThemeController.load();
    expect(ThemeController.mode.value, ThemeMode.light);
    await ThemeController.set(ThemeMode.dark);
    expect(ThemeController.mode.value, ThemeMode.light);
  }, skip: ThemeController.darkModeEnabled);

  test('the chosen theme is saved and loaded again', () async {
    SharedPreferences.setMockInitialValues({});
    await ThemeController.set(ThemeMode.dark);
    ThemeController.mode.value = ThemeMode.light;
    await ThemeController.load();
    expect(ThemeController.mode.value, ThemeMode.dark);
  }, skip: !ThemeController.darkModeEnabled);

  test('unknown saved values fall back to light', () {
    expect(ThemeController.parse('purple'), ThemeMode.light);
    expect(ThemeController.parse(null), ThemeMode.light);
  });
}

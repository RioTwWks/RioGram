import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/core/theme/theme_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ThemePreferences сохраняет режим и акцентный цвет', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = ThemePreferences();

    await preferences.setThemeMode(ThemeMode.dark);
    await preferences.setAccentColor(ThemePreferences.accentOptions[2]);

    expect(preferences.themeMode, ThemeMode.dark);
    expect(preferences.accentColor, ThemePreferences.accentOptions[2]);
  });
}

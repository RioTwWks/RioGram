import 'package:flutter/material.dart';

import 'telegram_theme.dart';
import 'theme_preferences.dart';

/// Управление темой приложения.
class ThemeManager extends ChangeNotifier {
  ThemeManager({ThemePreferences? preferences})
      : _preferences = preferences ?? ThemePreferences();

  final ThemePreferences _preferences;

  ThemeMode _themeMode = ThemeMode.system;
  Color _accentColor = ThemePreferences.accentOptions.first;
  bool _isLoaded = false;

  ThemeMode get themeMode => _themeMode;
  Color get accentColor => _accentColor;
  bool get isLoaded => _isLoaded;

  ThemeData get lightTheme =>
      TelegramTheme.build(brightness: Brightness.light, accentColor: _accentColor);

  ThemeData get darkTheme =>
      TelegramTheme.build(brightness: Brightness.dark, accentColor: _accentColor);

  Future<void> load() async {
    await _preferences.init();
    _themeMode = _preferences.themeMode;
    _accentColor = _preferences.accentColor;
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _preferences.setThemeMode(mode);
    notifyListeners();
  }

  Future<void> setAccentColor(Color color) async {
    _accentColor = color;
    await _preferences.setAccentColor(color);
    notifyListeners();
  }
}

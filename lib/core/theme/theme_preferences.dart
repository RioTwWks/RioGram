import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Настройки темы, сохраняемые в SharedPreferences.
class ThemePreferences {
  ThemePreferences({SharedPreferences? preferences})
      : _preferences = preferences;

  SharedPreferences? _preferences;

  static const _themeModeKey = 'theme_mode';
  static const _accentColorKey = 'accent_color';

  static const List<Color> accentOptions = [
    Color(0xFF2AABEE),
    Color(0xFF7B68EE),
    Color(0xFF43A047),
    Color(0xFFFF7043),
    Color(0xFFE91E63),
  ];

  Future<void> init() async {
    _preferences ??= await SharedPreferences.getInstance();
  }

  ThemeMode get themeMode {
    final value = _preferences?.getString(_themeModeKey) ?? 'system';
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Color get accentColor {
    final value = _preferences?.getInt(_accentColorKey);
    if (value == null) {
      return accentOptions.first;
    }
    return Color(value);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await init();
    final name = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _preferences!.setString(_themeModeKey, name);
  }

  Future<void> setAccentColor(Color color) async {
    await init();
    await _preferences!.setInt(_accentColorKey, color.toARGB32());
  }
}

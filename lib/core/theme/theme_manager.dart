import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/ui_customization_models.dart';
import 'telegram_theme.dart';
import 'theme_preferences.dart';
import 'ui_customization_manager.dart';
import 'ui_customization_preferences.dart';

/// Управление темой приложения.
class ThemeManager extends ChangeNotifier {
  ThemeManager({
    ThemePreferences? preferences,
    UiCustomizationManager? customization,
  })  : _preferences = preferences ?? ThemePreferences(),
        _customization = customization {
    _customization?.addListener(_onCustomizationChanged);
  }

  final ThemePreferences _preferences;
  final UiCustomizationManager? _customization;

  ThemeMode _themeMode = ThemeMode.system;
  Color _accentColor = ThemePreferences.accentOptions.first;
  var _isLoaded = false;

  ThemeMode get themeMode => _themeMode;
  Color get accentColor => _resolvedAccentColor;
  bool get isLoaded => _isLoaded;

  UiCustomizationManager? get customization => _customization;

  Color get _resolvedAccentColor {
    final custom = _customization;
    if (custom != null &&
        custom.useCustomAccent &&
        custom.customAccentColor != null) {
      return custom.customAccentColor!;
    }
    return _accentColor;
  }

  double get cornerRadiusScale =>
      _customization?.cornerRadiusScale ??
      UiCustomizationPreferences.defaultCornerRadiusScale;

  ThemeData get lightTheme => _buildTheme(Brightness.light);

  ThemeData get darkTheme => _buildTheme(Brightness.dark);

  ThemeData _buildTheme(Brightness brightness) {
    final accent = _resolvedAccentColor;
    final radiusScale = cornerRadiusScale;
    final fontPreset = _customization?.fontPreset ?? AppFontPreset.system;

    var theme = TelegramTheme.build(
      brightness: brightness,
      accentColor: accent,
      cornerRadiusScale: radiusScale,
      fontFamily: _fontFamilyFor(fontPreset),
    );

    theme = _applyGoogleFont(theme, fontPreset);
    return theme;
  }

  String? _fontFamilyFor(AppFontPreset preset) => preset.fontFamily;

  ThemeData _applyGoogleFont(ThemeData theme, AppFontPreset preset) {
    final base = theme.textTheme;
    final themed = switch (preset) {
      AppFontPreset.system => base,
      AppFontPreset.roboto => GoogleFonts.robotoTextTheme(base),
      AppFontPreset.openSans => GoogleFonts.openSansTextTheme(base),
      AppFontPreset.googleSans => GoogleFonts.interTextTheme(base),
    };
    return theme.copyWith(
      textTheme: themed,
      primaryTextTheme: themed,
    );
  }

  void _onCustomizationChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _customization?.removeListener(_onCustomizationChanged);
    super.dispose();
  }

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

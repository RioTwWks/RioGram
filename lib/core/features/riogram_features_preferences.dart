import 'package:shared_preferences/shared_preferences.dart';

/// Локальные настройки уникальных функций RioGram (§7.2).
class RioGramFeaturesPreferences {
  RioGramFeaturesPreferences({SharedPreferences? preferences})
      : _preferences = preferences;

  SharedPreferences? _preferences;

  static const _ghostModeKey = 'ghost_mode_enabled';
  static const _hideOnlineKey = 'ghost_hide_online';
  static const _hideTypingKey = 'ghost_hide_typing';
  static const _hideReadReceiptsKey = 'ghost_hide_read_receipts';
  static const _stealthSelfDestructKey = 'ghost_stealth_self_destruct';
  static const _antiRecallKey = 'anti_recall_enabled';
  static const _hoverPreviewKey = 'hover_preview_enabled';
  static const _videoSpeedKey = 'default_video_speed';
  static const _translatorLangKey = 'translator_target_language';

  static const double defaultVideoSpeed = 1.0;
  static const String defaultTranslatorLanguage = 'ru';

  Future<void> init() async {
    _preferences ??= await SharedPreferences.getInstance();
  }

  bool get ghostModeEnabled => _preferences?.getBool(_ghostModeKey) ?? false;
  bool get hideOnlineStatus => _preferences?.getBool(_hideOnlineKey) ?? true;
  bool get hideTypingStatus => _preferences?.getBool(_hideTypingKey) ?? true;
  bool get hideReadReceipts => _preferences?.getBool(_hideReadReceiptsKey) ?? true;
  bool get stealthViewSelfDestruct =>
      _preferences?.getBool(_stealthSelfDestructKey) ?? true;
  bool get antiRecallEnabled => _preferences?.getBool(_antiRecallKey) ?? false;
  bool get hoverPreviewEnabled =>
      _preferences?.getBool(_hoverPreviewKey) ?? true;
  double get defaultVideoSpeedValue =>
      _preferences?.getDouble(_videoSpeedKey) ?? defaultVideoSpeed;
  String get translatorTargetLanguage =>
      _preferences?.getString(_translatorLangKey) ?? defaultTranslatorLanguage;

  Future<void> setGhostModeEnabled(bool value) async {
    await init();
    await _preferences!.setBool(_ghostModeKey, value);
  }

  Future<void> setHideOnlineStatus(bool value) async {
    await init();
    await _preferences!.setBool(_hideOnlineKey, value);
  }

  Future<void> setHideTypingStatus(bool value) async {
    await init();
    await _preferences!.setBool(_hideTypingKey, value);
  }

  Future<void> setHideReadReceipts(bool value) async {
    await init();
    await _preferences!.setBool(_hideReadReceiptsKey, value);
  }

  Future<void> setStealthViewSelfDestruct(bool value) async {
    await init();
    await _preferences!.setBool(_stealthSelfDestructKey, value);
  }

  Future<void> setAntiRecallEnabled(bool value) async {
    await init();
    await _preferences!.setBool(_antiRecallKey, value);
  }

  Future<void> setHoverPreviewEnabled(bool value) async {
    await init();
    await _preferences!.setBool(_hoverPreviewKey, value);
  }

  Future<void> setDefaultVideoSpeed(double value) async {
    await init();
    await _preferences!.setDouble(_videoSpeedKey, value);
  }

  Future<void> setTranslatorTargetLanguage(String value) async {
    await init();
    await _preferences!.setString(_translatorLangKey, value);
  }
}

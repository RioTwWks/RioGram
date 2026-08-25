import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/ui_customization_models.dart';

/// Локальные настройки глубокой кастомизации UI (§7.3).
class UiCustomizationPreferences {
  UiCustomizationPreferences({SharedPreferences? preferences})
      : _preferences = preferences;

  SharedPreferences? _preferences;

  static const _useCustomAccentKey = 'ui_use_custom_accent';
  static const _customAccentKey = 'ui_custom_accent';
  static const _fontPresetKey = 'ui_font_preset';
  static const _cornerRadiusScaleKey = 'ui_corner_radius_scale';
  static const _hideMuteIconsKey = 'ui_hide_mute_icons';
  static const _hideNavigationBarKey = 'ui_hide_navigation_bar';
  static const _hideListIconsKey = 'ui_hide_list_icons';
  static const _hideStoriesStripKey = 'ui_hide_stories_strip';
  static const _chatSwipeEndKey = 'ui_chat_swipe_end';
  static const _chatSwipeStartKey = 'ui_chat_swipe_start';
  static const _messageSwipeEndKey = 'ui_message_swipe_end';
  static const _messageSwipeStartKey = 'ui_message_swipe_start';

  static const double defaultCornerRadiusScale = 1.0;

  Future<void> init() async {
    _preferences ??= await SharedPreferences.getInstance();
  }

  bool get useCustomAccent => _preferences?.getBool(_useCustomAccentKey) ?? false;

  Color? get customAccentColor {
    final value = _preferences?.getInt(_customAccentKey);
    return value == null ? null : Color(value);
  }

  AppFontPreset get fontPreset =>
      AppFontPresetX.fromStorage(_preferences?.getString(_fontPresetKey));

  double get cornerRadiusScale =>
      _preferences?.getDouble(_cornerRadiusScaleKey) ?? defaultCornerRadiusScale;

  bool get hideMuteIcons => _preferences?.getBool(_hideMuteIconsKey) ?? false;
  bool get hideNavigationBar =>
      _preferences?.getBool(_hideNavigationBarKey) ?? false;
  bool get hideStoriesStrip => _preferences?.getBool(_hideStoriesStripKey) ?? false;
  bool get hideListIcons => _preferences?.getBool(_hideListIconsKey) ?? false;

  ChatSwipeAction get chatSwipeEndToStart => _chatSwipe(
        _preferences?.getString(_chatSwipeEndKey),
        ChatSwipeAction.archive,
      );

  ChatSwipeAction get chatSwipeStartToEnd => _chatSwipe(
        _preferences?.getString(_chatSwipeStartKey),
        ChatSwipeAction.none,
      );

  MessageSwipeAction get messageSwipeEndToStart => _messageSwipe(
        _preferences?.getString(_messageSwipeEndKey),
        MessageSwipeAction.reply,
      );

  MessageSwipeAction get messageSwipeStartToEnd => _messageSwipe(
        _preferences?.getString(_messageSwipeStartKey),
        MessageSwipeAction.none,
      );

  Future<void> setUseCustomAccent(bool value) async {
    await init();
    await _preferences!.setBool(_useCustomAccentKey, value);
  }

  Future<void> setCustomAccentColor(Color color) async {
    await init();
    await _preferences!.setInt(_customAccentKey, color.toARGB32());
    await _preferences!.setBool(_useCustomAccentKey, true);
  }

  Future<void> setFontPreset(AppFontPreset preset) async {
    await init();
    await _preferences!.setString(_fontPresetKey, preset.name);
  }

  Future<void> setCornerRadiusScale(double value) async {
    await init();
    await _preferences!.setDouble(_cornerRadiusScaleKey, value);
  }

  Future<void> setHideMuteIcons(bool value) async {
    await init();
    await _preferences!.setBool(_hideMuteIconsKey, value);
  }

  Future<void> setHideNavigationBar(bool value) async {
    await init();
    await _preferences!.setBool(_hideNavigationBarKey, value);
  }

  Future<void> setHideListIcons(bool value) async {
    await init();
    await _preferences!.setBool(_hideListIconsKey, value);
  }

  Future<void> setHideStoriesStrip(bool value) async {
    await init();
    await _preferences!.setBool(_hideStoriesStripKey, value);
  }

  Future<void> setChatSwipeEndToStart(ChatSwipeAction action) async {
    await init();
    await _preferences!.setString(_chatSwipeEndKey, action.name);
  }

  Future<void> setChatSwipeStartToEnd(ChatSwipeAction action) async {
    await init();
    await _preferences!.setString(_chatSwipeStartKey, action.name);
  }

  Future<void> setMessageSwipeEndToStart(MessageSwipeAction action) async {
    await init();
    await _preferences!.setString(_messageSwipeEndKey, action.name);
  }

  Future<void> setMessageSwipeStartToEnd(MessageSwipeAction action) async {
    await init();
    await _preferences!.setString(_messageSwipeStartKey, action.name);
  }

  ChatSwipeAction _chatSwipe(String? raw, ChatSwipeAction fallback) {
    return ChatSwipeAction.values.firstWhere(
      (item) => item.name == raw,
      orElse: () => fallback,
    );
  }

  MessageSwipeAction _messageSwipe(String? raw, MessageSwipeAction fallback) {
    return MessageSwipeAction.values.firstWhere(
      (item) => item.name == raw,
      orElse: () => fallback,
    );
  }
}

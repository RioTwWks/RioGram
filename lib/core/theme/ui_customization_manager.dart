import 'package:flutter/material.dart';

import '../../models/ui_customization_models.dart';
import 'ui_customization_preferences.dart';

/// Управление глубокой кастомизацией интерфейса (§7.3).
class UiCustomizationManager extends ChangeNotifier {
  UiCustomizationManager({UiCustomizationPreferences? preferences})
      : _preferences = preferences ?? UiCustomizationPreferences();

  final UiCustomizationPreferences _preferences;

  var _isLoaded = false;
  var _useCustomAccent = false;
  Color? _customAccentColor;
  var _fontPreset = AppFontPreset.system;
  var _cornerRadiusScale = UiCustomizationPreferences.defaultCornerRadiusScale;
  var _hideMuteIcons = false;
  var _hideNavigationBar = false;
  var _hideListIcons = false;
  var _chatSwipeEndToStart = ChatSwipeAction.archive;
  var _chatSwipeStartToEnd = ChatSwipeAction.none;
  var _messageSwipeEndToStart = MessageSwipeAction.reply;
  var _messageSwipeStartToEnd = MessageSwipeAction.none;

  bool get isLoaded => _isLoaded;
  bool get useCustomAccent => _useCustomAccent;
  Color? get customAccentColor => _customAccentColor;
  AppFontPreset get fontPreset => _fontPreset;
  double get cornerRadiusScale => _cornerRadiusScale;
  bool get hideMuteIcons => _hideMuteIcons;
  bool get hideNavigationBar => _hideNavigationBar;
  bool get hideListIcons => _hideListIcons;
  ChatSwipeAction get chatSwipeEndToStart => _chatSwipeEndToStart;
  ChatSwipeAction get chatSwipeStartToEnd => _chatSwipeStartToEnd;
  MessageSwipeAction get messageSwipeEndToStart => _messageSwipeEndToStart;
  MessageSwipeAction get messageSwipeStartToEnd => _messageSwipeStartToEnd;

  Future<void> load() async {
    await _preferences.init();
    _useCustomAccent = _preferences.useCustomAccent;
    _customAccentColor = _preferences.customAccentColor;
    _fontPreset = _preferences.fontPreset;
    _cornerRadiusScale = _preferences.cornerRadiusScale;
    _hideMuteIcons = _preferences.hideMuteIcons;
    _hideNavigationBar = _preferences.hideNavigationBar;
    _hideListIcons = _preferences.hideListIcons;
    _chatSwipeEndToStart = _preferences.chatSwipeEndToStart;
    _chatSwipeStartToEnd = _preferences.chatSwipeStartToEnd;
    _messageSwipeEndToStart = _preferences.messageSwipeEndToStart;
    _messageSwipeStartToEnd = _preferences.messageSwipeStartToEnd;
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> setUseCustomAccent(bool value) async {
    _useCustomAccent = value;
    await _preferences.setUseCustomAccent(value);
    notifyListeners();
  }

  Future<void> setCustomAccentColor(Color color) async {
    _customAccentColor = color;
    _useCustomAccent = true;
    await _preferences.setCustomAccentColor(color);
    notifyListeners();
  }

  Future<void> setFontPreset(AppFontPreset preset) async {
    _fontPreset = preset;
    await _preferences.setFontPreset(preset);
    notifyListeners();
  }

  Future<void> setCornerRadiusScale(double value) async {
    _cornerRadiusScale = value;
    await _preferences.setCornerRadiusScale(value);
    notifyListeners();
  }

  Future<void> setHideMuteIcons(bool value) async {
    _hideMuteIcons = value;
    await _preferences.setHideMuteIcons(value);
    notifyListeners();
  }

  Future<void> setHideNavigationBar(bool value) async {
    _hideNavigationBar = value;
    await _preferences.setHideNavigationBar(value);
    notifyListeners();
  }

  Future<void> setHideListIcons(bool value) async {
    _hideListIcons = value;
    await _preferences.setHideListIcons(value);
    notifyListeners();
  }

  Future<void> setChatSwipeEndToStart(ChatSwipeAction action) async {
    _chatSwipeEndToStart = action;
    await _preferences.setChatSwipeEndToStart(action);
    notifyListeners();
  }

  Future<void> setChatSwipeStartToEnd(ChatSwipeAction action) async {
    _chatSwipeStartToEnd = action;
    await _preferences.setChatSwipeStartToEnd(action);
    notifyListeners();
  }

  Future<void> setMessageSwipeEndToStart(MessageSwipeAction action) async {
    _messageSwipeEndToStart = action;
    await _preferences.setMessageSwipeEndToStart(action);
    notifyListeners();
  }

  Future<void> setMessageSwipeStartToEnd(MessageSwipeAction action) async {
    _messageSwipeStartToEnd = action;
    await _preferences.setMessageSwipeStartToEnd(action);
    notifyListeners();
  }
}

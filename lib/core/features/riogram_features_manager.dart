import 'dart:async';

import 'package:flutter/foundation.dart';

import '../tdlib/tdlib_client.dart';
import 'riogram_features_preferences.dart';

/// Управление «Призрачным режимом» и связанными настройками §7.2.
class GhostModeManager extends ChangeNotifier {
  GhostModeManager({
    required TdlibClient client,
    RioGramFeaturesPreferences? preferences,
  })  : _client = client,
        _preferences = preferences ?? RioGramFeaturesPreferences();

  final TdlibClient _client;
  final RioGramFeaturesPreferences _preferences;

  var _ghostModeEnabled = false;
  var _hideOnlineStatus = true;
  var _hideTypingStatus = true;
  var _hideReadReceipts = true;
  var _stealthViewSelfDestruct = true;

  bool get ghostModeEnabled => _ghostModeEnabled;
  bool get hideOnlineStatus => _hideOnlineStatus;
  bool get hideTypingStatus => _hideTypingStatus;
  bool get hideReadReceipts => _hideReadReceipts;
  bool get stealthViewSelfDestruct => _stealthViewSelfDestruct;

  /// Активен ли конкретный аспект призрачного режима.
  bool get shouldHideOnline => _ghostModeEnabled && _hideOnlineStatus;
  bool get shouldHideTyping => _ghostModeEnabled && _hideTypingStatus;
  bool get shouldHideReadReceipts => _ghostModeEnabled && _hideReadReceipts;
  bool get shouldStealthViewSelfDestruct =>
      _ghostModeEnabled && _stealthViewSelfDestruct;

  Future<void> load() async {
    await _preferences.init();
    _ghostModeEnabled = _preferences.ghostModeEnabled;
    _hideOnlineStatus = _preferences.hideOnlineStatus;
    _hideTypingStatus = _preferences.hideTypingStatus;
    _hideReadReceipts = _preferences.hideReadReceipts;
    _stealthViewSelfDestruct = _preferences.stealthViewSelfDestruct;
    _applyOnlineStatus();
    notifyListeners();
  }

  Future<void> setGhostModeEnabled(bool value) async {
    _ghostModeEnabled = value;
    await _preferences.setGhostModeEnabled(value);
    _applyOnlineStatus();
    notifyListeners();
  }

  Future<void> setHideOnlineStatus(bool value) async {
    _hideOnlineStatus = value;
    await _preferences.setHideOnlineStatus(value);
    _applyOnlineStatus();
    notifyListeners();
  }

  Future<void> setHideTypingStatus(bool value) async {
    _hideTypingStatus = value;
    await _preferences.setHideTypingStatus(value);
    notifyListeners();
  }

  Future<void> setHideReadReceipts(bool value) async {
    _hideReadReceipts = value;
    await _preferences.setHideReadReceipts(value);
    notifyListeners();
  }

  Future<void> setStealthViewSelfDestruct(bool value) async {
    _stealthViewSelfDestruct = value;
    await _preferences.setStealthViewSelfDestruct(value);
    notifyListeners();
  }

  /// Применяет TDLib option «online» — false скрывает статус «в сети».
  void _applyOnlineStatus() {
    _client.send({
      '@type': 'setOption',
      'name': 'online',
      'value': {
        '@type': 'optionValueBoolean',
        'value': !shouldHideOnline,
      },
    });
  }

  /// Вызывается после авторизации для повторного применения настроек.
  void onAuthorized() {
    _applyOnlineStatus();
  }
}

/// Менеджер настроек медиа и перевода из §7.2.
class RioGramMediaFeaturesManager extends ChangeNotifier {
  RioGramMediaFeaturesManager({
    RioGramFeaturesPreferences? preferences,
  }) : _preferences = preferences ?? RioGramFeaturesPreferences();

  final RioGramFeaturesPreferences _preferences;

  var _antiRecallEnabled = false;
  var _hoverPreviewEnabled = true;
  var _defaultVideoSpeed = RioGramFeaturesPreferences.defaultVideoSpeed;
  var _translatorTargetLanguage =
      RioGramFeaturesPreferences.defaultTranslatorLanguage;

  bool get antiRecallEnabled => _antiRecallEnabled;
  bool get hoverPreviewEnabled => _hoverPreviewEnabled;
  double get defaultVideoSpeed => _defaultVideoSpeed;
  String get translatorTargetLanguage => _translatorTargetLanguage;

  Future<void> load() async {
    await _preferences.init();
    _antiRecallEnabled = _preferences.antiRecallEnabled;
    _hoverPreviewEnabled = _preferences.hoverPreviewEnabled;
    _defaultVideoSpeed = _preferences.defaultVideoSpeedValue;
    _translatorTargetLanguage = _preferences.translatorTargetLanguage;
    notifyListeners();
  }

  Future<void> setAntiRecallEnabled(bool value) async {
    _antiRecallEnabled = value;
    await _preferences.setAntiRecallEnabled(value);
    notifyListeners();
  }

  Future<void> setHoverPreviewEnabled(bool value) async {
    _hoverPreviewEnabled = value;
    await _preferences.setHoverPreviewEnabled(value);
    notifyListeners();
  }

  Future<void> setDefaultVideoSpeed(double value) async {
    _defaultVideoSpeed = value;
    await _preferences.setDefaultVideoSpeed(value);
    notifyListeners();
  }

  Future<void> setTranslatorTargetLanguage(String value) async {
    _translatorTargetLanguage = value;
    await _preferences.setTranslatorTargetLanguage(value);
    notifyListeners();
  }
}

/// Перевод сообщений через TDLib translateMessageText.
class MessageTranslator extends ChangeNotifier {
  MessageTranslator({required TdlibClient client}) : _client = client;

  final TdlibClient _client;
  StreamSubscription<Map<String, dynamic>>? _subscription;

  final Map<String, String> _cache = {};
  var _isTranslating = false;
  String? _lastError;

  bool get isTranslating => _isTranslating;
  String? get lastError => _lastError;

  static const supportedLanguages = <({String code, String label})>[
    (code: 'ru', label: 'Русский'),
    (code: 'en', label: 'English'),
    (code: 'uk', label: 'Українська'),
    (code: 'de', label: 'Deutsch'),
    (code: 'fr', label: 'Français'),
    (code: 'es', label: 'Español'),
    (code: 'zh', label: '中文'),
    (code: 'ar', label: 'العربية'),
    (code: 'tr', label: 'Türkçe'),
    (code: 'kk', label: 'Қазақша'),
  ];

  void startListening() {
    _subscription ??= _client.updates.listen(_handleUpdate);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  String? cachedTranslation(int chatId, int messageId, String languageCode) {
    return _cache['$chatId:$messageId:$languageCode'];
  }

  Future<String?> translateMessage({
    required int chatId,
    required int messageId,
    required String toLanguageCode,
  }) async {
    final cacheKey = '$chatId:$messageId:$toLanguageCode';
    final cached = _cache[cacheKey];
    if (cached != null) {
      return cached;
    }

    _isTranslating = true;
    _lastError = null;
    notifyListeners();

    final completer = Completer<String?>();
    late final StreamSubscription<Map<String, dynamic>> sub;
    sub = _client.updates.listen((update) {
      final extra = update['@extra'] as String?;
      if (extra != 'translate_$cacheKey') {
        return;
      }
      sub.cancel();
      if (update['@type'] == 'formattedText') {
        final text = update['text'] as String? ?? '';
        _cache[cacheKey] = text;
        completer.complete(text);
      } else if (update['@type'] == 'error') {
        _lastError = update['message'] as String? ?? 'Ошибка перевода';
        completer.complete(null);
      }
    });

    _client.send({
      '@type': 'translateMessageText',
      'chat_id': chatId,
      'message_id': messageId,
      'to_language_code': toLanguageCode,
      'tone': '',
      '@extra': 'translate_$cacheKey',
    });

    final result = await completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        sub.cancel();
        _lastError = 'Таймаут перевода';
        return null;
      },
    );

    _isTranslating = false;
    notifyListeners();
    return result;
  }

  void _handleUpdate(Map<String, dynamic> update) {
    // Основная логика в translateMessage через одноразовую подписку.
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tdlib/tdlib_client.dart';

/// Локаль и языковой пакет TDLib.
class AppLocaleManager extends ChangeNotifier {
  AppLocaleManager({required TdlibClient client}) : _client = client;

  final TdlibClient _client;

  static const _prefKey = 'app_language_pack_id';

  static const supportedLocales = <AppLocaleOption>[
    AppLocaleOption(packId: 'ru', label: 'Русский'),
    AppLocaleOption(packId: 'en', label: 'English'),
  ];

  StreamSubscription<Map<String, dynamic>>? _subscription;

  String _languagePackId = 'ru';
  var _isLoaded = false;
  var _isSaving = false;
  String? _lastError;

  String get languagePackId => _languagePackId;
  bool get isLoaded => _isLoaded;
  bool get isSaving => _isSaving;
  String? get lastError => _lastError;

  AppLocaleOption get currentOption => supportedLocales.firstWhere(
        (item) => item.packId == _languagePackId,
        orElse: () => supportedLocales.first,
      );

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _languagePackId = prefs.getString(_prefKey) ?? 'ru';
    _isLoaded = true;
    notifyListeners();
  }

  void startListening() {
    _subscription ??= _client.updates.listen(_handleUpdate);
    applyToTdlib();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> setLanguagePack(String packId) async {
    if (packId == _languagePackId) {
      return;
    }
    _isSaving = true;
    _lastError = null;
    notifyListeners();

    _languagePackId = packId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, packId);

    _client.send({
      '@type': 'setOption',
      'name': 'language_pack_id',
      'value': {
        '@type': 'optionValueString',
        'value': packId,
      },
      '@extra': 'locale_set_$packId',
    });
    notifyListeners();
  }

  void applyToTdlib() {
    _client.send({
      '@type': 'setOption',
      'name': 'language_pack_id',
      'value': {
        '@type': 'optionValueString',
        'value': _languagePackId,
      },
      '@extra': 'locale_apply',
    });
  }

  void _handleUpdate(Map<String, dynamic> update) {
    switch (update['@type']) {
      case 'ok':
        if ((update['@extra'] as String?)?.startsWith('locale_') ?? false) {
          _isSaving = false;
          notifyListeners();
        }
      case 'error':
        final extra = update['@extra'] as String?;
        if (extra != null && extra.startsWith('locale_')) {
          _isSaving = false;
          _lastError = update['message'] as String? ?? 'Ошибка языка';
          notifyListeners();
        }
    }
  }
}

class AppLocaleOption {
  const AppLocaleOption({
    required this.packId,
    required this.label,
  });

  final String packId;
  final String label;
}

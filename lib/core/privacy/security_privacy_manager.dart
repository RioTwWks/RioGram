import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/security_privacy_models.dart';
import '../tdlib/tdlib_client.dart';
import 'security_privacy_preferences.dart';

/// Local Premium, блокировка рекламы и телеметрия (§7.4).
class SecurityPrivacyManager extends ChangeNotifier {
  SecurityPrivacyManager({
    required TdlibClient client,
    SecurityPrivacyPreferences? preferences,
  })  : _client = client,
        _preferences = preferences ?? SecurityPrivacyPreferences();

  final TdlibClient _client;
  final SecurityPrivacyPreferences _preferences;

  StreamSubscription<Map<String, dynamic>>? _subscription;

  var _localPremiumEnabled = false;
  var _localPremiumUploadFileSize = true;
  var _localPremiumIncreasedLimits = true;
  var _localPremiumFasterDownloads = false;
  var _blockAdsEnabled = false;
  var _telemetryMode = TelemetryMode.disabled;

  final Map<LocalPremiumFeature, PremiumLimitInfo> _premiumLimits = {};
  String? _lastError;

  bool get localPremiumEnabled => _localPremiumEnabled;
  bool get localPremiumUploadFileSize => _localPremiumUploadFileSize;
  bool get localPremiumIncreasedLimits => _localPremiumIncreasedLimits;
  bool get localPremiumFasterDownloads => _localPremiumFasterDownloads;
  bool get blockAdsEnabled => _blockAdsEnabled;
  TelemetryMode get telemetryMode => _telemetryMode;
  String? get lastError => _lastError;
  Map<LocalPremiumFeature, PremiumLimitInfo> get premiumLimits =>
      Map.unmodifiable(_premiumLimits);

  bool get shouldBlockAds => _blockAdsEnabled;
  bool get isTelemetryEnabled => _telemetryMode == TelemetryMode.enabled;

  bool isLocalPremiumFeatureEnabled(LocalPremiumFeature feature) {
    if (!_localPremiumEnabled) {
      return false;
    }
    return switch (feature) {
      LocalPremiumFeature.uploadFileSize => _localPremiumUploadFileSize,
      LocalPremiumFeature.increasedLimits => _localPremiumIncreasedLimits,
      LocalPremiumFeature.fasterDownloads => _localPremiumFasterDownloads,
    };
  }

  int get maxUploadFileSizeBytes {
    if (isLocalPremiumFeatureEnabled(LocalPremiumFeature.uploadFileSize)) {
      return TelegramUploadLimits.premiumMaxBytes;
    }
    return TelegramUploadLimits.freeMaxBytes;
  }

  PremiumLimitInfo? limitFor(LocalPremiumFeature feature) {
    return switch (feature) {
      LocalPremiumFeature.uploadFileSize => PremiumLimitInfo(
          defaultValue: TelegramUploadLimits.freeMaxBytes,
          premiumValue: TelegramUploadLimits.premiumMaxBytes,
        ),
      LocalPremiumFeature.increasedLimits =>
        _premiumLimits[LocalPremiumFeature.increasedLimits],
      LocalPremiumFeature.fasterDownloads => null,
    };
  }

  Future<void> load() async {
    await _preferences.init();
    _localPremiumEnabled = _preferences.localPremiumEnabled;
    _localPremiumUploadFileSize = _preferences.localPremiumUploadFileSize;
    _localPremiumIncreasedLimits = _preferences.localPremiumIncreasedLimits;
    _localPremiumFasterDownloads = _preferences.localPremiumFasterDownloads;
    _blockAdsEnabled = _preferences.blockAdsEnabled;
    _telemetryMode = _preferences.telemetryMode;
    _applyTelemetryOptions();
    notifyListeners();
  }

  void startListening() {
    _subscription ??= _client.updates.listen(_handleUpdate);
    _fetchPremiumLimits();
  }

  void onAuthorized() {
    _applyTelemetryOptions();
    _applyAdBlockingServerPreference();
    _fetchPremiumLimits();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> setLocalPremiumEnabled(bool value) async {
    _localPremiumEnabled = value;
    await _preferences.setLocalPremiumEnabled(value);
    notifyListeners();
  }

  Future<void> setLocalPremiumUploadFileSize(bool value) async {
    _localPremiumUploadFileSize = value;
    await _preferences.setLocalPremiumUploadFileSize(value);
    notifyListeners();
  }

  Future<void> setLocalPremiumIncreasedLimits(bool value) async {
    _localPremiumIncreasedLimits = value;
    await _preferences.setLocalPremiumIncreasedLimits(value);
    notifyListeners();
  }

  Future<void> setLocalPremiumFasterDownloads(bool value) async {
    _localPremiumFasterDownloads = value;
    await _preferences.setLocalPremiumFasterDownloads(value);
    notifyListeners();
  }

  Future<void> setBlockAdsEnabled(bool value) async {
    _blockAdsEnabled = value;
    await _preferences.setBlockAdsEnabled(value);
    _applyAdBlockingServerPreference();
    notifyListeners();
  }

  Future<void> setTelemetryMode(TelemetryMode mode) async {
    _telemetryMode = mode;
    await _preferences.setTelemetryMode(mode);
    _applyTelemetryOptions();
    notifyListeners();
  }

  /// Проверяет размер файла перед отправкой; возвращает текст ошибки или null.
  String? validateUploadFileSize(int bytes) {
    final maxBytes = maxUploadFileSizeBytes;
    if (bytes <= maxBytes) {
      return null;
    }
    final maxGb = maxBytes ~/ (1024 * 1024 * 1024);
    return 'Файл слишком большой (лимит $maxGb ГБ). '
        'Включите Local Premium в настройках RioGram.';
  }

  void _applyTelemetryOptions() {
    final disable = !isTelemetryEnabled;
    for (final option in [
      'disable_network_statistics',
      'disable_persistent_network_statistics',
    ]) {
      _client.send({
        '@type': 'setOption',
        'name': option,
        'value': {
          '@type': 'optionValueBoolean',
          'value': disable,
        },
      });
    }
  }

  void _applyAdBlockingServerPreference() {
    if (!_blockAdsEnabled) {
      return;
    }
    _client.send({
      '@type': 'toggleHasSponsoredMessagesEnabled',
      'has_sponsored_messages_enabled': false,
      '@extra': 'security_privacy_disable_sponsored',
    });
  }

  void _fetchPremiumLimits() {
    const requests = <(LocalPremiumFeature, String)>[
      (
        LocalPremiumFeature.increasedLimits,
        'premiumLimitTypePinnedChatCount',
      ),
    ];
    for (final (feature, type) in requests) {
      _client.send({
        '@type': 'getPremiumLimit',
        'limit_type': {'@type': type},
        '@extra': 'security_premium_${feature.name}',
      });
    }
  }

  void _handleUpdate(Map<String, dynamic> update) {
    switch (update['@type']) {
      case 'premiumLimit':
        _handlePremiumLimit(update);
      case 'error':
        _handleError(update);
    }
  }

  void _handlePremiumLimit(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null || !extra.startsWith('security_premium_')) {
      return;
    }
    final featureName = extra.substring('security_premium_'.length);
    final feature = LocalPremiumFeature.values.cast<LocalPremiumFeature?>().firstWhere(
          (item) => item?.name == featureName,
          orElse: () => null,
        );
    if (feature == null) {
      return;
    }
    _premiumLimits[feature] = PremiumLimitInfo(
      defaultValue: (update['default_value'] as num?)?.toInt() ?? 0,
      premiumValue: (update['premium_value'] as num?)?.toInt() ?? 0,
    );
    notifyListeners();
  }

  void _handleError(Map<String, dynamic> update) {
    final extra = update['@extra'] as String?;
    if (extra == null || !extra.startsWith('security_')) {
      return;
    }
    if (extra == 'security_privacy_disable_sponsored') {
      // Для пользователей без Premium TDLib вернёт ошибку — клиентская фильтрация остаётся.
      return;
    }
    _lastError = update['message'] as String? ?? 'Ошибка настроек приватности';
    notifyListeners();
  }
}

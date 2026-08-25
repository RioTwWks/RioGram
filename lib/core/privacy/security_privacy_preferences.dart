import 'package:shared_preferences/shared_preferences.dart';

import '../../models/security_privacy_models.dart';

/// Локальные настройки безопасности и приватности (§7.4).
class SecurityPrivacyPreferences {
  SecurityPrivacyPreferences({SharedPreferences? preferences})
      : _preferences = preferences;

  SharedPreferences? _preferences;

  static const _localPremiumKey = 'local_premium_enabled';
  static const _localPremiumUploadKey = 'local_premium_upload';
  static const _localPremiumLimitsKey = 'local_premium_limits';
  static const _localPremiumSpeedKey = 'local_premium_speed';
  static const _blockAdsKey = 'block_ads_enabled';
  static const _telemetryModeKey = 'telemetry_mode';

  Future<void> init() async {
    _preferences ??= await SharedPreferences.getInstance();
  }

  bool get localPremiumEnabled =>
      _preferences?.getBool(_localPremiumKey) ?? false;
  bool get localPremiumUploadFileSize =>
      _preferences?.getBool(_localPremiumUploadKey) ?? true;
  bool get localPremiumIncreasedLimits =>
      _preferences?.getBool(_localPremiumLimitsKey) ?? true;
  bool get localPremiumFasterDownloads =>
      _preferences?.getBool(_localPremiumSpeedKey) ?? false;
  bool get blockAdsEnabled => _preferences?.getBool(_blockAdsKey) ?? false;

  TelemetryMode get telemetryMode {
    final raw = _preferences?.getString(_telemetryModeKey);
    return TelemetryMode.values.firstWhere(
      (mode) => mode.name == raw,
      orElse: () => TelemetryMode.disabled,
    );
  }

  Future<void> setLocalPremiumEnabled(bool value) async {
    await init();
    await _preferences!.setBool(_localPremiumKey, value);
  }

  Future<void> setLocalPremiumUploadFileSize(bool value) async {
    await init();
    await _preferences!.setBool(_localPremiumUploadKey, value);
  }

  Future<void> setLocalPremiumIncreasedLimits(bool value) async {
    await init();
    await _preferences!.setBool(_localPremiumLimitsKey, value);
  }

  Future<void> setLocalPremiumFasterDownloads(bool value) async {
    await init();
    await _preferences!.setBool(_localPremiumSpeedKey, value);
  }

  Future<void> setBlockAdsEnabled(bool value) async {
    await init();
    await _preferences!.setBool(_blockAdsKey, value);
  }

  Future<void> setTelemetryMode(TelemetryMode mode) async {
    await init();
    await _preferences!.setString(_telemetryModeKey, mode.name);
  }
}

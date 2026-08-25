import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Локальная блокировка приложения PIN-кодом и биометрией.
class AppLockManager extends ChangeNotifier {
  AppLockManager();

  static const _passcodeHashKey = 'riogram_app_passcode_hash';
  static const _biometricsKey = 'riogram_app_biometrics_enabled';
  static const _autoLockMinutesKey = 'riogram_app_auto_lock_minutes';

  final LocalAuthentication _localAuth = LocalAuthentication();

  var _isLoaded = false;
  var _isLocked = false;
  var _passcodeEnabled = false;
  var _biometricsEnabled = false;
  var _autoLockMinutes = 0;
  DateTime? _lastActivityAt;
  Timer? _autoLockTimer;

  bool get isLoaded => _isLoaded;
  bool get isLocked => _isLocked;
  bool get passcodeEnabled => _passcodeEnabled;
  bool get biometricsEnabled => _biometricsEnabled;
  int get autoLockMinutes => _autoLockMinutes;
  bool get canUseBiometrics => _biometricsEnabled && _passcodeEnabled;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _passcodeEnabled = prefs.getString(_passcodeHashKey)?.isNotEmpty ?? false;
    _biometricsEnabled = prefs.getBool(_biometricsKey) ?? false;
    _autoLockMinutes = prefs.getInt(_autoLockMinutesKey) ?? 0;
    _isLocked = _passcodeEnabled;
    _isLoaded = true;
    _restartAutoLockTimer();
    notifyListeners();
  }

  void recordActivity() {
    _lastActivityAt = DateTime.now();
    if (_isLocked) {
      return;
    }
    _restartAutoLockTimer();
  }

  Future<bool> setPasscode(String passcode) async {
    if (passcode.length < 4) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_passcodeHashKey, _hash(passcode));
    _passcodeEnabled = true;
    _isLocked = false;
    notifyListeners();
    return true;
  }

  Future<void> removePasscode(String currentPasscode) async {
    final ok = await verifyPasscodeAsync(currentPasscode);
    if (!ok) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_passcodeHashKey);
    await prefs.setBool(_biometricsKey, false);
    _passcodeEnabled = false;
    _biometricsEnabled = false;
    _isLocked = false;
    _autoLockTimer?.cancel();
    notifyListeners();
  }

  bool verifyPasscode(String passcode) {
    return false;
  }

  Future<bool> verifyPasscodeAsync(String passcode) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_passcodeHashKey);
    if (stored == null || stored.isEmpty) {
      return true;
    }
    return stored == _hash(passcode);
  }

  Future<bool> unlockWithPasscode(String passcode) async {
    final ok = await verifyPasscodeAsync(passcode);
    if (!ok) {
      return false;
    }
    _isLocked = false;
    recordActivity();
    notifyListeners();
    return true;
  }

  Future<bool> unlockWithBiometrics() async {
    if (!_biometricsEnabled || !_passcodeEnabled) {
      return false;
    }
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) {
        return false;
      }
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Разблокировать RioGram',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      if (authenticated) {
        _isLocked = false;
        recordActivity();
        notifyListeners();
      }
      return authenticated;
    } catch (error) {
      debugPrint('AppLockManager biometrics error: $error');
      return false;
    }
  }

  Future<void> setBiometricsEnabled(bool enabled) async {
    if (enabled) {
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) {
        return;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricsKey, enabled);
    _biometricsEnabled = enabled && _passcodeEnabled;
    notifyListeners();
  }

  Future<void> setAutoLockMinutes(int minutes) async {
    _autoLockMinutes = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_autoLockMinutesKey, minutes);
    _restartAutoLockTimer();
    notifyListeners();
  }

  void lockNow() {
    if (!_passcodeEnabled) {
      return;
    }
    _isLocked = true;
    notifyListeners();
  }

  void _restartAutoLockTimer() {
    _autoLockTimer?.cancel();
    if (!_passcodeEnabled || _autoLockMinutes <= 0) {
      return;
    }
    _autoLockTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      final last = _lastActivityAt;
      if (last == null || _isLocked || !_passcodeEnabled) {
        return;
      }
      final elapsed = DateTime.now().difference(last);
      if (elapsed.inMinutes >= _autoLockMinutes) {
        _isLocked = true;
        notifyListeners();
      }
    });
  }

  String _hash(String passcode) {
    final bytes = utf8.encode('riogram:$passcode');
    return sha256.convert(bytes).toString();
  }

  @override
  void dispose() {
    _autoLockTimer?.cancel();
    super.dispose();
  }
}

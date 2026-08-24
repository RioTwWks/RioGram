import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Нативная интеграция: CallKit (iOS), foreground service (Android).
class CallPlatformService {
  CallPlatformService._();

  static const _channel = MethodChannel('riogram/call_platform');

  static Future<void> startActiveCall({
    required String callUuid,
    required String handle,
    required String title,
    required bool isVideo,
    required bool isIncoming,
  }) async {
    if (kIsWeb) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('startActiveCall', {
        'callUuid': callUuid,
        'handle': handle,
        'title': title,
        'isVideo': isVideo,
        'isIncoming': isIncoming,
      });
    } on MissingPluginException {
      // Desktop / unsupported platform.
    } on PlatformException {
      // Ignore platform failures in dev builds.
    }
  }

  static Future<void> reportIncomingCall({
    required String callUuid,
    required String handle,
    required String title,
    required bool isVideo,
  }) async {
    if (kIsWeb || !Platform.isIOS) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('reportIncomingCall', {
        'callUuid': callUuid,
        'handle': handle,
        'title': title,
        'isVideo': isVideo,
      });
    } on MissingPluginException {
      // Ignore.
    } on PlatformException {
      // Ignore.
    }
  }

  static Future<void> endActiveCall({required String callUuid}) async {
    if (kIsWeb) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('endActiveCall', {
        'callUuid': callUuid,
      });
    } on MissingPluginException {
      // Ignore.
    } on PlatformException {
      // Ignore.
    }
  }

  static Future<void> setCallConnected({required String callUuid}) async {
    if (kIsWeb || !Platform.isIOS) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('setCallConnected', {
        'callUuid': callUuid,
      });
    } on MissingPluginException {
      // Ignore.
    } on PlatformException {
      // Ignore.
    }
  }

  /// Обработка действий CallKit → Dart (accept/decline/end).
  static void installHandler({
    void Function(String callUuid)? onAccept,
    void Function(String callUuid)? onDecline,
    void Function(String callUuid)? onEnd,
  }) {
    _channel.setMethodCallHandler((call) async {
      final uuid = call.arguments as String? ?? '';
      switch (call.method) {
        case 'onCallKitAccept':
          onAccept?.call(uuid);
        case 'onCallKitDecline':
          onDecline?.call(uuid);
        case 'onCallKitEnd':
          onEnd?.call(uuid);
      }
      return null;
    });
  }
}

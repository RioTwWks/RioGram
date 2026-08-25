import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract final class PlatformNavigation {
  static const _channel = MethodChannel('riogram/navigation_platform');

  static Future<void> configure() async {
    if (!kIsWeb && Platform.isIOS) {
      try {
        await _channel.invokeMethod<void>('configureTabBar', {
          'isTranslucent': false,
        });
      } on MissingPluginException {
      } on PlatformException {
      }
    }
  }
}

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'system_proxy_config.dart';

/// Определяет системный HTTP/SOCKS-прокси (корпоративная сеть, VPN, GNOME/KDE).
class SystemProxyDetector {
  SystemProxyDetector._();

  static const MethodChannel _channel =
      MethodChannel('com.riotwwks.riogram/system_proxy');

  /// Возвращает системный прокси или `null`, если не настроен.
  static Future<SystemProxyConfig?> detect() async {
    final fromPlatform = await _readPlatformProxy();
    if (fromPlatform != null) {
      return fromPlatform;
    }

    final fromEnv = _readEnvironmentProxy();
    if (fromEnv != null) {
      return fromEnv;
    }

    if (!kIsWeb && Platform.isLinux) {
      return _readGnomeProxy();
    }

    return null;
  }

  static Future<SystemProxyConfig?> _readPlatformProxy() async {
    if (kIsWeb) {
      return null;
    }
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getSystemProxy');
      if (result == null) {
        return null;
      }
      final host = result['host'] as String? ?? '';
      final port = result['port'] as int? ?? 0;
      if (host.isEmpty || port <= 0) {
        return null;
      }
      final typeName = result['type'] as String? ?? 'http';
      return SystemProxyConfig(
        host: host,
        port: port,
        type: typeName == 'socks5' ? SystemProxyType.socks5 : SystemProxyType.http,
        username: result['username'] as String? ?? '',
        password: result['password'] as String? ?? '',
      );
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      debugPrint('SystemProxyDetector: platform error: ${error.message}');
      return null;
    }
  }

  static SystemProxyConfig? _readEnvironmentProxy() {
    const keys = [
      'HTTPS_PROXY',
      'https_proxy',
      'HTTP_PROXY',
      'http_proxy',
      'ALL_PROXY',
      'all_proxy',
    ];
    for (final key in keys) {
      final value = Platform.environment[key];
      if (value != null && value.isNotEmpty) {
        final parsed = _parseProxyUrl(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  static Future<SystemProxyConfig?> _readGnomeProxy() async {
    try {
      final mode = await Process.run('gsettings', [
        'get',
        'org.gnome.system.proxy',
        'mode',
      ]);
      if (mode.exitCode != 0) {
        return null;
      }
      final modeValue = (mode.stdout as String).trim();
      if (modeValue != "'manual'") {
        return null;
      }

      // SOCKS vs HTTP
      final socksHost = await Process.run('gsettings', [
        'get',
        'org.gnome.system.proxy.socks',
        'host',
      ]);
      final socksPort = await Process.run('gsettings', [
        'get',
        'org.gnome.system.proxy.socks',
        'port',
      ]);
      final socksHostValue = _unwrapGsettingsString(socksHost.stdout as String);
      final socksPortValue = int.tryParse((socksPort.stdout as String).trim());
      if (socksHostValue != null &&
          socksHostValue.isNotEmpty &&
          socksPortValue != null &&
          socksPortValue > 0) {
        return SystemProxyConfig(
          host: socksHostValue,
          port: socksPortValue,
          type: SystemProxyType.socks5,
        );
      }

      final httpHost = await Process.run('gsettings', [
        'get',
        'org.gnome.system.proxy.http',
        'host',
      ]);
      final httpPort = await Process.run('gsettings', [
        'get',
        'org.gnome.system.proxy.http',
        'port',
      ]);
      final httpHostValue = _unwrapGsettingsString(httpHost.stdout as String);
      final httpPortValue = int.tryParse((httpPort.stdout as String).trim());
      if (httpHostValue != null &&
          httpHostValue.isNotEmpty &&
          httpPortValue != null &&
          httpPortValue > 0) {
        return SystemProxyConfig(
          host: httpHostValue,
          port: httpPortValue,
          type: SystemProxyType.http,
        );
      }
    } catch (error) {
      debugPrint('SystemProxyDetector: gsettings error: $error');
    }
    return null;
  }

  static String? _unwrapGsettingsString(String value) {
    final trimmed = value.trim();
    if (trimmed.length >= 2 &&
        trimmed.startsWith("'") &&
        trimmed.endsWith("'")) {
      return trimmed.substring(1, trimmed.length - 1);
    }
    return trimmed.isEmpty ? null : trimmed;
  }

  static SystemProxyConfig? _parseProxyUrl(String raw) {
    var value = raw.trim();
    if (value.isEmpty) {
      return null;
    }

    String? username;
    String? password;
    if (value.contains('@')) {
      final atIndex = value.lastIndexOf('@');
      final userInfo = value.substring(0, atIndex);
      value = value.substring(atIndex + 1);
      final colonIndex = userInfo.indexOf(':');
      if (colonIndex >= 0) {
        username = Uri.decodeComponent(userInfo.substring(0, colonIndex));
        password = Uri.decodeComponent(userInfo.substring(colonIndex + 1));
      } else {
        username = Uri.decodeComponent(userInfo);
      }
    }

    if (!value.contains('://')) {
      value = 'http://$value';
    }

    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) {
      return null;
    }

    final port = uri.port > 0 ? uri.port : _defaultPort(uri.scheme);
    if (port <= 0) {
      return null;
    }

    final scheme = uri.scheme.toLowerCase();
    final type = scheme.startsWith('socks')
        ? SystemProxyType.socks5
        : SystemProxyType.http;

    return SystemProxyConfig(
      host: uri.host,
      port: port,
      type: type,
      username: username ?? uri.userInfo.split(':').firstOrNull ?? '',
      password: password ??
          (uri.userInfo.contains(':')
              ? uri.userInfo.split(':').skip(1).join(':')
              : ''),
    );
  }

  static int _defaultPort(String scheme) {
    switch (scheme.toLowerCase()) {
      case 'https':
      case 'http':
        return 8080;
      case 'socks5':
      case 'socks':
      case 'socks4':
        return 1080;
      default:
        return 0;
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

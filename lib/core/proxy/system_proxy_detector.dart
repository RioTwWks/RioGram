import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'system_proxy_config.dart';
import '../tdlib/tdlib_json.dart';

/// Определяет системный HTTP/SOCKS-прокси (корпоративная сеть, VPN, GNOME/KDE).
class SystemProxyDetector {
  SystemProxyDetector._();

  static const MethodChannel _channel =
      MethodChannel('com.riotwwks.riogram/system_proxy');

  /// Возвращает системный прокси или `null`, если не настроен / порт закрыт.
  static Future<SystemProxyConfig?> detect() async {
    final candidates = <SystemProxyConfig?>[
      await _readPlatformProxy(),
      _readEnvironmentProxy(),
      if (!kIsWeb && Platform.isLinux) ...[
        await _readEtcEnvironmentProxy(),
        await _readKdeProxy(),
        await _readGnomeProxy(),
      ],
    ];

    for (var candidate in candidates) {
      if (candidate == null || !candidate.isConfigured) {
        continue;
      }
      candidate = await _enrichWithGnomeCredentials(candidate);
      if (!await _isPortOpen(candidate.host, candidate.port)) {
        debugPrint(
          'SystemProxyDetector: ${candidate.host}:${candidate.port} '
          'не отвечает (Connection refused) — пропуск',
        );
        continue;
      }
      debugPrint(
        'SystemProxyDetector: ${candidate.type.name} '
        '${candidate.host}:${candidate.port}'
        '${candidate.username.isNotEmpty ? ' (auth)' : ''}',
      );
      return candidate;
    }

    debugPrint('SystemProxyDetector: системный прокси не найден');
    return null;
  }

  static Future<SystemProxyConfig?> _readPlatformProxy() async {
    if (kIsWeb) {
      return null;
    }
    try {
      final result =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('getSystemProxy');
      if (result == null) {
        return null;
      }
      final host = result['host'] as String? ?? '';
      final port = tdIntOr(result['port']);
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

  static Future<SystemProxyConfig?> _readEtcEnvironmentProxy() async {
    try {
      final file = File('/etc/environment');
      if (!await file.exists()) {
        return null;
      }
      final lines = await file.readAsLines();
      final values = <String, String>{};
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) {
          continue;
        }
        final eq = trimmed.indexOf('=');
        if (eq <= 0) {
          continue;
        }
        var key = trimmed.substring(0, eq).trim();
        var value = trimmed.substring(eq + 1).trim();
        if (value.length >= 2 &&
            ((value.startsWith('"') && value.endsWith('"')) ||
                (value.startsWith("'") && value.endsWith("'")))) {
          value = value.substring(1, value.length - 1);
        }
        values[key] = value;
      }

      const keys = [
        'HTTPS_PROXY',
        'https_proxy',
        'HTTP_PROXY',
        'http_proxy',
        'ALL_PROXY',
        'all_proxy',
      ];
      for (final key in keys) {
        final value = values[key];
        if (value != null && value.isNotEmpty) {
          final parsed = _parseProxyUrl(value);
          if (parsed != null) {
            return parsed;
          }
        }
      }
    } catch (error) {
      debugPrint('SystemProxyDetector: /etc/environment error: $error');
    }
    return null;
  }

  static Future<SystemProxyConfig?> _readKdeProxy() async {
    try {
      final type = await _runKdeConfig(['ProxyType']);
      if (type == null) {
        return null;
      }
      final proxyType = int.tryParse(type);
      // 1 = Manual, 4 = Use environment variables (handled elsewhere).
      if (proxyType != 1) {
        return null;
      }

      final socks = await _runKdeConfig(['socksProxy']);
      if (socks != null && socks.isNotEmpty && socks != '/') {
        final parsed = _parseProxyUrl(socks);
        if (parsed != null) {
          return parsed.copyWith(type: SystemProxyType.socks5);
        }
      }

      final http = await _runKdeConfig(['httpProxy']);
      if (http != null && http.isNotEmpty && http != '/') {
        return _parseProxyUrl(http);
      }
    } catch (error) {
      debugPrint('SystemProxyDetector: KDE error: $error');
    }
    return null;
  }

  /// kreadconfig6 (Plasma 6) с fallback на kreadconfig5.
  static Future<String?> _runKdeConfig(List<String> keyArgs) async {
    const bins = ['kreadconfig6', 'kreadconfig5'];
    final args = [
      '--file',
      'kioslaverc',
      '--group',
      'Proxy Settings',
      '--key',
      ...keyArgs,
    ];
    for (final bin in bins) {
      try {
        final result = await Process.run(bin, args);
        if (result.exitCode == 0) {
          return (result.stdout as String).trim();
        }
      } on ProcessException {
        continue;
      }
    }
    return null;
  }

  /// GNOME: mode=manual, либо host/port заданы и локальный порт слушает
  /// (часто VPN оставляет credentials при mode=none).
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
      final isManual = modeValue == "'manual'";

      final socks = await _readGnomeEndpoint('socks', SystemProxyType.socks5);
      final http = await _readGnomeEndpoint('http', SystemProxyType.http);

      final preferred = socks ?? http;
      if (preferred == null) {
        return null;
      }

      if (isManual) {
        return preferred;
      }

      // mode=none/auto: берём только если порт реально открыт (локальный клиент).
      if (await _isPortOpen(preferred.host, preferred.port)) {
        debugPrint(
          'SystemProxyDetector: GNOME mode=$modeValue, но порт '
          '${preferred.host}:${preferred.port} открыт — используем',
        );
        return preferred;
      }
    } catch (error) {
      debugPrint('SystemProxyDetector: gsettings error: $error');
    }
    return null;
  }

  static Future<SystemProxyConfig?> _readGnomeEndpoint(
    String kind,
    SystemProxyType type,
  ) async {
    final hostResult = await Process.run('gsettings', [
      'get',
      'org.gnome.system.proxy.$kind',
      'host',
    ]);
    final portResult = await Process.run('gsettings', [
      'get',
      'org.gnome.system.proxy.$kind',
      'port',
    ]);
    if (hostResult.exitCode != 0 || portResult.exitCode != 0) {
      return null;
    }

    final host = _unwrapGsettingsString(hostResult.stdout as String);
    final port = int.tryParse((portResult.stdout as String).trim());
    if (host == null || host.isEmpty || port == null || port <= 0) {
      return null;
    }

    var username = '';
    var password = '';
    if (kind == 'http') {
      final useAuth = await Process.run('gsettings', [
        'get',
        'org.gnome.system.proxy.http',
        'use-authentication',
      ]);
      if (useAuth.exitCode == 0 &&
          (useAuth.stdout as String).trim() == 'true') {
        final user = await Process.run('gsettings', [
          'get',
          'org.gnome.system.proxy.http',
          'authentication-user',
        ]);
        final pass = await Process.run('gsettings', [
          'get',
          'org.gnome.system.proxy.http',
          'authentication-password',
        ]);
        username = _unwrapGsettingsString(user.stdout as String) ?? '';
        password = _unwrapGsettingsString(pass.stdout as String) ?? '';
      }
    }

    return SystemProxyConfig(
      host: host,
      port: port,
      type: type,
      username: username,
      password: password,
    );
  }

  /// GProxyResolver часто не отдаёт login/password — добираем из gsettings.
  static Future<SystemProxyConfig> _enrichWithGnomeCredentials(
    SystemProxyConfig proxy,
  ) async {
    if (proxy.username.isNotEmpty || kIsWeb || !Platform.isLinux) {
      return proxy;
    }
    try {
      final gnome = await _readGnomeEndpoint(
        proxy.type == SystemProxyType.socks5 ? 'socks' : 'http',
        proxy.type,
      );
      if (gnome == null) {
        return proxy;
      }
      if (gnome.host != proxy.host || gnome.port != proxy.port) {
        return proxy;
      }
      if (gnome.username.isEmpty) {
        return proxy;
      }
      return proxy.copyWith(
        username: gnome.username,
        password: gnome.password,
      );
    } catch (_) {
      return proxy;
    }
  }

  static Future<bool> _isPortOpen(String host, int port) async {
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(milliseconds: 700),
      );
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
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

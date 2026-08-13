import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Конфигурация приложения из переменных окружения (.env).
class AppConfig {
  AppConfig({
    required this.apiId,
    required this.apiHash,
    required this.phantomProxy,
    required this.stealthProxy,
  });

  final int apiId;
  final String apiHash;
  final ProxyConfig? phantomProxy;
  final ProxyConfig? stealthProxy;

  bool get hasApiCredentials => apiId > 0 && apiHash.isNotEmpty;

  static Future<AppConfig> load() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // .env может отсутствовать в CI — используем значения по умолчанию.
    }

    return AppConfig(
      apiId: int.tryParse(dotenv.maybeGet('TELEGRAM_API_ID') ?? '0') ?? 0,
      apiHash: dotenv.maybeGet('TELEGRAM_API_HASH') ?? '',
      phantomProxy: _readProxy(
        hostKey: 'PROXY_PHANTOM_HOST',
        portKey: 'PROXY_PHANTOM_PORT',
        secretKey: 'PROXY_PHANTOM_SECRET',
        name: 'PhantomProxy',
      ),
      stealthProxy: _readProxy(
        hostKey: 'PROXY_STEALTH_HOST',
        portKey: 'PROXY_STEALTH_PORT',
        secretKey: 'PROXY_STEALTH_SECRET',
        name: 'StealthGate',
      ),
    );
  }

  static ProxyConfig? _readProxy({
    required String hostKey,
    required String portKey,
    required String secretKey,
    required String name,
  }) {
    final host = dotenv.maybeGet(hostKey);
    if (host == null || host.isEmpty) {
      return null;
    }

    return ProxyConfig(
      name: name,
      host: host,
      port: int.tryParse(dotenv.maybeGet(portKey) ?? (name == 'PhantomProxy' ? '15443' : '14443')) ??
          (name == 'PhantomProxy' ? 15443 : 14443),
      secret: dotenv.maybeGet(secretKey) ?? '',
    );
  }
}

class ProxyConfig {
  const ProxyConfig({
    required this.name,
    required this.host,
    required this.port,
    required this.secret,
  });

  final String name;
  final String host;
  final int port;
  final String secret;

  bool get isConfigured => host.isNotEmpty && hasValidSecret;

  /// Проверка формата MTProto secret (см. td/mtproto/ProxySecret.cpp).
  bool get hasValidSecret {
    if (secret.isEmpty) {
      return false;
    }

    final decoded = _decodeSecret(secret);
    if (decoded == null || decoded.isEmpty) {
      return false;
    }

    if (decoded.length == 16) {
      return true;
    }
    if (decoded.length == 17 && decoded[0] == 0xDD) {
      return true;
    }
    if (decoded.length >= 18 && decoded[0] == 0xEE) {
      return true;
    }
    return false;
  }

  static List<int>? _decodeSecret(String encoded) {
    if (_isHex(encoded)) {
      return _hexDecode(encoded);
    }
    return null;
  }

  static bool _isHex(String value) {
    return RegExp(r'^[0-9a-fA-F]+$').hasMatch(value);
  }

  static List<int>? _hexDecode(String hex) {
    if (hex.length.isOdd) {
      return null;
    }
    final bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      final byte = int.tryParse(hex.substring(i, i + 2), radix: 16);
      if (byte == null) {
        return null;
      }
      bytes.add(byte);
    }
    return bytes;
  }
}

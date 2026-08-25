import '../../../models/wss_proxy_models.dart';

/// Переписывание URL WebSocket Telegram через WSS reverse proxy.
///
/// Алгоритм совместим с telegram-tt Proxy Hook и TG-WS-API:
/// `wss://venus.web.telegram.org/apiws`
/// → `wss://your-domain.ru/venus.web.telegram.org/apiws`
abstract final class WssUrlRewriter {
  static final RegExp _telegramHostPattern = RegExp(
    r'^wss://([a-z0-9.-]+\.(?:web\.)?telegram\.org)(/.*)?$',
    caseSensitive: false,
  );

  /// Нормализует базовый URL прокси до `wss://host` без trailing slash.
  static String? normalizeProxyBase(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    var value = trimmed;
    if (value.startsWith('https://')) {
      value = 'wss://${value.substring('https://'.length)}';
    } else if (value.startsWith('http://')) {
      value = 'ws://${value.substring('http://'.length)}';
    } else if (!value.startsWith('wss://') && !value.startsWith('ws://')) {
      value = 'wss://$value';
    }

    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  /// Возвращает переписанный URL или исходный, если прокси выключен/не применим.
  static String rewrite({
    required String originalUrl,
    required WssProxyConfig config,
  }) {
    if (!config.enabled || !config.isConfigured) {
      return originalUrl;
    }

    final proxyBase = normalizeProxyBase(config.url);
    if (proxyBase == null) {
      return originalUrl;
    }

    final match = _telegramHostPattern.firstMatch(originalUrl);
    if (match == null) {
      return originalUrl;
    }

    final host = match.group(1)!;
    final path = match.group(2) ?? '/apiws';
    return '$proxyBase/$host$path';
  }

  /// Проверяет, что URL относится к Telegram WebSocket endpoint.
  static bool isTelegramWebSocketUrl(String url) {
    return _telegramHostPattern.hasMatch(url);
  }
}

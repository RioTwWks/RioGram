import 'package:riogram/core/tdlib/web/wss_url_rewriter.dart';
import 'package:riogram/models/wss_proxy_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WssUrlRewriter', () {
    test('normalizeProxyBase accepts https and bare host', () {
      expect(
        WssUrlRewriter.normalizeProxyBase('https://proxy.example.ru/'),
        'wss://proxy.example.ru',
      );
      expect(
        WssUrlRewriter.normalizeProxyBase('proxy.example.ru'),
        'wss://proxy.example.ru',
      );
    });

    test('rewrite leaves url when proxy disabled', () {
      const original = 'wss://venus.web.telegram.org/apiws';
      expect(
        WssUrlRewriter.rewrite(
          originalUrl: original,
          config: const WssProxyConfig(),
        ),
        original,
      );
    });

    test('rewrite telegram dc url through proxy base', () {
      const config = WssProxyConfig(
        enabled: true,
        url: 'wss://riogram.example.ru',
      );
      expect(
        WssUrlRewriter.rewrite(
          originalUrl: 'wss://venus.web.telegram.org/apiws',
          config: config,
        ),
        'wss://riogram.example.ru/venus.web.telegram.org/apiws',
      );
    });

    test('rewrite kws relay host', () {
      const config = WssProxyConfig(
        enabled: true,
        url: 'https://edge.example.ru',
      );
      expect(
        WssUrlRewriter.rewrite(
          originalUrl: 'wss://kws1.web.telegram.org/apiws',
          config: config,
        ),
        'wss://edge.example.ru/kws1.web.telegram.org/apiws',
      );
    });

    test('isTelegramWebSocketUrl detects telegram hosts', () {
      expect(
        WssUrlRewriter.isTelegramWebSocketUrl(
          'wss://pluto.web.telegram.org/apiws',
        ),
        isTrue,
      );
      expect(
        WssUrlRewriter.isTelegramWebSocketUrl('wss://example.com/ws'),
        isFalse,
      );
    });
  });

  group('WssProxyConfig', () {
    test('roundtrip json', () {
      const config = WssProxyConfig(
        enabled: true,
        url: 'wss://proxy.test',
        autoReconnect: false,
        maxReconnectAttempts: 3,
      );
      final restored = WssProxyConfig.fromJson(config.toJson());
      expect(restored.enabled, config.enabled);
      expect(restored.url, config.url);
      expect(restored.autoReconnect, config.autoReconnect);
      expect(restored.maxReconnectAttempts, config.maxReconnectAttempts);
    });
  });
}

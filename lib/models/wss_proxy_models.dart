/// Конфигурация WSS-прокси для Web-платформы.
class WssProxyConfig {
  const WssProxyConfig({
    this.enabled = false,
    this.url = '',
    this.autoReconnect = true,
    this.maxReconnectAttempts = 5,
    this.reconnectDelayMs = 2000,
  });

  final bool enabled;
  final String url;
  final bool autoReconnect;
  final int maxReconnectAttempts;
  final int reconnectDelayMs;

  bool get isConfigured => url.trim().isNotEmpty;

  WssProxyConfig copyWith({
    bool? enabled,
    String? url,
    bool? autoReconnect,
    int? maxReconnectAttempts,
    int? reconnectDelayMs,
  }) {
    return WssProxyConfig(
      enabled: enabled ?? this.enabled,
      url: url ?? this.url,
      autoReconnect: autoReconnect ?? this.autoReconnect,
      maxReconnectAttempts: maxReconnectAttempts ?? this.maxReconnectAttempts,
      reconnectDelayMs: reconnectDelayMs ?? this.reconnectDelayMs,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'url': url,
    'autoReconnect': autoReconnect,
    'maxReconnectAttempts': maxReconnectAttempts,
    'reconnectDelayMs': reconnectDelayMs,
  };

  factory WssProxyConfig.fromJson(Map<String, dynamic> json) {
    return WssProxyConfig(
      enabled: json['enabled'] as bool? ?? false,
      url: json['url'] as String? ?? '',
      autoReconnect: json['autoReconnect'] as bool? ?? true,
      maxReconnectAttempts: json['maxReconnectAttempts'] as int? ?? 5,
      reconnectDelayMs: json['reconnectDelayMs'] as int? ?? 2000,
    );
  }
}

/// Статус WSS-транспорта (мониторинг из JS hook).
enum WssTransportState {
  idle,
  connecting,
  connected,
  reconnecting,
  failed,
}

class WssTransportStatus {
  const WssTransportStatus({
    required this.state,
    this.activeUrl,
    this.lastError,
    this.reconnectAttempt = 0,
  });

  final WssTransportState state;
  final String? activeUrl;
  final String? lastError;
  final int reconnectAttempt;

  bool get isHealthy =>
      state == WssTransportState.connected ||
      state == WssTransportState.idle ||
      state == WssTransportState.connecting;
}

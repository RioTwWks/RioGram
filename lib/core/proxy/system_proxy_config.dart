/// Системный HTTP/SOCKS-прокси, обнаруженный в настройках ОС.
class SystemProxyConfig {
  const SystemProxyConfig({
    required this.host,
    required this.port,
    required this.type,
    this.username = '',
    this.password = '',
  });

  final String host;
  final int port;
  final SystemProxyType type;
  final String username;
  final String password;

  bool get isConfigured => host.isNotEmpty && port > 0;

  SystemProxyConfig copyWith({
    String? host,
    int? port,
    SystemProxyType? type,
    String? username,
    String? password,
  }) {
    return SystemProxyConfig(
      host: host ?? this.host,
      port: port ?? this.port,
      type: type ?? this.type,
      username: username ?? this.username,
      password: password ?? this.password,
    );
  }

  /// Маркер в TDLib comment — транспортный прокси для доступа к MTProto edge.
  static const String transportComment = 'RioGram:Transport';
}

enum SystemProxyType { http, socks5 }

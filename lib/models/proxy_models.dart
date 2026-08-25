/// Тип пользовательского прокси (SOCKS5 / HTTP).
enum UserProxyType {
  socks5,
  http,
}

/// Пользовательский прокси, добавленный вручную.
class UserProxyConfig {
  const UserProxyConfig({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.type,
    this.username = '',
    this.password = '',
    this.httpOnly = false,
  });

  final String id;
  final String name;
  final String host;
  final int port;
  final UserProxyType type;
  final String username;
  final String password;
  final bool httpOnly;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'host': host,
      'port': port,
      'type': type.name,
      'username': username,
      'password': password,
      'httpOnly': httpOnly,
    };
  }

  static UserProxyConfig? fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String?;
    final type = UserProxyType.values.cast<UserProxyType?>().firstWhere(
          (item) => item?.name == typeName,
          orElse: () => null,
        );
    if (type == null) {
      return null;
    }
    final host = json['host'] as String? ?? '';
    if (host.isEmpty) {
      return null;
    }
    return UserProxyConfig(
      id: json['id'] as String? ?? host,
      name: json['name'] as String? ?? host,
      host: host,
      port: json['port'] as int? ?? 1080,
      type: type,
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      httpOnly: json['httpOnly'] as bool? ?? false,
    );
  }
}

/// Состояние проверки прокси.
enum ProxyHealth {
  unknown,
  checking,
  ok,
  failed,
}

/// Запись о прокси-сервере в TDLib.
class ProxyEntry {
  const ProxyEntry({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    this.isActive = false,
    this.health = ProxyHealth.unknown,
    this.lastPingMs,
  });

  final int id;
  final String name;
  final String host;
  final int port;
  final bool isActive;
  final ProxyHealth health;
  final int? lastPingMs;

  String get displayAddress => '$host:$port';

  ProxyEntry copyWith({
    bool? isActive,
    ProxyHealth? health,
    int? lastPingMs,
  }) {
    return ProxyEntry(
      id: id,
      name: name,
      host: host,
      port: port,
      isActive: isActive ?? this.isActive,
      health: health ?? this.health,
      lastPingMs: lastPingMs ?? this.lastPingMs,
    );
  }
}

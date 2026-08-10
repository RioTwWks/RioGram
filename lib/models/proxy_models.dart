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

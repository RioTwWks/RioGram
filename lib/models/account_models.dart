/// Сохранённый аккаунт RioGram (отдельная директория TDLib).
class AccountSession {
  const AccountSession({
    required this.id,
    required this.userId,
    this.phoneNumber = '',
    this.displayName = '',
    this.lastActiveAt,
  });

  final String id;
  final int userId;
  final String phoneNumber;
  final String displayName;
  final DateTime? lastActiveAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'phone_number': phoneNumber,
        'display_name': displayName,
        'last_active_at': lastActiveAt?.toIso8601String(),
      };

  factory AccountSession.fromJson(Map<String, dynamic> json) {
    final lastActiveRaw = json['last_active_at'] as String?;
    return AccountSession(
      id: json['id'] as String? ?? '${json['user_id']}',
      userId: json['user_id'] as int? ?? 0,
      phoneNumber: json['phone_number'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      lastActiveAt:
          lastActiveRaw == null ? null : DateTime.tryParse(lastActiveRaw),
    );
  }

  AccountSession copyWith({
    String? phoneNumber,
    String? displayName,
    DateTime? lastActiveAt,
  }) {
    return AccountSession(
      id: id,
      userId: userId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      displayName: displayName ?? this.displayName,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }
}

/// Политика прокси для мультиаккаунта.
enum AccountProxyPolicy {
  /// MTProto/SOCKS/HTTP из `.env` — общие для всех аккаунтов.
  sharedEnv,

  /// Пользовательские прокси из настроек — per-account (ключ = accountId).
  perAccountUserProxies,
}

extension AccountProxyPolicyX on AccountProxyPolicy {
  String get label => switch (this) {
        AccountProxyPolicy.sharedEnv =>
          'MTProto из .env — общий для всех аккаунтов',
        AccountProxyPolicy.perAccountUserProxies =>
          'Пользовательские SOCKS5/HTTP — отдельно на аккаунт',
      };
}

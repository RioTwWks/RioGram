import '../core/tdlib/tdlib_json.dart';

/// Активная сессия Telegram на другом устройстве.
class ActiveSessionModel {
  const ActiveSessionModel({
    required this.id,
    this.isCurrent = false,
    this.isUnconfirmed = false,
    this.deviceModel = '',
    this.platform = '',
    this.applicationName = '',
    this.applicationVersion = '',
    this.ipAddress = '',
    this.location = '',
    this.logInDate,
    this.lastActiveDate,
  });

  final int id;
  final bool isCurrent;
  final bool isUnconfirmed;
  final String deviceModel;
  final String platform;
  final String applicationName;
  final String applicationVersion;
  final String ipAddress;
  final String location;
  final DateTime? logInDate;
  final DateTime? lastActiveDate;

  String get deviceLabel {
    final parts = <String>[
      if (applicationName.isNotEmpty) applicationName,
      if (deviceModel.isNotEmpty) deviceModel,
      if (platform.isNotEmpty) platform,
    ];
    return parts.isNotEmpty ? parts.join(' • ') : 'Неизвестное устройство';
  }

  factory ActiveSessionModel.fromTdlib(Map<String, dynamic> json) {
    if (json['@type'] != 'session') {
      throw ArgumentError('Expected session, got ${json['@type']}');
    }
    return ActiveSessionModel(
      id: tdIntOr(json['id']),
      isCurrent: json['is_current'] as bool? ?? false,
      isUnconfirmed: json['is_unconfirmed'] as bool? ?? false,
      deviceModel: json['device_model'] as String? ?? '',
      platform: json['platform'] as String? ?? '',
      applicationName: json['application_name'] as String? ?? '',
      applicationVersion: json['application_version'] as String? ?? '',
      ipAddress: json['ip_address'] as String? ?? '',
      location: json['location'] as String? ?? '',
      logInDate: _dateFromSeconds(json['log_in_date']),
      lastActiveDate: _dateFromSeconds(json['last_active_date']),
    );
  }

  static DateTime? _dateFromSeconds(dynamic value) {
    final seconds = tdInt(value);
    if (seconds == null || seconds == 0) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }
}

/// Список активных сессий пользователя.
class SessionsListModel {
  const SessionsListModel({
    required this.sessions,
    this.inactiveSessionTtlDays = 180,
  });

  final List<ActiveSessionModel> sessions;
  final int inactiveSessionTtlDays;

  factory SessionsListModel.fromTdlib(Map<String, dynamic>? json) {
    if (json == null || json['@type'] != 'sessions') {
      return const SessionsListModel(sessions: []);
    }
    final raw = json['sessions'] as List<dynamic>? ?? const [];
    return SessionsListModel(
      sessions: raw
          .whereType<Map<String, dynamic>>()
          .map(ActiveSessionModel.fromTdlib)
          .toList(growable: false),
      inactiveSessionTtlDays: tdIntOr(json['inactive_session_ttl_days'], 180),
    );
  }
}

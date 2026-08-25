/// Режим отправки сетевой телеметрии TDLib.
enum TelemetryMode {
  /// Телеметрия отключена (по умолчанию).
  disabled,

  /// Телеметрия разрешена пользователем.
  enabled,
}

/// Локально разблокируемые «премиум»-возможности (§7.4).
enum LocalPremiumFeature {
  /// Увеличенный лимит размера загружаемых файлов (4 ГБ вместо 2 ГБ).
  uploadFileSize,

  /// Повышенные лимиты (закреплённые чаты, папки, длина сообщений).
  increasedLimits,

  /// Ускоренная загрузка медиа (клиентская подсказка; сервер решает сам).
  fasterDownloads,
}

/// Лимит Telegram Premium из TDLib `getPremiumLimit`.
class PremiumLimitInfo {
  const PremiumLimitInfo({
    required this.defaultValue,
    required this.premiumValue,
  });

  final int defaultValue;
  final int premiumValue;

  int valueFor({required bool usePremium}) =>
      usePremium ? premiumValue : defaultValue;
}

/// Константы лимитов загрузки файлов Telegram.
abstract final class TelegramUploadLimits {
  static const int freeMaxBytes = 2 * 1024 * 1024 * 1024;
  static const int premiumMaxBytes = 4 * 1024 * 1024 * 1024;
}

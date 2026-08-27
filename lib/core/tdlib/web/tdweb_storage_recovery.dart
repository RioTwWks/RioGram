/// Определяет повреждение локальной БД TDLib (web IndexedDB / binlog).
bool isTdlibDatabaseCorruptionMessage(String? message) {
  if (message == null || message.isEmpty) {
    return false;
  }
  final lower = message.toLowerCase();
  return lower.contains('crc mismatch') ||
      lower.contains('failed to validate binlog') ||
      lower.contains('binlog.cpp') ||
      (lower.contains('binlog') && lower.contains('failed'));
}

const String tdlibDatabaseCorruptionUserMessage =
    'Локальная база TDLib в браузере повреждена. '
    'Сбросьте локальные данные и войдите снова — переписка на сервере Telegram сохранится.';

String formatAuthErrorMessage(String? raw) {
  if (isTdlibDatabaseCorruptionMessage(raw)) {
    return tdlibDatabaseCorruptionUserMessage;
  }
  return raw ?? 'Ошибка инициализации';
}

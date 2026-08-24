import 'package:flutter/foundation.dart';

/// Сколько раз логировать успешную конвертацию String→int (антиспам).
const int _kMaxStringCoercionLogs = 20;
int _stringCoercionLogs = 0;

/// Безопасное чтение целых чисел из TDLib JSON.
///
/// TDLib часто сериализует int64 как [String], чтобы не терять точность.
/// Прямой каст `as int?` в этом случае падает.
int? tdInt(
  dynamic value, {
  String? field,
  String? context,
}) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed == null) {
      _logParseFailure(value, field: field, context: context);
    } else {
      _logStringCoercion(parsed, field: field, context: context);
    }
    return parsed;
  }
  _logUnexpectedType(value, field: field, context: context);
  return null;
}

/// Как [tdInt], но с запасным значением.
int tdIntOr(dynamic value, [int fallback = 0]) {
  return tdInt(value) ?? fallback;
}

void tdlibDebugLog(String message) {
  if (kDebugMode) {
    debugPrint('[Tdlib] $message');
  }
}

void _logStringCoercion(
  int parsed, {
  String? field,
  String? context,
}) {
  if (!kDebugMode || _stringCoercionLogs >= _kMaxStringCoercionLogs) {
    return;
  }
  _stringCoercionLogs++;
  final parts = <String>[
    'coerced String→int',
    if (field != null) 'field=$field',
    if (context != null) 'at $context',
    'value=$parsed',
    '($_stringCoercionLogs/$_kMaxStringCoercionLogs)',
  ];
  debugPrint('[TdlibJson] ${parts.join(' ')}');
}

void _logParseFailure(
  dynamic value, {
  String? field,
  String? context,
}) {
  if (!kDebugMode) {
    return;
  }
  final parts = <String>[
    'cannot parse int',
    if (field != null) 'field=$field',
    if (context != null) 'at $context',
    'value="$value"',
  ];
  debugPrint('[TdlibJson] ${parts.join(' ')}');
}

void _logUnexpectedType(
  dynamic value, {
  String? field,
  String? context,
}) {
  if (!kDebugMode) {
    return;
  }
  final parts = <String>[
    'unexpected ${value.runtimeType}',
    if (field != null) 'field=$field',
    if (context != null) 'at $context',
    'value=$value',
  ];
  debugPrint('[TdlibJson] ${parts.join(' ')}');
}

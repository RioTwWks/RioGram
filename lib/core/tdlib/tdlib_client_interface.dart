/// Общие типы TDLib-клиента (native и web).
typedef TdlibUpdateCallback = void Function(Map<String, dynamic> update);

class TdlibException implements Exception {
  TdlibException(this.message);

  final String message;

  @override
  String toString() => 'TdlibException: $message';
}

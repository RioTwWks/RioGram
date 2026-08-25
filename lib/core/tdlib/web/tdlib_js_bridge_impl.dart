/// Заглушка JS-bridge для native-платформ.
abstract final class JsBridgeImpl {
  static bool hasGlobal(String name) => false;

  static dynamic callDynamic(String objectName, String method, [List<dynamic>? args]) =>
      null;

  static bool callBool(String objectName, String method, [List<dynamic>? args]) => false;

  static String? callString(String objectName, String method, [List<dynamic>? args]) =>
      null;

  static void callVoid(String objectName, String method, [List<dynamic>? args]) {}

  static void setCallback(
    String objectName,
    String method,
    void Function(dynamic) callback,
  ) {}
}

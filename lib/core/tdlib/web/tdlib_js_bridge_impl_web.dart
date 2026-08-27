// Web-only JS interop; stub used on native targets during analysis.
// ignore_for_file: avoid_web_libraries_in_flutter, uri_does_not_exist

import 'dart:js_util' as js_util;

/// Web-реализация JS-bridge через dart:js_util.
abstract final class JsBridgeImpl {
  static bool hasGlobal(String name) {
    return js_util.hasProperty(js_util.globalThis, name);
  }

  static dynamic callDynamic(String objectName, String method, [List<dynamic>? args]) {
    final object = js_util.getProperty(js_util.globalThis, objectName);
    if (object == null) {
      return null;
    }
    return js_util.callMethod(
      object,
      method,
      (args ?? const []).map(_jsifyArg).toList(growable: false),
    );
  }

  static bool callBool(String objectName, String method, [List<dynamic>? args]) {
    return callDynamic(objectName, method, args) == true;
  }

  static String? callString(String objectName, String method, [List<dynamic>? args]) {
    final result = callDynamic(objectName, method, args);
    return result?.toString();
  }

  static void callVoid(String objectName, String method, [List<dynamic>? args]) {
    callDynamic(objectName, method, args);
  }

  static Future<dynamic> callPromise(
    String objectName,
    String method, [
    List<dynamic>? args,
  ]) async {
    final result = callDynamic(objectName, method, args);
    if (result != null && js_util.hasProperty(result, 'then')) {
      return js_util.promiseToFuture(result as Object);
    }
    return result;
  }

  /// Преобразует JSObject из JS-колбэков/promise в Dart [Map].
  static Map<String, dynamic>? toDartMap(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    final dartified = js_util.dartify(value);
    if (dartified == null) {
      return null;
    }
    return Map<String, dynamic>.from(dartified as Map);
  }

  static void setCallback(
    String objectName,
    String method,
    void Function(dynamic) callback,
  ) {
    final object = js_util.getProperty(js_util.globalThis, objectName);
    if (object == null) {
      return;
    }
    js_util.callMethod(object, method, [js_util.allowInterop(callback)]);
  }

  static dynamic _jsifyArg(dynamic value) {
    if (value is Map) {
      return js_util.jsify(value);
    }
    if (value is Function) {
      return js_util.allowInterop(value);
    }
    return value;
  }
}

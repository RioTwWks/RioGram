import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// FFI-привязки к libtdjson (TDLib JSON interface).
class TdlibBindings {
  TdlibBindings._(this._lib);

  final DynamicLibrary _lib;
  late final Pointer<Void> Function() _create;
  late final void Function(Pointer<Void>, Pointer<Utf8>) _send;
  late final Pointer<Utf8> Function(Pointer<Void>, double) _receive;
  late final void Function(Pointer<Void>) _destroy;
  late final Pointer<Utf8> Function(Pointer<Utf8>) _execute;

  static TdlibBindings? load() {
    try {
      final lib = _openLibrary();
      return TdlibBindings._(lib);
    } catch (_) {
      return null;
    }
  }

  static DynamicLibrary _openLibrary() {
    if (Platform.isLinux) {
      return DynamicLibrary.open('libtdjson.so');
    }
    if (Platform.isWindows) {
      return DynamicLibrary.open('tdjson.dll');
    }
    if (Platform.isMacOS) {
      return DynamicLibrary.open('libtdjson.dylib');
    }
    if (Platform.isAndroid) {
      return DynamicLibrary.open('libtdjson.so');
    }
    if (Platform.isIOS) {
      return DynamicLibrary.process();
    }
    throw UnsupportedError('Платформа ${Platform.operatingSystem} не поддерживается');
  }

  void bind() {
    _create = _lib
        .lookup<NativeFunction<Pointer<Void> Function()>>('td_json_client_create')
        .asFunction();
    _send = _lib
        .lookup<NativeFunction<Void Function(Pointer<Void>, Pointer<Utf8>)>>(
          'td_json_client_send',
        )
        .asFunction();
    _receive = _lib
        .lookup<NativeFunction<Pointer<Utf8> Function(Pointer<Void>, Double)>>(
          'td_json_client_receive',
        )
        .asFunction();
    _destroy = _lib
        .lookup<NativeFunction<Void Function(Pointer<Void>)>>('td_json_client_destroy')
        .asFunction();
    _execute = _lib
        .lookup<NativeFunction<Pointer<Utf8> Function(Pointer<Utf8>)>>(
          'td_json_client_execute',
        )
        .asFunction();
  }

  Pointer<Void> createClient() => _create();

  void send(Pointer<Void> client, String request) {
    final pointer = request.toNativeUtf8();
    try {
      _send(client, pointer);
    } finally {
      malloc.free(pointer);
    }
  }

  String? receive(Pointer<Void> client, {double timeout = 1.0}) {
    final pointer = _receive(client, timeout);
    if (pointer == nullptr) {
      return null;
    }
    try {
      return pointer.toDartString();
    } finally {
      malloc.free(pointer);
    }
  }

  void destroy(Pointer<Void> client) => _destroy(client);

  String? execute(String request) {
    final pointer = request.toNativeUtf8();
    try {
      final result = _execute(pointer);
      if (result == nullptr) {
        return null;
      }
      return result.toDartString();
    } finally {
      malloc.free(pointer);
    }
  }
}

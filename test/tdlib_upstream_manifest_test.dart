import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TDLib upstream manifest', () {
    late Map<String, dynamic> manifest;
    late String cmakeVersion;

    setUp(() {
      final manifestFile = File('td/upstream-base.json');
      expect(manifestFile.existsSync(), isTrue, reason: 'td/upstream-base.json must exist');
      manifest = jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;

      final cmake = File('td/CMakeLists.txt').readAsStringSync();
      final match = RegExp(r'project\(TDLib VERSION ([0-9.]+)').firstMatch(cmake);
      expect(match, isNotNull, reason: 'td/CMakeLists.txt must declare TDLib VERSION');
      cmakeVersion = match!.group(1)!;
    });

    test('manifest contains required fields', () {
      for (final key in ['repository', 'version', 'commit', 'merge_doc', 'patches_doc']) {
        expect(manifest[key], isNotNull, reason: 'missing $key');
        expect(manifest[key], isA<String>());
        expect((manifest[key] as String).isNotEmpty, isTrue);
      }
      expect(manifest['commit'], matches(RegExp(r'^[0-9a-f]{40}$')));
    });

    test('vendor CMake version matches pinned upstream base', () {
      expect(manifest['version'], cmakeVersion);
    });

    test('merge and patches docs exist', () {
      expect(File(manifest['merge_doc'] as String).existsSync(), isTrue);
      expect(File(manifest['patches_doc'] as String).existsSync(), isTrue);
    });

    test('DPI_BYPASS sources are present', () {
      for (final path in [
        'td/td/mtproto/dpi_bypass/DpiBypass.h',
        'td/td/mtproto/dpi_bypass/DpiBypass.cpp',
        'td/td/mtproto/TlsInit.cpp',
        'td/td/mtproto/TcpTransport.cpp',
      ]) {
        expect(File(path).existsSync(), isTrue, reason: path);
        final content = File(path).readAsStringSync();
        expect(content.contains('DPI_BYPASS'), isTrue, reason: '$path must contain DPI_BYPASS markers');
      }
    });
  });
}

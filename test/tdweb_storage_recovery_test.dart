import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/core/tdlib/web/tdweb_storage_recovery.dart';

void main() {
  group('isTdlibDatabaseCorruptionMessage', () {
    test('detects CRC mismatch binlog error', () {
      expect(
        isTdlibDatabaseCorruptionMessage(
          'Failed to validate binlog event CRC mismatch [actual:0x3732e2f6]',
        ),
        isTrue,
      );
    });

    test('ignores unrelated errors', () {
      expect(
        isTdlibDatabaseCorruptionMessage('Network is unreachable'),
        isFalse,
      );
    });

    test('formats user-friendly message', () {
      expect(
        formatAuthErrorMessage('CRC mismatch in Binlog.cpp'),
        tdlibDatabaseCorruptionUserMessage,
      );
    });

    test('offers reset after message is formatted', () {
      expect(
        shouldOfferWebStorageReset(tdlibDatabaseCorruptionUserMessage),
        isTrue,
      );
      expect(
        shouldOfferWebStorageReset(
          tdlibDatabaseCorruptionUserMessage,
          flagged: true,
        ),
        isTrue,
      );
    });
  });
}

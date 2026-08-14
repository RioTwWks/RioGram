import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/models/cache_models.dart';
import 'package:riogram/models/chat_models.dart';

void main() {
  group('AutoDownloadSettingsModel', () {
    test('defaults для Wi‑Fi и roaming', () {
      final wifi = AutoDownloadSettingsModel.defaults(DownloadNetworkType.wifi);
      final roaming =
          AutoDownloadSettingsModel.defaults(DownloadNetworkType.roaming);

      expect(wifi.isEnabled, isTrue);
      expect(roaming.isEnabled, isFalse);
      expect(wifi.maxPhotoBytes, AutoDownloadSettingsModel.mb10);
    });

    test('toTdlib / fromTdlib сохраняет лимиты', () {
      const settings = AutoDownloadSettingsModel(
        networkType: DownloadNetworkType.mobile,
        isEnabled: true,
        maxPhotoBytes: AutoDownloadSettingsModel.mb1,
        maxVideoBytes: 2 * AutoDownloadSettingsModel.mb1,
        maxOtherBytes: 3 * AutoDownloadSettingsModel.mb1,
      );
      final parsed = AutoDownloadSettingsModel.fromTdlib(
        settings.toTdlib(),
        DownloadNetworkType.mobile,
      );
      expect(parsed.maxPhotoBytes, settings.maxPhotoBytes);
      expect(parsed.maxVideoBytes, settings.maxVideoBytes);
    });

    test('allowsMessageDownload учитывает размер и тип', () {
      const settings = AutoDownloadSettingsModel(
        networkType: DownloadNetworkType.wifi,
        isEnabled: true,
        maxPhotoBytes: AutoDownloadSettingsModel.mb1,
        maxVideoBytes: AutoDownloadSettingsModel.mb1,
        maxOtherBytes: AutoDownloadSettingsModel.mb1,
      );

      expect(
        settings.allowsMessageDownload(
          kind: MessageKind.photo,
          fileSizeBytes: AutoDownloadSettingsModel.mb1 * 2,
          isOutgoing: false,
        ),
        isFalse,
      );
      expect(
        settings.allowsMessageDownload(
          kind: MessageKind.photo,
          fileSizeBytes: AutoDownloadSettingsModel.mb1 ~/ 2,
          isOutgoing: false,
        ),
        isTrue,
      );
      expect(
        settings.allowsMessageDownload(
          kind: MessageKind.document,
          fileSizeBytes: 999999999,
          isOutgoing: true,
        ),
        isTrue,
      );
    });
  });

  group('StorageStatisticsModel', () {
    test('formatBytes и fromTdlib', () {
      final stats = StorageStatisticsModel.fromTdlib({
        'size': 5 * 1024 * 1024,
        'photo_size': 1024,
        'video_size': 2048,
      });
      expect(stats.totalSize, 5 * 1024 * 1024);
      expect(StorageStatisticsModel.formatBytes(1024), '1.0 KB');
    });
  });

  group('MessageContent fileSizeBytes', () {
    test('парсит размер документа', () {
      final content = MessageContent.fromTdlib({
        '@type': 'messageDocument',
        'document': {
          'file_name': 'a.pdf',
          'document': {'id': 1, 'expected_size': 4096},
        },
      });
      expect(content.fileSizeBytes, 4096);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/models/audio_models.dart';
import 'package:riogram/models/chat_models.dart';

void main() {
  group('FileTransferState', () {
    test('парсит загрузку', () {
      final state = FileTransferState.fromTdlibFile({
        'id': 1,
        'expected_size': 1000,
        'local': {
          'is_downloading_active': true,
          'is_downloading_completed': false,
          'downloaded_prefix_size': 250,
        },
        'remote': {'size': 1000},
      });

      expect(state.isUpload, isFalse);
      expect(state.isActive, isTrue);
      expect(state.progressPercent, 25);
    });

    test('парсит отправку', () {
      final state = FileTransferState.fromTdlibFile({
        'id': 2,
        'expected_size': 2000,
        'local': {
          'is_uploading_active': true,
          'is_uploading_completed': false,
          'uploaded_size': 1000,
        },
        'remote': {'size': 2000, 'uploaded_size': 1000},
      });

      expect(state.isUpload, isTrue);
      expect(state.progressPercent, 50);
    });
  });

  group('VoiceNoteInfo', () {
    test('нормализует waveform', () {
      const info = VoiceNoteInfo(
        durationSeconds: 12,
        waveform: [0, 15, 31],
      );
      expect(info.normalizedWaveform, hasLength(3));
      expect(info.durationLabel, '0:12');
    });
  });

  group('MessageContent audio/voice', () {
    test('парсит messageVoiceNote', () {
      final content = MessageContent.fromTdlib({
        '@type': 'messageVoiceNote',
        'voice_note': {
          'duration': 7,
          'waveform': [1, 10, 20, 31],
          'voice': {'id': 55},
        },
      });

      expect(content.kind, MessageKind.voice);
      expect(content.voiceInfo?.durationSeconds, 7);
      expect(
        MessageContent.parseMediaFileId({
          '@type': 'messageVoiceNote',
          'voice_note': {'voice': {'id': 55}},
        }),
        55,
      );
    });

    test('парсит messageAudio с обложкой', () {
      final content = MessageContent.fromTdlib({
        '@type': 'messageAudio',
        'audio': {
          'duration': 180,
          'title': 'Track',
          'performer': 'Artist',
          'file_name': 'track.mp3',
          'audio': {'id': 66},
          'album_cover_thumbnail': {
            'file': {'id': 67},
          },
        },
      });

      expect(content.kind, MessageKind.audio);
      expect(content.audioInfo?.displayTitle, 'Track');
      expect(content.audioInfo?.displayArtist, 'Artist');
      expect(MessageContent.parseCoverFileId({
        '@type': 'messageAudio',
        'audio': {
          'album_cover_thumbnail': {'file': {'id': 67}},
        },
      }), 67);
    });
  });
}

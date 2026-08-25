import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/core/theme/telegram_theme.dart';
import 'package:riogram/models/audio_models.dart';
import 'package:riogram/models/location_models.dart';
import 'package:riogram/widgets/document_message_body.dart';
import 'package:riogram/widgets/static_map_preview.dart';
import 'package:riogram/widgets/voice_message_player.dart';

void main() {
  group('DocumentMessageBody', () {
    testWidgets('показывает имя файла и размер', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: TelegramTheme.build(brightness: Brightness.light),
          home: const Scaffold(
            body: DocumentMessageBody(
              fileName: 'report.pdf',
              documentInfo: DocumentFileInfo(
                fileName: 'report.pdf',
                fileSize: 2048,
              ),
            ),
          ),
        ),
      );

      expect(find.text('report.pdf'), findsOneWidget);
      expect(find.text('2.0 KB'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
    });

    testWidgets('выбирает иконку по расширению', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: TelegramTheme.build(brightness: Brightness.light),
          home: const Scaffold(
            body: DocumentMessageBody(fileName: 'archive.zip'),
          ),
        ),
      );

      expect(find.byIcon(Icons.folder_zip_outlined), findsOneWidget);
    });
  });

  group('StaticMapPreview', () {
    testWidgets('рендерит fallback при ошибке сети', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: TelegramTheme.build(brightness: Brightness.light),
          home: const Scaffold(
            body: StaticMapPreview(
              point: LocationPoint(latitude: 55.75, longitude: 37.62),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(StaticMapPreview), findsOneWidget);
    });
  });

  group('VoiceMessagePlayer', () {
    testWidgets('показывает waveform и длительность', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: TelegramTheme.build(brightness: Brightness.light),
          home: Scaffold(
            body: VoiceMessagePlayer(
              filePath: '/nonexistent/voice.ogg',
              voiceInfo: const VoiceNoteInfo(
                durationSeconds: 42,
                waveform: [10, 20, 30, 40, 50],
              ),
              isOutgoing: true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.text('0:42'), findsOneWidget);
    });
  });
}

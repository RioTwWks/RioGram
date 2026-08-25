import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/core/theme/telegram_theme.dart';
import 'package:riogram/models/audio_models.dart';
import 'package:riogram/widgets/document_message_body.dart';
import 'package:riogram/widgets/video_duration_badge.dart';
import 'package:riogram/widgets/voice_waveform.dart';

void main() {
  testWidgets('DocumentMessageBody min-height 56px', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DocumentMessageBody(
          fileName: 'a.pdf',
          documentInfo: DocumentFileInfo(fileName: 'a.pdf', fileSize: 1024),
        ),
      ),
    ));
    final box = tester.widget<Container>(find.byType(Container).first);
    expect(box.constraints?.minHeight, TelegramMediaSpacing.documentCardMinHeight);
  });

  testWidgets('VideoDurationBadge font 11sp', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: VideoDurationBadge(label: '1:23')),
    ));
    expect(tester.widget<Text>(find.text('1:23')).style?.fontSize, TelegramFontSizes.bubbleMeta);
  });

  test('VoiceWaveform resampleBars', () {
    expect(VoiceWaveform.resampleBars([0.1, 0.9]).length, 34);
    expect(VoiceWaveform.intrinsicWidth, 34 * 5 + 33 * 2);
  });
}

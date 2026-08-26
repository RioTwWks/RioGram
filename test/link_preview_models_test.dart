import 'package:flutter_test/flutter_test.dart';
import 'package:riogram/models/formatted_text.dart';
import 'package:riogram/models/link_preview_models.dart';

void main() {
  group('LinkPreviewInfo', () {
    test('fromTdlib parses title and domain', () {
      final preview = LinkPreviewInfo.fromTdlib({
        'url': 'https://example.com/page',
        'display_url': 'example.com/page',
        'site_name': 'Example',
        'title': 'Example page',
        'description': {'@type': 'formattedText', 'text': 'Desc', 'entities': []},
        'type': {'@type': 'linkPreviewTypeArticle'},
      });

      expect(preview.url, 'https://example.com/page');
      expect(preview.siteName, 'Example');
      expect(preview.title, 'Example page');
      expect(preview.description, 'Desc');
      expect(preview.domainLabel, 'example.com');
    });

    test('fromFormattedText extracts first URL entity', () {
      const formatted = FormattedText(
        text: 'See https://dart.dev today',
        entities: [
          TextEntity(
            offset: 4,
            length: 16,
            kind: TextEntityKind.url,
          ),
        ],
      );

      final preview = LinkPreviewInfo.fromFormattedText(formatted);
      expect(preview?.url, 'https://dart.dev');
      expect(preview?.domainLabel, 'dart.dev');
    });
  });
}

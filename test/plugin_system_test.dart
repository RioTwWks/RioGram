import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:riogram/core/plugins/builtin/reading_time_plugin.dart';
import 'package:riogram/core/plugins/builtin/signature_plugin.dart';
import 'package:riogram/core/plugins/plugin_manager.dart';
import 'package:riogram/models/plugin_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  group('PluginManager', () {
    test('signature plugin appends outgoing text when enabled', () async {
      final manager = PluginManager();
      await manager.setPluginEnabled(SignaturePlugin.pluginId, true);
      await manager.setPluginConfig(
        SignaturePlugin.pluginId,
        {'signature': '— RioGram'},
      );

      final result = manager.transformOutgoingText(
        context: const PluginMessageContext(
          chatId: 1,
          messageId: 0,
          isOutgoing: true,
        ),
        text: 'Привет',
      );

      expect(result, 'Привет\n\n— RioGram');
    });

    test('reading time plugin adds footer for long text', () async {
      final manager = PluginManager();
      await manager.setPluginEnabled(ReadingTimePlugin.pluginId, true);

      final longText = List.filled(150, 'word').join(' ');
      final result = manager.transformDisplayText(
        context: const PluginMessageContext(
          chatId: 1,
          messageId: 42,
          isOutgoing: false,
        ),
        text: longText,
      );

      expect(result, contains('мин чтения'));
    });

    test('disabled plugins do not transform text', () async {
      final manager = PluginManager();
      final result = manager.transformOutgoingText(
        context: const PluginMessageContext(
          chatId: 1,
          messageId: 0,
          isOutgoing: true,
        ),
        text: 'test',
      );
      expect(result, 'test');
    });
  });

  group('PluginManifest', () {
    test('roundtrip json', () {
      const manifest = PluginManifest(
        id: 'com.test.plugin',
        name: 'Test',
        version: '1.0.0',
        description: 'desc',
        author: 'author',
        capabilities: [PluginCapability.messageDisplayTransform],
      );
      final restored = PluginManifest.fromJson(manifest.toJson());
      expect(restored.id, manifest.id);
      expect(restored.capabilities, manifest.capabilities);
    });
  });
}

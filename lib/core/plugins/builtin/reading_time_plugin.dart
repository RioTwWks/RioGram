import '../../../models/plugin_models.dart';
import '../plugin_api.dart';

/// Добавляет оценку времени чтения к длинным сообщениям (демо display-hook).
final class ReadingTimePlugin implements RioGramPlugin {
  const ReadingTimePlugin();

  static const String pluginId = 'riogram.builtin.reading_time';

  @override
  PluginManifest get manifest => const PluginManifest(
        id: pluginId,
        name: 'Время чтения',
        version: '1.0.0',
        description:
            'Показывает примерное время чтения длинных текстовых сообщений.',
        author: 'RioGram',
        capabilities: [PluginCapability.messageDisplayTransform],
      );

  @override
  bool supports(PluginCapability capability) {
    return capability == PluginCapability.messageDisplayTransform;
  }

  @override
  String? transformMessageDisplay(
    PluginMessageContext context,
    String text,
    Map<String, String> config,
  ) {
    final minWords = int.tryParse(config['min_words'] ?? '') ?? 120;
    final words = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.length < minWords) {
      return null;
    }
    final minutes = (words.length / 200).ceil().clamp(1, 99);
    return '$text\n\n· ~$minutes мин чтения';
  }
}

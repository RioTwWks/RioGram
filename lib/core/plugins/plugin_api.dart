import '../../models/plugin_models.dart';

/// Контракт community-плагина RioGram.
abstract interface class RioGramPlugin {
  PluginManifest get manifest;

  bool supports(PluginCapability capability);

  /// Трансформация текста для отображения в UI. `null` — без изменений.
  String? transformMessageDisplay(
    PluginMessageContext context,
    String text,
    Map<String, String> config,
  ) {
    return null;
  }

  /// Трансформация исходящего текста перед отправкой. `null` — без изменений.
  String? transformOutgoingMessage(
    PluginMessageContext context,
    String text,
    Map<String, String> config,
  ) {
    return null;
  }
}

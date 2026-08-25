import '../../../models/plugin_models.dart';
import '../plugin_api.dart';

/// Добавляет подпись к исходящим сообщениям.
final class SignaturePlugin implements RioGramPlugin {
  const SignaturePlugin();

  static const String pluginId = 'riogram.builtin.signature';

  @override
  PluginManifest get manifest => const PluginManifest(
        id: pluginId,
        name: 'Подпись сообщений',
        version: '1.0.0',
        description: 'Добавляет настраиваемую подпись к исходящим текстам.',
        author: 'RioGram',
        capabilities: [PluginCapability.outgoingMessageTransform],
      );

  @override
  bool supports(PluginCapability capability) {
    return capability == PluginCapability.outgoingMessageTransform;
  }

  @override
  String? transformMessageDisplay(
    PluginMessageContext context,
    String text,
    Map<String, String> config,
  ) {
    return null;
  }

  @override
  String? transformOutgoingMessage(
    PluginMessageContext context,
    String text,
    Map<String, String> config,
  ) {
    final signature = (config['signature'] ?? '').trim();
    if (signature.isEmpty || !context.isOutgoing) {
      return null;
    }
    if (text.endsWith(signature)) {
      return null;
    }
    return '$text\n\n$signature';
  }
}

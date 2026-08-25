import 'plugin_api.dart';
import 'builtin/reading_time_plugin.dart';
import 'builtin/signature_plugin.dart';

/// Реестр встроенных и зарегистрированных плагинов.
final class PluginRegistry {
  PluginRegistry._();

  static final List<RioGramPlugin> _plugins = [
    const ReadingTimePlugin(),
    const SignaturePlugin(),
  ];

  static List<RioGramPlugin> get all => List.unmodifiable(_plugins);

  static void register(RioGramPlugin plugin) {
    if (_plugins.any((item) => item.manifest.id == plugin.manifest.id)) {
      return;
    }
    _plugins.add(plugin);
  }
}

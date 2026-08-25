import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/formatted_text.dart';
import '../../models/plugin_models.dart';
import 'plugin_api.dart';
import 'plugin_preferences.dart';
import 'plugin_registry.dart';

/// Менеджер экосистемы плагинов (§7.6).
class PluginManager extends ChangeNotifier {
  final Map<String, PluginUserState> _states = {};

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final storage = PluginPreferences(prefs);
    _states
      ..clear()
      ..addAll(storage.loadStates());
    notifyListeners();
  }

  List<PluginDescriptor> get descriptors {
    return PluginRegistry.all.map((plugin) {
      final manifest = plugin.manifest;
      return PluginDescriptor(
        manifest: manifest,
        state: _states[manifest.id] ?? const PluginUserState(enabled: false),
        isBuiltin: manifest.id.startsWith('riogram.builtin.'),
      );
    }).toList()
      ..sort((a, b) => a.manifest.name.compareTo(b.manifest.name));
  }

  PluginUserState stateFor(String pluginId) {
    return _states[pluginId] ?? const PluginUserState(enabled: false);
  }

  Future<void> setPluginEnabled(String pluginId, bool enabled) async {
    final current = stateFor(pluginId);
    _states[pluginId] = current.copyWith(enabled: enabled);
    await _persist();
    notifyListeners();
  }

  Future<void> setPluginConfig(
    String pluginId,
    Map<String, String> config,
  ) async {
    final current = stateFor(pluginId);
    _states[pluginId] = current.copyWith(config: config);
    await _persist();
    notifyListeners();
  }

  String transformDisplayText({
    required PluginMessageContext context,
    required String text,
  }) {
    var result = text;
    for (final plugin in _enabledPlugins(PluginCapability.messageDisplayTransform)) {
      final transformed = plugin.transformMessageDisplay(
        context,
        result,
        stateFor(plugin.manifest.id).config,
      );
      if (transformed != null && transformed != result) {
        result = transformed;
      }
    }
    return result;
  }

  FormattedText transformDisplayFormatted({
    required PluginMessageContext context,
    required FormattedText formatted,
  }) {
    final transformed = transformDisplayText(
      context: context,
      text: formatted.text,
    );
    if (transformed == formatted.text) {
      return formatted;
    }
    return FormattedText(text: transformed);
  }

  String transformOutgoingText({
    required PluginMessageContext context,
    required String text,
  }) {
    var result = text;
    for (final plugin in _enabledPlugins(PluginCapability.outgoingMessageTransform)) {
      final transformed = plugin.transformOutgoingMessage(
        context,
        result,
        stateFor(plugin.manifest.id).config,
      );
      if (transformed != null && transformed != result) {
        result = transformed;
      }
    }
    return result;
  }

  List<RioGramPlugin> _enabledPlugins(PluginCapability capability) {
    return PluginRegistry.all.where((plugin) {
      if (!plugin.supports(capability)) {
        return false;
      }
      return stateFor(plugin.manifest.id).enabled;
    }).toList();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await PluginPreferences(prefs).saveStates(_states);
  }
}

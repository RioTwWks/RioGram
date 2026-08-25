import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/external_integration_models.dart';
import '../../models/formatted_text.dart';
import '../tdlib/tdlib_client.dart';
import 'external_integrations_preferences.dart';

/// Автопостинг и внешние интеграции (§7.5).
class ExternalIntegrationsManager extends ChangeNotifier {
  ExternalIntegrationsManager({required TdlibClient client}) : _client = client;

  final TdlibClient _client;
  ExternalIntegrationsPreferences? _preferences;

  ExternalIntegrationsSettings _settings = const ExternalIntegrationsSettings();

  ExternalIntegrationsSettings get settings => _settings;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _preferences = ExternalIntegrationsPreferences(prefs);
    _settings = _preferences!.load();
    notifyListeners();
  }

  Future<void> setAutopostTarget({
    required int chatId,
    required String title,
  }) async {
    _settings = _settings.copyWith(
      autopostTarget: AutopostTarget(
        chatId: chatId,
        title: title,
        enabled: _settings.autopostTarget.enabled,
      ),
    );
    await _save();
    notifyListeners();
  }

  Future<void> setAutopostEnabled(bool enabled) async {
    _settings = _settings.copyWith(
      autopostTarget: _settings.autopostTarget.copyWith(enabled: enabled),
    );
    await _save();
    notifyListeners();
  }

  Future<void> clearAutopostTarget() async {
    _settings = _settings.copyWith(
      autopostTarget: const AutopostTarget(chatId: 0, title: ''),
    );
    await _save();
    notifyListeners();
  }

  Future<void> setMirrorOutgoingText(bool enabled) async {
    _settings = _settings.copyWith(mirrorOutgoingText: enabled);
    await _save();
    notifyListeners();
  }

  /// Дублирует исходящее текстовое сообщение в настроенный канал/бота.
  void mirrorOutgoingText({
    required int sourceChatId,
    required FormattedText text,
  }) {
    final target = _settings.autopostTarget;
    if (!target.enabled || !target.isConfigured || !_settings.mirrorOutgoingText) {
      return;
    }
    if (sourceChatId == target.chatId || text.text.trim().isEmpty) {
      return;
    }

    _client.send({
      '@type': 'sendMessage',
      'chat_id': target.chatId,
      'input_message_content': {
        '@type': 'inputMessageText',
        'text': text.toTdlib(),
      },
    });
  }

  Future<void> _save() async {
    final preferences = _preferences;
    if (preferences == null) {
      final prefs = await SharedPreferences.getInstance();
      _preferences = ExternalIntegrationsPreferences(prefs);
      await _preferences!.save(_settings);
      return;
    }
    await preferences.save(_settings);
  }
}

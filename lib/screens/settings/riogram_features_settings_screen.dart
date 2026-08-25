import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/features/riogram_features_manager.dart';
import '../../widgets/telegram_settings_tile.dart';
  const RioGramFeaturesSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ghost = context.watch<GhostModeManager>();
    final media = context.watch<RioGramMediaFeaturesManager>();

    return TelegramSettingsScaffold(
      title: 'Функции RioGram',
      children: [
        const TelegramSettingsSectionHeader('Призрачный режим'),
        TelegramSettingsGroup(
          children: [
            TelegramSettingsSwitchTile(
              title: 'Призрачный режим',
              subtitle: 'Скрывает активность в чатах',
              value: ghost.ghostModeEnabled,
              onChanged: ghost.setGhostModeEnabled,
            ),
            TelegramSettingsSwitchTile(
              title: 'Скрыть статус «в сети»',
              subtitle: 'Не показывать онлайн другим пользователям',
              value: ghost.hideOnlineStatus,
              onChanged: ghost.ghostModeEnabled
                  ? ghost.setHideOnlineStatus
                  : null,
            ),
            TelegramSettingsSwitchTile(
              title: 'Скрыть «печатает…»',
              subtitle: 'Не отправлять индикатор набора текста',
              value: ghost.hideTypingStatus,
              onChanged: ghost.ghostModeEnabled
                  ? ghost.setHideTypingStatus
                  : null,
            ),
            TelegramSettingsSwitchTile(
              title: 'Скрыть прочтение',
              subtitle: 'Не отправлять подтверждения о прочтении',
              value: ghost.hideReadReceipts,
              onChanged: ghost.ghostModeEnabled
                  ? ghost.setHideReadReceipts
                  : null,
            ),
            TelegramSettingsSwitchTile(
              title: 'Скрытый просмотр медиа',
              subtitle: 'Исчезающие фото/видео без уведомления',
              value: ghost.stealthViewSelfDestruct,
              onChanged: ghost.ghostModeEnabled
                  ? ghost.setStealthViewSelfDestruct
                  : null,
              showDivider: false,
            ),
          ],
        ),
        const TelegramSettingsSectionHeader('Анти-отзыв и медиа'),
        TelegramSettingsGroup(
          children: [
            TelegramSettingsSwitchTile(
              title: 'Анти-отзыв',
              subtitle: 'Сохранять удалённые и отредактированные сообщения',
              value: media.antiRecallEnabled,
              onChanged: media.setAntiRecallEnabled,
            ),
            TelegramSettingsSwitchTile(
              title: 'Превью при наведении',
              subtitle: 'Увеличенный просмотр фото/видео на десктопе',
              value: media.hoverPreviewEnabled,
              onChanged: media.setHoverPreviewEnabled,
            ),
            TelegramSettingsTile(
              title: 'Скорость видео по умолчанию',
              value: '${media.defaultVideoSpeed}x',
              onTap: () => _pickVideoSpeed(context, media),
            ),
            TelegramSettingsTile(
              title: 'Язык перевода',
              value: _languageLabel(media.translatorTargetLanguage),
              onTap: () => _pickTranslatorLanguage(context, media),
              showDivider: false,
            ),
          ],
        ),
      ],
    );
  }

  static String _languageLabel(String code) {
    return MessageTranslator.supportedLanguages
        .where((item) => item.code == code)
        .map((item) => item.label)
        .firstOrNull ?? code;
  }

  static Future<void> _pickVideoSpeed(
    BuildContext context,
    RioGramMediaFeaturesManager media,
  ) async {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: speeds.map((speed) {
            return RadioListTile<double>(
              title: Text('${speed}x'),
              value: speed,
              groupValue: media.defaultVideoSpeed,
              onChanged: (value) {
                if (value != null) {
                  media.setDefaultVideoSpeed(value);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  static Future<void> _pickTranslatorLanguage(
    BuildContext context,
    RioGramMediaFeaturesManager media,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: MessageTranslator.supportedLanguages.map((option) {
            return RadioListTile<String>(
              title: Text(option.label),
              value: option.code,
              groupValue: media.translatorTargetLanguage,
              onChanged: (value) {
                if (value != null) {
                  media.setTranslatorTargetLanguage(value);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}

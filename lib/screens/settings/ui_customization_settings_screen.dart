import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/theme_manager.dart';
import '../../core/theme/theme_preferences.dart';
import '../../core/theme/ui_customization_manager.dart';
import '../../models/ui_customization_models.dart';
import '../../widgets/telegram_settings_tile.dart';

/// Настройки глубокой кастомизации UI (§7.3).
class UiCustomizationSettingsScreen extends StatelessWidget {
  const UiCustomizationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ui = context.watch<UiCustomizationManager>();
    final theme = context.watch<ThemeManager>();

    return TelegramSettingsScaffold(
      title: 'Кастомизация UI',
      children: [
        const TelegramSettingsSectionHeader('Расширенная тема'),
        TelegramSettingsGroup(
          children: [
            TelegramSettingsSwitchTile(
              title: 'Свой акцентный цвет',
              subtitle: 'Произвольный цвет вместо пресетов',
              value: ui.useCustomAccent,
              onChanged: ui.setUseCustomAccent,
            ),
            TelegramSettingsTile(
              title: 'Выбрать цвет',
              value: ui.useCustomAccent && ui.customAccentColor != null
                  ? '#${ui.customAccentColor!.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}'
                  : 'Не выбран',
              onTap: () => _pickAccentColor(context, ui, theme),
            ),
            TelegramSettingsTile(
              title: 'Шрифт',
              value: ui.fontPreset.label,
              onTap: () => _pickFont(context, ui),
            ),
            TelegramSettingsTile(
              title: 'Скругление углов',
              value: '${(ui.cornerRadiusScale * 100).round()}%',
              onTap: () => _pickCornerRadius(context, ui),
              showDivider: false,
            ),
          ],
        ),
        const TelegramSettingsSectionHeader('Видимость элементов'),
        TelegramSettingsGroup(
          children: [
            TelegramSettingsSwitchTile(
              title: 'Скрыть иконки mute',
              subtitle: 'Колокольчик «без звука» в списке чатов',
              value: ui.hideMuteIcons,
              onChanged: ui.setHideMuteIcons,
            ),
            TelegramSettingsSwitchTile(
              title: 'Скрыть нижнюю навигацию',
              subtitle: 'Tab bar на мобильных (Чаты / Контакты / Настройки)',
              value: ui.hideNavigationBar,
              onChanged: ui.setHideNavigationBar,
            ),
            TelegramSettingsSwitchTile(
              title: 'Скрыть ленту историй',
              subtitle: 'Классический режим без stories над списком чатов',
              value: ui.hideStoriesStrip,
              onChanged: ui.setHideStoriesStrip,
            ),
            TelegramSettingsSwitchTile(
              title: 'Скрыть иконки в списке',
              subtitle: 'Pin, preview-иконки медиа, тип чата',
              value: ui.hideListIcons,
              onChanged: ui.setHideListIcons,
              showDivider: false,
            ),
          ],
        ),
        const TelegramSettingsSectionHeader('Жесты'),
        TelegramSettingsGroup(
          children: [
            TelegramSettingsTile(
              title: 'Свайп чата ← (влево)',
              value: ui.chatSwipeEndToStart.label,
              onTap: () => _pickChatSwipe(
                context,
                ui,
                title: 'Свайп чата влево',
                current: ui.chatSwipeEndToStart,
                onSelected: ui.setChatSwipeEndToStart,
              ),
            ),
            TelegramSettingsTile(
              title: 'Свайп чата → (вправо)',
              value: ui.chatSwipeStartToEnd.label,
              onTap: () => _pickChatSwipe(
                context,
                ui,
                title: 'Свайп чата вправо',
                current: ui.chatSwipeStartToEnd,
                onSelected: ui.setChatSwipeStartToEnd,
              ),
            ),
            TelegramSettingsTile(
              title: 'Свайп сообщения ←',
              value: ui.messageSwipeEndToStart.label,
              onTap: () => _pickMessageSwipe(
                context,
                ui,
                title: 'Свайп сообщения влево',
                current: ui.messageSwipeEndToStart,
                onSelected: ui.setMessageSwipeEndToStart,
              ),
            ),
            TelegramSettingsTile(
              title: 'Свайп сообщения →',
              value: ui.messageSwipeStartToEnd.label,
              onTap: () => _pickMessageSwipe(
                context,
                ui,
                title: 'Свайп сообщения вправо',
                current: ui.messageSwipeStartToEnd,
                onSelected: ui.setMessageSwipeStartToEnd,
                showDivider: false,
              ),
              showDivider: false,
            ),
          ],
        ),
      ],
    );
  }

  static Future<void> _pickAccentColor(
    BuildContext context,
    UiCustomizationManager ui,
    ThemeManager theme,
  ) async {
    final color = await showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Акцентный цвет'),
        content: SingleChildScrollView(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...ThemePreferences.accentOptions,
              if (ui.customAccentColor != null) ui.customAccentColor!,
            ].map((color) {
              return GestureDetector(
                onTap: () => Navigator.pop(context, color),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black26),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
        ],
      ),
    );
    if (color != null) {
      await ui.setCustomAccentColor(color);
      await theme.setAccentColor(color);
    }
  }

  static Future<void> _pickFont(
    BuildContext context,
    UiCustomizationManager ui,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppFontPreset.values.map((preset) {
            return RadioListTile<AppFontPreset>(
              title: Text(preset.label),
              value: preset,
              groupValue: ui.fontPreset,
              onChanged: (value) {
                if (value != null) {
                  ui.setFontPreset(value);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  static Future<void> _pickCornerRadius(
    BuildContext context,
    UiCustomizationManager ui,
  ) async {
    const scales = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: scales.map((scale) {
            return RadioListTile<double>(
              title: Text('${(scale * 100).round()}%'),
              value: scale,
              groupValue: ui.cornerRadiusScale,
              onChanged: (value) {
                if (value != null) {
                  ui.setCornerRadiusScale(value);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  static Future<void> _pickChatSwipe(
    BuildContext context,
    UiCustomizationManager ui, {
    required String title,
    required ChatSwipeAction current,
    required Future<void> Function(ChatSwipeAction) onSelected,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title, style: Theme.of(context).textTheme.titleMedium),
            ),
            ...ChatSwipeAction.values.map((action) {
              return RadioListTile<ChatSwipeAction>(
                title: Text(action.label),
                value: action,
                groupValue: current,
                onChanged: (value) async {
                  if (value != null) {
                    await onSelected(value);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  static Future<void> _pickMessageSwipe(
    BuildContext context,
    UiCustomizationManager ui, {
    required String title,
    required MessageSwipeAction current,
    required Future<void> Function(MessageSwipeAction) onSelected,
    bool showDivider = true,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title, style: Theme.of(context).textTheme.titleMedium),
            ),
            ...MessageSwipeAction.values.map((action) {
              return RadioListTile<MessageSwipeAction>(
                title: Text(action.label),
                value: action,
                groupValue: current,
                onChanged: (value) async {
                  if (value != null) {
                    await onSelected(value);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}

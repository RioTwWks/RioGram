import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/privacy/security_privacy_manager.dart';
import '../../models/security_privacy_models.dart';
import '../../widgets/telegram_settings_tile.dart';

/// Настройки безопасности и приватности RioGram (§7.4).
class SecurityPrivacySettingsScreen extends StatelessWidget {
  const SecurityPrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final privacy = context.watch<SecurityPrivacyManager>();

    return TelegramSettingsScaffold(
      title: 'Безопасность и приватность',
      children: [
        if (privacy.lastError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              privacy.lastError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const TelegramSettingsSectionHeader('Local Premium'),
        TelegramSettingsGroup(
          children: [
            TelegramSettingsSwitchTile(
              title: 'Local Premium',
              subtitle: 'Локальная разблокировка премиум-возможностей',
              value: privacy.localPremiumEnabled,
              onChanged: privacy.setLocalPremiumEnabled,
            ),
            TelegramSettingsSwitchTile(
              title: 'Лимит загрузки 4 ГБ',
              subtitle: 'Разрешить отправку файлов до 4 ГБ',
              value: privacy.localPremiumUploadFileSize,
              onChanged: privacy.localPremiumEnabled
                  ? privacy.setLocalPremiumUploadFileSize
                  : null,
            ),
            TelegramSettingsSwitchTile(
              title: 'Повышенные лимиты',
              subtitle: _limitsSubtitle(privacy),
              value: privacy.localPremiumIncreasedLimits,
              onChanged: privacy.localPremiumEnabled
                  ? privacy.setLocalPremiumIncreasedLimits
                  : null,
            ),
            TelegramSettingsSwitchTile(
              title: 'Ускоренная загрузка',
              subtitle: 'Подсказки о premium-скорости загрузки',
              value: privacy.localPremiumFasterDownloads,
              onChanged: privacy.localPremiumEnabled
                  ? privacy.setLocalPremiumFasterDownloads
                  : null,
              showDivider: false,
            ),
          ],
        ),
        const TelegramSettingsSectionHeader('Реклама'),
        TelegramSettingsGroup(
          children: [
            TelegramSettingsSwitchTile(
              title: 'Блокировать рекламу',
              subtitle: 'Скрывать спонсорские сообщения и чаты',
              value: privacy.blockAdsEnabled,
              onChanged: privacy.setBlockAdsEnabled,
              showDivider: false,
            ),
          ],
        ),
        const TelegramSettingsSectionHeader('Телеметрия'),
        TelegramSettingsGroup(
          children: [
            TelegramSettingsSwitchTile(
              title: 'Отправлять телеметрию Telegram',
              subtitle: 'Сетевая статистика TDLib (по умолчанию выкл.)',
              value: privacy.isTelemetryEnabled,
              onChanged: (value) {
                privacy.setTelemetryMode(
                  value ? TelemetryMode.enabled : TelemetryMode.disabled,
                );
              },
              showDivider: false,
            ),
          ],
        ),
      ],
    );
  }

  static String _limitsSubtitle(SecurityPrivacyManager privacy) {
    final limits = privacy.limitFor(LocalPremiumFeature.increasedLimits);
    if (limits == null) {
      return 'Закреплённые чаты, папки, длина сообщений';
    }
    return 'Закреплённые чаты: ${limits.defaultValue} → ${limits.premiumValue}';
  }
}

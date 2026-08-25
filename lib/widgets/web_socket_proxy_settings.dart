import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/proxy/web_proxy_manager.dart';
import '../../core/theme/telegram_theme.dart';
import 'telegram_settings_tile.dart';
import 'web_proxy_status_indicator.dart';

/// Настройки WSS-прокси для Web-платформы (§8.2).
class WebSocketProxySettings extends StatefulWidget {
  const WebSocketProxySettings({super.key, required this.manager});

  final WebProxyManager manager;

  @override
  State<WebSocketProxySettings> createState() => _WebSocketProxySettingsState();
}

class _WebSocketProxySettingsState extends State<WebSocketProxySettings> {
  late final TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.manager.config.url);
  }

  @override
  void didUpdateWidget(covariant WebSocketProxySettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.manager.config.url != widget.manager.config.url &&
        _urlController.text != widget.manager.config.url) {
      _urlController.text = widget.manager.config.url;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<WebProxyManager>();
    final tg = context.telegramTheme;

    return TelegramSettingsGroup(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: WebProxyStatusIndicator(manager: manager),
        ),
        if (manager.lastError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              manager.lastError!,
              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
            ),
          ),
        TelegramSettingsTile(
          title: 'WSS-прокси',
          subtitle: 'Туннель browser → RU VPS → Telegram',
          value: manager.config.enabled ? 'Вкл.' : 'Выкл.',
          trailing: Switch(
            value: manager.config.enabled,
            onChanged: (value) => manager.setEnabled(value),
          ),
          showChevron: false,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _urlController,
            enabled: manager.config.enabled,
            decoration: InputDecoration(
              labelText: 'Адрес WSS-прокси',
              hintText: 'wss://your-domain.ru',
              filled: true,
              fillColor: tg.inputFieldBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: manager.setProxyUrl,
          ),
        ),
        TelegramSettingsTile(
          title: 'Автопереподключение',
          subtitle: 'При обрыве WSS-соединения',
          trailing: Switch(
            value: manager.config.autoReconnect,
            onChanged: manager.config.enabled
                ? (value) => manager.setAutoReconnect(value)
                : null,
          ),
          showChevron: false,
        ),
        TelegramSettingsTile(
          title: 'Сохранить адрес',
          subtitle: 'Применить WSS hook',
          onTap: () async {
            await manager.setProxyUrl(_urlController.text);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    manager.previewRewrite(
                      'wss://venus.web.telegram.org/apiws',
                    ),
                  ),
                ),
              );
            }
          },
          showChevron: false,
          showDivider: false,
        ),
      ],
    );
  }
}

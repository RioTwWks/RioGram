import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/auth/session_manager.dart';
import '../../core/theme/telegram_theme.dart';
import '../../models/session_models.dart';
import '../../widgets/telegram_settings_tile.dart';

class ActiveSessionsScreen extends StatefulWidget {
  const ActiveSessionsScreen({super.key});

  @override
  State<ActiveSessionsScreen> createState() => _ActiveSessionsScreenState();
}

class _ActiveSessionsScreenState extends State<ActiveSessionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SessionManager>().loadActiveSessions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<SessionManager>();
    final sessions = manager.sessions?.sessions ?? const <ActiveSessionModel>[];

    if (manager.isLoading && sessions.isEmpty) {
      return Scaffold(
        backgroundColor: telegramSettingsPageBackground(context),
        appBar: AppBar(title: const Text('Активные сессии')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return TelegramSettingsScaffold(
      title: 'Активные сессии',
      actions: [
        IconButton(
          tooltip: 'Завершить все другие',
          onPressed: manager.isTerminating || sessions.length <= 1 ? null : () => _confirmTerminateAll(context, manager),
          icon: const Icon(Icons.logout),
        ),
      ],
      children: [
        if (manager.lastError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(manager.lastError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        if (manager.sessions != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Автовыход через ${manager.sessions!.inactiveSessionTtlDays} дн. неактивности',
              style: TextStyle(fontSize: TelegramFontSizes.chatSubtitle, color: context.telegramTheme.textSecondary),
            ),
          ),
        TelegramSettingsGroup(
          children: [
            ...sessions.asMap().entries.map((entry) {
              final session = entry.value;
              final isLast = entry.key == sessions.length - 1;
              return _SessionTile(
                session: session,
                showDivider: !isLast,
                onTerminate: session.isCurrent ? null : () => manager.terminateSession(session.id),
              );
            }),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmTerminateAll(BuildContext context, SessionManager manager) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Завершить другие сессии?'),
        content: const Text('Все устройства, кроме текущего, будут отключены от аккаунта.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Завершить')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) manager.terminateAllOtherSessions();
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, this.onTerminate, this.showDivider = true});

  final ActiveSessionModel session;
  final VoidCallback? onTerminate;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final tg = context.telegramTheme;
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    final lastActive = session.lastActiveDate;
    final subtitleParts = <String>[
      if (session.location.isNotEmpty) session.location,
      if (session.ipAddress.isNotEmpty) session.ipAddress,
      if (lastActive != null) 'Был(а): ${formatter.format(lastActive)}',
      if (session.isCurrent) 'Текущая сессия',
      if (session.isUnconfirmed) 'Не подтверждена',
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(session.isCurrent ? Icons.smartphone : Icons.devices_other_outlined, color: session.isCurrent ? tg.accent : tg.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session.deviceLabel, style: TextStyle(fontSize: TelegramFontSizes.chatTitle, color: tg.textPrimary)),
                    if (subtitleParts.isNotEmpty)
                      Text(subtitleParts.join('\n'), style: TextStyle(fontSize: TelegramFontSizes.chatSubtitle, color: tg.textSecondary)),
                  ],
                ),
              ),
              if (onTerminate != null)
                IconButton(tooltip: 'Завершить', onPressed: onTerminate, icon: Icon(Icons.close, color: tg.textSecondary)),
            ],
          ),
        ),
        if (showDivider) const TelegramSettingsDivider(inset: 56),
      ],
    );
  }
}

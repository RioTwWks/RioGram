import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/auth/session_manager.dart';
import '../../models/session_models.dart';

/// Список активных сессий Telegram и их завершение.
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Активные сессии'),
        actions: [
          IconButton(
            tooltip: 'Завершить все другие',
            onPressed: manager.isTerminating || sessions.length <= 1
                ? null
                : () => _confirmTerminateAll(context, manager),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: manager.isLoading && sessions.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (manager.lastError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      manager.lastError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (manager.sessions != null)
                  Text(
                    'Автовыход через '
                    '${manager.sessions!.inactiveSessionTtlDays} дн. неактивности',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: 12),
                ...sessions.map(
                  (session) => _SessionTile(
                    session: session,
                    onTerminate: session.isCurrent
                        ? null
                        : () => manager.terminateSession(session.id),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _confirmTerminateAll(
    BuildContext context,
    SessionManager manager,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Завершить другие сессии?'),
        content: const Text(
          'Все устройства, кроме текущего, будут отключены от аккаунта.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Завершить'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      manager.terminateAllOtherSessions();
    }
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
    this.onTerminate,
  });

  final ActiveSessionModel session;
  final VoidCallback? onTerminate;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    final lastActive = session.lastActiveDate;

    return Card(
      child: ListTile(
        leading: Icon(
          session.isCurrent ? Icons.smartphone : Icons.devices_other_outlined,
          color: session.isCurrent
              ? Theme.of(context).colorScheme.primary
              : null,
        ),
        title: Text(session.deviceLabel),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (session.location.isNotEmpty) Text(session.location),
            if (session.ipAddress.isNotEmpty) Text(session.ipAddress),
            if (lastActive != null)
              Text('Был(а): ${formatter.format(lastActive)}'),
            if (session.isCurrent) const Text('Текущая сессия'),
            if (session.isUnconfirmed) const Text('Не подтверждена'),
          ],
        ),
        trailing: onTerminate == null
            ? null
            : IconButton(
                tooltip: 'Завершить',
                onPressed: onTerminate,
                icon: const Icon(Icons.close),
              ),
      ),
    );
  }
}

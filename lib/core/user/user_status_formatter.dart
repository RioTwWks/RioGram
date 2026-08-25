import 'package:intl/intl.dart';

import '../../models/user_models.dart';

/// Форматирование статусов «в сети» / «был(а) недавно».
class UserStatusFormatter {
  const UserStatusFormatter._();

  static String format(UserStatusInfo status, {DateTime? now}) {
    final current = now ?? DateTime.now();
    return switch (status.kind) {
      UserStatusKind.online => 'в сети',
      UserStatusKind.offline => _formatWasOnline(status.wasOnlineAt, current),
      UserStatusKind.recently => 'был(а) недавно',
      UserStatusKind.lastWeek => 'был(а) на этой неделе',
      UserStatusKind.lastMonth => 'был(а) в этом месяце',
      UserStatusKind.empty => '',
      UserStatusKind.unknown => '',
    };
  }

  static String _formatWasOnline(DateTime? wasOnline, DateTime now) {
    if (wasOnline == null) {
      return 'не в сети';
    }
    final diff = now.difference(wasOnline);
    if (diff.inMinutes < 1) {
      return 'был(а) только что';
    }
    if (diff.inMinutes < 60) {
      return 'был(а) ${diff.inMinutes} мин. назад';
    }
    if (diff.inHours < 24 && wasOnline.day == now.day) {
      return 'был(а) сегодня в ${DateFormat.Hm().format(wasOnline)}';
    }
    if (diff.inDays < 7) {
      return 'был(а) ${DateFormat.E().add_Hm().format(wasOnline)}';
    }
    return 'был(а) ${DateFormat.yMMMd().format(wasOnline)}';
  }
}

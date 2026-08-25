import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/telegram_routes.dart';
import '../../core/user/profile_manager.dart';
import '../../widgets/chat_avatar.dart';
import '../../widgets/telegram_settings_tile.dart';
import '../profile/user_profile_screen.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileManager>().loadBlockedUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileManager>();

    if (profile.isLoadingBlocked) {
      return Scaffold(
        backgroundColor: telegramSettingsPageBackground(context),
        appBar: AppBar(title: const Text('Заблокированные')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (profile.blockedUsers.isEmpty) {
      return const TelegramSettingsScaffold(
        title: 'Заблокированные',
        children: [
          Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Заблокированных пользователей нет'),
            ),
          ),
        ],
      );
    }

    return TelegramSettingsScaffold(
      title: 'Заблокированные',
      children: [
        TelegramSettingsGroup(
          children: [
            ...profile.blockedUsers.asMap().entries.map((entry) {
              final blocked = entry.value;
              final user = profile.userById(blocked.userId);
              final title =
                  user?.displayName ?? blocked.displayName ?? 'Пользователь';
              final isLast = entry.key == profile.blockedUsers.length - 1;
              return TelegramSettingsTile(
                title: title,
                leading: ChatAvatar(
                  title: title,
                  localPath: user?.avatarLocalPath,
                  radius: 20,
                ),
                showChevron: false,
                showDivider: !isLast,
                trailing: IconButton(
                  tooltip: 'Разблокировать',
                  icon: const Icon(Icons.lock_open_outlined),
                  onPressed: () => profile.unblockUser(blocked.userId),
                ),
                onTap: () {
                  TelegramRoutes.push(
                    context,
                    UserProfileScreen(userId: blocked.userId),
                  );
                },
              );
            }),
          ],
        ),
      ],
    );
  }
}

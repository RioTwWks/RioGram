import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/user/profile_manager.dart';
import '../../widgets/chat_avatar.dart';
import '../profile/user_profile_screen.dart';

/// Список заблокированных пользователей.
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

    return Scaffold(
      appBar: AppBar(title: const Text('Заблокированные')),
      body: profile.isLoadingBlocked
          ? const Center(child: CircularProgressIndicator())
          : profile.blockedUsers.isEmpty
              ? const Center(child: Text('Заблокированных пользователей нет'))
              : ListView.builder(
                  itemCount: profile.blockedUsers.length,
                  itemBuilder: (context, index) {
                    final blocked = profile.blockedUsers[index];
                    final user = profile.userById(blocked.userId);
                    final title =
                        user?.displayName ?? blocked.displayName ?? 'Пользователь';

                    return ListTile(
                      leading: ChatAvatar(
                        title: title,
                        localPath: user?.avatarLocalPath,
                      ),
                      title: Text(title),
                      trailing: IconButton(
                        tooltip: 'Разблокировать',
                        icon: const Icon(Icons.lock_open_outlined),
                        onPressed: () =>
                            profile.unblockUser(blocked.userId),
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => UserProfileScreen(
                              userId: blocked.userId,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}

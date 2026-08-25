import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/chat/chat_manager.dart';
import '../../core/secret/secret_chat_manager.dart';
import '../../core/user/contact_manager.dart';
import '../../core/user/profile_manager.dart';
import '../../widgets/chat_avatar.dart';
import '../../widgets/user_status_subtitle.dart';

/// Просмотр профиля другого пользователя.
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({
    super.key,
    required this.userId,
    this.chatId,
  });

  final int userId;
  final int? chatId;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = context.read<ProfileManager>();
      profile.loadUserProfile(widget.userId);
      profile.loadCommonChats(widget.userId);
    });
  }

  Future<void> _copyUsername(String username) async {
    await Clipboard.setData(ClipboardData(text: '@$username'));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Username скопирован')),
    );
  }

  Future<void> _confirmBlock(ProfileManager profile, bool isBlocked) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isBlocked ? 'Разблокировать?' : 'Заблокировать?'),
        content: Text(
          isBlocked
              ? 'Пользователь снова сможет писать вам.'
              : 'Пользователь не сможет писать вам и звонить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isBlocked ? 'Разблокировать' : 'Заблокировать'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    if (isBlocked) {
      profile.unblockUser(widget.userId);
    } else {
      profile.blockUser(widget.userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileManager>();
    final contacts = context.read<ContactManager>();
    final chatManager = context.read<ChatManager>();

    final user = profile.userById(widget.userId);
    final fullInfo = profile.fullInfoFor(widget.userId);
    final commonChats = profile.commonChatsFor(widget.userId);
    final isLoading = profile.isLoadingFullInfo(widget.userId) && user == null;

    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Column(
                    children: [
                      ChatAvatar(
                        title: user?.displayName ?? 'Пользователь',
                        localPath: user?.avatarLocalPath,
                        radius: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user?.displayName ?? 'Пользователь',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (user != null)
                        UserStatusSubtitle(
                          status: user.status,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      if (user?.username != null &&
                          user!.username!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _copyUsername(user.username!),
                          child: Text('@${user.username}'),
                        ),
                      ],
                      if (user?.phoneNumber.isNotEmpty == true &&
                          user!.isContact) ...[
                        const SizedBox(height: 4),
                        Text(user.phoneNumber),
                      ],
                    ],
                  ),
                ),
                if (fullInfo?.bio.isNotEmpty == true) ...[
                  const SizedBox(height: 24),
                  Text('О себе', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Text(fullInfo!.bio),
                ],
                if (user?.isBot == true && fullInfo != null) ...[
                  const SizedBox(height: 24),
                  Text('Бот', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  if (fullInfo.botInfo.shortDescription.isNotEmpty)
                    Text(fullInfo.botInfo.shortDescription),
                  if (fullInfo.botInfo.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(fullInfo.botInfo.description),
                  ],
                  if (fullInfo.botInfo.commands.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...fullInfo.botInfo.commands.map(
                      (cmd) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(cmd.slashCommand),
                        subtitle: Text(cmd.description),
                      ),
                    ),
                  ],
                ],
                if (commonChats.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Общие чаты',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  ...commonChats.map(
                    (chat) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.groups_outlined),
                      title: Text(chat.title),
                      onTap: () {
                        chatManager.openChat(chat.id);
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                    ),
                  ),
                ] else if (profile.isLoadingCommonChats(widget.userId))
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                const SizedBox(height: 24),
                if (user != null && !user.isBot)
                  OutlinedButton.icon(
                    onPressed: () {
                      context.read<SecretChatManager>().createSecretChat(user.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Создание секретного чата…'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('Секретный чат'),
                  ),
                if (user != null && !user.isBot) const SizedBox(height: 8),
                if (user != null && !user.isContact)
                  OutlinedButton.icon(
                    onPressed: () {
                      contacts.addContact(
                        user.id,
                        firstName: user.firstName,
                        lastName: user.lastName,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Контакт добавлен')),
                      );
                    },
                    icon: const Icon(Icons.person_add_outlined),
                    label: const Text('Добавить в контакты'),
                  ),
                if (user != null && user.isContact) ...[
                  OutlinedButton.icon(
                    onPressed: () {
                      contacts.removeContact(user.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Контакт удалён')),
                      );
                    },
                    icon: const Icon(Icons.person_remove_outlined),
                    label: const Text('Удалить из контактов'),
                  ),
                  const SizedBox(height: 8),
                ],
                OutlinedButton.icon(
                  onPressed: () => _confirmBlock(
                    profile,
                    fullInfo?.isBlocked ?? false,
                  ),
                  icon: Icon(
                    (fullInfo?.isBlocked ?? false)
                        ? Icons.lock_open_outlined
                        : Icons.block,
                  ),
                  label: Text(
                    (fullInfo?.isBlocked ?? false)
                        ? 'Разблокировать'
                        : 'Заблокировать',
                  ),
                ),
                if (widget.chatId != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('Открыть чат'),
                  ),
                ],
              ],
            ),
    );
  }
}

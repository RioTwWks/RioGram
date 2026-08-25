import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/chat/chat_manager.dart';
import '../../core/secret/secret_chat_manager.dart';
import '../../models/secret_chat_models.dart';
import '../../core/user/contact_manager.dart';
import '../../core/user/profile_manager.dart';
import '../../models/chat_info_models.dart';
import '../../models/channel_models.dart';
import '../../models/chat_models.dart';
import '../../widgets/chat_avatar.dart';
import '../../widgets/chat_list_tile.dart';
import '../../widgets/chat_notification_settings_section.dart';
import '../../widgets/secret_chat_widgets.dart';
import '../../widgets/user_status_subtitle.dart';
import '../profile/user_profile_screen.dart';
import '../../core/navigation/telegram_routes.dart';

/// Экран информации о чате: описание, ссылка, участники, настройки.
class ChatInfoScreen extends StatefulWidget {
  const ChatInfoScreen({
    super.key,
    required this.chatId,
  });

  final int chatId;

  @override
  State<ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends State<ChatInfoScreen> {
  var _isJoining = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final manager = context.read<ChatManager>();
      manager.loadChatInfo(widget.chatId);
      final chat = manager.chatById(widget.chatId);
      final userId = chat?.privateUserId;
      if (userId != null && chat?.kind == ChatKind.privateChat) {
        final profile = context.read<ProfileManager>();
        profile.loadUserProfile(userId);
        profile.loadCommonChats(userId);
      }
    });
  }

  @override
  void dispose() {
    context.read<ChatManager>().clearChatInfo(widget.chatId);
    super.dispose();
  }

  Future<void> _copyToClipboard(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label скопировано')),
    );
  }

  Future<void> _confirmLeave(ChatSummary chat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(chat.kind == ChatKind.channel ? 'Отписаться?' : 'Покинуть чат?'),
        content: Text(
          chat.kind == ChatKind.channel
              ? 'Вы перестанете получать сообщения канала.'
              : 'Вы покинете «${chat.title}».',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(chat.kind == ChatKind.channel ? 'Отписаться' : 'Покинуть'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await context.read<ChatManager>().leaveChat(widget.chatId);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _subscribeToChannel(ChatManager manager, ChatSummary chat) async {
    setState(() => _isJoining = true);
    try {
      await manager.subscribeToChannel(chat.id);
      manager.loadChatInfo(chat.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Вы подписались на «${chat.title}»')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }

  Future<void> _upgradeBasicGroup(ChatManager manager) async {
    try {
      final chatId = await manager.upgradeBasicGroupToSupergroup(widget.chatId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Группа преобразована в супергруппу')),
      );
      manager.loadChatInfo(chatId);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  Future<void> _editPermissions(
    ChatManager manager,
    ChatDetailInfo info,
  ) async {
    final updated = await showDialog<ChatPermissionsInfo>(
      context: context,
      builder: (context) => _ChatPermissionsDialog(initial: info.permissions),
    );
    if (updated == null) {
      return;
    }
    manager.setChatPermissions(widget.chatId, updated);
  }

  Future<void> _showMemberActions(
    ChatManager manager,
    ChatDetailInfo info,
    ChatMemberInfo member,
  ) async {
    if (!info.canManageMembers || member.isOwner) {
      return;
    }

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (member.status == ChatMemberStatusKind.administrator ||
                member.status == ChatMemberStatusKind.creator)
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('Изменить должность'),
                onTap: () => Navigator.pop(context, 'tag'),
              ),
            if (!member.isBanned && member.status != ChatMemberStatusKind.creator)
              ListTile(
                leading: const Icon(Icons.block),
                title: const Text('Заблокировать'),
                onTap: () => Navigator.pop(context, 'ban'),
              ),
            if (member.isBanned)
              ListTile(
                leading: const Icon(Icons.lock_open_outlined),
                title: const Text('Разблокировать'),
                onTap: () => Navigator.pop(context, 'unban'),
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Отмена'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case 'tag':
        final tag = await _promptText(
          title: 'Должность администратора',
          initial: member.tag,
          maxLength: 16,
        );
        if (tag != null) {
          manager.setChatMemberTag(widget.chatId, member.userId, tag);
          manager.loadChatInfo(widget.chatId);
        }
      case 'ban':
        manager.banChatMember(widget.chatId, member.userId);
        manager.loadChatInfo(widget.chatId);
      case 'unban':
        manager.unbanChatMember(widget.chatId, member.userId);
        manager.loadChatInfo(widget.chatId);
    }
  }

  Future<String?> _promptText({
    required String title,
    String initial = '',
    int maxLength = 128,
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLength: maxLength,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<ChatManager>();
    final profile = context.watch<ProfileManager>();
    final secretManager = context.watch<SecretChatManager>();
    final contacts = context.read<ContactManager>();
    final chat = manager.chatById(widget.chatId);
    final info = manager.chatInfoFor(widget.chatId);
    final members = manager.chatMembersFor(widget.chatId);
    final membersTotal = manager.chatMembersTotalCountFor(widget.chatId);
    final isLoading =
        manager.isLoadingChatInfo && manager.loadingChatInfoForChatId == widget.chatId;

    if (chat == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Информация')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Информация')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                ChatAvatar(
                  title: chat.title,
                  localPath: chat.avatarLocalPath,
                  radius: 40,
                ),
                const SizedBox(height: 12),
                Text(
                  chat.title,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      chatKindIcon(chat.kind),
                      size: 16,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.55),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _chatTypeLabel(chat, info),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.65),
                          ),
                    ),
                  ],
                ),
                if (info?.memberCount != null || membersTotal > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${info?.memberCount ?? membersTotal} участников',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (isLoading) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
          if (manager.chatInfoError != null) ...[
            const SizedBox(height: 16),
            Text(
              manager.chatInfoError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (chat.kind == ChatKind.privateChat && chat.privateUserId != null)
            ..._privateChatSection(context, chat, profile, contacts),
          if (chat.kind == ChatKind.bot && chat.privateUserId != null) ...[
            const SizedBox(height: 24),
            Text('Бот', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._botInfoSection(context, profile, chat.privateUserId!),
          ],
          if (chat.kind == ChatKind.secret && chat.secretChatId != null) ...[
            const SizedBox(height: 24),
            SecretChatKeyIndicator(
              secretChat: secretManager.secretChatForId(chat.secretChatId!) ??
                  SecretChatSummary(
                    id: chat.secretChatId!,
                    userId: chat.privateUserId ?? 0,
                  ),
            ),
            SecretChatTtlPicker(
              value: secretManager.ttlForChat(chat.id),
              onChanged: (preset) =>
                  secretManager.setChatTtl(chat.id, preset),
            ),
            OutlinedButton.icon(
              onPressed: () =>
                  secretManager.closeSecretChat(chat.secretChatId!),
              icon: const Icon(Icons.lock_open_outlined),
              label: const Text('Закрыть секретный чат'),
            ),
          ],
          const SizedBox(height: 24),
          ChatNotificationSettingsSection(
            chatId: widget.chatId,
            chatKind: chat.kind,
          ),
          if (info != null && info.description.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Описание', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(info.description),
              ),
            ),
          ],
          if (info?.username != null) ...[
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.alternate_email),
              title: Text('@${info!.username}'),
              trailing: IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () => _copyToClipboard(
                  'https://t.me/${info.username}',
                  'Ссылка',
                ),
              ),
            ),
          ],
          if (info?.inviteLink != null) ...[
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.link),
              title: const Text('Ссылка-приглашение'),
              subtitle: Text(
                info!.inviteLink!.url,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () => _copyToClipboard(
                  info.inviteLink!.url,
                  'Ссылка-приглашение',
                ),
              ),
            ),
          ] else if (info?.canChangeInfo == true) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => manager.createPrimaryInviteLink(widget.chatId),
              icon: const Icon(Icons.add_link),
              label: const Text('Создать ссылку-приглашение'),
            ),
          ],
          if (info?.linkedChatId != null) ...[
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.forum_outlined),
              title: const Text('Группа обсуждения'),
              subtitle: Text('ID ${info!.linkedChatId}'),
            ),
          ],
          if (info != null && _hasAdminSettings(info)) ...[
            const SizedBox(height: 24),
            Text('Настройки', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: _adminSettingTiles(info.adminSettings),
              ),
            ),
          ],
          if (info != null && info.canChangeInfo) ...[
            const SizedBox(height: 24),
            Text('Права участников', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ..._permissionPreviewTiles(info.permissions),
                  ListTile(
                    leading: const Icon(Icons.tune),
                    title: const Text('Изменить права по умолчанию'),
                    onTap: () => _editPermissions(manager, info),
                  ),
                ],
              ),
            ),
          ],
          if (members.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Участники', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (final member in members)
                    ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          member.title.characters.first.toUpperCase(),
                        ),
                      ),
                      title: Text(member.title),
                      subtitle: member.statusLabel.isEmpty
                          ? null
                          : Text(member.statusLabel),
                      onTap: info?.canManageMembers == true
                          ? () => _showMemberActions(manager, info!, member)
                          : null,
                    ),
                  if (membersTotal > members.length)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Показано ${members.length} из $membersTotal',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text('Действия', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (info?.canUpgradeToSupergroup == true)
            OutlinedButton.icon(
              onPressed: () => _upgradeBasicGroup(manager),
              icon: const Icon(Icons.upgrade),
              label: const Text('Преобразовать в супергруппу'),
            ),
          if (info?.canUpgradeToSupergroup == true) const SizedBox(height: 8),
          if (chat.kind == ChatKind.channel &&
              manager.channelMembershipFor(chat.id) ==
                  ChannelMembershipKind.notSubscribed)
            FilledButton.icon(
              onPressed: _isJoining ? null : () => _subscribeToChannel(manager, chat),
              icon: _isJoining
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: const Text('Подписаться'),
            ),
          if (chat.kind == ChatKind.channel &&
              manager.channelMembershipFor(chat.id) ==
                  ChannelMembershipKind.notSubscribed)
            const SizedBox(height: 8),
          if (chat.canLeave &&
              !(chat.kind == ChatKind.channel &&
                  manager.channelMembershipFor(chat.id) ==
                      ChannelMembershipKind.notSubscribed))
            OutlinedButton.icon(
              onPressed: () => _confirmLeave(chat),
              icon: const Icon(Icons.logout),
              label: Text(
                chat.kind == ChatKind.channel ? 'Отписаться' : 'Покинуть чат',
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _privateChatSection(
    BuildContext context,
    ChatSummary chat,
    ProfileManager profile,
    ContactManager contacts,
  ) {
    final userId = chat.privateUserId!;
    final user = profile.userById(userId);
    final fullInfo = profile.fullInfoFor(userId);
    final commonChats = profile.commonChatsFor(userId);

    return [
      if (user != null) ...[
        const SizedBox(height: 8),
        Center(child: UserStatusSubtitle(status: user.status)),
      ],
      if (fullInfo?.bio.isNotEmpty == true) ...[
        const SizedBox(height: 16),
        Text('О себе', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(fullInfo!.bio),
      ],
      if (commonChats.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text('Общие чаты', style: Theme.of(context).textTheme.titleMedium),
        ...commonChats.map(
          (entry) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.groups_outlined),
            title: Text(entry.title),
          ),
        ),
      ],
      const SizedBox(height: 16),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.person_outline),
        title: const Text('Открыть профиль'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          TelegramRoutes.push(context, UserProfileScreen(userId: userId, chatId: chat.id));
        },
      ),
      if (user != null && !user.isContact)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.person_add_outlined),
          title: const Text('Добавить в контакты'),
          onTap: () {
            contacts.addContact(
              user.id,
              firstName: user.firstName,
              lastName: user.lastName,
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Контакт добавлен')),
            );
          },
        ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          (fullInfo?.isBlocked ?? false)
              ? Icons.lock_open_outlined
              : Icons.block,
        ),
        title: Text(
          (fullInfo?.isBlocked ?? false)
              ? 'Разблокировать'
              : 'Заблокировать',
        ),
        onTap: () {
          if (fullInfo?.isBlocked ?? false) {
            profile.unblockUser(userId);
          } else {
            profile.blockUser(userId);
          }
        },
      ),
      const Divider(height: 32),
    ];
  }

  List<Widget> _botInfoSection(
    BuildContext context,
    ProfileManager profile,
    int botUserId,
  ) {
    final fullInfo = profile.fullInfoFor(botUserId);
    if (fullInfo == null) {
      return const [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Загрузка информации о боте…'),
        ),
      ];
    }

    final botInfo = fullInfo.botInfo;
    return [
      if (botInfo.shortDescription.isNotEmpty)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(botInfo.shortDescription),
        ),
      if (botInfo.description.isNotEmpty)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(botInfo.description),
        ),
      if (botInfo.commands.isNotEmpty) ...[
        const ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Команды'),
        ),
        ...botInfo.commands.map(
          (cmd) => ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(cmd.slashCommand),
            subtitle: Text(cmd.description),
          ),
        ),
      ],
    ];
  }

  String _chatTypeLabel(ChatSummary chat, ChatDetailInfo? info) {
    if (chat.isForumChat) {
      return 'Форум';
    }
    return switch (chat.kind) {
      ChatKind.channel => 'Канал',
      ChatKind.group when chat.isBasicGroup => 'Базовая группа',
      ChatKind.group => 'Группа',
      ChatKind.bot => 'Бот',
      ChatKind.secret => 'Секретный чат',
      ChatKind.savedMessages => 'Избранное',
      ChatKind.privateChat => 'Личный чат',
    };
  }

  bool _hasAdminSettings(ChatDetailInfo info) {
    final settings = info.adminSettings;
    return settings.isSlowModeEnabled ||
        settings.hasAggressiveAntiSpamEnabled ||
        settings.joinByRequest ||
        settings.joinToSendMessages ||
        settings.slowModeDelay > 0;
  }

  List<Widget> _adminSettingTiles(ChatAdminSettings settings) {
    final tiles = <Widget>[];
    if (settings.isSlowModeEnabled || settings.slowModeDelay > 0) {
      tiles.add(
        ListTile(
          leading: const Icon(Icons.hourglass_bottom),
          title: const Text('Медленный режим'),
          subtitle: Text(
            settings.slowModeDelay > 0
                ? '${settings.slowModeDelay} сек.'
                : 'Включён',
          ),
        ),
      );
    }
    if (settings.hasAggressiveAntiSpamEnabled) {
      tiles.add(
        const ListTile(
          leading: Icon(Icons.shield_outlined),
          title: Text('Агрессивный антиспам'),
          subtitle: Text('Включён'),
        ),
      );
    }
    if (settings.joinByRequest) {
      tiles.add(
        const ListTile(
          leading: Icon(Icons.how_to_reg_outlined),
          title: Text('Одобрение новых участников'),
          subtitle: Text('Заявки на вступление'),
        ),
      );
    }
    if (settings.joinToSendMessages) {
      tiles.add(
        const ListTile(
          leading: Icon(Icons.login),
          title: Text('Вступление для отправки'),
          subtitle: Text('Нужно вступить, чтобы писать'),
        ),
      );
    }
    if (!settings.isAllHistoryAvailable) {
      tiles.add(
        const ListTile(
          leading: Icon(Icons.history),
          title: Text('История сообщений'),
          subtitle: Text('Скрыта для новых участников'),
        ),
      );
    }
    return tiles;
  }

  List<Widget> _permissionPreviewTiles(ChatPermissionsInfo permissions) {
    return [
      _permissionTile('Сообщения', permissions.canSendBasicMessages),
      _permissionTile('Медиа', permissions.canSendPhotos),
      _permissionTile('Опросы', permissions.canSendPolls),
      _permissionTile('Закрепление', permissions.canPinMessages),
      _permissionTile('Приглашения', permissions.canInviteUsers),
    ];
  }

  Widget _permissionTile(String label, bool enabled) {
    return ListTile(
      dense: true,
      title: Text(label),
      trailing: Icon(
        enabled ? Icons.check_circle_outline : Icons.cancel_outlined,
        color: enabled ? Colors.green : Colors.grey,
      ),
    );
  }
}

class _ChatPermissionsDialog extends StatefulWidget {
  const _ChatPermissionsDialog({required this.initial});

  final ChatPermissionsInfo initial;

  @override
  State<_ChatPermissionsDialog> createState() => _ChatPermissionsDialogState();
}

class _ChatPermissionsDialogState extends State<_ChatPermissionsDialog> {
  late ChatPermissionsInfo _permissions;

  @override
  void initState() {
    super.initState();
    _permissions = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Права участников'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Отправка сообщений'),
                value: _permissions.canSendBasicMessages,
                onChanged: (value) => setState(
                  () => _permissions =
                      _permissions.copyWith(canSendBasicMessages: value),
                ),
              ),
              SwitchListTile(
                title: const Text('Медиа'),
                value: _permissions.canSendPhotos,
                onChanged: (value) => setState(
                  () => _permissions = _permissions.copyWith(canSendPhotos: value),
                ),
              ),
              SwitchListTile(
                title: const Text('Опросы'),
                value: _permissions.canSendPolls,
                onChanged: (value) => setState(
                  () => _permissions = _permissions.copyWith(canSendPolls: value),
                ),
              ),
              SwitchListTile(
                title: const Text('Закрепление сообщений'),
                value: _permissions.canPinMessages,
                onChanged: (value) => setState(
                  () => _permissions =
                      _permissions.copyWith(canPinMessages: value),
                ),
              ),
              SwitchListTile(
                title: const Text('Приглашение пользователей'),
                value: _permissions.canInviteUsers,
                onChanged: (value) => setState(
                  () => _permissions =
                      _permissions.copyWith(canInviteUsers: value),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _permissions),
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

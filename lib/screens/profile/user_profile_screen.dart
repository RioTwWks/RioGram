import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/chat/chat_manager.dart';
import '../../core/secret/secret_chat_manager.dart';
import '../../core/theme/telegram_theme.dart';
import '../../core/user/contact_manager.dart';
import '../../core/user/profile_manager.dart';
import '../../models/user_models.dart';
import '../../widgets/telegram_settings_tile.dart';
import '../../widgets/user_status_subtitle.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key, required this.userId, this.chatId});

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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Username скопирован')));
  }

  Future<void> _confirmBlock(ProfileManager profile, bool isBlocked) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isBlocked ? 'Разблокировать?' : 'Заблокировать?'),
        content: Text(isBlocked ? 'Пользователь снова сможет писать вам.' : 'Пользователь не сможет писать вам и звонить.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(isBlocked ? 'Разблокировать' : 'Заблокировать')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (isBlocked) {
      profile.unblockUser(widget.userId);
    } else {
      profile.blockUser(widget.userId);
    }
  }

  List<Widget> _actionTiles({
    required BuildContext context,
    required ProfileManager profile,
    required ContactManager contacts,
    required UserSummary? user,
    required dynamic fullInfo,
    required TelegramThemeData tg,
  }) {
    final items = <({String title, Widget? leading, VoidCallback? onTap})>[];

    if (user != null && !user.isBot) {
      items.add((
        title: 'Секретный чат',
        leading: Icon(Icons.lock_outline, color: tg.accent),
        onTap: () {
          context.read<SecretChatManager>().createSecretChat(user.id);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Создание секретного чата…')));
        },
      ));
    }
    if (user != null && !user.isContact) {
      items.add((
        title: 'Добавить в контакты',
        leading: Icon(Icons.person_add_outlined, color: tg.accent),
        onTap: () {
          contacts.addContact(user.id, firstName: user.firstName, lastName: user.lastName);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Контакт добавлен')));
        },
      ));
    }
    if (user != null && user.isContact) {
      items.add((
        title: 'Удалить из контактов',
        leading: Icon(Icons.person_remove_outlined, color: tg.textSecondary),
        onTap: () {
          contacts.removeContact(user.id);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Контакт удалён')));
        },
      ));
    }
    items.add((
      title: (fullInfo?.isBlocked ?? false) ? 'Разблокировать' : 'Заблокировать',
      leading: Icon((fullInfo?.isBlocked ?? false) ? Icons.lock_open_outlined : Icons.block, color: Theme.of(context).colorScheme.error),
      onTap: () => _confirmBlock(profile, fullInfo?.isBlocked ?? false),
    ));
    if (widget.chatId != null) {
      items.add((title: 'Открыть чат', leading: Icon(Icons.chat_outlined, color: tg.accent), onTap: () => Navigator.of(context).pop()));
    }

    return items.asMap().entries.map((entry) {
      final item = entry.value;
      final isLast = entry.key == items.length - 1;
      return TelegramSettingsTile(title: item.title, leading: item.leading, showChevron: false, showDivider: !isLast, onTap: item.onTap);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileManager>();
    final contacts = context.read<ContactManager>();
    final chatManager = context.read<ChatManager>();
    final tg = context.telegramTheme;

    final user = profile.userById(widget.userId);
    final fullInfo = profile.fullInfoFor(widget.userId);
    final commonChats = profile.commonChatsFor(widget.userId);
    final isLoading = profile.isLoadingFullInfo(widget.userId) && user == null;

    if (isLoading) {
      return Scaffold(
        backgroundColor: telegramSettingsPageBackground(context),
        appBar: AppBar(title: const Text('Профиль')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: telegramSettingsPageBackground(context),
      appBar: AppBar(title: const Text('Профиль')),
      body: TelegramSettingsListView(
        children: [
          TelegramProfileHeader(
            displayName: user?.displayName ?? 'Пользователь',
            username: user?.username,
            phone: user?.isContact == true && user!.phoneNumber.isNotEmpty ? user.phoneNumber : null,
            avatarLocalPath: user?.avatarLocalPath,
            avatarFileId: user?.avatarFileId,
            onUsernameTap: user?.username != null ? () => _copyUsername(user!.username!) : null,
            subtitle: user != null
                ? UserStatusSubtitle(status: user.status, style: TextStyle(fontSize: TelegramFontSizes.chatSubtitle, color: tg.textSecondary))
                : null,
          ),
          if (fullInfo?.bio.isNotEmpty == true) ...[
            const TelegramSettingsSectionHeader('О себе'),
            TelegramSettingsGroup(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(fullInfo!.bio, style: TextStyle(fontSize: TelegramFontSizes.preview, color: tg.textPrimary)),
                ),
              ],
            ),
          ],
          if (user?.isBot == true && fullInfo != null) ...[
            const TelegramSettingsSectionHeader('Бот'),
            TelegramSettingsGroup(
              children: [
                if (fullInfo.botInfo.shortDescription.isNotEmpty)
                  Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: Text(fullInfo.botInfo.shortDescription)),
                if (fullInfo.botInfo.description.isNotEmpty)
                  Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 12), child: Text(fullInfo.botInfo.description)),
                ...fullInfo.botInfo.commands.asMap().entries.map((entry) {
                  final cmd = entry.value;
                  final isLast = entry.key == fullInfo.botInfo.commands.length - 1;
                  return TelegramSettingsTile(title: cmd.slashCommand, subtitle: cmd.description, showChevron: false, showDivider: !isLast);
                }),
              ],
            ),
          ],
          if (commonChats.isNotEmpty) ...[
            const TelegramSettingsSectionHeader('Общие чаты'),
            TelegramSettingsGroup(
              children: [
                ...commonChats.asMap().entries.map((entry) {
                  final chat = entry.value;
                  final isLast = entry.key == commonChats.length - 1;
                  return TelegramSettingsTile(
                    title: chat.title,
                    leading: Icon(Icons.groups_outlined, color: tg.textSecondary),
                    showChevron: false,
                    showDivider: !isLast,
                    onTap: () {
                      chatManager.openChat(chat.id);
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                  );
                }),
              ],
            ),
          ] else if (profile.isLoadingCommonChats(widget.userId))
            const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator())),
          const TelegramSettingsSectionHeader('Действия'),
          TelegramSettingsGroup(
            children: _actionTiles(context: context, profile: profile, contacts: contacts, user: user, fullInfo: fullInfo, tg: tg),
          ),
        ],
      ),
    );
  }
}
